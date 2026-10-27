#!/usr/bin/env python3
"""Small interpretable evolutionary search; real completed-game outcomes are fitness."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
from pathlib import Path

from runner import write_run

FEATURES = ('food', 'industry', 'science', 'gold')


def fingerprint(policy):
    return hashlib.sha256(json.dumps(policy, sort_keys=True).encode()).hexdigest()[:12]


def matchups(policy, seeds, rounds):
    configs, seats = [], []
    for seed in seeds:
        for opponent in [{}, {'goal': 'expedition'}]:
            for seat in [0, 1]:
                players = [{'civilization': 'forge', 'policy': opponent},
                           {'civilization': 'forge', 'policy': opponent}]
                players[seat] = {'civilization': 'forge', 'policy': policy}
                configs.append({'seed': seed, 'mapType': 'pangaea', 'mapSize': 'compact',
                                'hostileMode': 'off', 'maxRounds': rounds, 'telemetryEvery': 10,
                                'players': players})
                seats.append(seat)
    return configs, seats


def evaluate(policy, seeds, directory, label, workers, rounds):
    configs, seats = matchups(policy, seeds, rounds)
    output = directory / f'{label}-{fingerprint(policy)}.json'
    record = write_run(configs, output, workers)
    credits, outcomes = [], []
    for match, seat in zip(record['matches'], seats, strict=True):
        winners = match.get('winnerIds', [])
        if match['status'] == 'finished':
            credit = (1 / len(winners) if seat in winners else 0) if winners else 0.5
            credits.append(credit)
        outcomes.append({'seat': seat, 'status': match['status'], 'winners': winners,
                         'round': match.get('round'), 'reason': match.get('victoryReason')})
    valid = len(credits) == len(configs) and not record['sourceChangedDuringRun']
    return {'policy': policy, 'valid': valid, 'fitness': sum(credits) / len(credits) if valid else None,
            'games': len(configs), 'outcomes': outcomes, 'artifact': str(output),
            'elapsedSeconds': record['elapsedSeconds'], 'source': record['source']['luaSourceHash']}


def mutate(policy, rng, strategy_search=False):
    result = dict(policy)
    result['weights'] = {key: round(min(4, max(0.25, policy['weights'][key] *
                            math.exp(rng.gauss(0, 0.45)))), 6) for key in FEATURES}
    if strategy_search and rng.random() < 0.5:
        goal = rng.choice([None, 'industrial', 'expedition', 'conquest', 'diplomatic'])
        if goal is None:
            result.pop('goal', None)
        else:
            result['goal'] = goal
    return result


def export_lua(policy, path):
    weights = ', '.join(f'{key} = {policy["weights"][key]!r}' for key in FEATURES)
    goal = ', goal = ' + json.dumps(policy['goal']) if policy.get('goal') else ''
    path.write_text('-- Offline trained policy data; requires the reviewed Lua policy adapter.\n'
                    f'return {{ version = 1, weights = {{ {weights} }}{goal} }}\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--train-seeds', default='75123,47771,61283')
    parser.add_argument('--eval-seeds', default='95117,18731,99119')
    parser.add_argument('--population', type=int, default=4)
    parser.add_argument('--generations', type=int, default=2)
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--rounds', type=int, default=180)
    parser.add_argument('--seed', type=int, default=20261026)
    parser.add_argument('--goal', choices=['industrial', 'expedition', 'conquest', 'diplomatic'])
    parser.add_argument('--strategy-search', action='store_true',
                        help='Also search high-level goal commitment; incompatible with --goal')
    args = parser.parse_args()
    training = [int(x) for x in args.train_seeds.split(',')]
    holdout = [int(x) for x in args.eval_seeds.split(',')]
    if set(training) & set(holdout):
        parser.error('Training and held-out seeds must be disjoint')
    if args.population < 2 or args.generations < 1 or not 1 <= args.workers <= 6:
        parser.error('Use population >=2, generations >=1, workers 1–6')
    if args.strategy_search and args.goal:
        parser.error('A fixed goal and strategic-goal search are different experiments')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    baseline = {'version': 1, 'weights': dict.fromkeys(FEATURES, 1.0)}
    if args.goal:
        baseline['goal'] = args.goal
    rng = random.Random(args.seed)
    cache, history = {}, []
    population = [baseline] + [mutate(baseline, rng) for _ in range(args.population - 1)]
    if args.strategy_search:
        for policy, goal in zip(population[1:], ['expedition', 'conquest', 'diplomatic', 'industrial']):
            policy['goal'] = goal
    for generation in range(args.generations):
        ranked = []
        for policy in population:
            key = fingerprint(policy)
            if key not in cache:
                cache[key] = evaluate(policy, training, args.output_dir,
                                      f'train-g{generation}', args.workers, args.rounds)
                print(json.dumps({'generation': generation, 'policy': key,
                                  'fitness': cache[key]['fitness'], 'valid': cache[key]['valid']}), flush=True)
            ranked.append(cache[key])
        ranked.sort(key=lambda x: (x['fitness'] if x['valid'] else -1), reverse=True)
        if not ranked[0]['valid']:
            raise RuntimeError('No valid candidate: inspect errors/censoring before training')
        history.append(ranked)
        champion = ranked[0]['policy']
        population = [champion] + [mutate(champion, rng, args.strategy_search)
                                   for _ in range(args.population - 1)]
    # Holdout is consulted only after all training selections are final.
    baseline_eval = evaluate(baseline, holdout, args.output_dir, 'holdout-baseline', args.workers, args.rounds)
    champion_eval = evaluate(champion, holdout, args.output_dir, 'holdout-champion', args.workers, args.rounds)
    export_lua(champion, args.output_dir / 'champion.lua')
    archive = [{'id': 'original-adaptive', 'policy': baseline}]
    seen = {fingerprint(baseline)}
    for generation, ranked in enumerate(history):
        for item in ranked:
            key = fingerprint(item['policy'])
            if item['valid'] and key not in seen:
                archive.append({'id': f'g{generation}-{key}', 'policy': item['policy']})
                seen.add(key)
    (args.output_dir / 'league.json').write_text(json.dumps(archive, indent=2) + '\n')
    summary = {'method': 'elitist bounded log-normal weight mutation; fixed opponent mixture',
               'config': vars(args) | {'output_dir': str(args.output_dir)}, 'history': history,
               'baselineHoldout': baseline_eval, 'championHoldout': champion_eval,
               'claimLimit': 'Small seed-block pilot; held-out strength requires uncertainty and independent replication.'}
    (args.output_dir / 'evolution_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({'summary': str(args.output_dir / 'evolution_summary.json'),
                      'baselineHoldout': baseline_eval['fitness'], 'championHoldout': champion_eval['fitness']}))


if __name__ == '__main__':
    main()
