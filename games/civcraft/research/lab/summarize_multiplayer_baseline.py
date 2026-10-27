#!/usr/bin/env python3
"""Post-process completed multiplayer baseline records without launching games."""
from __future__ import annotations

import json
from pathlib import Path

import multiplayer_baseline_batch as batch


def first_round(rows, predicate):
    for pair in rows:
        if predicate(pair):
            return pair[0].get("round")
    return None


def player_progress(turns, player_id):
    rows = []
    for turn in turns:
        player = next((p for p in turn.get("players", []) if p.get("id") == player_id), None)
        if player is not None:
            rows.append((turn, player))
    first_science = first_round(rows, lambda pair: (pair[1].get("science") or 0) > 0)
    first_tech = first_round(rows, lambda pair: (pair[1].get("technologies") or 0) > 0)
    first_two_cities = first_round(rows, lambda pair: len(pair[1].get("cities") or []) >= 2)

    def eligible(pair):
        status = (pair[0].get("victoryEligibility") or {}).get(str(player_id), {})
        return any(status.get(route, False) for route in ("conquest", "expedition", "industrial", "diplomatic"))

    first_eligible = first_round(rows, eligible)
    last_turn, last = rows[-1] if rows else ({}, {})
    return {
        "firstScienceRound": first_science,
        "firstScienceYield": next((p.get("science") for _, p in rows if (p.get("science") or 0) > 0), None),
        "firstTechnologyRound": first_tech,
        "firstTwoCitiesRound": first_two_cities,
        "firstVictoryEligibilityRound": first_eligible,
        "routeIntentAtFinish": last.get("strategy"),
        "finalTechnologies": last.get("technologies"),
        "finalCities": len(last.get("cities") or []),
        "finalVictoryEligibility": (last_turn.get("victoryEligibility") or {}).get(str(player_id), {}),
    }


def main() -> None:
    manifest = json.loads(batch.MANIFEST_PATH.read_text())
    records = []
    for entry in manifest["jobs"]:
        path = batch.record_path(entry["config"])
        records.append(json.loads(path.read_text()))
    source = manifest["sourceManifestBeforeRun"]
    after = batch.source_manifest()
    old_progress = batch.player_progress
    batch.player_progress = player_progress
    try:
        summary = batch.summarize(records, source, after,
                                  {"reused": len(records), "launched": 0, "postprocessOnly": True})
    finally:
        batch.player_progress = old_progress
    summary["gameProgress"] = []
    for row in records:
        if row.get("status") != "finished":
            continue
        config, result = row["config"], row["result"]
        summary["gameProgress"].append({
            "jobId": row["jobId"],
            "mapType": config["mapType"],
            "seed": config["seed"],
            "roster": config["roster"],
            "playerCount": config["playerCount"],
            "seatRotationIndex": config["seatRotationIndex"],
            "victoryReason": result.get("victoryReason"),
            "finishRound": result.get("round"),
            "winnerIds": result.get("winnerIds", []),
            "players": [
                {"seat": seat, "role": player["role"], "civilization": player["civilization"],
                 "progress": player_progress(result.get("turns", []), seat)}
                for seat, player in enumerate(config["players"])
            ],
        })
    summary["manifest"] = str(batch.MANIFEST_PATH)
    summary["runRoot"] = str(batch.RUN_ROOT)
    summary["postprocess"] = {
        "status": "completed-from-durable-records",
        "gamesLaunched": 0,
        "driverRunFailure": "reducer-only tuple bug after all 28 game records were persisted",
        "sourceChangedSinceRun": source != after,
    }
    destination = batch.RESULTS / "multiplayer_baseline.json"
    destination.write_text(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"output": str(destination), "attempted": len(records),
                      "finished": summary["execution"]["finishedGames"],
                      "statusCounts": summary["execution"]["statusCounts"]}, sort_keys=True))


if __name__ == "__main__":
    main()
