#!/usr/bin/env python3
"""Native parity for the standalone Lua siege policy, without Python hook wrappers."""
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

from coordinated_siege_study import ROOT, HERE, PARAMETERS, POLICY, base_config
import military_competence_benchmark as military
from runtime import Runtime
from runner import source_manifest
from check_native_parity import lua_literal


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def offline(case):
    runtime = Runtime(case['config'])
    if case['coordinated']:
        policy = runtime.lua.globals().dofile('/games/civcraft/research/lab/coordinated_siege_policy.lua')
        runtime.call(policy.install, runtime.lua.table_from(PARAMETERS))
    military._fixture_setup(runtime, case['scenario'])
    result = {'states': [runtime.canonical_state()], 'observations': []}
    for _ in range(8):
        runtime.pump()
        result['states'].append(runtime.canonical_state())
        result['observations'].append([runtime.call(runtime.lua.globals().LAB_CANONICAL.encode,
            runtime.call(runtime.engine.observe, runtime.state, observer)) for observer in (0, 1)])
        if runtime.finished():
            break
        runtime.advance()
    result['finalState'] = runtime.canonical_state()
    return result


def main():
    cases = [{'scenario': scenario, 'coordinated': coordinated, 'parameters': PARAMETERS,
              'config': base_config(95117, 0, 'coordinated' if coordinated else 'existing_hooks')}
             for scenario in ('siege_breach', 'fortified_capture') for coordinated in (False, True)]
    source = source_manifest()
    files = (Path(__file__), HERE/'siege_policy_native.lua', Path(military.__file__), POLICY,
             HERE/'coordinated_siege_study.py')
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    expected = [offline(case) for case in cases]
    profile = Path(tempfile.mkdtemp(prefix='civcraft-siege-policy-'))
    computer = profile/'computer/0'
    computer.mkdir(parents=True)
    (computer/'siege_cases.lua').write_text('return '+lua_literal(cases))
    (computer/'siege_setup.lua').write_text('return '+military._FIXTURE_LUA)
    shutil.copyfile(HERE/'siege_policy_native.lua', computer/'siege_policy_native.lua')
    command = ['/Applications/CraftOS-PC.app/Contents/MacOS/craftos', '--headless',
               '--directory', str(profile), '--mount-ro', f'/repo={ROOT}', '--exec',
               'fs.copy("/repo/games/civcraft","/games/civcraft");'
               'fs.copy("/repo/tools/civcraft_lab","/lab");'
               'shell.run("/siege_policy_native.lua");os.shutdown()']
    with (profile/'console.log').open('w') as log:
        completed = subprocess.run(command, stdout=log, stderr=log, timeout=120)
    payload = computer/'siege_policy_native.json'
    if not payload.exists():
        raise RuntimeError(f'Native output missing, exit {completed.returncode}: {profile}')
    native = json.loads(payload.read_text())
    checks = []
    for case, wanted, actual in zip(cases, expected, native['cases'], strict=True):
        checks.append({'scenario': case['scenario'], 'coordinated': case['coordinated'],
                       'allStatesEqual': wanted['states'] == actual['states'],
                       'allObservationsEqual': wanted['observations'] == actual['observations'],
                       'finalStateEqual': wanted['finalState'] == actual['finalState'],
                       'stateBoundaries': len(wanted['states']),
                       'observationPairs': len(wanted['observations']),
                       'finalStateSha256': digest(wanted['finalState'])})
    unchanged = source == source_manifest() and hashes == {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    result = {'purpose': 'Standalone Lua siege policy native/Lupa scenario parity',
              'sourceManifest': source, 'researchHashes': hashes, 'cases': cases,
              'checks': checks, 'sourceUnchanged': unchanged,
              'nativeHost': native['host'], 'nativeExitCode': completed.returncode,
              'profile': str(profile), 'policyBytes': POLICY.stat().st_size,
              'limitations': ['This does not validate the Python-installed military hook bundle natively.',
                              'Controlled scenario armies are supplied budgets, not full-game economic achievements.']}
    output = HERE/'results/coordinated_siege_native_parity.json'
    output.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'output': str(output), 'sourceUnchanged': unchanged, 'checks': checks}))
    if completed.returncode or not unchanged or not all(c[k] for c in checks
            for k in ('allStatesEqual', 'allObservationsEqual', 'finalStateEqual')):
        raise SystemExit('Native siege policy parity failed')


if __name__ == '__main__':
    main()
