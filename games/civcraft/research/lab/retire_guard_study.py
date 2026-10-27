#!/usr/bin/env python3
"""Known-case recovery decision: retire obsolete guards instead of losing new siege."""
import json
import time
from pathlib import Path

from coordinated_siege_study import HERE, ROOT, SiegeRuntime, base_config, hash_file
from operational_siege_diagnostic import attach_probe
import military_competence_benchmark as military
import runner
import workers
from runtime import from_lua

POLICY = HERE/'retire_guard_intervention.lua'


class RetirementRuntime:
    def __new__(cls, config, *args, **kwargs):
        runtime = SiegeRuntime(config, *args, **kwargs)
        runtime.restore(config['researchCheckpoint'])
        if config['retireArm'] == 'retire_and_route':
            runtime.call(runtime.lua.globals().dofile(
                '/games/civcraft/research/lab/route_detour_policy.lua').install)
        callbacks, data = runtime.call(runtime.lua.globals().dofile(
            '/games/civcraft/research/lab/retire_guard_intervention.lua').install, 1, 81, 4)
        runtime.retirement_data = data
        runtime.pump = lambda: runtime.call(runtime.engine.pump, runtime.state, callbacks)
        attach_probe(runtime, 1)
        cls.last = runtime
        return runtime


def worker(connection, config):
    try:
        runner.Runtime = RetirementRuntime
        result = runner.play(config)
        runtime = RetirementRuntime.last
        result.update(retirement=from_lua(runtime.retirement_data),
            operationalSnapshots=runtime.operational_snapshots,
            operationalRecords=from_lua(runtime.operational_records) or [],
            capturesSinceCheckpoint=from_lua(runtime.capture_events) or [])
        connection.send(result)
    except Exception as exc:
        connection.send({'config':config, 'status':'error', 'error':repr(exc)})
    finally:
        connection.close()


def summarize(match, arm):
    snapshots = match.get('operationalSnapshots', [])
    records = match.get('operationalRecords', [])
    return {**{k:match.get(k) for k in ('status', 'error', 'round', 'winnerIds',
        'victoryReason', 'initialStateHash', 'finalStateHash', 'capturesSinceCheckpoint', 'retirement')},
        'arm':arm,
        'firstSiegeLastSeen': {str(unit_id):max((s['round'] for s in snapshots
            if any(u['id'] == unit_id for u in s['militaryUnits'])), default=None) for unit_id in (36,37)},
        'siegeFirstDecisionsWithWallForecast':sum(r['siege'] and r['forecastsWithWallDamage'] > 0 for r in records),
        'checkpoints':[s for s in snapshots if s['round'] in (80,81,82,90,100,110,120)
                       or s['round'] == match.get('round')],
        'finalPlayerMetrics': match.get('turns', [{}])[-1].get('players', []),
        'dispatches':{k:v for k,v in match.get('dispatches', {}).items() if k != 'trace'}}


def main():
    reference_path = HERE/'runs/route_detour_diagnostic.json'
    reference = json.loads(reference_path.read_text())
    assert reference['sourceUnchanged'] and reference['controlFinalStateEqual']
    checkpoint = reference['matches'][0]['config']['researchCheckpoint']
    before = runner.source_manifest()
    assert before == reference['sourceManifest'], 'Gameplay/runner changed since reference controls'
    files = (Path(__file__), POLICY, HERE/'route_detour_policy.lua', HERE/'operational_probe.lua',
             HERE/'operational_siege_diagnostic.py', HERE/'coordinated_siege_policy.lua',
             HERE/'coordinated_siege_study.py', Path(military.__file__))
    hashes = {str(p.relative_to(ROOT)):hash_file(p) for p in files}
    for relative in ('route_detour_policy.lua','operational_probe.lua','coordinated_siege_policy.lua',
                     'coordinated_siege_study.py','military_competence_benchmark.py'):
        p = HERE/relative
        assert hashes[str(p.relative_to(ROOT))] == reference['researchHashes'][str(p.relative_to(ROOT))]
    configs = [dict(base_config(923671,1,'coordinated'), researchCheckpoint=checkpoint, retireArm=arm)
               for arm in ('retire_guards','retire_and_route')]
    old_worker = workers._worker
    workers._worker = worker
    started = time.perf_counter()
    try:
        matches = workers.run_bounded(configs, 2)
    finally:
        workers._worker = old_worker
    unchanged = before == runner.source_manifest() and hashes == {
        str(p.relative_to(ROOT)):hash_file(p) for p in files}
    record = {'purpose':'Same-checkpoint voluntary retirement and route recovery factorial',
        'sourceManifest':before, 'researchHashes':hashes, 'sourceUnchanged':unchanged,
        'referenceArtifact':str(reference_path), 'referenceArtifactSha256':hash_file(reference_path),
        'checkpointHash':reference['checkpointHash'], 'elapsedSeconds':time.perf_counter()-started,
        'matches':matches}
    raw = HERE/'runs/retire_guard_study.json'
    raw.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False)+'\n')
    compact = {k:v for k,v in record.items() if k != 'matches'}
    compact.update(rawArtifact=str(raw), rawSha256=hash_file(raw), matches=[])
    for match in reference['matches']:
        compact['matches'].append(summarize(match, match['config']['detourArm']))
    for match, config in zip(matches, configs, strict=True):
        compact['matches'].append(summarize(match, config['retireArm']))
    output = HERE/'results/retire_guard_study.json'
    output.write_text(json.dumps(compact, indent=2, sort_keys=True, allow_nan=False)+'\n')
    print(json.dumps({'output':str(output),'sourceUnchanged':unchanged,
        'matches':[{k:m[k] for k in ('arm','status','round','victoryReason','firstSiegeLastSeen','retirement')}
                   for m in compact['matches']]}))
    if not unchanged or any(m['status'] != 'finished' or m['initialStateHash'] != reference['checkpointHash']
            or len(m['retirement']['requests']) != 4 or not all(r['accepted'] for r in m['retirement']['requests'])
            for m in matches):
        raise SystemExit('Retirement study failed source/fidelity/legality/completion checks')


if __name__ == '__main__':
    main()
