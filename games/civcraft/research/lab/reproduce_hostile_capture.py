#!/usr/bin/env python3
"""Reproduce the standard-hostiles captured-settler crash in isolated runtimes.

This is an audit fixture only. It intentionally leaves the game invariant
unchanged and records errors separately from match outcomes.
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
CONFIG = {
    "seed": 95117,
    "mapSize": "compact",
    "mapType": "pangaea",
    "hostileMode": "standard",
    "players": [{"civilization": "forge"}, {"civilization": "forge"}],
}


def source_manifest() -> dict:
    files = sorted((REPOSITORY / "games/civcraft").glob("*.lua"))
    files += sorted((REPOSITORY / "tools/civcraft_lab").glob("*.lua"))
    files += sorted((REPOSITORY / "tools/civcraft_lab").glob("*.py"))
    digests = {
        str(path.relative_to(REPOSITORY)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in files
    }
    return {
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=REPOSITORY, text=True
        ).strip(),
        "sha256": hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest(),
        "files": digests,
    }


def run_native(executable: Path) -> dict:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-hostile-capture-"))
    computer = profile / "computer/0"
    computer.mkdir(parents=True)
    command = [
        str(executable), "--headless", "--directory", str(profile),
        "--mount-ro", f"/repo={REPOSITORY}", "--exec",
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'fs.copy("/repo/tools/civcraft_lab","/lab");'
        'fs.copy("/repo/games/civcraft/research/lab/reproduce_hostile_capture.lua",'
        '"/lab/reproduce_hostile_capture.lua");'
        'shell.run("/lab/reproduce_hostile_capture.lua");os.shutdown()',
    ]
    log_path = profile / "console.log"
    with log_path.open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=log, timeout=120)
    output_path = computer / "hostile_capture_native.json"
    if not output_path.exists():
        raise RuntimeError(
            f"Native fixture produced no output (exit {completed.returncode}); "
            f"inspect {log_path}"
        )
    result = json.loads(output_path.read_text())
    result.update({"command": command, "profile": str(profile),
                   "consoleLog": str(log_path), "exitCode": completed.returncode})
    return result


def run_lupa() -> dict:
    """Run the same loop through the lab Runtime when Lupa is installed."""
    try:
        import sys
        sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
        from runtime import Runtime, from_lua
    except Exception as exc:
        return {"status": "unavailable", "error": f"{type(exc).__name__}: {exc}"}
    try:
        runtime = Runtime(CONFIG)
        successful_advances, status, error = 0, "finished", None
        for _ in range(180):
            if runtime.finished():
                break
            try:
                runtime.pump()
                if runtime.finished():
                    break
                runtime.advance()
                successful_advances += 1
            except Exception as exc:
                status, error = "error", f"{type(exc).__name__}: {exc}"
                break
        units = from_lua(runtime.state.units)
        orphan = [
            {"id": u.get("id"), "kind": u.get("kind"), "owner": u.get("owner"),
             "x": u.get("x"), "y": u.get("y"), "spawner": u.get("spawner"),
             "spawnerPresent": u.get("spawner") is not None}
            for u in units if u.get("owner") == -2147483647 and u.get("spawner") is None
        ]
        return {"status": status, "error": error,
                "errorRound": int(runtime.state.round) if status == "error" else None,
                "completedRounds": int(runtime.state.round) - 1 if status == "error" else int(runtime.state.round),
                "successfulAdvances": successful_advances,
                "orphanHostileUnits": orphan, "runtime": "Lupa Lua 5.3"}
    except Exception as exc:
        return {"status": "harness_error", "error": f"{type(exc).__name__}: {exc}"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--craftos", type=Path,
                        default=Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos"))
    parser.add_argument("--output", type=Path,
                        default=REPOSITORY / "tools/civcraft_lab/results/hostile_capture_reproduction.json")
    args = parser.parse_args()
    record = {
        "schemaVersion": 1, "fixture": "games/civcraft/research/lab/reproduce_hostile_capture.lua",
        "config": CONFIG, "source": source_manifest(),
        "host": {"machine": platform.machine(), "python": platform.python_version(),
                  "craftos": str(args.craftos)},
        "native": run_native(args.craftos), "lupa": run_lupa(),
        "expected": {"errorLine": "games/civcraft/hostiles.lua:103: table index is nil",
                     "errorRound": 15, "completedRounds": 14,
                     "orphanOwner": -2147483647, "orphanKind": "settler", "orphanSpawner": None},
        "commands": {"native": "python3 games/civcraft/research/lab/reproduce_hostile_capture.py",
                     "lupa": "same command when tools/civcraft_lab/requirements.txt is installed"},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"native": record["native"].get("status"),
                      "nativeErrorRound": record["native"].get("errorRound"),
                      "lupa": record["lupa"].get("status"), "output": str(args.output)}))


if __name__ == "__main__":
    main()
