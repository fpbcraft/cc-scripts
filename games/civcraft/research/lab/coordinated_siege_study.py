#!/usr/bin/env python3
"""Paired research-only siege composition/tactics ablation, with held-out maps."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
import military_competence_benchmark as military
import runner
import workers
from runtime import from_lua

POLICY = HERE / 'coordinated_siege_policy.lua'
PARAMETERS = {'siegeCount': 3, 'attackQuorum': 2, 'shotBonus': 120}
SEEDS = (387493, 923671)


class SiegeRuntime:
    def __new__(cls, config, *args, **kwargs):
        runtime = military.MilitaryHookRuntime(config, *args, **kwargs)
        if config['siegeArm'] == 'coordinated':
            policy = runtime.lua.globals().dofile(
                '/games/civcraft/research/lab/coordinated_siege_policy.lua')
            runtime.call(policy.install, runtime.lua.table_from(PARAMETERS))
        runtime.capture_events = runtime.call(runtime.lua.eval('''function()
            local actions = dofile('/games/civcraft/actions.lua')
            local original = actions.apply
            local events = {}
            actions.apply = function(state, actor, request, systems)
                local owners = {}
                for _, city in ipairs(state.cities or {}) do owners[city.id] = city.owner end
                local ok, why, outcome = original(state, actor, request, systems)
                if ok then
                    for _, city in ipairs(state.cities or {}) do
                        local previous = owners[city.id]
                        if previous ~= nil and previous ~= city.owner then
                            events[#events+1] = {round=state.round, actor=actor,
                                cityId=city.id, previousOwner=previous, owner=city.owner}
                        end
                    end
                end
                return ok, why, outcome
            end
            return events
        end'''))
        cls.last = runtime
        return runtime


def fixture(config):
    runtime = SiegeRuntime(config)
    telemetry = runtime.lua.globals().dofile('/lab/telemetry.lua').install(
        runtime.lua.table_from({'actionBudget': 4096, 'trace': True}))
    military._fixture_setup(runtime, config['scenario'])
    initial = runtime.state_hash()
    snapshots = [military._fixture_snapshot(runtime)]
    for _ in range(8):
        runtime.pump()
        snapshots.append(military._fixture_snapshot(runtime))
        if runtime.finished():
            break
        runtime.advance()
    return {'config': config, 'status': 'finished' if runtime.finished() else 'scenario_horizon',
            'snapshots': snapshots, 'initialStateHash': initial,
            'finalStateHash': runtime.state_hash(), 'dispatches': from_lua(telemetry),
            'captures': from_lua(runtime.capture_events) or []}


def worker(connection, config):
    try:
        if config.get('scenario'):
            result = fixture(config)
        else:
            runner.Runtime = SiegeRuntime
            result = runner.play(config)
            result['captures'] = from_lua(SiegeRuntime.last.capture_events) or []
        connection.send(result)
    except Exception as exc:
        connection.send({'config': config, 'status': 'error', 'error': repr(exc)})
    finally:
        connection.close()


def base_config(seed, seat, arm):
    players = [{'civilization': 'forge', 'ai': True,
                'policy': {'version': 1, 'goal': 'industrial'}} for _ in range(2)]
    players[seat]['policy']['goal'] = 'conquest'
    return {'seed': seed, 'mapSize': 'compact', 'mapType': 'pangaea',
            'hostileMode': 'off', 'maxRounds': 180, 'wallSeconds': 180,
            'telemetryEvery': 1, 'trace': True, 'players': players,
            'timelySiegeResearch': True, 'siegeAttackHook': False,
            'siegeArm': arm, 'conquestSeat': seat}


def hash_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(match):
    config = match['config']
    target = config['conquestSeat']
    output = {key: match.get(key) for key in
              ('status', 'error', 'round', 'victoryReason', 'winnerIds',
               'initialStateHash', 'finalStateHash', 'elapsedSeconds')}
    output.update(seed=config['seed'], seat=target, arm=config['siegeArm'],
                  scenario=config.get('scenario'))
    output['captures'] = match.get('captures', [])
    output['registeredOpponentCaptures'] = [event for event in output['captures']
        if event['actor'] == target and event['owner'] == target
        and event['previousOwner'] in (0, 1) and event['previousOwner'] != target]
    snapshots = match.get('snapshots', [])
    if snapshots:
        enemy_city_ids = {c['id'] for c in snapshots[0]['cities'] if c['owner'] == 1}
        output['firstCaptureRound'] = next((s['round'] for s in snapshots
            if any(c['id'] in enemy_city_ids and c['owner'] == 0 for c in s['cities'])), None)
        output['wallHistory'] = [[s['round'], c['wallHP']] for s in snapshots
            for c in s['cities'] if c['id'] in enemy_city_ids]
    turns = match.get('turns', [])
    if turns:
        initial = next(p for p in turns[0]['players'] if p['id'] == target)
        output['firstCityCountIncreaseRound'] = next((s['round'] for s in turns
            if any(p['id'] == target and len(p['cities']) > len(initial['cities']) for p in s['players'])), None)
        # City count increases include founding: never label these captures.
        output['finalPlayerMetrics'] = turns[-1]['players']
    trace = match.get('dispatches', {}).get('trace', [])
    queues = [item for item in trace if item['actor'] == target and item['accepted']
              and item['request']['action'] == 'queue' and item['request'].get('kind') == 'unit']
    output['queuedUnitKinds'] = dict(Counter(item['request']['id'] for item in queues))
    output['firstSiegeQueueRound'] = next((item['round'] for item in queues
        if item['request']['id'] in ('catapult', 'heavysiege')), None)
    output['firstDeclarationRound'] = next((item['round'] for item in trace
        if item['actor'] == target and item['accepted'] and item['request']['action'] == 'declareWar'), None)
    output['dispatches'] = {k: v for k, v in match.get('dispatches', {}).items() if k != 'trace'}
    return output


def reduce_result(raw):
    record = json.loads(raw.read_text())
    compact = {k: v for k, v in record.items() if k != 'matches'}
    compact.update(rawArtifact=str(raw), rawSha256=hash_file(raw),
                   analysisDriverSha256=hash_file(Path(__file__)),
                   matches=[summarize(match) for match in record['matches']])
    output = HERE / 'results' / raw.name
    output.write_text(json.dumps(compact, indent=2, sort_keys=True) + '\n')
    return output, compact


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', choices=('fixtures', 'holdout'))
    parser.add_argument('--reduce', type=Path, help='Reduce an existing raw artifact without launching games')
    parser.add_argument('--workers', type=int, default=2, choices=(1, 2, 3, 4))
    args = parser.parse_args()
    if args.reduce:
        output, _ = reduce_result(args.reduce)
        print(json.dumps({'output': str(output), 'gamesLaunched': 0}))
        return
    if not args.phase:
        parser.error('--phase is required unless --reduce is supplied')
    before = runner.source_manifest()
    files = (Path(__file__), POLICY, Path(military.__file__))
    hashes = {str(p.relative_to(ROOT)): hash_file(p) for p in files}
    if args.phase == 'fixtures':
        configs = [dict(base_config(95117, 0, arm), scenario=scenario)
                   for scenario in ('siege_breach', 'fortified_capture', 'capital_defense', 'settler_protection')
                   for arm in ('existing_hooks', 'coordinated')]
    else:
        configs = [base_config(seed, seat, arm) for seed in SEEDS for seat in (0, 1)
                   for arm in ('existing_hooks', 'coordinated')]
    started = time.perf_counter()
    old_worker = workers._worker
    workers._worker = worker
    try:
        matches = workers.run_bounded(configs, args.workers)
    finally:
        workers._worker = old_worker
    result = {'schemaVersion': 1, 'purpose': 'Research-only coordinated siege ablation',
              'phase': args.phase, 'parametersFixedBeforeHoldout': PARAMETERS,
              'sourceManifest': before, 'researchHashes': hashes,
              'sourceChangedDuringRun': before != runner.source_manifest()
                  or hashes != {str(p.relative_to(ROOT)): hash_file(p) for p in files},
              'workers': args.workers, 'elapsedSeconds': time.perf_counter() - started,
              'matches': matches}
    raw = HERE / 'runs' / f'coordinated_siege_{args.phase}.json'
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    output, compact = reduce_result(raw)
    print(json.dumps({'output': str(output), 'sourceChanged': result['sourceChangedDuringRun'],
                      'statuses': dict(Counter(m['status'] for m in matches)),
                      'matches': [{k: m.get(k) for k in ('seed', 'seat', 'arm', 'scenario',
                          'status', 'firstCaptureRound', 'firstSiegeQueueRound', 'round', 'victoryReason')}
                                  for m in compact['matches']]}))
    if result['sourceChangedDuringRun'] or any(m['status'] in ('error', 'timeout') for m in matches):
        raise SystemExit('Study failed; inspect recorded errors/source changes')


if __name__ == '__main__':
    main()
