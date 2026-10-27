#!/usr/bin/env python3
"""Compare the Surprise War conformance fixture in Lupa and CraftOS-PC.

This is a correctness fixture, not a balance benchmark.  It preserves raw
canonical payloads in a temporary artifact and writes a compact hash/check
record under research/lab/results.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import tempfile
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
CONFIG = {
    "seed": 75123,
    "mapSize": "compact",
    "mapType": "pangaea",
    "hostileMode": "off",
    "players": [
        {"civilization": "forge", "ai": False},
        {"civilization": "scholar", "ai": False},
    ],
    "maxRounds": 4,
}


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def offline_payloads() -> dict:
    import sys

    sys.path.insert(0, str(HERE))
    import run_conformance_extensions as extension  # noqa: E402

    observer = extension.observer_adversarial()
    replay = extension.surprise_replay()
    return {"observer": observer, "replay": replay}


def run_native(executable: Path) -> dict:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-conformance-extension-"))
    computer = profile / "computer/0"
    computer.mkdir(parents=True)
    command = [
        str(executable),
        "--headless",
        "--directory",
        str(profile),
        "--mount-ro",
        f"/repo={REPOSITORY}",
        "--exec",
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'fs.copy("/repo/tools/civcraft_lab","/lab");'
        'fs.copy("/repo/games/civcraft/research/lab/conformance_extension_fixture.lua",'
        '"/lab/conformance_extension_fixture.lua");'
        'fs.copy("/repo/games/civcraft/research/lab/conformance_extension_native.lua",'
        '"/lab/conformance_extension_native.lua");'
        'shell.run("/lab/conformance_extension_native.lua");os.shutdown()',
    ]
    log_path = profile / "console.log"
    with log_path.open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=log, timeout=120)
    output_path = computer / "conformance_extension_native.json"
    if not output_path.exists():
        raise RuntimeError(
            f"Native conformance fixture failed (exit {completed.returncode}); inspect {log_path}"
        )
    result = json.loads(output_path.read_text())
    result.update({
        "profile": str(profile),
        "consoleLog": str(log_path),
        "exitCode": completed.returncode,
    })
    return result


def checkpoint_hashes(checkpoints: list[dict]) -> list[dict]:
    return [
        {
            "label": row["label"],
            "stateSha256": digest(row["state"]),
            "observation0Sha256": digest(row["observation0"]),
            "observation1Sha256": digest(row["observation1"]),
            "proposals0Sha256": digest(row["proposals0"]),
        }
        for row in checkpoints
    ]


def compare_equal(checks: list[dict], label: str, field: str, left, right) -> None:
    checks.append({
        "label": label,
        "field": field,
        "equal": left == right,
        "leftSha256": digest(left) if isinstance(left, str) else None,
        "rightSha256": digest(right) if isinstance(right, str) else None,
    })


def compare(offline: dict, native: dict) -> dict:
    checks: list[dict] = []
    offline_observer = offline["observer"]
    native_observer = native["observerAdversarial"]
    checks.append({
        "label": "observer-hidden-tile",
        "field": "hiddenTile",
        "equal": offline_observer["hiddenTile"] == native_observer["hiddenTile"],
    })
    for side in ["before", "after"]:
        for field in ["observation", "proposals"]:
            compare_equal(
                checks,
                f"observer-{side}",
                field,
                offline_observer[f"_{side}Payload"][field],
                native_observer[side][field],
            )

    offline_replay = offline["replay"]
    native_primary = native["primary"]
    offline_checkpoints = [row["left"] for row in offline_replay["_checkpointPayloads"]]
    native_checkpoints = native_primary["checkpoints"]
    checks.append({
        "label": "checkpoint-count",
        "field": "count",
        "equal": len(offline_checkpoints) == len(native_checkpoints),
        "offline": len(offline_checkpoints),
        "native": len(native_checkpoints),
    })
    for index, (offline_row, native_row) in enumerate(zip(offline_checkpoints, native_checkpoints)):
        label = f"checkpoint-{index}-{offline_row['label']}"
        checks.append({"label": label, "field": "label", "equal": offline_row["label"] == native_row["label"]})
        for field in ["state", "observation0", "observation1", "proposals0"]:
            compare_equal(checks, label, field, offline_row[field], native_row[field])

    native_replica = native["replica"]
    native_replay = native["replay"]
    for peer_name, peer in [("replica", native_replica), ("replay", native_replay)]:
        for index, (primary_row, peer_row) in enumerate(zip(native_checkpoints, peer["checkpoints"])):
            for field in ["state", "observation0", "observation1", "proposals0"]:
                compare_equal(checks, f"native-primary=={peer_name}-{index}", field,
                              primary_row[field], peer_row[field])

    offline_outcomes = [row["left"] for row in offline_replay["outcomes"]]
    native_outcomes = [
        {
            "ok": bool(row["result"].get("ok")),
            "message": row["result"].get("message"),
            "detail": row["result"].get("detail"),
        }
        for row in native_primary["outcomes"]
    ]
    native_outcomes = [
        {"ok": result["ok"], "message": result["message"], "detail": result["detail"]}
        for result in native_outcomes
    ]
    offline_outcomes = [
        {"ok": result["ok"], "message": result["message"], "detail": result["detail"]}
        for result in offline_outcomes
    ]
    checks.append({
        "label": "outcomes",
        "field": "sequence",
        "equal": offline_outcomes == native_outcomes,
    })
    checks.append({
        "label": "reaction-checks",
        "field": "all",
        "equal": offline_replay["reactionChecks"] == native_primary["reactionChecks"],
        "offline": offline_replay["reactionChecks"],
        "native": native_primary["reactionChecks"],
    })
    checks.append({
        "label": "telemetry-trace",
        "field": "trace",
        "equal": offline_replay["_trace"]["trace"] == native_primary["trace"],
    })
    checks.append({
        "label": "final-state",
        "field": "canonical",
        "equal": offline_checkpoints[-1]["state"] == native_primary["finalState"],
        "offlineSha256": digest(offline_checkpoints[-1]["state"]),
        "nativeSha256": digest(native_primary["finalState"]),
    })
    return {"checks": checks, "failed": [check for check in checks if not check["equal"]]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--craftos", type=Path,
                        default=Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos"))
    parser.add_argument("--output", type=Path,
                        default=HERE / "results/conformance_extension_native.json")
    parser.add_argument("--raw-output", type=Path,
                        default=Path("/tmp/civcraft-conformance-extension-native.raw.json"))
    args = parser.parse_args()

    offline = offline_payloads()
    native = run_native(args.craftos)
    comparison = compare(offline, native)

    from runner import source_manifest

    source = source_manifest()
    fixture_files = {
        name: file_digest(HERE / name)
        for name in [
            "run_conformance_extensions.py",
            "check_conformance_extension_native.py",
            "conformance_extension_fixture.lua",
            "conformance_extension_native.lua",
        ]
    }
    raw_record = {
        "schemaVersion": 1,
        "fixture": "conformance_extension_fixture.lua",
        "config": CONFIG,
        "source": source,
        "scriptSha256": fixture_files,
        "host": {"machine": platform.machine(), "python": platform.python_version(),
                 "craftos": str(args.craftos)},
        "offline": offline,
        "native": native,
        "comparison": comparison,
    }
    args.raw_output.parent.mkdir(parents=True, exist_ok=True)
    args.raw_output.write_text(json.dumps(raw_record, indent=2) + "\n")

    compact = {
        "schemaVersion": 1,
        "fixture": raw_record["fixture"],
        "config": CONFIG,
        "sourceManifest": source,
        "scriptSha256": fixture_files,
        "host": raw_record["host"],
        "offline": {
            "observer": {
                "beforeSha256": {field: digest(offline["observer"]["_beforePayload"][field])
                                 for field in ["observation", "proposals"]},
                "afterSha256": {field: digest(offline["observer"]["_afterPayload"][field])
                                for field in ["observation", "proposals"]},
            },
            "checkpointHashes": checkpoint_hashes(
                [row["left"] for row in offline["replay"]["_checkpointPayloads"]]
            )
        },
        "native": {
            "profile": native["profile"],
            "consoleLog": native["consoleLog"],
            "observer": {
                "beforeSha256": {field: digest(native["observerAdversarial"]["before"][field])
                                 for field in ["observation", "proposals"]},
                "afterSha256": {field: digest(native["observerAdversarial"]["after"][field])
                                for field in ["observation", "proposals"]},
            },
            "checkpointHashes": checkpoint_hashes(native["primary"]["checkpoints"]),
            "traceActionCount": len(native["primary"]["trace"]),
        },
        "comparison": comparison,
        "rawArtifact": str(args.raw_output),
        "limitations": [
            "Native CraftOS-PC run is a short correctness fixture, not a full-game benchmark.",
            "Observer coverage is limited to the adversarial fields exercised by this fixture.",
            "PYTHONHASHSEED variation checks Python-side orchestration only; it does not vary a Lua hash seed.",
            "The known 21-check wartime/save parity fixture remains a separate artifact and is not folded into this result.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(compact, indent=2) + "\n")
    print(json.dumps({"checks": len(comparison["checks"]),
                      "failed": len(comparison["failed"]),
                      "output": str(args.output),
                      "rawOutput": str(args.raw_output)}))
    if comparison["failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
