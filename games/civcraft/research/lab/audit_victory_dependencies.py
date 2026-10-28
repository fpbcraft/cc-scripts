#!/usr/bin/env python3
"""Static prerequisite arithmetic from live Lua content; not simulated timing."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from lupa.lua53 import LuaRuntime
from runtime import from_lua


def closure(records, targets):
    seen, visiting = set(), set()

    def visit(key):
        assert key in records, f'Unknown prerequisite: {key}'
        assert key not in visiting, f'Prerequisite cycle: {key}'
        if key in seen:
            return
        visiting.add(key)
        for parent in records[key].get('requires', []):
            visit(parent)
        visiting.remove(key)
        seen.add(key)

    for target in targets:
        visit(target)
    return seen


def main():
    path = ROOT / 'games/civcraft/content.lua'
    content = from_lua(LuaRuntime(unpack_returned_tuples=True).execute(path.read_text()))
    routes = {}
    for target, copies in [('bank', 3), ('dragon', 1), ('councilhall', 1)]:
        buildings = closure(content['buildings'], [target])
        techs = closure(content['techs'], [content['buildings'][b]['tech'] for b in buildings])
        routes[target] = {
            'requiredCityCopiesForThisStaticComparison': copies,
            'localBuildings': sorted(buildings), 'localBuildingCount': len(buildings),
            'baseLocalIndustry': sum(content['buildings'][b]['production'] for b in buildings),
            'baseIndustryAcrossRequiredCopies': copies * sum(content['buildings'][b]['production'] for b in buildings),
            'globalTechnologies': sorted(techs), 'globalTechnologyCount': len(techs),
            'baseGlobalScience': sum(content['techs'][t]['cost'] for t in techs),
        }
    industrial = set(routes['bank']['globalTechnologies'])
    expedition = set(routes['dragon']['globalTechnologies'])
    result = {
        'purpose': 'Exact static dependency closures from current content; costs are not completion times',
        'contentSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'routes': routes,
        'industrialExpedition': {
            'sharedTechnologies': sorted(industrial & expedition),
            'sharedTechnologyCount': len(industrial & expedition),
            'industrialOnly': sorted(industrial - expedition),
            'expeditionOnly': sorted(expedition - industrial),
            'baseScienceDifference': routes['bank']['baseGlobalScience'] - routes['dragon']['baseGlobalScience'],
            'aggregateBaseIndustryRatio': routes['bank']['baseIndustryAcrossRequiredCopies'] / routes['dragon']['baseLocalIndustry'],
        },
        'limits': [
            'Standard base content costs only; speed, overflow and changing yields affect actual timing.',
            'Industry is local and can run in parallel; a total industry ratio is not a turn ratio.',
            'Excluded optional economic/defensive buildings, city founding, staffing, rail construction and travel.',
            'Industrial also requires network/hold conditions; Council closure does not guarantee votes or a Diplomatic finish.',
            'Shared research need not be bad design; military, naval and situational branches can create counterplay.',
            'No gameplay costs or prerequisite rules were modified.',
        ],
    }
    destination = HERE / 'results/victory_dependency_audit.json'
    destination.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: {v: row[v] for v in ['localBuildingCount', 'baseLocalIndustry', 'globalTechnologyCount', 'baseGlobalScience']}
                      for k, row in routes.items()}, indent=2))


if __name__ == '__main__':
    main()
