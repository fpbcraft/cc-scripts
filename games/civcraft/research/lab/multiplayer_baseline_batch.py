#!/usr/bin/env python3
"""Research-only 3/4-player current-rules baseline.

This driver deliberately lives beside the existing two-player baseline.  It
reuses the authoritative lab Runtime and runner, adds only a read-only
victory-status projection to telemetry, and writes one atomic record per game
so an interrupted batch can resume without changing the source or scoring a
missing game as a loss.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
MANIFEST_PATH = HERE / "multiplayer_baseline_manifest.json"
RUN_ROOT = HERE / "runs" / "multiplayer-baseline-v1"
SCRIPT_PATH = Path(__file__).resolve()

import sys

sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
import workers  # noqa: E402
from runner import from_lua, source_manifest  # noqa: E402


CONFIG_VERSION = "multiplayer-baseline-v1"
TERMINAL = {"finished", "censored", "error", "timeout", "invalid_setup"}
MAP_BLOCKS = {
    # One new seed per map family.  Both roster sizes use the same seed in a
    # family; role/civilization assignments are the only planned contrast.
    "pangaea": 730127,
    "archipelago": 740131,
}
SELECTED = json.loads((RESULTS / "strategy_search_pilot.json").read_text())["championHoldout"]["policy"]
ADAPTED = json.loads((RESULTS / "adversarial_archive_adaptation_pilot.json").read_text())["selection"]["selectedPolicy"]
POLICIES = {
    "selected-expedition": SELECTED,
    "adapted-expedition": ADAPTED,
    "industrial": {"version": 1, "goal": "industrial"},
    # An empty policy preserves the installed personality-driven adaptive AI.
    "original-adaptive": {},
}


def stable(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def sha_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def adapter_fingerprints() -> dict[str, str]:
    return {"driver": file_sha(SCRIPT_PATH), "runner": file_sha(ROOT / "tools/civcraft_lab/runner.py"),
            "workers": file_sha(ROOT / "tools/civcraft_lab/workers.py"),
            "runtime": file_sha(ROOT / "tools/civcraft_lab/runtime.py")}


class InstrumentedRuntime:
    """Proxy the real Runtime and add only read-only victory status metrics."""

    def __init__(self, config: dict, *, instruction_budget: int = 200_000_000):
        from runtime import Runtime

        self._inner = Runtime(config, instruction_budget=instruction_budget)
        self.lua = self._inner.lua
        self._eligibility = self.lua.eval(
            """
            function(state)
                local Victory = dofile('/games/civcraft/victory.lua')
                local result = {}
                for _, p in ipairs(state.players) do
                    local s = Victory.status(state, p)
                    local capitals, own = 0, 0
                    for _, c in ipairs(state.cities) do
                        if c.capitalOf then
                            capitals = capitals + 1
                            if c.owner == p.id then own = own + 1 end
                        end
                    end
                    result[p.id] = {
                        conquest = capitals >= 2 and own == capitals,
                        expedition = s.dragon == true,
                        industrial = (p.industryTurns or 0) >= s.industryTarget,
                        diplomatic = s.diplomatic == true,
                        score = state.round >= (state.roundLimit or 180),
                        connected = s.connected,
                        industryTurns = p.industryTurns or 0,
                        industryTarget = s.industryTarget,
                    }
                end
                return result
            end
            """
        )

    @property
    def state(self):
        return self._inner.state

    def pump(self):
        return self._inner.pump()

    def advance(self):
        return self._inner.advance()

    def finished(self):
        return self._inner.finished()

    def state_hash(self):
        return self._inner.state_hash()

    def metrics(self):
        metrics = self._inner.metrics()
        metrics["victoryEligibility"] = from_lua(self._inner.call(self._eligibility, self._inner.state))
        return metrics


def play_worker(connection, config: dict) -> None:
    import runner

    runner.Runtime = InstrumentedRuntime
    try:
        connection.send(runner.play(config))
    finally:
        connection.close()


def role_records(roster: str, count: int, rotation: int) -> list[dict]:
    if count == 3:
        roles = [
            ("selected-expedition", "forge"),
            ("adapted-expedition", "mariner"),
            ("industrial", "scholar"),
        ] if roster == "mixed" else [
            ("selected-expedition", "forge"),
            ("adapted-expedition", "forge"),
            ("industrial", "forge"),
        ]
    elif count == 4:
        roles = [
            ("selected-expedition", "forge"),
            ("adapted-expedition", "mariner"),
            ("industrial", "scholar"),
            ("original-adaptive", "merchant"),
        ] if roster == "mixed" else [
            ("selected-expedition", "forge"),
            ("adapted-expedition", "forge"),
            ("industrial", "forge"),
            ("original-adaptive", "forge"),
        ]
    else:
        raise ValueError(f"unsupported player count {count}")
    # Rotate the role/civilization pair together.  With one new seed per map
    # family this gives two seat placements per role, not all N! permutations.
    rotated = roles[rotation % count :] + roles[: rotation % count]
    return [{"civilization": civ, "policy": POLICIES[role], "policyId": role, "role": role} for role, civ in rotated]


def config_for(map_type: str, seed: int, roster: str, count: int, rotation: int | None = None) -> dict:
    if rotation is None:
        rotation = 0 if map_type == "pangaea" else 1
    players = role_records(roster, count, rotation)
    return {
        "configVersion": CONFIG_VERSION,
        "seed": seed,
        "mapSize": "compact",
        "mapType": map_type,
        "hostileMode": "off",
        "telemetryEvery": 1,
        "maxRounds": 180,
        "wallSeconds": 240,
        "instructionBudget": 200_000_000,
        "actionBudget": 4096,
        "roster": roster,
        "playerCount": count,
        "roleRotation": rotation,
        "players": players,
    }


def build_jobs() -> list[dict]:
    jobs = []
    for map_type, seed in MAP_BLOCKS.items():
        for roster in ("all-forge", "mixed"):
            for count in (3, 4):
                base_rotation = 0 if map_type == "pangaea" else 1
                # Three/four games per block are the complete seat rotations
                # for the three/four-player roster.  The role/civilization
                # pair rotates together, so each role occupies each seat once.
                for seat_rotation in range(count):
                    config = config_for(map_type, seed, roster, count,
                                        rotation=(base_rotation + seat_rotation) % count)
                    config["seatRotationIndex"] = seat_rotation
                    jobs.append(config)
    return jobs


def job_id(config: dict) -> str:
    return sha_text(stable(config))[:20]


def write_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{next(tempfile._get_candidate_names())}.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")
    tmp.replace(path)


def source_fingerprint(source: dict) -> str:
    return sha_text(stable({"source": source, "adapters": adapter_fingerprints()}))


def expected_manifest(jobs: list[dict], source: dict) -> dict:
    return {
        "schemaVersion": 1,
        "status": "prepared-not-run",
        "configVersion": CONFIG_VERSION,
        "purpose": "Controlled 3/4-player current-rules slice; not full victory fairness",
        "sourceManifestBeforeRun": source,
        "sourceFingerprint": source_fingerprint(source),
        "adapterFingerprintsBeforeRun": adapter_fingerprints(),
        "configuration": {
            "mapFamilies": {key: value for key, value in MAP_BLOCKS.items()},
            "newSeeds": list(MAP_BLOCKS.values()),
            "rosters": {
                "all-forge": {"three": ["selected-expedition", "adapted-expedition", "industrial"],
                               "four": ["selected-expedition", "adapted-expedition", "industrial", "original-adaptive"]},
                "mixed": {"three": ["forge:selected-expedition", "mariner:adapted-expedition", "scholar:industrial"],
                          "four": ["forge:selected-expedition", "mariner:adapted-expedition", "scholar:industrial", "merchant:original-adaptive"]},
            },
            "roleRotation": "all seat rotations per 3/4-player block; base rotation 0 on Pangaea and 1 on Archipelago; civilization and policy rotate together",
            "hostileMode": "off",
            "maxRounds": 180,
            "attemptedGames": len(jobs),
            "workers": 2,
            "policies": POLICIES,
        },
        "jobs": [{"jobId": job_id(job), "config": job} for job in jobs],
        "limits": [
            "Two map clusters only: uncertainty is descriptive and very wide, not a population estimate.",
            "All games use the current source and hostile mode off; hostile robustness is out of scope.",
            "Original-adaptive preserves native personality behavior; role/policy competence remains a confound.",
            "The matrix rotates role/civilization pairs across the two map blocks, not every N! seating permutation.",
            "No faction equivalence, victory-route fairness, or balance claim follows from 28 games.",
        ],
    }


def prepare() -> dict:
    source = source_manifest()
    manifest = expected_manifest(build_jobs(), source)
    write_atomic(MANIFEST_PATH, manifest)
    return manifest


def record_path(config: dict) -> Path:
    return RUN_ROOT / f"{job_id(config)}.json"


def reusable(config: dict, source: dict) -> dict | None:
    path = record_path(config)
    if not path.exists():
        return None
    try:
        row = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    if row.get("status") not in TERMINAL or row.get("jobId") != job_id(config):
        return None
    if row.get("config") != config or row.get("sourceFingerprint") != source_fingerprint(source):
        return None
    if row.get("adapterFingerprints") != adapter_fingerprints():
        return None
    return row


def durable(config: dict, result: dict, source: dict) -> dict:
    status = result.get("status", "error")
    if status not in TERMINAL:
        status = "error"
    return {
        "schemaVersion": 1,
        "jobId": job_id(config),
        "status": status,
        "config": config,
        "sourceHead": source["head"],
        "luaSourceHash": source["luaSourceHash"],
        "sourceFingerprint": source_fingerprint(source),
        "adapterFingerprints": adapter_fingerprints(),
        "result": result,
    }


def run_jobs(jobs: list[dict], source: dict, worker_count: int) -> tuple[list[dict], dict]:
    records, pending = [], []
    reused = 0
    for config in jobs:
        row = reusable(config, source)
        if row is None:
            pending.append(config)
        else:
            records.append(row)
            reused += 1
    original_worker = workers._worker
    workers._worker = play_worker
    started = time.perf_counter()
    try:
        for offset in range(0, len(pending), worker_count):
            batch = pending[offset : offset + worker_count]
            results = workers.run_bounded(batch, workers=worker_count)
            for config, result in zip(batch, results, strict=True):
                if result is None:
                    result = {"status": "error", "error": "missing_worker_result", "config": config}
                row = durable(config, result, source)
                write_atomic(record_path(config), row)
                records.append(row)
    finally:
        workers._worker = original_worker
    records.sort(key=lambda row: row["jobId"])
    return records, {"reused": reused, "launched": len(pending), "elapsedSeconds": time.perf_counter() - started}


def first_round(turns: list[dict], predicate) -> int | None:
    for turn in turns:
        if predicate(turn):
            return turn.get("round")
    return None


def player_progress(turns: list[dict], player_id: int) -> dict:
    rows = []
    for turn in turns:
        players = turn.get("players", [])
        player = next((p for p in players if p.get("id") == player_id), None)
        if player:
            rows.append((turn, player))
    first_science = first_round(rows, lambda pair: (pair[1].get("science") or 0) > 0)
    first_tech = first_round(rows, lambda pair: (pair[1].get("technologies") or 0) > 0)
    first_two_cities = first_round(rows, lambda pair: len(pair[1].get("cities") or []) >= 2)
    first_eligible = first_round(
        rows,
        lambda pair: any((pair[0].get("victoryEligibility") or {}).get(str(player_id), {}).get(route, False)
                          for route in ("conquest", "expedition", "industrial", "diplomatic")),
    )
    last = rows[-1][1] if rows else {}
    last_turn = rows[-1][0] if rows else {}
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


def summarize(records: list[dict], source_before: dict, source_after: dict, run_stats: dict) -> dict:
    status_counts = Counter(row["status"] for row in records)
    finished = [row for row in records if row["status"] == "finished"]
    route_counts = Counter(row["result"].get("victoryReason") for row in finished)
    role_rows = defaultdict(list)
    block_rows = defaultdict(list)
    for row in finished:
        config, result = row["config"], row["result"]
        winners = result.get("winnerIds") or []
        for seat, player in enumerate(config["players"]):
            credit = (1 / len(winners)) if winners and seat in winners else 0.0
            progress = player_progress(result.get("turns", []), seat)
            item = {
                "jobId": row["jobId"], "mapType": config["mapType"], "seed": config["seed"],
                "roster": config["roster"], "playerCount": config["playerCount"], "seat": seat,
                "role": player["role"], "civilization": player["civilization"], "winner": seat in winners,
                "winnerCredit": credit, "victoryReason": result.get("victoryReason"),
                "finishRound": result.get("round"), "progress": progress,
            }
            role_rows[player["role"]].append(item)
            block_rows[(config["mapType"], config["roster"])].append(item)
    role_summary = {}
    for role, rows in sorted(role_rows.items()):
        role_summary[role] = {
            "attemptedPursuerRows": len(rows),
            "finishedPursuerRows": len(rows),
            "winnerCredit": sum(r["winnerCredit"] for r in rows) / len(rows),
            "nominalPerPursuerReference": sorted({1 / r["playerCount"] for r in rows}),
            "victories": dict(Counter(r["victoryReason"] for r in rows)),
        }
    blocks = []
    for (map_type, roster), rows in sorted(block_rows.items()):
        by_role = {}
        for role in sorted({row["role"] for row in rows}):
            subset = [row for row in rows if row["role"] == role]
            by_role[role] = {"winnerCredit": sum(r["winnerCredit"] for r in subset) / len(subset),
                             "rows": len(subset)}
        blocks.append({"mapType": map_type, "roster": roster, "rows": len(rows), "byRole": by_role})
    # With only two map clusters, report a deliberately wide descriptive
    # Hoeffding bound around the two cluster means; do not call it a CI over
    # all possible CivCraft maps.
    cluster_rows = defaultdict(lambda: defaultdict(list))
    for (map_type, roster), rows in block_rows.items():
        for role in {r["role"] for r in rows}:
            values = [r["winnerCredit"] for r in rows if r["role"] == role]
            cluster_rows[(roster, role)][map_type].append(sum(values) / len(values))
    cluster_intervals = {}
    for (roster, role), by_map in sorted(cluster_rows.items()):
        values = [v[0] for v in by_map.values()]
        mean = sum(values) / len(values)
        epsilon = math.sqrt(math.log(2 / 0.05) / (2 * len(values)))
        cluster_intervals[f"{roster}:{role}"] = {
            "clusterCount": len(values), "clusterMeans": by_map, "mean": mean,
            "descriptiveHoeffding95": [max(0.0, mean - epsilon), min(1.0, mean + epsilon)],
            "nominalReferenceByPlayerCount": sorted({1 / r["playerCount"] for r in role_rows[role]}),
        }
    return {
        "schemaVersion": 1,
        "status": "complete" if all(row["status"] == "finished" for row in records) else "incomplete-or-invalid",
        "purpose": "28-game 3/4-player current-rules slice; controlled routes and rosters, not full fairness",
        "sourceBeforeAfter": {"before": source_before, "after": source_after,
                              "sourceChangedDuringRun": source_before != source_after},
        "adapterFingerprints": adapter_fingerprints(),
        "execution": {"attemptedGames": len(records), "finishedGames": len(finished),
                       "statusCounts": dict(status_counts), "runStats": run_stats},
        "victoryReasons": dict(route_counts),
        "roleSummary": role_summary,
        "mapRosterBlocks": blocks,
        "clusterUncertainty": cluster_intervals,
        "rawRunDirectory": str(RUN_ROOT),
        "claimLimits": [
            "Two map clusters and one new seed per family; intervals are descriptive and wide.",
            "Original-adaptive and route policies have different competence; this is a controlled context slice, not faction equivalence.",
            "Hostiles are off and all 28 games use the current rules; no hostile/multiplayer-network claim follows.",
            "Role/civilization pairs rotate between the two map blocks, not all N! seat permutations.",
            "Errors, censored games and timeouts remain ineligible and are never converted to losses.",
        ],
    }


def smoke() -> dict:
    source = source_manifest()
    config = config_for("pangaea", MAP_BLOCKS["pangaea"], "all-forge", 3)
    root = Path(tempfile.mkdtemp(prefix="civcraft-multiplayer-smoke-"))
    # Smoke uses a short budget only to exercise serialization and resume; it
    # is not included in the 28-game result.
    config["maxRounds"], config["wallSeconds"] = 2, 30
    original = workers._worker
    workers._worker = play_worker
    try:
        result = workers.run_bounded([config], workers=1)[0]
    finally:
        workers._worker = original
    row = durable(config, result, source)
    write_atomic(root / "smoke.json", row)
    print(json.dumps({"status": row["status"], "path": str(root / "smoke.json")}, sort_keys=True))
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--output", type=Path, default=RESULTS / "multiplayer_baseline.json")
    args = parser.parse_args()
    if sum(bool(value) for value in (args.prepare, args.run, args.smoke)) != 1:
        raise SystemExit("choose exactly one of --prepare, --run, --smoke")
    if args.smoke:
        smoke()
        return
    if args.prepare:
        manifest = prepare()
        print(json.dumps({"manifest": str(MANIFEST_PATH), "games": len(manifest["jobs"]),
                          "sourceHead": manifest["sourceManifestBeforeRun"]["head"]}, sort_keys=True))
        return
    if args.workers <= 0:
        raise SystemExit("--workers must be positive")
    manifest = json.loads(MANIFEST_PATH.read_text())
    source_before = source_manifest()
    if source_before != manifest["sourceManifestBeforeRun"]:
        raise SystemExit("source changed after manifest preparation; refusing to run")
    jobs = [entry["config"] for entry in manifest["jobs"]]
    records, stats = run_jobs(jobs, source_before, args.workers)
    source_after = source_manifest()
    summary = summarize(records, source_before, source_after, stats)
    summary["manifest"] = str(MANIFEST_PATH)
    summary["runRoot"] = str(RUN_ROOT)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"attempted": len(records), "finished": summary["execution"]["finishedGames"],
                      "statusCounts": summary["execution"]["statusCounts"], "output": str(args.output)}, sort_keys=True))


if __name__ == "__main__":
    main()
