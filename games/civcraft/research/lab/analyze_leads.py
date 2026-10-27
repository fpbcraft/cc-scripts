#!/usr/bin/env python3
"""Retrospective fixed-controller lead persistence, not perfect-play solvability."""
import hashlib
import json
import math
import random
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROUNDS = (31, 61, 91)


def summarize(rows):
    output = {}
    for round_number in ROUNDS:
        group = [r for r in rows if r['round'] == round_number]
        leaders = [r for r in group if r['scoreLeader'] is not None]
        confident = [r for r in group if r['confidence'] >= .8]
        output[str(round_number)] = {
            'snapshots': len(group), 'scoreTies': len(group)-len(leaders),
            'uniqueScoreLeaders': len(leaders),
            'scoreLeaderMeanFinalWinCredit': statistics.mean(r['leaderWinCredit'] for r in leaders) if leaders else None,
            'modelConfidentSnapshots': len(confident),
            'confidenceCoverage': len(confident) / len(group),
            'confidentPredictionMeanFinalWinCredit': statistics.mean(r['predictedWinCredit'] for r in confident) if confident else None,
            'medianRoundsRemainingWhenConfident': statistics.median(r['remainingRounds'] for r in confident) if confident else None,
        }
    return output


def main():
    model_path = HERE / 'results/outcome_model_study.json'
    model_study = json.loads(model_path.read_text())
    raw_path = Path(model_study['batches']['test']['rawArtifact'])
    raw = json.loads(raw_path.read_text())
    assert not model_study['sourceChangedDuringRun']
    assert raw['sourceManifestBeforeRun'] == model_study['sourceManifestBeforeRun']
    assert {m['config']['seed'] for m in raw['matches']} == set(model_study['split']['test'])
    model, rows = model_study['model'], []
    for match_id, match in enumerate(raw['matches']):
        assert match['status'] == 'finished'
        winners = match['winnerIds']

        def credit(seat):
            return (1/len(winners) if seat in winners else 0) if winners else .5

        for round_number in ROUNDS:
            snapshot = next(t for t in match['turns'] if t['round'] == round_number)
            p0, p1 = snapshot['players']
            assert p0['id'] == 0 and p1['id'] == 1 and snapshot['phase'] == 'game'
            features = [math.log1p(max(0, p0[k]))-math.log1p(max(0, p1[k])) for k in model['features']]
            logit = sum(x*w for x, w in zip(features, model['weights'], strict=True)) / model['temperature']
            probability = 1/(1+math.exp(-max(-40, min(40, logit))))
            leader = (0 if p0['score'] > p1['score'] else 1) if p0['score'] != p1['score'] else None
            predicted = 0 if probability >= .5 else 1
            rows.append({'match': match_id, 'seed': match['config']['seed'], 'round': round_number,
                         'scoreLeader': leader, 'leaderWinCredit': credit(leader) if leader is not None else None,
                         'modelProbabilityPlayerZero': probability, 'confidence': max(probability, 1-probability),
                         'predictedWinCredit': credit(predicted), 'remainingRounds': match['round']-round_number})
    seeds = sorted({r['seed'] for r in rows})
    assert len(seeds) == 6
    by_seed = {s: [r for r in rows if r['seed'] == s] for s in seeds}
    rng, intervals = random.Random(20261027), {}
    resamples = [summarize([r for seed in rng.choices(seeds, k=len(seeds)) for r in by_seed[seed]])
                 for _ in range(2000)]
    for round_number in map(str, ROUNDS):
        intervals[round_number] = {}
        for metric in ('scoreLeaderMeanFinalWinCredit', 'confidenceCoverage', 'confidentPredictionMeanFinalWinCredit'):
            values = sorted(s[round_number][metric] for s in resamples if s[round_number][metric] is not None)
            intervals[round_number][metric] = [values[int(.025*(len(values)-1))], values[int(.975*(len(values)-1))]] if values else None
    result = {
        'purpose': 'Retrospective fixed-controller lead/outcome associations on the untouched outcome-model test maps',
        'modelSha256': hashlib.sha256(model_path.read_bytes()).hexdigest(),
        'rawSha256': hashlib.sha256(raw_path.read_bytes()).hexdigest(),
        'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'testMapSeeds': seeds, 'independentMapBlocks': len(seeds),
        'summary': summarize(rows), 'clusterBootstrap95Intervals': intervals, 'rows': rows,
        'limits': ['Six map clusters, fixed Forge controllers, compact Pangaea, no hostiles.',
                   'Scores and critic use privileged evaluator totals; these are not observations supplied to playing policies.',
                   'Confidence uses the already fixed calibrated model and 0.8 threshold, without refitting on test outcomes.',
                   'Predictability under fixed controllers is not inevitability under stronger play or proof of a causal runaway lead.',
                   'No optimal continuation, intervention or counter-strategy is evaluated by this descriptive analysis.'],
    }
    destination = HERE / 'results/lead_persistence.json'
    destination.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps(result['summary'], indent=2))


if __name__ == '__main__':
    main()
