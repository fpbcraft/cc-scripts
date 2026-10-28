#!/usr/bin/env python3
"""Descriptive paired summary; map blocks, not player rows, are replications."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean, median

HERE = Path(__file__).resolve().parent


def analyze(record):
    pairs = defaultdict(dict)
    grouped = defaultdict(list)
    for match in record['matches']:
        config = match['config']
        key = (config['mapType'], config['seed'], tuple(p['civilization'] for p in config['players']), config['profile'])
        pairs[key][config['contentRules']] = match
        grouped[config['contentRules']].append(match)
    result = {'status': record['status'], 'sourceUnchanged': record['sourceUnchanged'],
              'matches': len(record['matches']), 'pairedConditions': len(pairs),
              'independentMapBlocks': len({(k[0], k[1]) for k in pairs}), 'economies': {}, 'paired': {}}
    milestones = sorted({name for match in record['matches'] for p in match.get('players', []) for name in p['milestones']})
    for rules, matches in grouped.items():
        players = [p for match in matches for p in match.get('players', [])]
        metric = {'statuses': dict(Counter(m['status'] for m in matches)),
                  'victoryReasons': dict(Counter(m.get('victoryReason') for m in matches)),
                  'finishRounds': {'median': median(m['round'] for m in matches if m['status'] == 'finished'),
                                   'min': min(m['round'] for m in matches), 'max': max(m['round'] for m in matches)},
                  'players': len(players), 'milestones': {}, 'periods': {},
                  'finalUnitsMedian': median(p['final']['unitCount'] for p in players)}
        for name in milestones:
            values = [p['milestones'][name] for p in players if name in p['milestones']]
            metric['milestones'][name] = {'reached': len(values), 'totalPlayers': len(players),
                                          'medianRound': median(values) if values else None}
        for period in ('1-30', '31-60', '61+'):
            totals = Counter()
            for p in players:
                totals.update(p['periods'].get(period, {}))
            city_rounds = totals['cityRounds']
            metric['periods'][period] = dict(totals) | {
                'meanUnitsPerPlayerRound': totals['unitRounds'] / totals['rounds'],
                'meanLegalBuildingOptionsPerCityRound': totals['availableBuildingOptions'] / city_rounds,
                'zeroBuildingOptionShare': totals['zeroBuildingOptionCityRounds'] / city_rounds,
                'oneBuildingOptionShare': totals['oneBuildingOptionCityRounds'] / city_rounds,
                'repeatableShare': totals['repeatableCityRounds'] / city_rounds,
                'idleShare': totals['idleCityRounds'] / city_rounds}
        result['economies'][rules] = metric
    paired_rows, milestone_deltas = [], defaultdict(list)
    by_map, by_civ = defaultdict(list), defaultdict(list)
    for key, arms in pairs.items():
        if set(arms) != {'baseline', 'p1'}:
            continue
        original, p1 = arms['baseline'], arms['p1']
        row = {'mapType': key[0], 'seed': key[1], 'roster': list(key[2]), 'profile': key[3],
               'finishRoundDelta': p1['round'] - original['round'],
               'winnerChanged': original['winnerIds'] != p1['winnerIds'],
               'baselineWinners': original['winnerIds'], 'p1Winners': p1['winnerIds'], 'players': []}
        by_map[(key[0], key[1])].append(row['finishRoundDelta'])
        for a, b in zip(original['players'], p1['players']):
            delta = {name: b['milestones'][name] - a['milestones'][name] for name in milestones
                     if name in a['milestones'] and name in b['milestones']}
            for name, value in delta.items():
                milestone_deltas[name].append(value)
            row['players'].append({'civilization': a['civilization'], 'seat': a['seat'], 'milestoneDeltas': delta})
            by_civ[a['civilization']].append({'baselineWin': a['seat'] in original['winnerIds'],
                                             'p1Win': b['seat'] in p1['winnerIds'], 'deltas': delta})
        paired_rows.append(row)
    result['paired'] = {'winnerChanges': sum(p['winnerChanged'] for p in paired_rows),
                        'finishRoundDeltaMedian': median(p['finishRoundDelta'] for p in paired_rows),
                        'mapBlockMeanFinishRoundDeltas': {f'{k[0]}:{k[1]}': mean(v) for k, v in by_map.items()},
                        'milestones': {name: {'completePlayerPairs': len(v), 'medianDelta': median(v),
                                              'minDelta': min(v), 'maxDelta': max(v)}
                                       for name, v in milestone_deltas.items()},
                        'byCivilization': {civ: {'appearancesPerEconomy': len(rows),
                            'baselineWins': sum(r['baselineWin'] for r in rows), 'p1Wins': sum(r['p1Win'] for r in rows),
                            'secondCityMedianDelta': median(r['deltas']['secondCity'] for r in rows if 'secondCity' in r['deltas'])}
                            for civ, rows in by_civ.items()}, 'conditions': paired_rows}
    result['limits'] = record['limits'] + [
        'Milestone deltas use complete player pairs only; reach counts are reported separately.',
        'Late periods and final assets have different ending times; compare early fixed windows for pacing.',
        'No iid-player confidence interval: only four independent map blocks, with correlated roster/policy/seat cells.',
        'Policies were selected under the original economy. Adaptation and human play remain necessary.']
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=HERE / 'results/p1_pacing_pilot.json')
    parser.add_argument('--output', type=Path, default=HERE / 'results/p1_pacing_summary.json')
    args = parser.parse_args()
    result = analyze(json.loads(args.input.read_text()))
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('paired', 'limits')}))
    print(json.dumps({k: v for k, v in result['paired'].items() if k != 'conditions'}))


if __name__ == '__main__':
    main()
