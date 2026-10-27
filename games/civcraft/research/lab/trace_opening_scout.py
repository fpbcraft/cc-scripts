#!/usr/bin/env python3
"""Passive diagnostic of one already observed Scout-first failure."""
import hashlib
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import from_lua
from runner import source_manifest
from p1_pacing_study import OpeningRuntime

PROBE = '''function(target)
 local Tactics = dofile('/games/civcraft/ai_tactics.lua')
 local original = Tactics.ranked
 local data, seen = {}, {}
 Tactics.ranked = function(view, player, unit, systems)
  local choices = original(view, player, unit, systems)
  if player.id == target and unit.kind == 'scout' and not seen[view.round] then
   seen[view.round] = true
   local row = {round=view.round, unitID=unit.id, x=unit.x, y=unit.y, hp=unit.hp,
                role=unit.aiRole and unit.aiRole.name, choices={}}
   local campaign = (player.aiPlan or {}).campaign or {}
   row.campaign = {kind=campaign.kind, phase=campaign.phase, x=campaign.x, y=campaign.y}
   for i=1,math.min(3,#choices) do
    local c = choices[i]
    row.choices[i] = {score=c.score, action=c.request.action, x=c.request.x, y=c.request.y}
   end
   data[#data+1] = row
  end
  return choices
 end
 return data
end'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--training', type=Path, default=HERE / 'results/p1_opening_train.json')
    parser.add_argument('--output', type=Path, default=HERE / 'results/p1_scout_diagnostic.json')
    args = parser.parse_args()
    training = json.loads(args.training.read_text())
    before = source_manifest()
    assert before == training['source']
    condition = next(c for c in training['conditions'] if c['config']['contentRules'] == 'p1'
                     and next(a for a in c['arms'] if a['opening'] == 'scout')['targetWinCredit']
                     < next(a for a in c['arms'] if a['opening'] == 'default')['targetWinCredit'])
    expected = next(a for a in condition['arms'] if a['opening'] == 'scout')
    config = condition['config']
    runtime = OpeningRuntime(config)
    assert runtime.state_hash() == condition['startHash']
    target = config['targetSeat']
    probe = runtime.call(runtime.lua.eval(PROBE), target)
    assert runtime.apply(target, expected['request'])[0]
    positions, contacts = [], []
    while not runtime.finished() and runtime.state.round <= config['maxRounds']:
        runtime.pump()
        for unit in runtime.state.units.values():
            if unit.owner == target and unit.kind == 'scout':
                positions.append({'round': int(runtime.state.round), 'id': unit.id, 'x': unit.x, 'y': unit.y,
                                  'hp': unit.hp, 'movesLeft': unit.movesLeft})
        contacts.append(sum(bool(v) for v in (runtime.state.players[target + 1].contacts or runtime.lua.table()).values()))
        if runtime.finished() or runtime.state.round >= config['maxRounds']:
            break
        runtime.advance()
    actual_hash = runtime.state_hash()
    decisions = from_lua(probe)
    unique = sorted({(p['x'], p['y']) for p in positions})
    longest, current, last = 0, 0, None
    for p in positions:
        point = (p['id'], p['x'], p['y'])
        current = current + 1 if point == last else 1
        longest = max(longest, current)
        last = point
    result = {'config': config, 'selectedAfterInspection': 'First training P1 condition losing win credit under Scout-first',
              'source': before, 'sourceUnchanged': before == source_manifest(),
              'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'expectedFinalStateHash': expected['finalStateHash'], 'actualFinalStateHash': actual_hash,
              'fullStateEqual': actual_hash == expected['finalStateHash'], 'scoutObservedRounds': len(positions),
              'uniquePostActorScoutPositions': unique, 'longestSamePositionRun': longest,
              'tacticalDecisionCalls': len(decisions), 'topActionCounts': {},
              'firstDecisions': decisions[:8], 'lastDecisions': decisions[-4:],
              'firstPositions': positions[:8], 'lastPositions': positions[-4:], 'maximumContacts': max(contacts)}
    from collections import Counter
    result['topActionCounts'] = dict(Counter(row['choices'][0]['action'] for row in decisions))
    path = args.output
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('source','firstDecisions','lastDecisions','config')}))
    if not result['fullStateEqual'] or not result['sourceUnchanged']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
