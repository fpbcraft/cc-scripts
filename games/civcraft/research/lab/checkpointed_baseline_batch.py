#!/usr/bin/env python3
"""Checkpointed fixed-strategy baseline matrix.

Research-only harness. It uses the existing fixed-Forge-personality ablation
worker and actual ``runner.play`` jobs. Per-game terminal records are atomic
and source/config fingerprints are required before a record can be reused.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import shutil
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
MANIFEST_PATH = HERE / "baseline_matrix_manifest.json"
RUNS_ROOT = HERE / "runs"
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
import workers  # noqa: E402
from runner import source_manifest  # noqa: E402
from run_fixed_personality_ablation import ablation_worker  # noqa: E402


SCRIPT_PATH = Path(__file__).resolve()
ADAPTER_PATH = HERE / "run_fixed_personality_ablation.py"
RUNTIME_PATH = ROOT / "tools/civcraft_lab/runtime.py"
WORKERS_PATH = ROOT / "tools/civcraft_lab/workers.py"
SELECTED_POLICY = json.loads((RESULTS / "strategy_search_pilot.json").read_text())["championHoldout"]["policy"]
NON_FORGE = ("verdant", "iron", "scholar", "nomad", "wild", "mariner", "highland", "merchant", "sentinel")
MAP_BLOCKS = {
    "continents": (610111, 610113),
    "archipelago": (620117, 620119),
    "pangaea": (630127, 630131),
    "highlands": (640137, 640139),
}
TERMINAL_STATUSES = {"finished", "censored", "error", "timeout", "invalid_setup"}
CONFIG_VERSION = "baseline-matrix-v1"


def stable_json(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def adapter_fingerprints() -> dict:
    return {
        "fixedPersonalityAblation": file_sha(ADAPTER_PATH),
        "runtime": file_sha(RUNTIME_PATH),
        "workers": file_sha(WORKERS_PATH),
    }


def policy_records() -> list[dict]:
    return [{"version": SELECTED_POLICY["version"], "weights": SELECTED_POLICY["weights"],
             "goal": SELECTED_POLICY["goal"]}]


def config_for(block: str, seed: int, target_civ: str | None, target_seat: int | None, mirror: bool) -> dict:
    if mirror:
        players = [
            {"civilization": "forge", "policy": SELECTED_POLICY},
            {"civilization": "forge", "policy": SELECTED_POLICY},
        ]
        label = "forge-mirror"
    elif target_seat == 0:
        players = [
            {"civilization": target_civ, "policy": SELECTED_POLICY},
            {"civilization": "forge", "policy": SELECTED_POLICY},
        ]
        label = f"{target_civ}-vs-forge"
    else:
        players = [
            {"civilization": "forge", "policy": SELECTED_POLICY},
            {"civilization": target_civ, "policy": SELECTED_POLICY},
        ]
        label = f"forge-vs-{target_civ}"
    return {
        "configVersion": CONFIG_VERSION,
        "mapBlock": block,
        "seed": seed,
        "mapSize": "compact",
        "mapType": block,
        "hostileMode": "off",
        "telemetryEvery": 10,
        "maxRounds": 180,
        "wallSeconds": 180,
        "instructionBudget": 200_000_000,
        "actionBudget": 4096,
        "players": players,
        "targetCiv": target_civ or "forge",
        "targetSeat": target_seat if target_seat is not None else 0,
        "mirror": mirror,
        "label": label,
    }


def build_jobs(max_rounds: int = 180) -> list[dict]:
    jobs = []
    for block, seeds in MAP_BLOCKS.items():
        for seed in seeds:
            for civ in NON_FORGE:
                for seat in (0, 1):
                    config = config_for(block, seed, civ, seat, False)
                    if max_rounds != 180:
                        config["maxRounds"] = max_rounds
                        config["wallSeconds"] = max(30, min(180, max_rounds * 2))
                    jobs.append(config)
            config = config_for(block, seed, None, None, True)
            if max_rounds != 180:
                config["maxRounds"] = max_rounds
                config["wallSeconds"] = max(30, min(180, max_rounds * 2))
            jobs.append(config)
    return jobs


def source_fingerprint(manifest: dict) -> str:
    return sha(stable_json({"source": manifest, "adapter": adapter_fingerprints()}))


def job_id(config: dict) -> str:
    return sha(stable_json(config))[:20]


def write_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{next(tempfile._get_candidate_names())}.tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def expected_manifest(jobs: list[dict], source: dict) -> dict:
    return {
        "schemaVersion": 1,
        "status": "prepared-not-run",
        "configVersion": CONFIG_VERSION,
        "purpose": "Fixed strategy slice: selected expedition policy, fixed Forge personality, all map families",
        "sourceManifestBeforeRun": source,
        "sourceFingerprint": source_fingerprint(source),
        "scriptSha256BeforeRun": file_sha(SCRIPT_PATH),
        "adapterFingerprintsBeforeRun": adapter_fingerprints(),
        "configuration": {
            "mapBlocks": {key: list(value) for key, value in MAP_BLOCKS.items()},
            "nonForge": list(NON_FORGE),
            "players": "target civilization versus Forge selected expedition; both seat rotations",
            "forgeMirror": "one Forge-versus-Forge selected-expedition game per map block",
            "mapSize": "compact", "hostileMode": "off", "maxRounds": 180,
            "metricsEvery": 10, "workers": 4,
            "selectedPolicy": SELECTED_POLICY,
            "fixedPersonalityHook": "run_fixed_personality_ablation.FixedPersonalityRuntime",
        },
        "jobs": [{"jobId": job_id(config), "config": config} for config in jobs],
        "jobCount": len(jobs),
        "limits": [
            "This is a fixed-strategy slice, not all-route fairness or all-population faction balance.",
            "Exactly eight independent map blocks: two seeds per map family.",
            "Hostile mode is off because this baseline isolates faction/map/policy behavior.",
            "Player IDs, names and actor order remain normal runner defaults; no causal seat claim follows.",
        ],
    }


def prepare_manifest(max_rounds: int = 180) -> dict:
    source = source_manifest()
    jobs = build_jobs(max_rounds)
    if max_rounds == 180:
        manifest = expected_manifest(jobs, source)
        write_atomic(MANIFEST_PATH, manifest)
        return manifest
    return expected_manifest(jobs, source)


def record_path(run_root: Path, job: dict) -> Path:
    return run_root / f"{job_id(job)}.json"


def reusable(path: Path, job: dict, source: dict, expected_script: str | None = None,
             expected_adapters: dict | None = None) -> dict | None:
    if not path.exists():
        return None
    try:
        record = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    if record.get("status") not in TERMINAL_STATUSES:
        return None
    if record.get("jobId") != job_id(job) or record.get("config") != job:
        return None
    if record.get("sourceFingerprint") != source_fingerprint(source):
        return None
    if record.get("adapterFingerprints") != (expected_adapters or adapter_fingerprints()):
        return None
    if expected_script is not None and record.get("scriptSha256") != expected_script:
        return None
    return record


def durable_record(job: dict, result: dict, source: dict) -> dict:
    status = result.get("status", "error")
    if status not in TERMINAL_STATUSES:
        status = "error"
    return {
        "schemaVersion": 1,
        "jobId": job_id(job),
        "status": status,
        "config": job,
        "sourceHead": source["head"],
        "luaSourceHash": source["luaSourceHash"],
        "sourceFingerprint": source_fingerprint(source),
        "adapterFingerprints": adapter_fingerprints(),
        "scriptSha256": file_sha(SCRIPT_PATH),
        "result": result,
    }


def run_jobs(jobs: list[dict], run_root: Path, source: dict, workers_count: int,
             limit: int | None = None, expected_script: str | None = None,
             expected_adapters: dict | None = None) -> tuple[list[dict], dict]:
    records: list[dict] = []
    pending: list[dict] = []
    reused = 0
    for job in jobs:
        cached = reusable(record_path(run_root, job), job, source, expected_script, expected_adapters)
        if cached is not None:
            records.append(cached)
            reused += 1
        else:
            pending.append(job)
    if limit is not None:
        pending = pending[:limit]
    original_worker = workers._worker
    workers._worker = ablation_worker
    started = time.perf_counter()
    try:
        for index in range(0, len(pending), workers_count):
            batch = pending[index:index + workers_count]
            results = workers.run_bounded(batch, workers_count)
            for job, result in zip(batch, results, strict=True):
                if result is None:
                    result = {"status": "error", "error": "missing_worker_result", "config": job}
                record = durable_record(job, result, source)
                write_atomic(record_path(run_root, job), record)
                records.append(record)
    finally:
        workers._worker = original_worker
    records.sort(key=lambda row: row["jobId"])
    return records, {"reused": reused, "launched": len(pending), "elapsedSeconds": time.perf_counter() - started}


def smoke() -> dict:
    root = Path(tempfile.mkdtemp(prefix="civcraft-baseline-smoke-"))
    run_root = root / "runs"
    source = source_manifest()
    jobs = build_jobs(max_rounds=2)[:2]
    manifest = expected_manifest(jobs, source)
    write_atomic(root / "manifest.json", manifest)
    first, first_stats = run_jobs(jobs, run_root, source, workers_count=1, limit=1,
                                  expected_script=manifest["scriptSha256BeforeRun"],
                                  expected_adapters=manifest["adapterFingerprintsBeforeRun"])
    hashes_first = {row["jobId"]: sha(stable_json(row)) for row in first}
    second, second_stats = run_jobs(jobs, run_root, source, workers_count=1, limit=1,
                                    expected_script=manifest["scriptSha256BeforeRun"],
                                    expected_adapters=manifest["adapterFingerprintsBeforeRun"])
    hashes_second = {row["jobId"]: sha(stable_json(row)) for row in second}
    third, third_stats = run_jobs(jobs, run_root, source, workers_count=1, limit=0,
                                  expected_script=manifest["scriptSha256BeforeRun"],
                                  expected_adapters=manifest["adapterFingerprintsBeforeRun"])
    hashes_third = {row["jobId"]: sha(stable_json(row)) for row in third}
    result = {
        "schemaVersion": 1,
        "purpose": "Resumability smoke: first one job, resume remaining, third cached-only",
        "root": str(root),
        "manifest": str(root / "manifest.json"),
        "first": first_stats,
        "second": second_stats,
        "third": third_stats,
        "firstHashes": hashes_first,
        "secondHashes": hashes_second,
        "thirdHashes": hashes_third,
        "allTerminal": all(row["status"] in TERMINAL_STATUSES for row in third),
        "sameHashesAfterResume": hashes_second == hashes_third,
        "cachedOnlyThird": third_stats["reused"] == len(jobs) and third_stats["launched"] == 0,
    }
    write_atomic(root / "smoke_result.json", result)
    print(json.dumps(result, sort_keys=True))
    if not result["allTerminal"] or not result["sameHashesAfterResume"] or not result["cachedOnlyThird"]:
        raise SystemExit("Resumability smoke failed")
    return result


def normalize_route(reason: str | None) -> list[str]:
    if not reason:
        return []
    return [part.strip() for part in reason.split("/") if part.strip()]


def compact_result(records: list[dict], source_before: dict, source_after: dict, run_stats: dict,
                   *, script_before: str | None = None, script_after: str | None = None,
                   adapter_before: dict | None = None, adapter_after: dict | None = None) -> dict:
    finished = [row for row in records if row["status"] == "finished"]
    status_counts = Counter(row["status"] for row in records)
    routes = Counter(route for row in finished for route in normalize_route(row["result"].get("victoryReason")))
    block_rows: dict[str, list[dict]] = defaultdict(list)
    civ_rows: dict[str, list[dict]] = defaultdict(list)
    intent_finish = Counter()
    for row in finished:
        config = row["config"]
        result = row["result"]
        winners = result.get("winnerIds", [])
        target_win_credit = (1 / len(winners) if config["targetSeat"] in winners else 0.0) if winners else 0.5
        if config["mirror"]:
            continue
        # A block is one map-family/seed pair.  The two seeds per family are
        # intentionally independent clusters for the descriptive interval.
        block_key = f"{config['mapBlock']}:{config['seed']}"
        block_rows[block_key].append({"credit": target_win_credit, "config": config, "result": result})
        civ_rows[config["targetCiv"]].append({"credit": target_win_credit, "config": config, "result": result})
        intent_finish["intended-expedition-games"] += 1
        for route in normalize_route(result.get("victoryReason")):
            intent_finish[f"actual-{route}"] += 1
    per_block = []
    for block, rows in sorted(block_rows.items()):
        mean = sum(row["credit"] for row in rows) / len(rows) if rows else None
        map_family, seed = block.split(":", 1)
        per_block.append({"mapFamily": map_family, "seed": int(seed), "games": len(rows),
                          "targetWinCredit": mean})
    block_means = [row["targetWinCredit"] for row in per_block if row["targetWinCredit"] is not None]
    block_mean = sum(block_means) / len(block_means) if block_means else None
    block_epsilon = math.sqrt(math.log(2 / 0.05) / (2 * len(block_means))) if block_means else None
    civ_summary = {}
    for civ, rows in sorted(civ_rows.items()):
        civ_summary[civ] = {
            "games": len(rows),
            "targetWinCredit": sum(row["credit"] for row in rows) / len(rows),
            "victoryReasons": dict(Counter(route for row in rows for route in normalize_route(row["result"].get("victoryReason")))),
        }
    return {
        "schemaVersion": 1,
        "purpose": "Fixed strategy slice; not all-route fairness or all-population faction balance",
        "sourceHashBeforeAfter": {"before": source_before["luaSourceHash"], "after": source_after["luaSourceHash"],
                                   "sourceChangedDuringRun": source_before != source_after},
        "scriptSha256BeforeRun": script_before or file_sha(SCRIPT_PATH),
        "scriptSha256AfterRun": script_after or file_sha(SCRIPT_PATH),
        "adapterFingerprints": adapter_after or adapter_before or adapter_fingerprints(),
        "configuration": {"mapBlocks": {key: list(value) for key, value in MAP_BLOCKS.items()},
                          "nonForge": list(NON_FORGE), "gamesAttempted": len(records),
                          "workers": 4, "mapSize": "compact", "hostileMode": "off", "maxRounds": 180},
        "executionQuality": {"statusCounts": dict(status_counts), "finished": len(finished),
                              "attempted": len(records), "runStats": run_stats},
        "victoryReasons": dict(routes),
        "routeIntentVsFinish": {"targetIntent": "expedition", "counts": dict(intent_finish)},
        "mapBlockIntervals": {
            "blocks": per_block,
            "aggregate": {
                "clusterCount": len(block_means),
                "targetWinCredit": block_mean,
                "hoeffding95": [max(0, block_mean - block_epsilon), min(1, block_mean + block_epsilon)]
                if block_mean is not None else None,
            },
        },
        "civilizationSummary": civ_summary,
        "rawRunDirectory": str(RUNS_ROOT),
        "limits": [
            "This fixed selected-expedition slice is not a route-fairness study.",
            "Hoeffding intervals are honest eight-block descriptive bounds, not population estimates over all maps.",
            "All map families have two seeds; player IDs, actor order and policy tie-breaks remain normal.",
            "Hostiles are disabled; results do not generalize to wilderness pressure.",
            "Errors/timeouts are execution-quality outcomes, never losses or route failures.",
        ],
    }


def full_run(args: argparse.Namespace) -> None:
    if not MANIFEST_PATH.exists():
        raise SystemExit("Prepare manifest first with --prepare-manifest")
    manifest = json.loads(MANIFEST_PATH.read_text())
    source_before = source_manifest()
    if source_before != manifest["sourceManifestBeforeRun"]:
        raise SystemExit("Source changed after manifest preparation; refusing to run")
    if file_sha(SCRIPT_PATH) != manifest["scriptSha256BeforeRun"]:
        raise SystemExit("Driver changed after manifest preparation; refusing to resume")
    if adapter_fingerprints() != manifest["adapterFingerprintsBeforeRun"]:
        raise SystemExit("Runtime adapter changed after manifest preparation; refusing to resume")
    jobs = [entry["config"] for entry in manifest["jobs"]]
    run_root = RUNS_ROOT / CONFIG_VERSION
    records, stats = run_jobs(jobs, run_root, source_before, args.workers,
                              expected_script=manifest["scriptSha256BeforeRun"],
                              expected_adapters=manifest["adapterFingerprintsBeforeRun"])
    source_after = source_manifest()
    compact = compact_result(records, source_before, source_after, stats,
                             script_before=manifest["scriptSha256BeforeRun"],
                             script_after=manifest["scriptSha256BeforeRun"],
                             adapter_before=manifest["adapterFingerprintsBeforeRun"],
                             adapter_after=manifest["adapterFingerprintsBeforeRun"])
    compact["manifest"] = str(MANIFEST_PATH)
    compact["runRoot"] = str(run_root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(compact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"attempted": len(records), "finished": compact["executionQuality"]["finished"],
                      "statusCounts": compact["executionQuality"]["statusCounts"],
                      "output": str(args.output), "runRoot": str(run_root)}))


def analyze_existing(args: argparse.Namespace) -> None:
    """Rebuild the compact analysis from durable records without rerunning games."""
    if not MANIFEST_PATH.exists():
        raise SystemExit("Manifest is missing; cannot identify the source-frozen run")
    manifest = json.loads(MANIFEST_PATH.read_text())
    run_root = RUNS_ROOT / CONFIG_VERSION
    records = []
    for entry in manifest["jobs"]:
        path = record_path(run_root, entry["config"])
        if not path.exists():
            raise SystemExit(f"Missing durable record: {path}")
        records.append(json.loads(path.read_text()))
    existing = json.loads(args.output.read_text()) if args.output.exists() else {}
    source = manifest["sourceManifestBeforeRun"]
    compact = compact_result(
        records, source, source,
        existing.get("executionQuality", {}).get("runStats", {"reused": len(records), "launched": 0}),
        script_before=manifest["scriptSha256BeforeRun"],
        script_after=manifest["scriptSha256BeforeRun"],
        adapter_before=manifest["adapterFingerprintsBeforeRun"],
        adapter_after=manifest["adapterFingerprintsBeforeRun"],
    )
    compact["manifest"] = str(MANIFEST_PATH)
    compact["runRoot"] = str(run_root)
    compact["analysisOnly"] = True
    compact["postRunAnalysisScriptSha256"] = file_sha(SCRIPT_PATH)
    args.output.write_text(json.dumps(compact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"records": len(records), "output": str(args.output),
                      "analysisOnly": True, "postRunAnalysisScriptSha256": compact["postRunAnalysisScriptSha256"]}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare-manifest", action="store_true")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--analyze-existing", action="store_true")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--output", type=Path, default=RESULTS / "baseline_matrix.json")
    args = parser.parse_args()
    modes = sum(bool(value) for value in (args.prepare_manifest, args.run, args.smoke, args.analyze_existing))
    if modes != 1:
        raise SystemExit("Choose exactly one of --prepare-manifest, --smoke, --run or --analyze-existing")
    if args.prepare_manifest:
        manifest = prepare_manifest()
        print(json.dumps({"manifest": str(MANIFEST_PATH), "jobs": manifest["jobCount"],
                          "sourceHead": manifest["sourceManifestBeforeRun"]["head"]}))
    elif args.smoke:
        smoke()
    elif args.analyze_existing:
        analyze_existing(args)
    else:
        if args.workers <= 0:
            raise SystemExit("--workers must be positive")
        full_run(args)


if __name__ == "__main__":
    main()
