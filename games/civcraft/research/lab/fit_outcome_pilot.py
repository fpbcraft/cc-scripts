#!/usr/bin/env python3
"""A deliberately small, privileged offline outcome critic; never a game policy."""
import argparse
import hashlib
import json
import math
from pathlib import Path

FEATURES = ('population', 'industry', 'science', 'technologies', 'combatPower',
            'unitCount', 'buildings', 'gold', 'score')
ROUNDS = (31, 61, 91)


def sigmoid(value):
    return 1 / (1 + math.exp(-max(-40, min(40, value))))


def features(players):
    # Signed, bounded-scale differences preserve seat-exchange symmetry. This
    # includes hidden opponent totals: suitable only for privileged diagnostics.
    return [math.log1p(max(0, players[0][key])) - math.log1p(max(0, players[1][key]))
            for key in FEATURES]


def fit(rows):
    weights = [0.0] * len(FEATURES)
    # Fixed before holdout evaluation. No tuning or calibration on the holdout.
    for _ in range(1000):
        gradient = [0.1 * value for value in weights]
        for row in rows:
            prediction = sigmoid(sum(a * b for a, b in zip(weights, row['x'], strict=True)))
            for index, value in enumerate(row['x']):
                gradient[index] += (prediction - row['y']) * value / len(rows)
        weights = [a - 0.1 * b for a, b in zip(weights, gradient, strict=True)]
    return weights


def evaluate(rows, predictor):
    predictions = [predictor(row) for row in rows]
    bins = []
    for low, high in ((0, .25), (.25, .5), (.5, .75), (.75, 1.000001)):
        indices = [i for i, p in enumerate(predictions) if low <= p < high]
        if indices:
            bins.append({'range': [low, min(1, high)], 'rows': len(indices),
                         'meanPrediction': sum(predictions[i] for i in indices) / len(indices),
                         'observedWinCredit': sum(rows[i]['y'] for i in indices) / len(indices)})
    return {'rows': len(rows),
            'brier': sum((p - r['y']) ** 2 for p, r in zip(predictions, rows, strict=True)) / len(rows),
            'logLoss': -sum(r['y'] * math.log(max(1e-12, p)) +
                           (1 - r['y']) * math.log(max(1e-12, 1-p))
                           for p, r in zip(predictions, rows, strict=True)) / len(rows),
            'accuracy': sum((p >= .5) == (r['y'] >= .5)
                            for p, r in zip(predictions, rows, strict=True)) / len(rows),
            'reliabilityBins': bins}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = json.loads(args.input.read_text())
    assert not raw['sourceChangedDuringRun'], 'Source integrity failure'
    train, holdout, compact = [], [], []
    for index, match in enumerate(raw['matches']):
        assert match['status'] == 'finished' and len(match['config']['players']) == 2
        seed = match['config']['seed']
        assert seed in (99119, 61283), 'This pilot fixes its split before fitting'
        for round_number in ROUNDS:
            turn = next(t for t in match['turns'] if t['round'] == round_number)
            assert turn['phase'] == 'game', 'Features must precede the outcome'
            winners = match['winnerIds']
            target = (1 / len(winners) if 0 in winners else 0) if winners else .5
            row = {'match': index, 'seed': seed, 'round': round_number,
                   'x': features(turn['players']), 'y': target}
            (train if seed == 99119 else holdout).append(row)
            compact.append(row)
    assert len(train) == len(holdout) == 36
    weights = fit(train)
    prior = sum(row['y'] for row in train) / len(train)
    learned = lambda row: sigmoid(sum(a * b for a, b in zip(weights, row['x'], strict=True)))
    result = {
        'purpose': 'Privileged offline diagnostic pilot, not an observed-information policy or recovery model',
        'inputSha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
        'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'source': raw['source'], 'sourceChangedDuringRun': False,
        'split': {'trainSeeds': [99119], 'holdoutSeeds': [61283],
                  'trainMatches': 12, 'holdoutMatches': 12, 'snapshotsPerMatch': 3,
                  'independentMapBlocksPerSplit': 1, 'rounds': ROUNDS},
        'model': {'type': 'L2 logistic regression, no intercept', 'features': FEATURES,
                  'weights': weights, 'l2': .1, 'iterations': 1000, 'learningRate': .1},
        'train': evaluate(train, learned), 'holdout': evaluate(holdout, learned),
        'constantPriorHoldout': evaluate(holdout, lambda _: prior),
        'perRoundHoldout': {str(r): evaluate([x for x in holdout if x['round'] == r], learned)
                            for r in ROUNDS},
        'dataset': compact,
        'limitations': [
            'One independent map block per split; snapshots and seat rotations are correlated.',
            'Same archived controllers, all Forge, no hostiles; no unseen-policy or faction generalization.',
            'Privileged opponent totals cannot be supplied to a playing policy.',
            'Brier and log loss measure probabilistic quality, not calibration alone.',
            'No separate calibration set; bin frequencies are descriptive and too small for reliability claims.',
            'Associative predictions do not establish the causal effect of a mistake or a game-rule change.',
        ],
        'methodReference': 'https://scikit-learn.org/stable/modules/calibration.html',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: {m: result[k][m] for m in ('brier', 'logLoss', 'accuracy')}
                      for k in ('train', 'holdout', 'constantPriorHoldout')}, indent=2))


if __name__ == '__main__':
    main()
