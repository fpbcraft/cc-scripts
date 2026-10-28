#!/usr/bin/env python3
"""Reproduce a complete native/offline match with the exported selected policy."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from check_native_parity import lua_literal
from runner import source_manifest
from runtime import Runtime


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--content-rules', choices=('baseline', 'p1'), default='baseline')
    args = parser.parse_args()
    policy = json.loads((HERE / 'results/strategy_search_pilot.json').read_text())['championHoldout']['policy']
    config = {'seed': 75123, 'mapSize': 'compact', 'mapType': 'pangaea', 'hostileMode': 'off',
              'players': [{'civilization': 'forge', 'policy': policy}, {'civilization': 'forge'}],
              'contentRules': args.content_rules}
    source = source_manifest()
    runtime = Runtime(config)
    while not runtime.finished():
        runtime.pump()
        runtime.advance()
    expected = runtime.canonical_state()
    profile = Path(tempfile.mkdtemp(prefix='civcraft-full-policy-'))
    computer = profile / 'computer/0'
    computer.mkdir(parents=True)
    (computer / 'parity_config.lua').write_text('return ' + lua_literal(config))
    shutil.copyfile(HERE / 'selected_policy.lua', computer / 'exported_policy.lua')
    script = ('fs.copy("/repo/games/civcraft","/games/civcraft");'
              'fs.copy("/repo/tools/civcraft_lab","/lab");'
              'shell.run("/games/civcraft/research/lab/native_policy_match.lua");os.shutdown()')
    command = ['/Applications/CraftOS-PC.app/Contents/MacOS/craftos', '--headless',
               '--directory', str(profile), '--mount-ro', f'/repo={ROOT}', '--exec', script]
    with (profile / 'console.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=log, check=True, timeout=180)
    output = computer / 'full_policy_match.json'
    if not output.exists():
        raise RuntimeError(f'Native adapter failed; inspect {profile}/console.log')
    observed = json.loads(output.read_text())
    actual = observed.pop('canonicalState')
    result = {'config': config, 'source': source,
              'fixtureSha256': hashlib.sha256((HERE / 'native_policy_match.lua').read_bytes()).hexdigest(),
              'exportSha256': hashlib.sha256((HERE / 'selected_policy.lua').read_bytes()).hexdigest(),
              'offlineRound': int(runtime.state.round), 'offlineVictory': runtime.state.victoryReason,
              'native': observed, 'fullStateEqual': expected == actual,
              'offlineHash': hashlib.sha256(expected.encode()).hexdigest(),
              'nativeHash': hashlib.sha256(actual.encode()).hexdigest(), 'profile': str(profile)}
    destination = HERE / ('results/p1_full_policy_native_parity.json' if args.content_rules == 'p1' else 'results/full_policy_native_parity.json')
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'round': result['offlineRound'], 'fullStateEqual': result['fullStateEqual'],
                      'output': str(destination)}))
    if not result['fullStateEqual']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
