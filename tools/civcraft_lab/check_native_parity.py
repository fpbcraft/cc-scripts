#!/usr/bin/env python3
"""Compare full authoritative states and detached observations across runtimes."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

from runtime import REPOSITORY, Runtime


def lua_literal(value):
    if isinstance(value, dict):
        return '{' + ','.join(f'[{lua_literal(k)}]={lua_literal(v)}' for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(map(lua_literal, value)) + '}'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return repr(value)
    return json.dumps(value)


def native(config, executable):
    profile = Path(tempfile.mkdtemp(prefix='civcraft-lab-parity-'))
    computer = profile / 'computer/0'
    computer.mkdir(parents=True)
    (computer / 'parity_config.lua').write_text('return ' + lua_literal(config))
    command = [str(executable), '--headless', '--directory', str(profile),
               '--mount-ro', f'/repo={REPOSITORY}', '--exec',
               'fs.copy("/repo/games/civcraft","/games/civcraft");'
               'fs.copy("/repo/tools/civcraft_lab","/lab");'
               'shell.run("/lab/parity_fixture.lua");os.shutdown()']
    with (profile / 'console.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=log, timeout=90, check=True)
    output = computer / 'parity_results.json'
    if not output.exists():
        raise RuntimeError(f'Native fixture failed; inspect {profile}/console.log')
    return json.loads(output.read_text()), str(profile)


def offline(config):
    runtime = Runtime(config)
    checkpoints = []

    def capture(label):
        observation = runtime.engine.observe(runtime.state, 0)
        checkpoints.append({'label': label, 'state': runtime.canonical_state(),
                            'observation': runtime.lua.globals().LAB_CANONICAL.encode(observation)})

    capture('initial')
    assert runtime.apply(0, {'action': 'researchTech', 'id': 'mining'})[0]
    capture('research')
    assert not runtime.apply(0, {'action': 'researchTech', 'id': 'netherite'})[0]
    capture('rejection')
    for round_number in range(1, 4):
        runtime.pump()
        capture(f'actors{round_number}')
        runtime.advance()
        capture(f'boundary{round_number}')
    return checkpoints


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--craftos', type=Path,
                        default=Path('/Applications/CraftOS-PC.app/Contents/MacOS/craftos'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    results = []
    for count, trained in [(2, False), (4, False), (2, True)]:
        config = {'seed': 12345 + count, 'mapSize': 'compact', 'mapType': 'continents',
                  'hostileMode': 'standard',
                  'players': [{'civilization': ['forge', 'scholar', 'iron', 'merchant'][i]}
                              for i in range(count)]}
        if trained:
            config['players'][0]['policy'] = {'version': 1, 'goal': 'expedition',
                                              'weights': {'science': 2, 'industry': 0.75}}
        expected = offline(config)
        observed, profile = native(config, args.craftos)
        checks = []
        for left, right in zip(expected, observed['checkpoints'], strict=True):
            for field in ['state', 'observation']:
                equal = left[field] == right[field]
                checks.append({'label': left['label'], 'field': field, 'equal': equal,
                               'offlineSha256': hashlib.sha256(left[field].encode()).hexdigest(),
                               'nativeSha256': hashlib.sha256(right[field].encode()).hexdigest()})
        results.append({'config': config, 'host': observed['host'], 'profile': profile, 'checks': checks})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + '\n')
    failed = [check for result in results for check in result['checks'] if not check['equal']]
    print(json.dumps({'fixtures': len(results), 'checks': sum(len(r['checks']) for r in results),
                      'failed': len(failed), 'output': str(args.output)}))
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
