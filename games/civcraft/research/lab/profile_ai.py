#!/usr/bin/env python3
"""Inclusive Lua CPU instrumentation of a known full match, with hash control."""
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import Runtime, from_lua
from runner import source_manifest

HOOK = '''
local targets = {
    {'ai', 'knowledge', 'beginTurn', 'military', 'research', 'staff', 'materials', 'choose', 'settle', 'engineer', 'diplomacy'},
    {'ai_routes', 'from'}, {'ai_tactics', 'ranked'}, {'ai_production', 'ranked'},
    {'ai_settlement', 'select', 'available', 'order'}, {'ai_campaigns', 'update'},
    {'presentation', 'capture'}, {'world', 'forPlayer', 'reveal'},
}
LAB_PROFILE = {}
for _, target in ipairs(targets) do
    local module = dofile('/games/civcraft/' .. target[1] .. '.lua')
    for index = 2, #target do
        local name = target[index]
        local original = assert(module[name], target[1] .. '.' .. name)
        local row = {calls = 0, cpuSeconds = 0, maxCallCpuSeconds = 0}
        LAB_PROFILE[target[1] .. '.' .. name] = row
        module[name] = function(...)
            local started = os.clock()
            local results = table.pack(original(...))
            local elapsed = os.clock() - started
            row.calls = row.calls + 1
            row.cpuSeconds = row.cpuSeconds + elapsed
            row.maxCallCpuSeconds = math.max(row.maxCallCpuSeconds, elapsed)
            return table.unpack(results, 1, results.n)
        end
    end
end
'''


def main():
    baseline = json.loads((HERE / 'results/host_benchmark.json').read_text())
    expected = baseline['cells'][0]['outcomes'][2]
    policy = json.loads((HERE / 'results/strategy_search_pilot.json').read_text())['championHoldout']['policy']
    config = {'seed': expected['seed'], 'mapSize': 'compact', 'mapType': 'pangaea',
              'hostileMode': 'off', 'players': [{'civilization': 'forge', 'policy': policy} for _ in range(4)]}
    before = source_manifest()
    runtime = Runtime(config)
    runtime.lua.execute(HOOK)
    started, cpu_started = time.perf_counter(), time.process_time()
    while not runtime.finished() and runtime.state.round < 180:
        runtime.pump()
        runtime.advance()
    actual = runtime.state_hash()
    result = {'purpose': 'Inclusive offline Lua CPU profile; wrappers add overhead and nested rows overlap',
              'source': before, 'sourceChangedDuringRun': before != source_manifest(), 'config': config,
              'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'wallSeconds': time.perf_counter() - started, 'processCpuSeconds': time.process_time() - cpu_started,
              'round': int(runtime.state.round), 'reason': runtime.state.victoryReason,
              'profile': from_lua(runtime.lua.globals().LAB_PROFILE),
              'finalHash': actual, 'unprofiledHash': expected['hash'], 'stateUnchangedByProfiling': actual == expected['hash'],
              'limits': ['One four-player compact no-hostile fixture; not a broad performance ranking.',
                         'Inclusive CPU times overlap; do not sum nested rows or infer exclusive costs.',
                         'Profiling changes allocations/timing; gameplay hash must match the unprofiled control.',
                         'Other research simulations may run concurrently; wall time is not isolated throughput.']}
    path = HERE / 'results/ai_cpu_profile.json'
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'hashEqual': result['stateUnchangedByProfiling'],
                      'cpuSeconds': result['processCpuSeconds'], 'output': str(path)}))
    if not result['stateUnchangedByProfiling'] or result['sourceChangedDuringRun']:
        raise SystemExit('Profile integrity failure')


if __name__ == '__main__':
    main()
