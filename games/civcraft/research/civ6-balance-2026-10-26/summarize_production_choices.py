"""Summarize a raw native trace; counts describe legal options, not their value."""
import collections
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
raw = json.loads(Path(sys.argv[1]).read_text())
(root / 'civcraft_production_trace.json').write_text(json.dumps(raw, indent=2) + '\n')
samples = raw['matches'][0]['productionSamples']
summary = {
    'head': raw['researchHead'], 'fixture': raw['fixture'], 'seed': raw['seed'],
    'victoryRound': raw['matches'][0]['round'],
    'victoryReason': raw['matches'][0]['victoryReason'],
    'measurement': 'Post-AI-turn snapshots. Legal building count does not measure strategic value. Correlated city-rounds from one match are not independent trials.',
    'periods': [], 'snapshots': [],
}
for lo, hi in [(1, 30), (31, 60), (61, 100), (101, 149)]:
    rows = [(s, c) for s in samples if lo <= s['round'] <= hi for c in s['cities']]
    if not rows:
        continue
    counts = collections.Counter(len(c['availableBuildings']) for _, c in rows)
    summary['periods'].append({
        'rounds': [lo, hi], 'city_rounds': len(rows),
        'zero_legal_buildings': counts[0], 'one_legal_building': counts[1],
        'at_most_one_fraction': round((counts[0] + counts[1]) / len(rows), 4),
        'unit_project_fraction': round(sum(c.get('project', {}).get('kind') == 'unit' for _, c in rows) / len(rows), 4),
        'idle_fraction': round(sum(not c.get('project') for _, c in rows) / len(rows), 4),
    })
for sample in samples:
    if sample['player'] == 0 and sample['round'] in [1, 10, 20, 30, 60, 100, 140, 149]:
        summary['snapshots'].append({
            'round': sample['round'], 'unitCount': sum(sample['units'].values()),
            'unitKinds': sample['units'], 'gold': sample['gold'], 'treasury': sample['treasury'],
            'cities': [{
                'id': c['id'], 'buildings': c['built'],
                'legalBuildingCount': len(c['availableBuildings']),
                'project': c.get('project'), 'industry': c['yields']['industry'],
            } for c in sample['cities']],
        })
(root / 'PRODUCTION-CHOICE-MEASUREMENTS.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
