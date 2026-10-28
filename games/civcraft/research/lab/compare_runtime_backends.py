#!/usr/bin/env python3
"""Paired Lua 5.3/LuaJIT conformance with bounded spawned workers."""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import Runtime, from_lua
from runner import source_manifest
import workers


def differences(a, b, path='', limit=12):
    if a == b:
        return []
    if isinstance(a, dict) and isinstance(b, dict):
        rows = []
        for key in sorted(a.keys() | b.keys(), key=str):
            rows.extend(differences(a.get(key), b.get(key), f'{path}.{key}', limit))
            if len(rows) >= limit:
                break
        return rows[:limit]
    if isinstance(a, list) and isinstance(b, list):
        rows = []
        for i in range(max(len(a), len(b))):
            rows.extend(differences(a[i] if i < len(a) else None, b[i] if i < len(b) else None, f'{path}[{i}]', limit))
            if len(rows) >= limit:
                break
        return rows[:limit]
    return [{'path': path, 'lua53': a, 'luajit21': b}]


def compare(config):
    runtimes = [Runtime(config | {'runtimeBackend': backend}) for backend in ('lua53', 'luajit21')]
    telemetry = [r.lua.globals().dofile('/lab/telemetry.lua').install(
        r.lua.table_from({'trace': True, 'actionBudget': 4096})) for r in runtimes]
    cpu = [0.0, 0.0]
    boundaries, observations = 0, 0
    digest = hashlib.sha256()

    def check(label):
        nonlocal boundaries, observations
        hashes = [r.state_hash() for r in runtimes]
        if hashes[0] != hashes[1]:
            delta = differences(from_lua(runtimes[0].state), from_lua(runtimes[1].state))
            trace_delta = differences(from_lua(telemetry[0].trace), from_lua(telemetry[1].trace))
            raise AssertionError(json.dumps({'boundary': label, 'stateDifferences': delta, 'traceDifferences': trace_delta}))
        digest.update((label + ':' + hashes[0]).encode())
        boundaries += 1
        if runtimes[0].state.round <= 5 or runtimes[0].state.round % 10 == 0:
            for player in range(len(config['players'])):
                assert runtimes[0].observe(player) == runtimes[1].observe(player), f'{label}: observer {player}'
                observations += 1
            assert runtimes[0].metrics() == runtimes[1].metrics(), f'{label}: metrics'

    check('initial')
    while not runtimes[0].finished():
        # Alternate call order by round to reduce a consistent timing-order bias.
        for operation in ('pump', 'advance'):
            if operation == 'advance' and (runtimes[0].finished() or runtimes[0].state.round >= config['maxRounds']):
                break
            for i in ((0, 1) if runtimes[0].state.round % 2 else (1, 0)):
                started = time.process_time()
                getattr(runtimes[i], operation)()
                cpu[i] += time.process_time() - started
            check(f'{operation}:{int(runtimes[0].state.round)}')
        if runtimes[0].finished() or runtimes[0].state.round >= config['maxRounds']:
            break
    traces = [from_lua(t.trace) for t in telemetry]
    assert traces[0] == traces[1], 'Ordered action trace mismatch'
    return {'config': config, 'status': 'finished' if runtimes[0].finished() else 'censored',
            'round': int(runtimes[0].state.round), 'victoryReason': runtimes[0].state.victoryReason,
            'winnerIds': from_lua(runtimes[0].state.winnerIDs) or [],
            'boundaryChecks': boundaries, 'observerChecks': observations,
            'actionAttempts': int(telemetry[0].attempted), 'traceSha256': hashlib.sha256(
                json.dumps(traces[0], sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
            'boundaryDigest': digest.hexdigest(), 'finalStateHash': runtimes[0].state_hash(),
            'cpuSeconds': dict(zip(('lua53', 'luajit21'), cpu)), 'cpuSpeedup': cpu[0] / cpu[1],
            'jitVersion': runtimes[1].lua.eval('jit.version'), 'parity': True}


def worker(connection, config):
    try:
        try:
            result = compare(config)
        except Exception as exc:
            result = {'config': config, 'status': 'error', 'error': f'{type(exc).__name__}: {exc}', 'parity': False}
        connection.send(result)
    finally:
        connection.close()


def configs():
    rows = []
    for rules in ('baseline', 'p1'):
        for count, seed, map_type in ((2, 611953, 'pangaea'), (4, 817069, 'archipelago')):
            rows.append({'seed': seed, 'contentRules': rules, 'players': [
                {'civilization': civ} for civ in ('scholar', 'forge', 'iron', 'merchant')[:count]],
                'mapType': map_type, 'mapSize': 'compact', 'hostileMode': 'off',
                'maxRounds': 180, 'wallSeconds': 240})
        for seed, map_type in ((753979, 'highlands'), (932081, 'continents')):
            rows.append({'seed': seed, 'contentRules': rules, 'players': [
                {'civilization': civ} for civ in ('verdant', 'mariner', 'sentinel')],
                'mapType': map_type, 'mapSize': 'compact', 'hostileMode': 'standard',
                'maxRounds': 8, 'wallSeconds': 60})
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'results/runtime_backend_parity.json')
    parser.add_argument('--cases', type=int, nargs='+', help='Zero-based case indices; default all eight')
    args = parser.parse_args()
    before = source_manifest()
    workers._worker = worker
    started = time.perf_counter()
    cases = configs()
    if args.cases is not None:
        cases = [cases[i] for i in args.cases]
    results = workers.run_bounded(cases, args.workers)
    after = source_manifest()
    record = {'source': before, 'sourceUnchanged': before == after, 'workers': args.workers,
              'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'elapsedSeconds': time.perf_counter() - started, 'matches': results,
              'limits': ['Count hooks under compiled traces are not equivalent instruction ceilings; external worker wall budgets remain mandatory.',
                         'Timings include pump/advance only; conformance hashing, observations, metrics, initialization and trace conversion are excluded.',
                         'Hostile cases are eight-round prefixes, not full stability evidence.']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'output': str(args.output), 'sourceUnchanged': before == after,
                      'matches': [{k: row.get(k) for k in ('status', 'round', 'parity', 'error', 'cpuSpeedup')} for row in results]}), flush=True)
    if before != after or not all(row.get('parity') for row in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
