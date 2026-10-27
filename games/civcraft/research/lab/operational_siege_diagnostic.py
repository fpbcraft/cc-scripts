#!/usr/bin/env python3
"""Observe a previously evaluated match and require exact final-state equivalence."""
import hashlib
import json
import time
from pathlib import Path

from coordinated_siege_study import HERE, ROOT, POLICY, SiegeRuntime, base_config, hash_file
import military_competence_benchmark as military
import runner
import workers
from runtime import from_lua


def attach_probe(runtime, actor):
    runtime.operational_records = runtime.call(runtime.lua.globals().dofile(
        '/games/civcraft/research/lab/operational_probe.lua').install, actor)
    runtime.operational_snapshots = []
    original_pump = runtime.pump

    def observe_pump():
        original_pump()
        if runtime.state.round >= 50:
            runtime.operational_snapshots.append(military._diagnostic_snapshot(runtime, actor))

    runtime.pump = observe_pump


class OperationalRuntime:
    def __new__(cls, config, *args, **kwargs):
        runtime = SiegeRuntime(config, *args, **kwargs)
        attach_probe(runtime, config['conquestSeat'])
        cls.last = runtime
        return runtime


def worker(connection, config):
    try:
        runner.Runtime = OperationalRuntime
        result = runner.play(config)
        runtime = OperationalRuntime.last
        result['operationalRecords'] = from_lua(runtime.operational_records) or []
        result['operationalSnapshots'] = runtime.operational_snapshots
        result['captures'] = from_lua(runtime.capture_events) or []
        connection.send(result)
    except Exception as exc:
        connection.send({'config': config, 'status': 'error', 'error': repr(exc)})
    finally:
        connection.close()


def main():
    config = base_config(923671, 1, 'coordinated')
    expected_path = HERE/'results/coordinated_siege_holdout.json'
    previous = json.loads(expected_path.read_text())
    expected = next(m for m in previous['matches'] if m['seed'] == 923671
                    and m['seat'] == 1 and m['arm'] == 'coordinated')
    source = runner.source_manifest()
    files = (Path(__file__), HERE/'operational_probe.lua', POLICY,
             HERE/'coordinated_siege_study.py', Path(military.__file__))
    hashes = {str(p.relative_to(ROOT)): hash_file(p) for p in files}
    old_worker = workers._worker
    workers._worker = worker
    started = time.perf_counter()
    try:
        match = workers.run_bounded([config], 1)[0]
    finally:
        workers._worker = old_worker
    record = {'purpose': 'Read-only operational diagnostic of coordinated siege failure',
              'config': config, 'sourceManifest': source, 'researchHashes': hashes,
              'sourceUnchanged': source == runner.source_manifest() and hashes == {
                  str(p.relative_to(ROOT)): hash_file(p) for p in files},
              'expectedArtifactSha256': hash_file(expected_path),
              'expectedFinalStateHash': expected['finalStateHash'],
              'finalStateEqual': match.get('finalStateHash') == expected['finalStateHash'],
              'elapsedSeconds': time.perf_counter()-started, 'match': match}
    raw = HERE/'runs/operational_siege_diagnostic.json'
    raw.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False)+'\n')
    compact = {k:v for k,v in record.items() if k != 'match'}
    records = match.get('operationalRecords', [])
    siege = [r for r in records if r['siege']]
    compact.update(rawArtifact=str(raw), rawSha256=hash_file(raw),
        status=match['status'], round=match.get('round'), victoryReason=match.get('victoryReason'),
        captures=match.get('captures', []),
        siegeRecords=siege,
        checkpoints=[s for s in match.get('operationalSnapshots', [])
                     if s['round'] % 10 == 0 or s['round'] == match.get('round')],
        limits=['One known evaluation cell; diagnostic, not held-out strength evidence.',
                'Probe records the first ranked decision per unit/round, plus its call count.',
                'Range-route costs use discovered terrain, a 64-cost/1024-node bound, and geometric range, not line of sight.',
                'Privileged post-turn snapshots are diagnostic only and are never consumed by a playing policy.'])
    output = HERE/'results/operational_siege_diagnostic.json'
    output.write_text(json.dumps(compact, indent=2, sort_keys=True, allow_nan=False)+'\n')
    print(json.dumps({'output': str(output), 'status': match['status'],
        'finalStateEqual': record['finalStateEqual'], 'sourceUnchanged': record['sourceUnchanged'],
        'siegeDecisionSnapshots': len(siege), 'error': match.get('error')}))
    if not record['sourceUnchanged'] or not record['finalStateEqual'] or match['status'] != 'finished':
        raise SystemExit('Operational diagnostic failed equivalence/source/completion checks')


if __name__ == '__main__':
    main()
