"""Whole-game worker. Research truncation is censoring, never a fabricated score win."""
from __future__ import annotations

import hashlib
import json
import platform
import subprocess
import time
from pathlib import Path

from runtime import REPOSITORY, Runtime, from_lua


def source_manifest() -> dict:
    files = sorted((REPOSITORY / 'games/civcraft').glob('*.lua'))
    files += sorted(Path(__file__).resolve().parent.glob('*.lua'))
    files += sorted(Path(__file__).resolve().parent.glob('*.py'))
    files += [Path(__file__).resolve().parent / 'requirements.txt']
    digests = {str(p.relative_to(REPOSITORY)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    combined = hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPOSITORY, text=True).strip()
    return {'head': head, 'luaSourceHash': combined, 'files': digests}


def play(config: dict) -> dict:
    started = time.perf_counter()
    result = {'config': config, 'status': 'error', 'winnerIds': [], 'turns': []}
    runtime, telemetry = None, None
    try:
        runtime = Runtime(config, instruction_budget=config.get('instructionBudget', 200_000_000))
        result['runtime'] = runtime.runtime_info
        telemetry = runtime.lua.globals().dofile('/lab/telemetry.lua').install(
            runtime.lua.table_from({'actionBudget': config.get('actionBudget', 4096),
                                    'trace': config.get('trace', False)}))
        result['initialStateHash'] = runtime.state_hash()
        max_round = config.get('maxRounds', 270)
        while not runtime.finished() and runtime.state.round <= max_round:
            runtime.pump()
            every = config.get('telemetryEvery', 1)
            if (runtime.state.round - 1) % every == 0 or runtime.state.round >= max_round:
                result['turns'].append(runtime.metrics())
            if runtime.finished() or runtime.state.round >= max_round:
                break
            runtime.advance()
        if runtime.finished():
            result.update(status='finished', round=int(runtime.state.round),
                          victoryReason=runtime.state.victoryReason,
                          winnerIds=from_lua(runtime.state.winnerIDs or runtime.lua.table()) or [])
            if not result['turns'] or result['turns'][-1]['round'] != runtime.state.round:
                result['turns'].append(runtime.metrics())
        else:
            result.update(status='censored', round=int(runtime.state.round),
                          censorReason='research_round_budget')
        result['finalStateHash'] = runtime.state_hash()
        result['dispatches'] = from_lua(telemetry)
    except Exception as exc:
        result.update(error=f'{type(exc).__name__}: {exc}')
        if runtime is not None:
            result['errorRound'] = int(runtime.state.round)
            result['errorStateHash'] = runtime.state_hash()
            result['orphanHostileUnits'] = [
                {'id': unit.id, 'kind': unit.kind, 'x': unit.x, 'y': unit.y}
                for unit in runtime.state.units.values()
                if unit.owner == -2147483647 and unit.spawner is None]
        if telemetry is not None:
            result['dispatches'] = from_lua(telemetry)
    result['elapsedSeconds'] = time.perf_counter() - started
    return result


def write_run(configs: list[dict], output: Path, workers: int = 1) -> dict:
    from workers import run_bounded

    configs = [{'runtimeBackend': 'luajit21'} | config for config in configs]
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest = source_manifest()
    started = time.perf_counter()
    results = run_bounded(configs, workers)
    after = source_manifest()
    record = {'schemaVersion': 1, 'source': manifest,
              'host': {'machine': platform.machine(), 'python': platform.python_version(),
                       'cpuCount': __import__('os').cpu_count(),
                       'hardwareModel': 'not verified by this runner'},
              'sourceChangedDuringRun': manifest != after,
              'workers': workers, 'elapsedSeconds': time.perf_counter() - started,
              'matches': results}
    output.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False) + '\n')
    return record
