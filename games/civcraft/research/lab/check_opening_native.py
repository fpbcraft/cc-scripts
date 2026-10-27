#!/usr/bin/env python3
"""Validate one selected opening per economy in real CraftOS, against held-out results."""
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from check_native_parity import lua_literal
from runner import source_manifest


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=HERE / 'results/p1_opening_evaluate.json')
    parser.add_argument('--output', type=Path, default=HERE / 'results/p1_opening_native.json')
    args = parser.parse_args()
    record = json.loads(args.input.read_text())
    before = source_manifest()
    assert record['source'] == before and record['sourceUnchanged'] and record['status'] == 'complete'
    cases = []
    for rules in ('baseline', 'p1'):
        condition = next(c for c in record['conditions'] if c['config']['contentRules'] == rules)
        opening = record['selectedOpenings'][rules]
        expected = next(a for a in condition['arms'] if a['opening'] == opening)
        config = condition['config'] | {'opening': opening}
        profile = Path(tempfile.mkdtemp(prefix='civcraft-opening-native-'))
        computer = profile / 'computer/0'
        computer.mkdir(parents=True)
        (computer / 'opening_config.lua').write_text('return ' + lua_literal(config))
        command = ['/Applications/CraftOS-PC.app/Contents/MacOS/craftos', '--headless', '--directory', str(profile),
                   '--mount-ro', f'/repo={ROOT}', '--exec',
                   'fs.copy("/repo/games/civcraft","/games/civcraft");fs.copy("/repo/tools/civcraft_lab","/lab");'
                   'shell.run("/games/civcraft/research/lab/native_opening_match.lua");os.shutdown()']
        with (profile / 'console.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=log, check=True, timeout=180)
        actual = json.loads((computer / 'opening_result.json').read_text())
        actual_initial, actual_state = digest(actual.pop('initialState')), digest(actual.pop('canonicalState'))
        checks = {'initialStateEqual': actual_initial == condition['startHash'],
                  'fullStateEqual': actual_state == expected['finalStateHash'],
                  'dispatchCountsEqual': actual['dispatchCounts'] == expected['dispatchCounts']}
        row = {'config': config, 'profile': str(profile), 'checks': checks, 'native': actual,
               'initialStateHash': actual_initial, 'finalStateHash': actual_state}
        cases.append(row)
        print(json.dumps({'economy': rules, 'opening': opening, 'checks': checks, 'round': actual['round']}), flush=True)
    result = {'source': before, 'sourceUnchanged': before == source_manifest(), 'cases': cases,
              'evaluationArtifactSha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
              'nativeDriverSha256': hashlib.sha256((HERE / 'native_opening_match.lua').read_bytes()).hexdigest()}
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    if not result['sourceUnchanged'] or not all(all(row['checks'].values()) for row in cases):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
