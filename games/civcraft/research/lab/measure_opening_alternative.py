#!/usr/bin/env python3
"""Matched actual-game continuations after one legal opening queue choice."""
from __future__ import annotations

import hashlib
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
from runtime import Runtime, from_lua
from runner import source_manifest
import workers

SEEDS = (375491, 884323, 318791, 546311)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_pair(config):
    target = config['targetSeat']
    original = Runtime(config)
    checkpoint = original.canonical_state()
    before = original.state_hash()
    arms = []
    for variant in ('baseline', 'guard_first'):
        runtime = Runtime(config)
        runtime.restore(checkpoint)
        assert runtime.state_hash() == before
        options = runtime.lua.table_from({'trace': True, 'actionBudget': 4096})
        telemetry = runtime.lua.globals().dofile('/lab/telemetry.lua').install(options)
        initial = runtime.observe(target)
        city = next(c for c in initial['cities'] if c.get('owner') == target)
        intervention = None
        if variant == 'guard_first':
            intervention = {'action': 'queue', 'cityX': city['x'], 'cityY': city['y'],
                            'kind': 'unit', 'id': 'warrior'}
            result = runtime.apply(target, intervention)
            ok = result[0] if isinstance(result, tuple) else bool(result)
            if not ok:
                arms.append({'variant': variant, 'status': 'intervention_unavailable',
                             'startHash': before, 'request': intervention, 'reason': str(result)})
                continue
        samples, first_settler, first_expansion = [], None, None
        while not runtime.finished() and runtime.state.round <= 180:
            if runtime.state.round > 8:
                options.trace = False
            runtime.pump()
            metrics = runtime.metrics()
            own = next(p for p in metrics['players'] if p['id'] == target)
            if own['units'].get('settler', 0) and first_settler is None:
                first_settler = int(runtime.state.round)
            if len(own['cities']) >= 2 and first_expansion is None:
                first_expansion = int(runtime.state.round)
            if runtime.state.round <= 10 or runtime.state.round in (20, 40, 80, 120):
                samples.append({'round': int(runtime.state.round), 'units': own['units'],
                                'cities': own['cities'], 'population': own['population'],
                                'industry': own['industry'], 'science': own['science']})
            if runtime.finished() or runtime.state.round >= 180:
                break
            runtime.advance()
        dispatch = from_lua(telemetry)
        finished = runtime.finished()
        winners = from_lua(runtime.state.winnerIDs or runtime.lua.table()) or []
        arms.append({'variant': variant, 'status': 'finished' if finished else 'censored',
                     'startHash': before, 'intervention': intervention,
                     'round': int(runtime.state.round), 'winnerIds': winners,
                     'targetWinCredit': ((1 / len(winners) if target in winners else 0)
                                         if winners else .5) if finished else None,
                     'victoryReason': runtime.state.victoryReason if finished else None,
                     'firstObservedSettlerRound': first_settler,
                     'firstObservedSecondCityRound': first_expansion,
                     'finalHash': runtime.state_hash(), 'samples': samples,
                     'dispatches': dispatch})
    return {'config': config, 'checkpointRound': 1, 'startHash': before, 'arms': arms,
            'status': 'finished' if all(a['status'] == 'finished' for a in arms) else 'incomplete'}


def pair_worker(connection, config):
    try:
        try:
            result = run_pair(config)
        except Exception as exc:
            result = {'config': config, 'status': 'error', 'error': f'{type(exc).__name__}: {exc}'}
        connection.send(result)
    finally:
        connection.close()


