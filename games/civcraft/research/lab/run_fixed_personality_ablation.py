#!/usr/bin/env python3
"""Research-only fixed-personality ablation for the faction policy pilot.

The live lab sources are not modified. Each spawned worker subclasses the
research Runtime and replaces only the cached personality lookup with a copy
of the Forge profile before the first actor pump. Actions, observations,
budgets and runner result handling remain the existing implementation.
"""
from __future__ import annotations

import hashlib
import json
import multiprocessing
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))


class FixedPersonalityRuntime:
    """Late-bound wrapper so the shared runner keeps its normal contract."""

    def __new__(cls, *args, **kwargs):
        from runtime import Runtime

        runtime = Runtime(*args, **kwargs)
        runtime.lua.execute(
            """
            local personalities = __civcraftModuleCache['/games/civcraft/ai_personalities.lua']
            local forge = personalities.forCivilization('forge')
            personalities.forCivilization = function(_)
                local copy = {}
                for key, value in pairs(forge) do copy[key] = value end
                return copy
            end
            """
        )
        return runtime


def ablation_worker(connection, config):
    import runner

    runner.Runtime = FixedPersonalityRuntime
    try:
        connection.send(runner.play(config))
    finally:
        connection.close()


def source_manifest():
    from runner import source_manifest as manifest

    return manifest()


def main() -> None:
    import workers

    configs = json.loads((HERE / "faction_policy_manifest.json").read_text())
    before = source_manifest()
    original_worker = workers._worker
    workers._worker = ablation_worker
    try:
        results = workers.run_bounded(configs, workers=2)
    finally:
        workers._worker = original_worker
    after = source_manifest()
    raw = {
        "schemaVersion": 1,
        "purpose": "Fixed-Forge-personality ablation of the 36-match faction policy pilot",
        "source": before,
        "sourceChangedDuringRun": before != after,
        "workers": 2,
        "matches": results,
        "ablation": {
            "hook": "Personalities.forCivilization always returns a copy of the original Forge profile",
            "gameplaySourcesModified": False,
            "policyGoal": "expedition",
            "weightsHeldConstant": True,
            "assetsOrActionsChanged": False,
        },
    }
    raw_path = Path("/tmp/civcraft-faction-policy-ablation.raw.json")
    raw_path.write_text(json.dumps(raw, indent=2, sort_keys=True) + "\n")
    from collections import Counter, defaultdict
    from statistics import mean, median

    status_counts = Counter(match.get("status") for match in results)
    route_counts = Counter(match.get("victoryReason") for match in results if match.get("status") == "finished")
    seat_wins = Counter(
        seat for match in results if match.get("status") == "finished" for seat in match.get("winnerIds", [])
    )
    by_civ = defaultdict(lambda: {"matches": 0, "wins": 0, "rounds": []})
    for match in results:
        if match.get("status") != "finished":
            continue
        players = match["config"]["players"]
        winners = match.get("winnerIds", [])
        for seat, player in enumerate(players):
            civ = player["civilization"]
            if civ == "forge":
                continue
            row = by_civ[civ]
            row["matches"] += 1
            row["wins"] += int(seat in winners)
            row["rounds"].append(match["round"])
    compact = {
        "schemaVersion": 1,
        "rawArtifact": str(raw_path),
        "source": {"head": before["head"], "luaSourceHash": before["luaSourceHash"],
                   "sourceChangedDuringRun": before != after},
        "ablation": raw["ablation"],
        "fixture": {"matches": len(results), "statusCounts": dict(status_counts),
                    "victoryReasons": dict(route_counts), "seatWins": {f"seat{k}": v for k, v in sorted(seat_wins.items())},
                    "meanRound": mean([m["round"] for m in results if m.get("status") == "finished"]),
                    "medianRound": median([m["round"] for m in results if m.get("status") == "finished"])},
        "civilizationComparisons": {
            civ: {"matches": row["matches"], "wins": row["wins"],
                  "rate": row["wins"] / row["matches"], "medianRound": median(row["rounds"])}
            for civ, row in sorted(by_civ.items())
        },
        "interpretation": "This controls the civilization-specific AI personality, but seat order remains a separate factor; compare paired seat rotations against faction_policy_pilot.json.",
        "scriptSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    destination = HERE / "results/faction_policy_ablation.json"
    destination.write_text(json.dumps(compact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"matches": len(results), "statusCounts": dict(status_counts),
                      "sourceChangedDuringRun": before != after,
                      "rawArtifact": str(raw_path), "output": str(destination)}))


if __name__ == "__main__":
    multiprocessing.freeze_support()
    main()
