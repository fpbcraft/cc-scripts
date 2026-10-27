#!/usr/bin/env python3
"""Checkpointed, matched original/P1 pacing pilot with read-only round telemetry."""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import from_lua
from runner import source_manifest
from run_fixed_personality_ablation import FixedPersonalityRuntime
import workers

PROBE = '''function(state, metric)
 for i, p in ipairs(state.players) do
  local row = metric.players[i]
  row.settlersTrained = p.settlersTrained or 0
  row.contacts = 0
  for _, known in pairs(p.contacts or {}) do if known then row.contacts = row.contacts + 1 end end
  row.farms, row.libraries, row.markets = 0, 0, 0
  for _, c in ipairs(state.cities) do
   if c.owner == p.id then
    row.farms = row.farms + (c.buildings.farm and 1 or 0)
    row.libraries = row.libraries + (c.buildings.library and 1 or 0)
    row.markets = row.markets + (c.buildings.market and 1 or 0)
   end
  end
 end
 return metric
end'''


class OpeningRuntime:
    def __new__(cls, *args, **kwargs):
        runtime = FixedPersonalityRuntime(*args, **kwargs)
        probe = runtime.lua.eval(PROBE)
        runtime.metrics = lambda: from_lua(runtime.call(probe, runtime.state,
                                                       runtime.call(runtime.engine.metrics, runtime.state)))
        return runtime


def summarize(match):
    players = []
    for seat in range(len(match['config']['players'])):
        milestones, periods = {}, {}
        for turn in match.get('turns', []):
            row = turn['players'][seat]
            conditions = {'firstTechnology': row['technologies'] > 0,
                          'firstTrainedSettler': row['settlersTrained'] > 0,
                          'secondCity': len(row['cities']) >= 2,
                          'firstScoutPresent': row['units'].get('scout', 0) > 0,
                          'firstFarm': row['farms'] > 0, 'firstLibrary': row['libraries'] > 0,
                          'firstMarket': row['markets'] > 0, 'firstContact': row['contacts'] > 0,
                          'secondAge': row['age'] >= 2, 'thirdAge': row['age'] >= 3}
            for key, reached in conditions.items():
                if reached:
                    milestones.setdefault(key, turn['round'])
            period = '1-30' if turn['round'] <= 30 else '31-60' if turn['round'] <= 60 else '61+'
            totals = periods.setdefault(period, Counter())
            totals.update(rounds=1, unitRounds=row['unitCount'], cityRounds=len(row['cities']),
                          idleCityRounds=row['idleCities'])
            for city in row['cities']:
                n = len(city['availableBuildings'])
                totals.update(availableBuildingOptions=n, zeroBuildingOptionCityRounds=int(n == 0),
                              oneBuildingOptionCityRounds=int(n == 1))
                if city.get('projectKind') == 'project':
                    totals['repeatableCityRounds'] += 1
                    totals['project:' + city['projectId']] += 1
        final = (match.get('turns') or [{}])[-1].get('players', [])
        players.append({'seat': seat, 'civilization': match['config']['players'][seat]['civilization'],
                        'milestones': milestones, 'periods': {k: dict(v) for k, v in periods.items()},
                        'final': ({key: final[seat][key] for key in ('unitCount', 'population', 'technologies',
                                   'buildings', 'gold', 'science', 'industry', 'treasury')}
                                  | {'cities': len(final[seat]['cities'])}) if final else None})
    return {key: value for key, value in match.items() if key not in ('turns', 'dispatches')} | {
        'players': players, 'dispatches': {key: value for key, value in match.get('dispatches', {}).items()
                                          if key != 'trace'}}


def worker(connection, config):
    import runner
    runner.Runtime = OpeningRuntime
    try:
        try:
            result = summarize(runner.play(config))
        except Exception as exc:
            result = {'config': config, 'status': 'error', 'error': f'{type(exc).__name__}: {exc}'}
        connection.send(result)
    finally:
        connection.close()


def configurations(backend):
    policies = {row['id']: row['policy'] for row in json.loads((HERE / 'archived_route_league.json').read_text())}
    rows = []
    for map_type, seed in (('pangaea', 611953), ('pangaea', 753979),
                           ('archipelago', 817069), ('archipelago', 932081)):
        for roster in (('forge', 'forge'), ('scholar', 'forge'), ('forge', 'scholar')):
            for profile in ('selected-expedition', 'industrial-specialist'):
                for rules in ('baseline', 'p1'):
                    rows.append({'seed': seed, 'mapType': map_type, 'mapSize': 'compact',
                                 'hostileMode': 'off', 'contentRules': rules, 'runtimeBackend': backend,
                                 'maxRounds': 180, 'telemetryEvery': 1, 'wallSeconds': 180,
                                 'profile': profile, 'players': [{'civilization': civ, 'policy': policies[profile]}
                                                                for civ in roster]})
    return rows


def atomic(path, record):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--backend', choices=('lua53', 'luajit21'), default='luajit21')
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--limit', type=int)
    parser.add_argument('--output', type=Path, default=HERE / 'results/p1_pacing_pilot.json')
    args = parser.parse_args()
    if not 1 <= args.workers <= 6:
        parser.error('Use 1–6 workers')
    before = source_manifest()
    script_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    adapter_hash = hashlib.sha256((HERE / 'run_fixed_personality_ablation.py').read_bytes()).hexdigest()
    jobs = configurations(args.backend)
    if args.limit:
        jobs = jobs[:args.limit]
    record = {'source': before, 'scriptSha256': script_hash, 'adapterSha256': adapter_hash,
              'plannedMatches': len(jobs), 'workers': args.workers, 'matches': [],
              'status': 'running', 'sourceUnchanged': True,
              'limits': ['Four independent map blocks; seat/roster/policy cells within maps are correlated.',
                         'Fixed pre-P1 policies and Forge personalities; no retraining or overall fairness claim.',
                         'Available buildings are legal options, not a measure of their strategic value.',
                         'Milestones are first post-actor observations; missing milestones are unreached, not zero.',
                         'Hostiles off because the known captured-Settler error remains unresolved.']}
    if args.output.exists():
        existing = json.loads(args.output.read_text())
        for key in ('source', 'scriptSha256', 'adapterSha256', 'plannedMatches'):
            if existing[key] != record[key]:
                raise RuntimeError(f'Existing output differs at {key}; choose a fresh output path')
        record['matches'] = existing['matches']
        assert [m['config'] for m in record['matches']] == jobs[:len(record['matches'])]
    workers._worker = worker
    args.output.parent.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    completed_before = len(record['matches'])
    for i in range(completed_before, len(jobs), args.workers):
        record['matches'].extend(workers.run_bounded(jobs[i:i + args.workers], args.workers))
        record['sourceUnchanged'] = before == source_manifest()
        record['lastInvocationElapsedSeconds'] = time.perf_counter() - started
        atomic(args.output, record)
        print(json.dumps({'completed': len(record['matches']), 'planned': len(jobs),
                          'statuses': dict(Counter(m['status'] for m in record['matches']))}), flush=True)
        if not record['sourceUnchanged']:
            raise RuntimeError('Authoritative source changed; checkpoint retained, do not pool it')
    record['status'] = 'complete'
    atomic(args.output, record)


if __name__ == '__main__':
    main()