def main():
    inputs = [HERE / 'results/strategy_search_pilot.json',
              HERE / 'results/adversarial_archive_adaptation_pilot.json']
    champion = json.loads(inputs[0].read_text())['championHoldout']['policy']
    counter = json.loads(inputs[1].read_text())['selection']['selectedPolicy']
    configs = []
    for seed in SEEDS:
        for opponent_id, opponent in [('industrial', {'version': 1, 'goal': 'industrial'}),
                                      ('adapted-expedition', counter)]:
            for target in (0, 1):
                players = [{'civilization': 'forge', 'policy': opponent} for _ in range(2)]
                players[target] = {'civilization': 'forge', 'policy': champion}
                configs.append({'seed': seed, 'targetSeat': target, 'opponentId': opponent_id,
                                'players': players, 'mapSize': 'compact', 'mapType': 'pangaea',
                                'hostileMode': 'off', 'wallSeconds': 180, 'maxRounds': 180})
    # Persist the design before observing any outcomes.
    manifest_path = HERE / 'opening_alternative_manifest.json'
    manifest_path.write_text(json.dumps(configs, indent=2) + '\n')
    source = source_manifest()
    input_hashes = {str(p.relative_to(HERE)): digest(p) for p in inputs}
    original_worker = workers._worker
    workers._worker = pair_worker
    try:
        results = workers.run_bounded(configs, workers=4)
    finally:
        workers._worker = original_worker
    raw_path = Path('/tmp/civcraft-opening-alternative.raw.json')
    raw = {'source': source, 'sourceChangedDuringRun': source != source_manifest(),
           'inputHashes': input_hashes,
           'inputsChangedDuringRun': input_hashes != {str(p.relative_to(HERE)): digest(p) for p in inputs},
           'scriptSha256': digest(Path(__file__)), 'pairs': results}
    raw_path.write_text(json.dumps(raw, indent=2, sort_keys=True) + '\n')
    by_seed = defaultdict(list)
    compact = []
    for pair in results:
        item = {k: v for k, v in pair.items() if k != 'arms'}
        item['arms'] = [{k: v for k, v in arm.items() if k not in ('samples', 'dispatches')}
                        for arm in pair.get('arms', [])]
        if pair['status'] == 'finished':
            baseline, changed = pair['arms']
            delta = changed['targetWinCredit'] - baseline['targetWinCredit']
            by_seed[pair['config']['seed']].append(delta)
            item['winCreditDelta'] = delta
            b, c = baseline['firstObservedSecondCityRound'], changed['firstObservedSecondCityRound']
            item['secondCityDelay'] = c - b if b is not None and c is not None else None
            item['guardCompletedByRoundFour'] = any(s['round'] <= 4 and s['units'].get('warrior', 0) >= 2
                                                   for s in changed['samples'])
        compact.append(item)
    block_means = {str(seed): sum(values) / len(values) for seed, values in by_seed.items()}
    mean = sum(block_means.values()) / len(block_means) if block_means else None
    # Distribution-free bounded-mean interval under independent map sampling;
    # paired differences lie in [-1,1]. With four blocks this is intentionally
    # wide, instead of treating 16 permutations as independent observations.
    radius = 2 * math.sqrt(math.log(2 / .05) / (2 * len(block_means))) if block_means else None
    result = {k: v for k, v in raw.items() if k != 'pairs'} | {
        'purpose': 'One legal opening guard investment; not pre-labelled a mistake or optimal recovery',
        'rawArtifact': str(raw_path), 'manifest': str(manifest_path.relative_to(HERE)),
        'attemptedPairs': len(configs), 'completedPairs': sum(p['status'] == 'finished' for p in results),
        'pairs': compact, 'mapBlockWinCreditDeltas': block_means,
        'meanMapBlockWinCreditDelta': mean,
        'illustrative95PercentHoeffdingInterval': [max(-1, mean-radius), min(1, mean+radius)]
            if mean is not None else None,
        'intervalAssumption': 'Independent map blocks sampled from a common map population; four seeded exploratory maps do not establish broad generalization.',
        'limits': ['All Forge, compact Pangaea, no hostiles; two opponent policies and both seats.',
                   'Initial canonical checkpoints match exactly; all orders use the authoritative action validator.',
                   'Continuation policy is fixed, not an optimal or adapted recovery policy.',
                   'First-settler measurement is sampled after actor phases and can miss a settler founded within that phase.',
                   'First-second-city observations and retained queue work measure timing, not subjective fun.',
                   'A legal alternative may help or hurt; report improvement rather than defining the result by the word mistake.']}
    destination = HERE / 'results/opening_alternative.json'
    destination.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'pairs': len(configs), 'completed': result['completedPairs'],
                      'delta': mean, 'output': str(destination)}))
    if raw['sourceChangedDuringRun'] or raw['inputsChangedDuringRun']:
        raise SystemExit('Study source/input integrity failed')


if __name__ == '__main__':
    main()
