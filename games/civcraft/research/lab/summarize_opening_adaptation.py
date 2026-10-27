#!/usr/bin/env python3
"""Summarize restricted opening selection and paired held-out outcomes."""
import json
import argparse
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean, median

HERE = Path(__file__).resolve().parent


def summarize(records):
    rows = defaultdict(list)
    for condition in records:
        for arm in condition.get('arms', []):
            rows[(condition['config']['contentRules'], arm['opening'])].append((condition, arm))
    groups = {}
    for (rules, opening), values in rows.items():
        finished = [a for _, a in values if a['status'] == 'finished']
        metrics = {}
        for name in ('firstScout', 'firstFarm', 'secondCity', 'firstTechnology', 'firstContact', 'secondAge', 'thirdAge'):
            observed = [a['milestones'][name] for a in finished if name in a['milestones']]
            metrics[name] = {'reached': len(observed), 'players': len(finished),
                             'medianRound': median(observed) if observed else None}
        checkpoints = {}
        for round_number in (10, 20, 30, 60):
            samples = [s for a in finished for s in a['samples'] if s['round'] == round_number]
            checkpoints[str(round_number)] = {'samples': len(samples), **{
                field: mean(s[field] for s in samples) if samples else None
                for field in ('exploredTiles', 'observerCandidateSites', 'cities', 'population', 'science', 'industry', 'units')}}
        groups[f'{rules}:{opening}'] = {'games': len(values), 'statuses': dict(Counter(a['status'] for _, a in values)),
            'winCredit': sum(a['targetWinCredit'] for a in finished),
            'meanWinCredit': mean(a['targetWinCredit'] for a in finished) if finished else None,
            'victoryReasons': dict(Counter(a['victoryReason'] for a in finished)),
            'milestones': metrics, 'checkpoints': checkpoints}
    return groups


def paired(records):
    results, maps = [], defaultdict(list)
    for condition in records:
        default = next(a for a in condition.get('arms', []) if a['opening'] == 'default')
        for arm in condition['arms']:
            if arm['opening'] == 'default' or arm['status'] != 'finished' or default['status'] != 'finished':
                continue
            def sample(a):
                return next(s for s in a['samples'] if s['round'] == 30)
            row = {key: condition['config'][key] for key in ('contentRules', 'seed', 'mapType', 'opponentId', 'targetSeat')}
            row.update(opening=arm['opening'], winCreditDelta=arm['targetWinCredit'] - default['targetWinCredit'],
                       exploredTiles30Delta=sample(arm)['exploredTiles'] - sample(default)['exploredTiles'],
                       candidateSites30Delta=sample(arm)['observerCandidateSites'] - sample(default)['observerCandidateSites'],
                       secondCityDelay=arm['milestones']['secondCity'] - default['milestones']['secondCity'],
                       winnerChanged=arm['winnerIds'] != default['winnerIds'],
                       endingRoundDelta=arm['round'] - default['round'])
            results.append(row)
            maps[(row['contentRules'], row['opening'], row['mapType'], row['seed'])].append(row)
    blocks = [{**dict(zip(('economy', 'opening', 'mapType', 'seed'), key)), 'conditions': len(values),
               **{name: mean(r[name] for r in values) for name in ('winCreditDelta', 'exploredTiles30Delta',
                    'candidateSites30Delta', 'secondCityDelay', 'endingRoundDelta')}} for key, values in maps.items()]
    return {'conditions': results, 'mapBlocks': blocks}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--training', type=Path, default=HERE / 'results/p1_opening_train.json')
    parser.add_argument('--evaluation', type=Path, default=HERE / 'results/p1_opening_evaluate.json')
    parser.add_argument('--output', type=Path, default=HERE / 'results/p1_opening_summary.json')
    args = parser.parse_args()
    train = json.loads(args.training.read_text())
    evaluation = json.loads(args.evaluation.read_text())
    assert all(r['status'] == 'complete' and r['sourceUnchanged'] and r['inputsUnchanged'] for r in (train, evaluation))
    assert train['source'] == evaluation['source']
    result = {'training': summarize(train['conditions']), 'evaluation': summarize(evaluation['conditions']),
              'selected': train['selection'], 'heldOutPaired': paired(evaluation['conditions']),
              'trainingPaired': paired(train['conditions']),
              'counts': {'trainingGames': sum(len(c['arms']) for c in train['conditions']),
                         'evaluationGames': sum(len(c['arms']) for c in evaluation['conditions']),
                         'trainingMapBlocks': len(train['mapBlocks']), 'evaluationMapBlocks': len(evaluation['mapBlocks'])},
              'limits': ['Selection was restricted to one initial order; later controller decisions are unchanged.',
                         'All Forge/fixed Forge personality; no hostiles; only two known opponent policies.',
                         'Four held-out map blocks with four correlated seat/opponent conditions each; no broad fairness claim.',
                         'Candidate settlement sites use detached observer knowledge and need not be reachable or legally free in hidden state.',
                         'Exploration/site diagnostics were never supplied to the acting policy.',
                         'Missing milestones are unreached, not zero. Shared wins use fractional credit.']}
    path = args.output
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'counts': result['counts'], 'selected': train['selection']['selected'],
                      'evaluation': {key: {k: v for k, v in row.items() if k not in ('milestones','checkpoints')}
                                     for key, row in result['evaluation'].items()},
                      'heldOutPairedMapBlocks': result['heldOutPaired']['mapBlocks']}))


if __name__ == '__main__':
    main()
