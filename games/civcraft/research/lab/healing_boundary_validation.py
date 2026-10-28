#!/usr/bin/env python3
"""Validate the approved healing/fortify boundary exception in both runtimes.

This is a focused correctness fixture, not a balance benchmark. Each case uses
a fresh actual Runtime state and the native companion uses a fresh CraftOS
state. Raw native payloads remain in a temporary profile; the repository result
contains hashes and compact diagnostics only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
FIXTURE_PATH = HERE / "healing_boundary_fixture.lua"
NATIVE_PATH = HERE / "healing_boundary_native.lua"
RESULT_PATH = HERE / "results/healing_boundary_validation.json"
CRAFTOS_DEFAULT = Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
CONFIG = {
    "seed": 867530,
    "mapSize": "compact",
    "mapType": "pangaea",
    "hostileMode": "off",
    "players": [
        {"civilization": "forge", "ai": False},
        {"civilization": "verdant", "ai": False},
    ],
    "maxRounds": 2,
}


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest() -> dict:
    import runner

    return runner.source_manifest()


def capture(runtime) -> dict:
    canonical = runtime.lua.globals().LAB_CANONICAL
    return {
        "state": runtime.call(canonical.encode, runtime.state),
        "observation0": runtime.call(runtime.engine.observe, runtime.state, 0),
        "observation1": runtime.call(runtime.engine.observe, runtime.state, 1),
    }


def encode_capture(runtime, captured: dict) -> dict:
    canonical = runtime.lua.globals().LAB_CANONICAL
    return {key: runtime.call(canonical.encode, value) if key != "state" else value
            for key, value in captured.items()}


def offline_cases() -> list[dict]:
    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    from runtime import Runtime, from_lua  # noqa: E402

    probe = Runtime(CONFIG)
    fixture = probe.lua.execute(FIXTURE_PATH.read_text())
    specs = from_lua(probe.call(fixture["cases"]))
    records = []
    for spec in specs:
        runtime = Runtime(CONFIG)
        mod = runtime.lua.execute(FIXTURE_PATH.read_text())
        lua_spec = runtime.lua.table_from(spec, recursive=True)
        runtime.call(mod["setupOnly"], runtime.state, lua_spec)
        before_raw = capture(runtime)
        before = encode_capture(runtime, before_raw)
        result = runtime.call(mod["run"], runtime.state, lua_spec)
        result = from_lua(result)
        after_raw = capture(runtime)
        after = encode_capture(runtime, after_raw)
        records.append({
            "id": spec["id"],
            "spec": spec,
            "before": before,
            "after": after,
            "summary": result["after"],
        })
    return records


def run_native(executable: Path) -> tuple[dict, Path]:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-healing-boundary-"))
    computer = profile / "computer/0"
    computer.mkdir(parents=True)
    command = [
        str(executable), "--headless", "--directory", str(profile),
        "--mount-ro", f"/repo={REPOSITORY}",
        "--exec",
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'fs.copy("/repo/tools/civcraft_lab","/lab");'
        'fs.copy("/repo/games/civcraft/research/lab/healing_boundary_fixture.lua",'
        '"/lab/healing_boundary_fixture.lua");'
        'fs.copy("/repo/games/civcraft/research/lab/healing_boundary_native.lua",'
        '"/lab/healing_boundary_native.lua");'
        'shell.run("/lab/healing_boundary_native.lua");os.shutdown()',
    ]
    log_path = profile / "console.log"
    started = time.perf_counter()
    with log_path.open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=log, timeout=180)
    output_path = computer / "healing_boundary_native.json"
    if not output_path.exists():
        raise RuntimeError(f"Native fixture failed (exit {completed.returncode}); inspect {log_path}")
    result = json.loads(output_path.read_text())
    result["profile"] = str(profile)
    result["consoleLog"] = str(log_path)
    result["exitCode"] = completed.returncode
    result["elapsedSeconds"] = time.perf_counter() - started
    return result, profile


def expected_summary(spec: dict) -> dict:
    hp = spec["hp"]
    if spec["location"] == "owned" and (not spec["acted"] or spec["fortified"]):
        hp += 20
    if spec["inRange"] and spec["location"] != "enemy":
        hp += 10
    return {
        "healerHP": 90,
        "recipientHP": min(100, hp),
        "enemyHP": 40,
    }


def compact_record(offline: list[dict], native: dict, manifest_before: dict,
                   manifest_after: dict, profile: Path, started: float) -> dict:
    native_by_id = {row["id"]: row for row in native["cases"]}
    checks = []
    semantic_failures = []
    for row in offline:
        peer = native_by_id.get(row["id"])
        if peer is None:
            checks.append({"id": row["id"], "equal": False, "reason": "missing-native-case"})
            continue
        fields = ["state", "observation0", "observation1"]
        equal = True
        field_hashes = {}
        for phase in ("before", "after"):
            for field in fields:
                left = row[phase][field]
                right = peer[f"{phase}{field[0].upper()}{field[1:]}"]
                same = left == right
                equal = equal and same
                field_hashes[f"{phase}.{field}"] = {
                    "equal": same, "offlineSha256": digest(left), "nativeSha256": digest(right)
                }
        expected = expected_summary(row["spec"])
        observed = row["summary"]
        semantic = all(observed.get(key) == value for key, value in expected.items())
        semantic_failures.extend([] if semantic else [{"id": row["id"], "expected": expected, "observed": observed}])
        checks.append({"id": row["id"], "equal": equal, "semanticEqual": semantic,
                       "fieldHashes": field_hashes})
    parity_failures = [row for row in checks if not row["equal"]]
    return {
        "schemaVersion": 1,
        "purpose": "User-approved healing outside territory and owned-land fortify boundary validation",
        "scope": "Fresh actual Runtime and fresh native CraftOS state per case; 128 cases (2 healer types x 4 ownership/geography locations x 2 acted x 2 fortified x 2 ranges x 2 HP bands)",
        "config": CONFIG,
        "caseCount": len(offline),
        "nativeHost": native.get("host"),
        "nativeExitCode": native.get("exitCode"),
        "nativeElapsedSeconds": native.get("elapsedSeconds"),
        "sourceManifestBefore": manifest_before,
        "sourceManifestAfter": manifest_after,
        "sourceChangedDuringRun": manifest_before != manifest_after,
        "scriptSha256": {
            "driver": file_digest(Path(__file__)),
            "fixture": file_digest(FIXTURE_PATH),
            "native": file_digest(NATIVE_PATH),
        },
        "checks": {
            "canonicalStateAndObservationsEqual": len(parity_failures) == 0,
            "semanticExpectationsEqual": len(semantic_failures) == 0,
            "parityFailureCount": len(parity_failures),
            "semanticFailureCount": len(semantic_failures),
            "caseChecks": checks,
        },
        "limits": [
            "This validates current round resolution and observation parity only; it is not a balance or healing-throughput study.",
            "The approved exception is specifically support healing outside owned territory; passive self/rest healing remains territory-gated.",
            "Enemy-owned recipients are included as non-healing controls; no diplomacy or combat action is exercised.",
            "Raw native payload is retained only in the disposable profile, not committed to the repository.",
        ],
        "profile": str(profile),
        "elapsedSeconds": time.perf_counter() - started,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--craftos", type=Path, default=CRAFTOS_DEFAULT)
    parser.add_argument("--output", type=Path, default=RESULT_PATH)
    args = parser.parse_args()
    started = time.perf_counter()
    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    before = source_manifest()
    offline = offline_cases()
    native, profile = run_native(args.craftos)
    after = source_manifest()
    result = compact_record(offline, native, before, after, profile, started)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"output": str(args.output), "caseCount": result["caseCount"],
                      "canonicalStateAndObservationsEqual": result["checks"]["canonicalStateAndObservationsEqual"],
                      "semanticExpectationsEqual": result["checks"]["semanticExpectationsEqual"],
                      "profile": str(profile)}))
    if not result["checks"]["canonicalStateAndObservationsEqual"] or not result["checks"]["semanticExpectationsEqual"]:
        raise SystemExit("Healing boundary validation failed")


if __name__ == "__main__":
    main()
