#!/usr/bin/env python3
"""Identify early siege removals from the saved operational checkpoint."""
import json
from pathlib import Path

from coordinated_siege_study import HERE, ROOT, SiegeRuntime, base_config, hash_file
from runtime import from_lua
from runner import source_manifest


def continuation(checkpoint, instrumented):
    runtime = SiegeRuntime(base_config(923671, 1, 'coordinated'))
    runtime.restore(checkpoint)
    notices = None
    if instrumented:
        notices = runtime.call(runtime.lua.eval('''function()
            local events = dofile('/games/civcraft/events.lua')
            local systems = dofile('/games/civcraft/systems.lua')
            local original = events.notice
            local records = {}
            events.notice = function(state, kind, entity, content, recipient)
                if kind == 'disband' and entity and entity.owner == 1 then
                    local player = state.players[2]
                    records[#records+1] = {round=state.round, unitId=entity.id,
                        kind=entity.kind, hp=entity.hp or 100, goldAtNotice=player.gold,
                        treasuryNet=systems.treasury(player, state).net}
                end
                return original(state, kind, entity, content, recipient)
            end
            return records
        end'''))
    telemetry = runtime.lua.globals().dofile('/lab/telemetry.lua').install(
        runtime.lua.table_from({'trace': True, 'actionBudget': 4096}))
    while runtime.state.round < 84:
        runtime.pump()
        runtime.advance()
    return runtime.state_hash(), from_lua(notices) if notices is not None else [], from_lua(telemetry)


def main():
    before = source_manifest()
    path = HERE/'runs/route_detour_diagnostic.json'
    previous = json.loads(path.read_text())
    checkpoint = previous['matches'][0]['config']['researchCheckpoint']
    control, _, _ = continuation(checkpoint, False)
    observed, removals, telemetry = continuation(checkpoint, True)
    manual = [item for item in telemetry['trace'] if item['request']['action'] == 'disband']
    result = {'purpose': 'Matched-checkpoint automatic upkeep disband diagnosis',
        'sourceManifest': before, 'sourceUnchanged': before == source_manifest(),
        'scriptSha256': hash_file(Path(__file__)), 'inputSha256': hash_file(path),
        'checkpointHash': previous['checkpointHash'], 'finalRound': 84,
        'controlFinalHash': control, 'observedFinalHash': observed, 'fullStatesEqual': control == observed,
        'removals': removals, 'manualDisbandAttempts': manual,
        'limits': ['One four-round continuation of a known map; not a general bankruptcy frequency estimate.',
                   'Both control and instrumented continuations use the existing source upkeep rule.']}
    output = HERE/'results/siege_upkeep_diagnostic.json'
    output.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'output': str(output), 'fullStatesEqual': control == observed,
                      'removals': removals, 'manualDisbandAttempts': len(manual)}))
    if not result['sourceUnchanged'] or control != observed or manual:
        raise SystemExit('Upkeep diagnostic failed source/fidelity/no-manual-order check')


if __name__ == '__main__':
    main()
