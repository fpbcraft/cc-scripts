#!/usr/bin/env python3
"""Paired legal research diversion from identical round-10 checkpoints."""
import hashlib
import json
import multiprocessing
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runner import source_manifest
from runtime import Runtime, from_lua


def continuation(config):
    initial = Runtime(config)
    while initial.state.round < 10:
        initial.pump()
        initial.advance()
    checkpoint = initial.canonical_state()
    rows = []
    for variant in ['baseline', 'research_diversion']:
        runtime = Runtime(config)
        runtime.restore(checkpoint)
        before = runtime.state_hash()
        accepted = True
        previous = runtime.state.players[1].researchTarget
        if variant == 'research_diversion':
            outcome = runtime.apply(0, {'action': 'researchTech', 'id': 'sailing'})
            accepted = outcome[0] if isinstance(outcome, tuple) else bool(outcome)
        if not accepted:
            rows.append({'variant': variant, 'status': 'intervention_unavailable', 'startHash': before})
            continue
        samples = []
        while not runtime.finished():
            runtime.pump()
            if runtime.state.round in [10, 20, 40, 80, 120]:
                samples.append(runtime.metrics())
            if not runtime.finished():
                runtime.advance()
        rows.append({'variant': variant, 'status': 'finished', 'startHash': before,
                     'previousResearch': previous, 'interventionAccepted': accepted,
                     'round': int(runtime.state.round), 'winnerIds': from_lua(runtime.state.winnerIDs) or [],
                     'victoryReason': runtime.state.victoryReason,
                     'finalHash': runtime.state_hash(), 'samples': samples})
    return {'config': config, 'checkpointRound': 10, 'variants': rows}


def main():
    policy = json.loads((HERE / 'results/strategy_search_pilot.json').read_text())['championHoldout']['policy']
    configs = []
    for seed in [99119, 61283]:
        for opponent in ['industrial', 'expedition']:
            configs.append({'seed': seed, 'mapSize': 'compact', 'mapType': 'pangaea',
                            'hostileMode': 'off', 'players': [
                                {'civilization': 'forge', 'policy': policy},
                                {'civilization': 'forge', 'policy': {'version': 1, 'goal': opponent}}]})
    source = source_manifest()
    with ProcessPoolExecutor(max_workers=2, mp_context=multiprocessing.get_context('spawn')) as pool:
        results = list(pool.map(continuation, configs))
    record = {'purpose': 'Pilot legal optional-research diversion; not optimal continuation or a learned win-probability estimate',
              'source': source, 'sourceChangedDuringRun': source != source_manifest(),
              'scriptSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'samples': results, 'limits': 'Two map blocks, one target faction/policy, no mobs, research mistakes only.'}
    destination = Path('/tmp/civcraft-recoverability-pilot.json')
    destination.write_text(json.dumps(record, indent=2) + '\n')
    compact = record | {'samples': [{**case, 'variants': [
        {key: value for key, value in variant.items() if key != 'samples'} for variant in case['variants']]}
        for case in results], 'rawArtifact': str(destination)}
    (HERE / 'results/recoverability_pilot.json').write_text(json.dumps(compact, indent=2) + '\n')
    print(json.dumps({'pairs': len(results), 'sourceChangedDuringRun': record['sourceChangedDuringRun'],
                      'rawArtifact': str(destination)}))


if __name__ == '__main__':
    main()
