#!/usr/bin/env python3
"""Compare a handcrafted hostile settler capture and production save reload.

This is a correctness fixture, not a balance experiment.  It runs the same
fixture setup through Lupa and native CraftOS-PC, then separately checks that
the actual Saves.save/load path preserves the captured state and its next
lifecycle boundary.
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
    "players": [{"civilization": "forge"}, {"civilization": "scholar"}],
}


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_offline() -> dict:
    import sys

    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    from runtime import Runtime, from_lua

    runtime = Runtime(CONFIG)
    fixture = runtime.lua.execute((HERE / "wartime_save_parity_fixture.lua").read_text())
    canonical = runtime.lua.globals().LAB_CANONICAL
    lifecycle = runtime.lua.globals().dofile("/games/civcraft/match_lifecycle.lua")
    runtime.call(fixture["setup"], runtime.state)

    def capture(label: str, state) -> dict:
        return {
            "label": label,
            "state": runtime.call(canonical.encode, state),
            "observation0": runtime.call(canonical.encode, runtime.engine.observe(state, 0)),
            "observation1": runtime.call(canonical.encode, runtime.engine.observe(state, 1)),
        }

    checkpoints = [capture("before-capture", runtime.state)]
    runtime.call(fixture["capture"], runtime.state)
    checkpoints.append(capture("after-capture", runtime.state))
    hostile_probe = runtime.call(canonical.decode, runtime.call(canonical.encode, runtime.state))
    try:
        runtime.call(lifecycle["advance"], hostile_probe)
        hostile_continuation = {"ok": True, "error": None}
    except Exception as exc:
        hostile_continuation = {"ok": False, "error": str(exc)}
    direct = runtime.call(canonical.decode, runtime.call(canonical.encode, runtime.state))
    # Keep hostile processing enabled: captured civilians must survive the
    # next round without being treated as spawned combat mobs.
    runtime.call(lifecycle["advance"], direct)
    checkpoints.append(capture("continuation-direct", direct))
    registered_state = runtime.call(runtime.engine.newGame, runtime.lua.table_from(CONFIG, recursive=True))
    registered_outcome = from_lua(runtime.call(fixture["registeredWar"], registered_state))
    registered_checkpoint = capture("registered-war-capture", registered_state)
    return {"checkpoints": checkpoints, "runtime": "Lupa Lua 5.3",
            "hostileContinuation": hostile_continuation,
            "registeredWar": {"outcome": registered_outcome,
                               "checkpoint": registered_checkpoint}}


def run_native(executable: Path) -> dict:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-wartime-save-"))
    computer = profile / "computer/0"
    computer.mkdir(parents=True)
    command = [
        str(executable), "--headless", "--directory", str(profile), "--mount-ro",
        f"/repo={REPOSITORY}", "--exec",
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'fs.copy("/repo/tools/civcraft_lab","/lab");'
        'fs.copy("/repo/games/civcraft/research/lab/wartime_save_parity_fixture.lua",'
        '"/lab/wartime_save_parity_fixture.lua");'
        'fs.copy("/repo/games/civcraft/research/lab/wartime_save_parity_native.lua",'
        '"/lab/wartime_save_parity_native.lua");'
        'shell.run("/lab/wartime_save_parity_native.lua");os.shutdown()',
    ]
    log_path = profile / "console.log"
    with log_path.open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=log, timeout=120)
    output_path = computer / "wartime_save_parity_native.json"
    if not output_path.exists():
        raise RuntimeError(f"Native fixture failed (exit {completed.returncode}); inspect {log_path}")
    result = json.loads(output_path.read_text())
    result.update({"profile": str(profile), "consoleLog": str(log_path),
                   "exitCode": completed.returncode})
    return result


def compare(offline: dict, native: dict) -> dict:
    offline_by_label = {row["label"]: row for row in offline["checkpoints"]}
    native_by_label = {row["label"]: row for row in native["checkpoints"]}
    checks = []
    for label in ["before-capture", "after-capture", "continuation-direct"]:
        for field in ["state", "observation0", "observation1"]:
            left, right = offline_by_label[label][field], native_by_label[label][field]
            checks.append({"label": label, "field": field, "equal": left == right,
                           "offlineSha256": digest(left), "nativeSha256": digest(right)})

    def same_native(left_label: str, right_label: str, field: str) -> None:
        left, right = native_by_label[left_label][field], native_by_label[right_label][field]
        checks.append({"label": f"{left_label}=={right_label}", "field": field,
                       "equal": left == right, "leftSha256": digest(left),
                       "rightSha256": digest(right)})

    for field in ["state", "observation0", "observation1"]:
        same_native("after-capture", "after-save-load", field)
        same_native("continuation-direct", "continuation-loaded", field)
    for side, record in [("offline", offline), ("native", native)]:
        diagnostic = record.get("hostileContinuation", {})
        error = str(diagnostic.get("error", ""))
        checks.append({"label": "active-hostile-diagnostic", "field": side,
                       "equal": diagnostic.get("ok") is True,
                       "error": error})
    offline_war, native_war = offline["registeredWar"], native["registeredWar"]
    checks.append({"label": "registered-war-outcome", "field": "outcome",
                   "equal": offline_war["outcome"] == native_war["outcome"],
                   "offline": offline_war["outcome"], "native": native_war["outcome"]})
    for field in ["state", "observation0", "observation1"]:
        left = offline_war["checkpoint"][field]
        right = native_war["checkpoint"][field]
        checks.append({"label": "registered-war-capture", "field": field,
                       "equal": left == right, "offlineSha256": digest(left),
                       "nativeSha256": digest(right)})
    return {"checks": checks, "failed": [check for check in checks if not check["equal"]]}


def compact_side(record: dict) -> dict:
    """Keep checkpoint labels/hashes while excluding canonical payload strings."""
    compact = {key: value for key, value in record.items() if key != "checkpoints"}
    compact["checkpointHashes"] = []
    for checkpoint in record.get("checkpoints", []):
        compact["checkpointHashes"].append({
            "label": checkpoint["label"],
            "stateSha256": digest(checkpoint["state"]),
            "observation0Sha256": digest(checkpoint["observation0"]),
            "observation1Sha256": digest(checkpoint["observation1"]),
        })
    registered = record.get("registeredWar")
    if registered:
        checkpoint = registered["checkpoint"]
        compact["registeredWar"] = {
            "outcome": registered["outcome"],
            "checkpointHashes": {
                "label": checkpoint["label"],
                "stateSha256": digest(checkpoint["state"]),
                "observation0Sha256": digest(checkpoint["observation0"]),
                "observation1Sha256": digest(checkpoint["observation1"]),
            },
        }
    return compact


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--craftos", type=Path,
                        default=Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos"))
    parser.add_argument("--output", type=Path,
                        default=HERE / "results/wartime_save_parity_m0.json")
    parser.add_argument("--raw-output", type=Path,
                        default=Path("/tmp/civcraft-wartime-save-parity.raw.json"),
                        help="Raw canonical payload record; compact result stores hashes only")
    args = parser.parse_args()
    offline = run_offline()
    native = run_native(args.craftos)
    comparison = compare(offline, native)
    raw_record = {
        "schemaVersion": 1,
        "fixture": "wartime_save_parity_fixture.lua",
        "config": CONFIG,
        "host": {"machine": platform.machine(), "python": platform.python_version(),
                 "craftos": str(args.craftos)},
        "offline": offline,
        "native": native,
        "comparison": comparison,
        "limitation": "The save branch uses an intentionally unregistered hostile owner; capture is exercised by Hostiles.round -> Combat.attack -> Stacks.capture, because Actions.apply cannot submit an order for the wilderness owner. A separate same-run branch covers registered-player declareWar followed by the next-round legal settler capture through Actions.apply. Surprise War remains untested. M0 fixes captured-civilian hostile accounting; the active-hostile continuation must now succeed, and save/reload retains hostile processing. Historical pre-fix results remain in their original artifact.",
    }
    args.raw_output.parent.mkdir(parents=True, exist_ok=True)
    args.raw_output.write_text(json.dumps(raw_record, indent=2) + "\n")
    import sys

    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    from runner import source_manifest

    source = source_manifest()
    fixture_files = {
        name: file_digest(HERE / name)
        for name in ["check_wartime_save_parity.py", "wartime_save_parity_fixture.lua",
                     "wartime_save_parity_native.lua"]
    }
    record = {
        "schemaVersion": 2,
        "fixture": raw_record["fixture"],
        "config": CONFIG,
        "source": {"head": source["head"], "luaSourceHash": source["luaSourceHash"],
                    "fixtureSha256": fixture_files},
        "host": raw_record["host"],
        "offline": compact_side(offline),
        "native": compact_side(native),
        "comparison": comparison,
        "rawArtifact": str(args.raw_output),
        "limitation": raw_record["limitation"],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"checks": len(comparison["checks"]), "failed": len(comparison["failed"]),
                      "output": str(args.output), "rawOutput": str(args.raw_output)}))
    if comparison["failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
