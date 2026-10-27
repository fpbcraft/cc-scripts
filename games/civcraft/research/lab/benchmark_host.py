#!/usr/bin/env python3
"""Isolated whole-game CPU/RSS/throughput study; no alternative game model."""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import resource
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import Runtime
from runner import source_manifest
import workers

LAST_RUNTIME = None


class ProfiledRuntime(Runtime):
    def __init__(self, *args, **kwargs):
        global LAST_RUNTIME
        self.timings = {}
        self.sampled_lua_peak_kib = 0
        self._measure('initialization', lambda: super(ProfiledRuntime, self).__init__(*args, **kwargs))
        self.memory_count = self.lua.eval('function() return collectgarbage("count") end')
        self._sample_memory()
        LAST_RUNTIME = self

    def _measure(self, phase, function):
        wall, cpu = time.perf_counter(), time.process_time()
        try:
            return function()
        finally:
            row = self.timings.setdefault(phase, {'wallSeconds': 0, 'cpuSeconds': 0, 'calls': 0})
            row['wallSeconds'] += time.perf_counter() - wall
            row['cpuSeconds'] += time.process_time() - cpu
            row['calls'] += 1

    def _sample_memory(self):
        self.sampled_lua_peak_kib = max(self.sampled_lua_peak_kib, self.memory_count())

    def pump(self):
        result = self._measure('actorPump', super().pump)
        self._sample_memory()
        return result

    def advance(self):
        return self._measure('roundBoundary', super().advance)

    def metrics(self):
        return self._measure('metricsAndLuaConversion', super().metrics)

    def canonical_state(self):
        return self._measure('canonicalEncoding', super().canonical_state)


def profiled_worker(connection, config):
    import runner
    runner.Runtime = ProfiledRuntime
    wall, cpu = time.perf_counter(), time.process_time()
    try:
        result = runner.play(config)
        result['profile'] = {'phases': LAST_RUNTIME.timings if LAST_RUNTIME else {},
                             'sampledLuaPeakKiB': LAST_RUNTIME.sampled_lua_peak_kib if LAST_RUNTIME else None,
                             'workerWallSeconds': time.perf_counter() - wall,
                             'workerCpuSeconds': time.process_time() - cpu,
                             'peakProcessRssBytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss *
                             (1 if sys.platform == 'darwin' else 1024)}
        start_wall, start_cpu = time.perf_counter(), time.process_time()
        encoded = json.dumps(result, sort_keys=True, allow_nan=False)
        result['profile']['jsonEncoding'] = {'wallSeconds': time.perf_counter() - start_wall,
                                             'cpuSeconds': time.process_time() - start_cpu,
                                             'bytes': len(encoded.encode())}
        connection.send(result)
    finally:
        connection.close()


def diagnostic(command):
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT, timeout=10).strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return f'unavailable: {exc}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, default=Path('/tmp/civcraft-host-benchmark.raw.json'))
    parser.add_argument('--summary', type=Path, default=HERE / 'results/host_benchmark.json')
    args = parser.parse_args()
    policy = json.loads((HERE / 'results/strategy_search_pilot.json').read_text())['championHoldout']['policy']
    configs = [{'seed': seed, 'mapSize': 'compact', 'mapType': 'pangaea', 'hostileMode': 'off',
                'maxRounds': 180, 'telemetryEvery': 10, 'wallSeconds': 180,
                'players': [{'civilization': 'forge', 'policy': policy} for _ in range(count)]}
               for count in (2, 4) for seed in (404977, 616039)]
    source = source_manifest()
    before = diagnostic(['pmset', '-g', 'therm']) if sys.platform == 'darwin' else 'not macOS'
    batches = []
    original = workers._worker
    workers._worker = profiled_worker
    try:
        # Each batch runs the identical four worlds in fresh spawned processes.
        for count in (1, 2, 4):
            started = time.perf_counter()
            results = workers.run_bounded(configs, count)
            elapsed = time.perf_counter() - started
            batches.append({'workers': count, 'elapsedSeconds': elapsed, 'matches': results})
            print(json.dumps({'workers': count, 'elapsedSeconds': elapsed,
                              'statuses': [m['status'] for m in results]}), flush=True)
    finally:
        workers._worker = original
    raw = {'source': source, 'sourceChangedDuringRun': source != source_manifest(),
           'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
           'configurations': configs, 'batches': batches}
    args.raw.write_text(json.dumps(raw, indent=2, sort_keys=True) + '\n')
    expected = [m.get('finalStateHash') for m in batches[0]['matches']]
    cells = []
    for batch in batches:
        matches = batch['matches']
        profiles = [m['profile'] for m in matches if 'profile' in m]
        phases = {}
        for record in profiles:
            for key, values in record['phases'].items():
                row = phases.setdefault(key, {'wallSeconds': 0, 'cpuSeconds': 0, 'calls': 0})
                for name in row:
                    row[name] += values[name]
        finished = sum(m['status'] == 'finished' for m in matches)
        cells.append({'workers': batch['workers'], 'attempted': len(matches), 'finished': finished,
                      'elapsedSeconds': batch['elapsedSeconds'],
                      'completedGamesPerSecond': finished / batch['elapsedSeconds'],
                      'workerCpuSeconds': sum(p['workerCpuSeconds'] for p in profiles),
                      'maxSingleWorkerRssBytes': max((p['peakProcessRssBytes'] for p in profiles), default=0),
                      'peakSampledLuaKiB': max((p['sampledLuaPeakKiB'] for p in profiles), default=0),
                      'phasesSumAcrossWorkers': phases,
                      'sameFinalHashesAsOneWorker': [m.get('finalStateHash') for m in matches] == expected,
                      'outcomes': [{'players': len(m['config']['players']), 'seed': m['config']['seed'],
                                    'status': m['status'], 'round': m.get('round'),
                                    'reason': m.get('victoryReason'), 'hash': m.get('finalStateHash')}
                                   for m in matches]})
    summary = {'purpose': 'Local short isolated 1/2/4-worker scaling study, not sustained throughput guarantee',
               'source': source, 'sourceChangedDuringRun': raw['sourceChangedDuringRun'],
               'scriptSha256': raw['scriptSha256'], 'rawArtifact': str(args.raw),
               'host': {'machine': platform.machine(), 'python': platform.python_version(),
                        'hardware': diagnostic(['sysctl', '-n', 'machdep.cpu.brand_string', 'hw.memsize', 'hw.logicalcpu']),
                        'thermalDiagnosticBefore': before,
                        'thermalDiagnosticAfter': diagnostic(['pmset', '-g', 'therm'])},
               'cells': cells,
               'limits': ['Four games per worker level; only two seeds, compact Pangaea, no hostiles.',
                          'Includes startup, telemetry and IPC; CPU phases exclude import/startup before worker timer.',
                          'RSS is each process lifetime high-water mark, not simultaneous aggregate memory.',
                          'Lua memory is sampled after initialization/actor pumps, not an allocation maximum.',
                          'Short ordered 1/2/4 runs cannot establish long-term thermal stability or 10000-game rate.',
                          'No other research simulation should run concurrently; OS/user background activity is uncontrolled.']}
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n')
    if raw['sourceChangedDuringRun'] or any(c['finished'] != c['attempted'] or
                                           not c['sameFinalHashesAsOneWorker'] for c in cells):
        raise SystemExit('Benchmark integrity/completion failure; inspect raw records')


if __name__ == '__main__':
    main()
