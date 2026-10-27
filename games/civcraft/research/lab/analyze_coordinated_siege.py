#!/usr/bin/env python3
"""Reduce matched siege-policy results without launching any games."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name):
    path = HERE/'results'/name
    return path, json.loads(path.read_text())


def main():
    path, study = load('coordinated_siege_holdout.json')
    old_path, preflight = load('coordinated_siege_holdout_strength8.json')
    assert not study['sourceChangedDuringRun'] and not preflight['sourceChangedDuringRun']
    assert len(study['matches']) == 8
    indexed = {(m['seed'], m['seat'], m['arm']): m for m in study['matches']}
    old = {(m['seed'], m['seat']): m for m in preflight['matches'] if m['arm'] == 'existing_hooks'}
    pairs = []
    for seed, seat in sorted(old):
        control = indexed[(seed, seat, 'existing_hooks')]
        candidate = indexed[(seed, seat, 'coordinated')]
        assert control['status'] == candidate['status'] == 'finished'
        assert control['initialStateHash'] == candidate['initialStateHash']
        assert control['finalStateHash'] == old[(seed, seat)]['finalStateHash']
        entry = {'seed': seed, 'seat': seat,
                 'initialStatesEqual': True, 'repeatedControlStateEqual': True,
                 'armsFinalStateEqual': control['finalStateHash'] == candidate['finalStateHash'],
                 'arms': []}
        for match in (control, candidate):
            player = next(p for p in match['finalPlayerMetrics'] if p['id'] == seat)
            entry['arms'].append({'arm': match['arm'], 'round': match['round'],
                'victoryReason': match['victoryReason'],
                'conquestSeatWon': seat in match['winnerIds'],
                'opponentCitiesCaptured': len(match['registeredOpponentCaptures']),
                'firstSiegeQueueRound': match['firstSiegeQueueRound'],
                'acceptedSiegeQueues': sum(match['queuedUnitKinds'].get(k, 0) for k in ('catapult', 'heavysiege')),
                'finalSiegeUnits': sum(player['units'].get(k, 0) for k in ('catapult', 'heavysiege')),
                'finalSwordUnits': player['units'].get('swordsman', 0),
                'finalUnitCount': player['unitCount'], 'finalGold': player['gold']})
        pairs.append(entry)
    result = {'purpose': 'Matched current-policy siege intervention analysis',
              'inputHashes': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (path, old_path)},
              'analysisSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'independentMapBlocks': 2, 'pairedCells': 4, 'pairs': pairs,
              'limits': ['Four paired cells share two map seeds; no broad fairness or equivalence claim.',
                         'Earlier hook bundle is research-only; control is not the unchanged shipping AI.',
                         'Accepted recruitment queues and final completed units are different measurements.',
                         'The same evaluation maps were reused after a content-threshold implementation correction.']}
    output = HERE/'results/coordinated_siege_pair_analysis.json'
    output.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'output': str(output), 'pairs': len(pairs),
                      'repeatedControlsEqual': True,
                      'opponentCaptures': sum(a['opponentCitiesCaptured'] for p in pairs for a in p['arms'])}))


if __name__ == '__main__':
    main()
