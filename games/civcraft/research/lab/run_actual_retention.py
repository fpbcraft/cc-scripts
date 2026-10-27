#!/usr/bin/env python3
"""Run held-out full games for actual compact policies versus original AI."""

from __future__ import annotations

import argparse
import hashlib
import json
import multiprocessing as mp
import time
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
from runtime import Runtime, from_lua  # noqa: E402
from runner import source_manifest  # noqa: E402


def config(seed: int, policy: dict | None = None, seat: int = 0) -> dict:
    players = [{"civilization": "forge"}, {"civilization": "forge"}]
    if policy is not None:
        players[seat]["policy"] = policy
    return {"seed": seed, "mapSize": "compact", "mapType": "pangaea", "hostileMode": "off",
            "maxRounds": 180, "telemetryEvery": 10,
            "players": players}


def run(seed: int, name: str, policy_path: Path | None, seat: int = 0, policy: dict | None = None,
        mode: str = "model") -> dict:
    started = time.perf_counter()
    runtime = Runtime(config(seed, policy, seat))
    if policy_path is not None:
        policy_source = policy_path.read_text(encoding="utf-8")
        adapter = (HERE / "compact_policy_adapter.lua").read_text(encoding="utf-8")
        runtime.lua.execute("COMPACT_PLAYER_ID = " + str(seat) + "\nCOMPACT_MODE = " + repr(mode) +
                            "\nCOMPACT_POLICY = (function()\n" + policy_source + "\nend)()\n" + adapter)
    while not runtime.finished() and int(runtime.state.round) <= 180:
        runtime.pump()
        if runtime.finished() or int(runtime.state.round) >= 180:
            break
        runtime.advance()
    return {"policy": name, "seed": seed,
            "status": "finished" if runtime.finished() else "censored", "targetSeat": seat,
            "round": int(runtime.state.round), "victoryReason": runtime.state.victoryReason,
            "winnerIds": from_lua(runtime.state.winnerIDs or runtime.lua.table()) or [],
            "elapsedSeconds": time.perf_counter() - started,
            "finalStateHash": runtime.state_hash()}


def _job(job: tuple) -> dict:
    name, seed, seat, policy_path, policy, mode = job
    try:
        return run(seed, name, Path(policy_path) if policy_path else None, seat, policy, mode)
    except Exception as exc:
        return {"policy": name, "seed": seed, "targetSeat": seat, "status": "error",
                "error": f"{type(exc).__name__}: {exc}"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", default="95117,808381")
    parser.add_argument("--out", type=Path, default=HERE / "results/actual_full_game_retention.json")
    args = parser.parse_args()
    seeds = [int(x) for x in args.seeds.split(",") if x]
    archived = json.loads((HERE / "results/strategy_search_pilot.json").read_text())[
        "championHoldout"]["policy"]
    compact_weights = HERE / "formats/actual_weights.lua"
    policies = [("original_teacher", None, None, "none"),
                ("oracle_rank_hook", compact_weights, None, "oracle"),
                ("archived_champion", None, archived, "none"),
    ] + [
        (name, HERE / "formats" / ("actual_" + name + ".lua"), None, "model")
        for name in ("weights", "rule_tree", "tiny_quantized_mlp")]
    model_paths = [HERE / "compact_policy_adapter.lua", HERE / "policy_format_comparison.py"] + [p for _, p, _, _ in policies if p]
    source_before = source_manifest()
    model_hashes_before = {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in model_paths}
    jobs = [(name, seed, seat, str(path) if path else None, policy, mode)
            for name, path, policy, mode in policies for seed in seeds for seat in (0, 1)]
    print(json.dumps({"event": "suite_start", "workers": 4, "jobs": len(jobs)}), flush=True)
    context = mp.get_context("spawn")
    pool = context.Pool(processes=4)
    try:
        async_result = pool.map_async(_job, jobs)
        matches = async_result.get(timeout=240)
        pool.close()
    except Exception as exc:
        pool.terminate()
        matches = [{"status": "timeout", "error": f"{type(exc).__name__}: {exc}"}]
    finally:
        pool.join()
    source_after = source_manifest()
    model_hashes_after = {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in model_paths}
    oracle_hash_checks = []
    original_by_key = {(m.get("seed"), m.get("targetSeat")): m.get("finalStateHash")
                       for m in matches if m.get("policy") == "original_teacher"}
    for match in matches:
        if match.get("policy") == "oracle_rank_hook":
            key = (match.get("seed"), match.get("targetSeat"))
            oracle_hash_checks.append({"seed": key[0], "targetSeat": key[1],
                                       "equalToOriginal": match.get("finalStateHash") == original_by_key.get(key),
                                       "oracleHash": match.get("finalStateHash"),
                                       "originalHash": original_by_key.get(key)})
    output = {"status": "actual_full_game_retention", "seeds": seeds, "players": 2, "workers": 4,
              "source_before": source_before, "source_after": source_after,
              "source_changed_during_run": source_before != source_after,
              "model_hashes_before": model_hashes_before, "model_hashes_after": model_hashes_after,
              "model_changed_during_run": model_hashes_before != model_hashes_after,
              "oracle_control": {"matches": oracle_hash_checks,
                                 "all_equal": bool(oracle_hash_checks) and all(x["equalToOriginal"] for x in oracle_hash_checks)},
              "matches": matches,
              "claim_limits": ["Two Forge seats, hostile-off, compact Pangaea holdout only.",
                               "This is retention against the original controller, not faction balance.",
                               "Errors/censors would be ineligible, not converted to losses."]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": output["status"], "matches": len(matches), "out": str(args.out),
                      "source_changed_during_run": output["source_changed_during_run"]}))


if __name__ == "__main__":
    main()
