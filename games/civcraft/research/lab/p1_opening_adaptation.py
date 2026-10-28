#!/usr/bin/env python3
"""Restricted opening adaptation: select on training maps, evaluate on fresh maps.

Only one validated initial queue order changes. No assets, prices, visibility,
movement, later policies or authoritative action allowances are modified.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import from_lua
from runner import source_manifest
from p1_pacing_study import OpeningRuntime, atomic
import workers

MAPS = {
    'train': [('pangaea', 271003), ('continents', 382021), ('archipelago', 493031), ('highlands', 604043)],
    'evaluate': [('pangaea', 715049), ('continents', 826061), ('archipelago', 937069), ('highlands', 148079)],
}
SELECTION_RULE = ('Per economy maximize mean target fractional win credit over four map blocks, '
                  'then mean explored tiles at round 30, then earlier second city, '
                  'then default/scout/farm priority. Fixed before training; no held-out selection.')
SITE_PROBE = '''function(view, actor)
 local Settlement = dofile('/games/civcraft/ai_settlement.lua')
 local player
 for _, p in ipairs(view.players) do if p.id == actor then player = p end end
 local sites = 0
 for key in pairs(view.world.tiles) do
  local x,y = key:match('^(%d+):(%d+)$')
  if x and Settlement.value(view, player, tonumber(x), tonumber(y)) then sites = sites + 1 end
 end
 return sites
end'''


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def configurations(stage, selected=None):
    policies = {r['id']: r['policy'] for r in json.loads((HERE / 'archived_route_league.json').read_text())}
    adapted = json.loads((HERE / 'results/adversarial_archive_adaptation_pilot.json').read_text())['selection']['selectedPolicy']
    configs = []
    for map_type, seed in MAPS[stage]:
        for rules in ('baseline', 'p1'):
            openings = ['default', 'scout'] + (['farm'] if rules == 'p1' else []) if stage == 'train' else list(dict.fromkeys(['default', selected[rules]]))
            for opponent_id, opponent in [('industrial', policies['industrial-specialist']), ('archived-expedition', adapted)]:
                for seat in (0, 1):
                    players = [{'civilization': 'forge', 'policy': opponent} for _ in range(2)]
                    players[seat] = {'civilization': 'forge', 'policy': policies['selected-expedition']}
                    configs.append({'seed': seed, 'mapType': map_type, 'mapSize': 'compact', 'hostileMode': 'off',
                                    'contentRules': rules, 'runtimeBackend': 'luajit21', 'maxRounds': 180,
                                    'wallSeconds': 240, 'players': players, 'targetSeat': seat,
                                    'opponentId': opponent_id, 'openings': openings, 'stage': stage})
    return configs


def one_arm(config, opening, checkpoint, start_hash):
    runtime = OpeningRuntime(config)
    runtime.restore(checkpoint)
    assert runtime.state_hash() == start_hash
    target = config['targetSeat']
    telemetry_options = runtime.lua.table_from({'trace': True, 'actionBudget': 4096})
    telemetry = runtime.lua.globals().dofile('/lab/telemetry.lua').install(telemetry_options)
    request = None
    if opening != 'default':
        city = next(c for c in runtime.observe(target)['cities'] if c.get('owner') == target)
        request = {'action': 'queue', 'kind': 'unit' if opening == 'scout' else 'building',
                   'id': opening, 'cityX': city['x'], 'cityY': city['y']}
        outcome = runtime.apply(target, request)
        if not outcome[0]:
            return {'opening': opening, 'status': 'unavailable', 'request': request, 'reason': outcome[1]}
    site_probe = runtime.lua.eval(SITE_PROBE)
    milestones, samples, actual_first_projects = {}, [], []
    while not runtime.finished() and runtime.state.round <= config['maxRounds']:
        if runtime.state.round > 30:
            telemetry_options.trace = False
        runtime.pump()
        own = runtime.metrics()['players'][target]
        current = int(runtime.state.round)
        for name, reached in {'firstScout': own['units'].get('scout', 0) > 0,
                              'firstFarm': own['farms'] > 0, 'secondCity': len(own['cities']) >= 2,
                              'firstTechnology': own['technologies'] > 0, 'firstContact': own['contacts'] > 0,
                              'secondAge': own['age'] >= 2, 'thirdAge': own['age'] >= 3}.items():
            if reached:
                milestones.setdefault(name, current)
        if current in (1, 5, 10, 20, 30, 60, 90):
            player = runtime.state.players[target + 1]
            before_probe = runtime.state_hash()
            sites = runtime.call(site_probe, runtime.call(runtime.engine.observe, runtime.state, target), target)
            assert before_probe == runtime.state_hash(), 'Observer site diagnostic mutated canonical state'
            samples.append({'round': current, 'exploredTiles': sum(bool(v) for v in player.explored.values()),
                            'observerCandidateSites': sites, 'cities': len(own['cities']),
                            'population': own['population'], 'science': own['science'], 'industry': own['industry'],
                            'gold': own['gold'], 'units': own['unitCount'], 'treasuryNet': own['treasury']['net']})
        if current <= 5:
            actual_first_projects.append({'round': current, 'projects': [c.get('projectId') for c in own['cities']]})
        if runtime.finished() or current >= config['maxRounds']:
            break
        runtime.advance()
    finished = runtime.finished()
    winners = from_lua(runtime.state.winnerIDs or runtime.lua.table()) or []
    counts = from_lua(telemetry)
    queues = [t for t in counts.get('trace', []) if t['actor'] == target and t['request']['action'] == 'queue']
    return {'opening': opening, 'status': 'finished' if finished else 'censored',
            'startHash': start_hash, 'request': request, 'round': int(runtime.state.round),
            'winnerIds': winners, 'victoryReason': runtime.state.victoryReason,
            'targetWinCredit': (1 / len(winners) if target in winners else 0) if finished and winners else None,
            'milestones': milestones, 'samples': samples, 'firstProjects': actual_first_projects,
            'earlyQueueOrders': queues[:12], 'dispatchCounts': {k: v for k, v in counts.items() if k != 'trace'},
            'finalStateHash': runtime.state_hash(), 'runtime': runtime.runtime_info}


def run_condition(config):
    initial = OpeningRuntime(config)
    checkpoint, start_hash = initial.canonical_state(), initial.state_hash()
    arms = []
    for opening in config['openings']:
        try:
            arm = one_arm(config, opening, checkpoint, start_hash)
        except Exception as exc:
            arm = {'opening': opening, 'status': 'error', 'error': f'{type(exc).__name__}: {exc}'}
        arms.append(arm)
    return {'config': config, 'startHash': start_hash, 'arms': arms,
            'status': 'finished' if all(a['status'] == 'finished' for a in arms) else 'incomplete'}


def worker(connection, config):
    try:
        try:
            result = run_condition(config)
        except Exception as exc:
            result = {'config': config, 'status': 'error', 'error': f'{type(exc).__name__}: {exc}'}
        connection.send(result)
    finally:
        connection.close()


def selection(results):
    groups = defaultdict(list)
    for condition in results:
        for arm in condition.get('arms', []):
            if arm['status'] != 'finished':
                raise RuntimeError('Do not select using incomplete outcomes')
            round30 = next(s for s in arm['samples'] if s['round'] == 30)
            groups[(condition['config']['contentRules'], arm['opening'])].append((arm['targetWinCredit'],
                round30['exploredTiles'], arm['milestones'].get('secondCity', 181)))
    statistics = {f'{rules}:{opening}': {'games': len(rows), 'meanWinCredit': mean(r[0] for r in rows),
                    'meanExploredTiles30': mean(r[1] for r in rows), 'meanSecondCityRound': mean(r[2] for r in rows)}
                  for (rules, opening), rows in groups.items()}
    chosen = {}
    order = ['default', 'scout', 'farm']
    for rules in ('baseline', 'p1'):
        available = [opening for (r, opening) in groups if r == rules]
        chosen[rules] = max(available, key=lambda opening: (
            statistics[f'{rules}:{opening}']['meanWinCredit'], statistics[f'{rules}:{opening}']['meanExploredTiles30'],
            -statistics[f'{rules}:{opening}']['meanSecondCityRound'], -order.index(opening)))
    return {'rule': SELECTION_RULE, 'selected': chosen, 'trainingStatistics': statistics}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=('train', 'evaluate'), required=True)
    parser.add_argument('--training', type=Path, default=HERE / 'results/p1_opening_train.json')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    if not 1 <= args.workers <= 6:
        parser.error('Use 1–6 workers')
    output = args.output or HERE / f'results/p1_opening_{args.stage}.json'
    before = source_manifest()
    selected = None
    training = None
    if args.stage == 'evaluate':
        training = json.loads(args.training.read_text())
        assert training['status'] == 'complete' and training['sourceUnchanged'] and training['source'] == before
        selected = training['selection']['selected']
    jobs = configurations(args.stage, selected)
    if args.limit:
        jobs = jobs[:args.limit]
    inputs = [HERE / 'p1_pacing_study.py', HERE / 'run_fixed_personality_ablation.py',
              HERE / 'archived_route_league.json', HERE / 'results/adversarial_archive_adaptation_pilot.json']
    hashes = {str(p.relative_to(HERE)): fingerprint(p) for p in inputs}
    record = {'source': before, 'sourceUnchanged': True, 'stage': args.stage, 'selectionRule': SELECTION_RULE,
              'scriptSha256': fingerprint(Path(__file__)), 'inputHashes': hashes, 'status': 'running',
              'plannedConditions': len(jobs), 'conditions': [], 'workers': args.workers,
              'trainingArtifactSha256': fingerprint(args.training) if training else None,
              'selectedOpenings': selected, 'mapBlocks': MAPS[args.stage]}
    if output.exists():
        previous = json.loads(output.read_text())
        for key in ('source', 'scriptSha256', 'inputHashes', 'plannedConditions', 'trainingArtifactSha256'):
            assert previous[key] == record[key], f'Existing checkpoint differs at {key}; choose a new output'
        record['conditions'] = previous['conditions']
        assert [c['config'] for c in record['conditions']] == jobs[:len(record['conditions'])]
    output.parent.mkdir(parents=True, exist_ok=True)
    atomic(output, record)
    workers._worker = worker
    started = time.perf_counter()
    for i in range(len(record['conditions']), len(jobs), args.workers):
        record['conditions'].extend(workers.run_bounded(jobs[i:i + args.workers], args.workers))
        record['sourceUnchanged'] = before == source_manifest()
        record['inputsUnchanged'] = hashes == {str(p.relative_to(HERE)): fingerprint(p) for p in inputs}
        record['lastInvocationElapsedSeconds'] = time.perf_counter() - started
        atomic(output, record)
        print(json.dumps({'stage': args.stage, 'conditions': len(record['conditions']), 'planned': len(jobs),
                          'statuses': dict(Counter(c['status'] for c in record['conditions']))}), flush=True)
        assert record['sourceUnchanged'] and record['inputsUnchanged'], 'Source or adapters changed during study'
    record['status'] = 'complete'
    if args.stage == 'train' and not args.limit:
        record['selection'] = selection(record['conditions'])
    atomic(output, record)
    if 'selection' in record:
        print(json.dumps(record['selection']), flush=True)


if __name__ == '__main__':
    main()
