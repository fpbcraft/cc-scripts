#!/usr/bin/env python3
"""Cross-play archived policies on matched maps, rotating starting positions."""
import argparse
import itertools
import json
from pathlib import Path

from runner import write_run


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--league', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seeds', default='99119,61283')
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--limit', type=int, default=4)
    args = parser.parse_args()
    agents = json.loads(args.league.read_text())[:args.limit]
    if len(agents) < 2 or len({a['id'] for a in agents}) != len(agents):
        parser.error('Supply at least two uniquely named archived agents')
    configs, labels = [], []
    for seed in map(int, args.seeds.split(',')):
        for first, second in itertools.combinations(agents, 2):
            for order in [(first, second), (second, first)]:
                configs.append({'seed': seed, 'mapType': 'pangaea', 'mapSize': 'compact',
                                'hostileMode': 'off', 'telemetryEvery': 10, 'maxRounds': 180,
                                'players': [{'civilization': 'forge', 'policy': a['policy']} for a in order]})
                labels.append([a['id'] for a in order])
    raw_path = args.output.with_suffix('.raw.json')
    raw = write_run(configs, raw_path, args.workers)
    pairs = {}
    for match, order in zip(raw['matches'], labels, strict=True):
        for seat in [0, 1]:
            key = f'{order[seat]} vs {order[1-seat]}'
            cell = pairs.setdefault(key, {'attempted': 0, 'finished': 0, 'credit': 0, 'errors': 0})
            cell['attempted'] += 1
            if match['status'] != 'finished':
                cell['errors'] += 1
                continue
            cell['finished'] += 1
            winners = match['winnerIds']
            cell['credit'] += (1 / len(winners) if seat in winners else 0) if winners else 0.5
    summary = {'schemaVersion': 1, 'agents': agents, 'seeds': args.seeds,
               'sourceChangedDuringRun': raw['sourceChangedDuringRun'], 'cells': pairs,
               'rawArtifact': str(raw_path), 'source': raw['source'],
               'limitation': 'Bounded cross-play pilot, not proof of global robustness or equilibrium.'}
    args.output.write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({'matches': len(configs), 'summary': str(args.output),
                      'sourceChangedDuringRun': raw['sourceChangedDuringRun']}))


if __name__ == '__main__':
    main()
