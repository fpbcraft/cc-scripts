#!/usr/bin/env python3
"""Research-only geography versus seat/order permutation study.

The reverse arm wraps only ``World.generate`` in an isolated Runtime and
swaps ``world.starts[1]``/``world.starts[2]`` before normal initialization.
No gameplay module, engine rule or policy asset is changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
from runtime import Runtime, from_lua  # noqa: E402
from runner import source_manifest  # noqa: E402
import workers  # noqa: E402


SEEDS = [203807, 708091, 807121, 509443]
POLICY = json.loads((HERE / "results/strategy_search_pilot.json").read_text())["championHoldout"]["policy"]
CONFIG_BASE = {
    "mapSize": "compact",
    "mapType": "pangaea",
    "hostileMode": "off",
    "maxRounds": 180,
    "telemetryEvery": 1,
    "wallSeconds": 180,
    "players": [
        {"civilization": "forge", "ai": True, "policy": POLICY},
        {"civilization": "forge", "ai": True, "policy": POLICY},
    ],
}


def sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


class PermutedRuntime(Runtime):
    """Runtime that swaps generated starts once, before Engine.newGame."""

    def __init__(self, config: dict):
        self.swap_starts = bool(config.get("swapStarts"))
        self._world_wrapper_installed = False
        super().__init__(config, instruction_budget=config.get("instructionBudget", 200_000_000))

    def _install_world_wrapper(self) -> None:
        world = self.lua.globals().dofile("/games/civcraft/world.lua")
        original = world.generate
        wrapper_factory = self.lua.eval(
            """function(original)
                return function(seed, size, count, mapType)
                    local generated = original(seed, size, count, mapType)
                    assert(generated.starts and #generated.starts >= 2, "Need two generated starts")
                    generated.starts[1], generated.starts[2] = generated.starts[2], generated.starts[1]
                    return generated
                end
            end"""
        )
        world.generate = wrapper_factory(original)
        self._world_wrapper_installed = True

    def call(self, function, *args):
        # Runtime.__init__ reaches this override for its first newGame call
        # after bootstrap, policy installation and _run_budgeted setup.
        if self.swap_starts and not self._world_wrapper_installed:
            self._install_world_wrapper()
        return super().call(function, *args)


def config_for(seed: int, reverse: bool) -> dict:
    config = json.loads(json.dumps(CONFIG_BASE))
    config["seed"] = seed
    config["swapStarts"] = reverse
    config["variant"] = "reverse-starts" if reverse else "baseline"
    return config


def canonical(runtime: Runtime, value) -> str:
    return runtime.call(runtime.lua.globals().LAB_CANONICAL.encode, value)


def stable_json(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def normalized_villages(runtime: Runtime) -> list[dict]:
    cities = from_lua(runtime.state.cities)
    villages = [city for city in cities if city.get("village") is True]
    return sorted(villages, key=lambda city: (city.get("id", 0), city.get("x", 0), city.get("y", 0)))


def player_assets(players: list[dict]) -> list[dict]:
    private_projection = {"explored", "visible", "mapMemory", "knownLandmarks"}
    result = []
    for player in players:
        result.append({key: value for key, value in player.items() if key not in private_projection})
    return result


def initial_snapshot(runtime: Runtime) -> dict:
    state = runtime.state
    world = state.world
    world_fields = {}
    for field in ["tiles", "resources", "geography", "landmarks", "rails"]:
        value = world[field] if world[field] is not None else runtime.lua.table()
        world_fields[field] = canonical(runtime, value)
    players = from_lua(state.players)
    assets = player_assets(players)
    villages = normalized_villages(runtime)
    spawners = from_lua(state.spawners or runtime.lua.table())
    starts = from_lua(world.starts)
    return {
        "starts": starts,
        "worldFields": world_fields,
        "worldFieldSha256": {field: sha(value) for field, value in world_fields.items()},
        "neutralVillages": villages,
        "neutralVillagesSha256": sha(stable_json(villages)),
        "spawners": spawners,
        "spawnersSha256": sha(stable_json(spawners)),
        "players": players,
        "playerAssets": assets,
        "playersSha256": sha(stable_json(assets)),
        "stateHash": runtime.state_hash(),
    }


def metric_summary(metric: dict) -> dict:
    result = {"round": metric.get("round"), "phase": metric.get("phase"), "players": []}
    for player in metric.get("players", []):
        result["players"].append({
            key: (len(player.get("cities") or []) if key == "cities" else player.get(key))
            for key in [
                "id", "civilization", "age", "technologies", "cities", "population",
                "industry", "science", "unitCount", "combatPower", "buildings",
                "score", "strategy", "hasSettler", "noCityOrSettler",
            ]
        })
    return result


def milestone_rows(previous: dict | None, current: dict) -> list[dict]:
    if previous is None:
        return [{"type": "initial", "round": current["round"], "player": player["id"],
                 "age": player["age"], "technologies": player["technologies"],
                 "cities": player.get("cities")}
                for player in current["players"]]
    rows = []
    for old, new in zip(previous["players"], current["players"]):
        for field in ["age", "technologies", "cities", "hasSettler", "strategy"]:
            if old.get(field) != new.get(field):
                rows.append({"type": field, "round": current["round"], "player": new["id"],
                             "from": old.get(field), "to": new.get(field)})
    return rows


def run_match(config: dict) -> dict:
    started = time.perf_counter()
    runtime = None
    result = {"config": config, "status": "error", "winnerIds": [], "trajectory": [], "milestones": []}
    try:
        runtime = PermutedRuntime(config)
        result["initial"] = initial_snapshot(runtime)
        previous = None
        max_round = config["maxRounds"]
        while not runtime.finished() and runtime.state.round <= max_round:
            runtime.pump()
            metric = metric_summary(runtime.metrics())
            result["trajectory"].append({
                "round": metric["round"],
                "stateHash": runtime.state_hash(),
                "players": metric["players"],
            })
            result["milestones"].extend(milestone_rows(previous, metric))
            previous = metric
            if runtime.finished() or runtime.state.round >= max_round:
                break
            runtime.advance()
        if runtime.finished():
            result.update(
                status="finished",
                round=int(runtime.state.round),
                winnerIds=from_lua(runtime.state.winnerIDs or runtime.lua.table()) or [],
                victoryReason=runtime.state.victoryReason,
            )
        else:
            result.update(status="censored", round=int(runtime.state.round),
                          censorReason="research_round_budget")
        result["finalStateHash"] = runtime.state_hash()
        result["finalState"] = canonical(runtime, runtime.state)
    except Exception as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
        if runtime is not None:
            result["errorRound"] = int(runtime.state.round)
            result["errorStateHash"] = runtime.state_hash()
    result["elapsedSeconds"] = time.perf_counter() - started
    return result


def permutation_worker(connection, config):
    try:
        connection.send(run_match(config))
    finally:
        connection.close()


def compare_pair(baseline: dict, reverse: dict) -> dict:
    baseline_starts = baseline["initial"]["starts"]
    reverse_starts = reverse["initial"]["starts"]
    expected_reverse = [baseline_starts[1], baseline_starts[0]]
    winner_ids_equal = baseline.get("winnerIds") == reverse.get("winnerIds")
    def winner_coordinates(result: dict) -> list[dict]:
        starts = result["initial"]["starts"]
        return [starts[int(winner)] for winner in result.get("winnerIds", [])]
    geography_coordinates_equal = winner_coordinates(baseline) == winner_coordinates(reverse)
    return {
        "seed": baseline["config"]["seed"],
        "baselineStarts": baseline_starts,
        "reverseStarts": reverse_starts,
        "expectedReverseStarts": expected_reverse,
        "startsSwappedExactly": reverse_starts == expected_reverse,
        "worldStaticHashesEqual": baseline["initial"]["worldFieldSha256"] == reverse["initial"]["worldFieldSha256"],
        "neutralVillagesEqual": baseline["initial"]["neutralVillagesSha256"] == reverse["initial"]["neutralVillagesSha256"],
        "spawnersEqual": baseline["initial"]["spawnersSha256"] == reverse["initial"]["spawnersSha256"],
        "initialPlayersEqual": baseline["initial"]["playersSha256"] == reverse["initial"]["playersSha256"],
        "baseline": {key: baseline.get(key) for key in ["status", "round", "winnerIds", "victoryReason", "finalStateHash"]},
        "reverse": {key: reverse.get(key) for key in ["status", "round", "winnerIds", "victoryReason", "finalStateHash"]},
        "winnerIdsEqual": winner_ids_equal,
        "winnerGeographyCoordinatesEqual": geography_coordinates_equal,
        "winnerInterpretation": (
            "same-winning-ID-and-same-geographic-coordinate"
            if winner_ids_equal and geography_coordinates_equal else
            "same-winning-ID-but-different-geographic-coordinate"
            if winner_ids_equal else
            "different-winning-ID"
        ),
    }


def compact_match(match: dict) -> dict:
    initial = match.get("initial", {})
    trajectory = match.get("trajectory", [])
    return {
        "config": match["config"],
        "status": match.get("status"),
        "round": match.get("round"),
        "winnerIds": match.get("winnerIds", []),
        "victoryReason": match.get("victoryReason"),
        "finalStateHash": match.get("finalStateHash"),
        "elapsedSeconds": match.get("elapsedSeconds"),
        "initial": {
            "starts": initial.get("starts"),
            "worldFieldSha256": initial.get("worldFieldSha256"),
            "neutralVillagesSha256": initial.get("neutralVillagesSha256"),
            "spawnersSha256": initial.get("spawnersSha256"),
            "playersSha256": initial.get("playersSha256"),
            "stateHash": initial.get("stateHash"),
        },
        "earlyTrajectory": trajectory[:20],
        "milestones": match.get("milestones", []),
        "error": match.get("error"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument("--raw", type=Path, default=Path("/tmp/civcraft-start-position-permutation.raw.json"))
    parser.add_argument("--output", type=Path, default=HERE / "results/start_position_permutation.json")
    args = parser.parse_args()
    if args.workers <= 0:
        raise SystemExit("--workers must be positive")

    configs = []
    for seed in SEEDS:
        configs.append(config_for(seed, False))
        configs.append(config_for(seed, True))
    source = source_manifest()
    original_worker = workers._worker
    started = time.perf_counter()
    workers._worker = permutation_worker
    try:
        matches = workers.run_bounded(configs, args.workers)
    finally:
        workers._worker = original_worker
    after_source = source_manifest()
    pairs = []
    for index in range(0, len(matches), 2):
        pairs.append(compare_pair(matches[index], matches[index + 1]))
    raw = {
        "schemaVersion": 1,
        "purpose": "Starting-position permutation; same Forge expedition champion in both seats",
        "source": source,
        "sourceChangedDuringRun": source != after_source,
        "scriptSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "host": {"machine": platform.machine(), "python": platform.python_version(), "workers": args.workers},
        "configuration": {"seeds": SEEDS, "players": CONFIG_BASE["players"], "mapSize": "compact",
                          "mapType": "pangaea", "hostileMode": "off", "maxRounds": CONFIG_BASE["maxRounds"]},
        "elapsedSeconds": time.perf_counter() - started,
        "matches": matches,
        "pairs": pairs,
    }
    args.raw.parent.mkdir(parents=True, exist_ok=True)
    args.raw.write_text(json.dumps(raw, indent=2, sort_keys=True) + "\n")
    compact = {
        "schemaVersion": 1,
        "purpose": raw["purpose"],
        "source": {"head": source["head"], "luaSourceHash": source["luaSourceHash"]},
        "scriptSha256": raw["scriptSha256"],
        "host": raw["host"],
        "configuration": raw["configuration"],
        "elapsedSeconds": raw["elapsedSeconds"],
        "workers": args.workers,
        "matches": [compact_match(match) for match in matches],
        "pairs": pairs,
        "rawArtifact": str(args.raw),
        "limits": [
            "Eight bounded games (four seeds x baseline/reverse), not a causal intervention or balance estimate.",
            "Both seats use the same Forge expedition champion; shared entity IDs, names and deterministic tie-breaks can still affect policy behaviour.",
            "The reverse arm swaps generated starts only; it does not independently rotate IDs, names or actor order.",
            "Winner-ID/geography comparisons are descriptive and must not be interpreted as causal attribution.",
            "Early trajectories are recorded for diagnosis; full canonical states remain in the raw /tmp artifact.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(compact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"games": len(matches), "workers": args.workers,
                      "statuses": [match.get("status") for match in matches],
                      "output": str(args.output), "raw": str(args.raw)}))
    if raw["sourceChangedDuringRun"] or any(match.get("status") == "error" for match in matches):
        raise SystemExit("Permutation run integrity failure; inspect raw artifact")


if __name__ == "__main__":
    main()
