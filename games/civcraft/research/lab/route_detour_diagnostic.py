#!/usr/bin/env python3
"""Shared-checkpoint operational counterfactual; unchanged rules and legal choices."""
import json
import time
from pathlib import Path

from coordinated_siege_study import HERE, ROOT, SiegeRuntime, base_config, hash_file
from operational_siege_diagnostic import attach_probe
import military_competence_benchmark as military
import runner
import workers
from runtime import from_lua

POLICY = HERE/'route_detour_policy.lua'


class BranchRuntime:
    def __new__(cls, config, *args, **kwargs):
        runtime = SiegeRuntime(config, *args, **kwargs)
        runtime.restore(config['researchCheckpoint'])
        if config['detourArm'] == 'route':
            runtime.call(runtime.lua.globals().dofile(
                '/games/civcraft/research/lab/route_detour_policy.lua').install)
        attach_probe(runtime, config['conquestSeat'])
        cls.last = runtime
        return runtime


def worker(connection, config):
    try:
        if config['detourArm'] == 'prefix':
            runtime = SiegeRuntime(config)
            while runtime.state.round < 80:
                runtime.pump()
                if runtime.finished():
                    raise RuntimeError('Match finished before checkpoint')
                runtime.advance()
            runtime.pump()
            result = {'status': 'checkpoint', 'round': int(runtime.state.round),
                      'checkpoint': runtime.canonical_state(), 'checkpointHash': runtime.state_hash()}
        else:
            runner.Runtime = BranchRuntime
            result = runner.play(config)
            runtime = BranchRuntime.last
            result['operationalRecords'] = from_lua(runtime.operational_records) or []
            result['operationalSnapshots'] = runtime.operational_snapshots
            result['capturesSinceCheckpoint'] = from_lua(runtime.capture_events) or []
        connection.send(result)
    except Exception as exc:
        connection.send({'status': 'error', 'error': repr(exc)})
    finally:
        connection.close()


def main():
    config = base_config(923671, 1, 'coordinated')
    before = runner.source_manifest()
    files = (Path(__file__), POLICY, HERE/'operational_probe.lua', HERE/'operational_siege_diagnostic.py',
             HERE/'coordinated_siege_policy.lua', HERE/'coordinated_siege_study.py', Path(military.__file__))
    hashes = {str(p.relative_to(ROOT)): hash_file(p) for p in files}
    expected_path = HERE/'results/coordinated_siege_holdout.json'
    expected = next(m for m in json.loads(expected_path.read_text())['matches']
                    if m['seed'] == 923671 and m['seat'] == 1 and m['arm'] == 'coordinated')
    started = time.perf_counter()
    previous_worker = workers._worker
    workers._worker = worker
    try:
        prefix = workers.run_bounded([dict(config, detourArm='prefix')], 1)[0]
        if prefix['status'] != 'checkpoint':
            raise RuntimeError(f'Checkpoint generation failed: {prefix}')
        configs = [dict(config, detourArm=arm, researchCheckpoint=prefix['checkpoint'])
                   for arm in ('control', 'route')]
        matches = workers.run_bounded(configs, 2)
    finally:
        workers._worker = previous_worker
    record = {'purpose': 'Round-80 route-following counterfactual on a known failed siege case',
              'sourceManifest': before, 'researchHashes': hashes,
              'sourceUnchanged': before == runner.source_manifest() and hashes == {
                  str(p.relative_to(ROOT)): hash_file(p) for p in files},
              'checkpointHash': prefix['checkpointHash'], 'expectedArtifactSha256': hash_file(expected_path),
              'expectedControlFinalStateHash': expected['finalStateHash'],
              'controlFinalStateEqual': matches[0].get('finalStateHash') == expected['finalStateHash'],
              'branchesInitialStateEqual': all(m.get('initialStateHash') == prefix['checkpointHash'] for m in matches),
              'elapsedSeconds': time.perf_counter()-started, 'matches': matches}
    raw = HERE/'runs/route_detour_diagnostic.json'
    raw.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False)+'\n')
    compact = {k:v for k,v in record.items() if k != 'matches'}
    compact.update(rawArtifact=str(raw), rawSha256=hash_file(raw), matches=[])
    for match in matches:
        records = match.get('operationalRecords', [])
        compact['matches'].append({**{k:match.get(k) for k in ('status', 'error', 'round',
            'winnerIds', 'victoryReason', 'finalStateHash', 'capturesSinceCheckpoint')},
            'arm': match.get('config', {}).get('detourArm'),
            'siegeRecords': [r for r in records if r['siege']],
            'checkpoints': [s for s in match.get('operationalSnapshots', [])
                            if s['round'] % 10 == 0 or s['round'] == match.get('round')],
            'dispatches': {k:v for k,v in match.get('dispatches', {}).items() if k != 'trace'}})
    output = HERE/'results/route_detour_diagnostic.json'
    output.write_text(json.dumps(compact, indent=2, sort_keys=True, allow_nan=False)+'\n')
    print(json.dumps({'output': str(output), 'controlFinalStateEqual': record['controlFinalStateEqual'],
        'branchesInitialStateEqual': record['branchesInitialStateEqual'], 'sourceUnchanged': record['sourceUnchanged'],
        'matches': [{k:m[k] for k in ('arm', 'status', 'round', 'victoryReason', 'capturesSinceCheckpoint')}
                    for m in compact['matches']]}))
    if not all(record[k] for k in ('controlFinalStateEqual', 'branchesInitialStateEqual', 'sourceUnchanged')) \
            or any(m['status'] != 'finished' for m in matches):
        raise SystemExit('Counterfactual failed fidelity/source/completion checks')


if __name__ == '__main__':
    main()
