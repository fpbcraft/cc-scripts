#!/usr/bin/env python3
"""Compare observer proposal candidates and metadata in Lupa and CraftOS."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
NATIVE_SCRIPT = HERE / "proposals_native.lua"
OUTPUT = HERE / "results/proposal_native_parity.json"
CONFIG = {
    "seed": 75123,
    "mapSize": "compact",
    "mapType": "continents",
    "hostileMode": "off",
    "players": [
        {"civilization": "forge", "ai": False},
        {"civilization": "scholar", "ai": False},
    ],
    "maxRounds": 4,
}


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def run_lupa() -> dict:
    import sys

    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    from runtime import Runtime  # noqa: E402

    runtime = Runtime(CONFIG)
    proposals, coverage = runtime.engine.legalActions(runtime.state, 0)
    metadata = runtime.engine.legalActionMetadata()
    canonical = runtime.lua.globals().LAB_CANONICAL
    return {
        "proposals": runtime.call(canonical.encode, proposals),
        "coverage": coverage,
        "metadata": runtime.call(canonical.encode, metadata),
        "state": runtime.state_hash(),
    }


def run_native(executable: Path) -> tuple[dict, Path]:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-proposal-parity-"))
    computer = profile / "computer/0"
    computer.mkdir(parents=True)
    command = [
        str(executable), "--headless", "--directory", str(profile),
        "--mount-ro", f"/repo={REPOSITORY}", "--exec",
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'fs.copy("/repo/tools/civcraft_lab","/lab");'
        'fs.copy("/repo/games/civcraft/research/lab/proposals_native.lua",'
        '"/lab/proposals_native.lua");'
        'shell.run("/lab/proposals_native.lua");os.shutdown()',
    ]
    log = profile / "console.log"
    with log.open("w") as stream:
        completed = subprocess.run(command, stdout=stream, stderr=stream, timeout=120)
    output = computer / "proposal_native.json"
    if not output.exists():
        raise RuntimeError(f"Native proposal fixture failed (exit {completed.returncode}); inspect {log}")
    result = json.loads(output.read_text())
    result["profile"] = str(profile)
    result["exitCode"] = completed.returncode
    return result, profile


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--craftos", type=Path, default=Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos"))
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
    from runner import source_manifest
    before = source_manifest()
    lupa = run_lupa()
    native, profile = run_native(args.craftos)
    after = source_manifest()
    checks = {
        "proposalsEqual": lupa["proposals"] == native["proposals"],
        "coverageEqual": lupa["coverage"] == native["coverage"],
        "metadataEqual": lupa["metadata"] == native["metadata"],
        "initialStateEqual": lupa["state"] == digest(native["state"]),
        "sourceUnchanged": before == after,
    }
    result = {
        "schemaVersion": 1,
        "purpose": "Native/Lupa observer proposal and action-space metadata parity",
        "config": CONFIG,
        "sourceManifest": before,
        "fixtureHashes": {str(path.relative_to(REPOSITORY)): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in (Path(__file__), NATIVE_SCRIPT)},
        "nativeHost": native.get("host"),
        "nativeExitCode": native.get("exitCode"),
        "checks": checks,
        "lupa": {key: {"sha256": digest(value), "length": len(value)} for key, value in lupa.items() if isinstance(value, str)},
        "native": {"proposalsSha256": digest(native["proposals"]), "metadataSha256": digest(native["metadata"]),
                   "stateSha256": digest(native["state"]), "profile": str(profile)},
        "limits": [
            "Proposal candidates remain non-exhaustive and observer-only; parity does not make them a legal mask.",
            "Native execution uses the same fresh initial state and does not execute proposals.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"output": str(args.output), "checks": checks, "profile": str(profile)}))
    if not all(checks.values()):
        raise SystemExit("Native/Lupa proposal parity failed")


if __name__ == "__main__":
    main()
