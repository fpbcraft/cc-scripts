#!/usr/bin/env python3
"""Fast Lupa-only adversarial observer and replay conformance checks.

This intentionally avoids native/full-game runs. It is a research fixture for
information boundaries, canonical hash stability and a selected Surprise War
reaction/trace replay.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
FIXTURE_SOURCE = (HERE / "conformance_extension_fixture.lua").read_text()
sys.path.insert(0, str(REPOSITORY / "tools/civcraft_lab"))
from runtime import Runtime, from_lua  # noqa: E402


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


def sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def fixture(runtime: Runtime):
    return runtime.lua.execute(FIXTURE_SOURCE)


def observe_hashes(runtime: Runtime) -> dict:
    canonical = runtime.lua.globals().LAB_CANONICAL
    observation = runtime.call(runtime.engine.observe, runtime.state, 0)
    proposals = runtime.call(runtime.engine.legalActions, runtime.state, 0)[0]
    return {
        "observation": runtime.call(canonical.encode, observation),
        "proposals": runtime.call(canonical.encode, proposals),
    }


def normalize_result(value) -> dict:
    value = from_lua(value)
    if isinstance(value, (list, tuple)):
        return {
            "ok": bool(value[0]) if value else False,
            "message": value[1] if len(value) > 1 else None,
            "detail": value[2] if len(value) > 2 else None,
        }
    return {"ok": bool(value), "message": None, "detail": None}


def observer_adversarial() -> dict:
    runtime = Runtime(CONFIG)
    mod = fixture(runtime)
    before = observe_hashes(runtime)
    hidden = from_lua(runtime.call(mod["hideRival"], runtime.state))
    after = observe_hashes(runtime)
    return {
        "hiddenTile": hidden,
        "observationEqual": before["observation"] == after["observation"],
        "proposalEqual": before["proposals"] == after["proposals"],
        "beforeSha256": {key: sha(value) for key, value in before.items()},
        "afterSha256": {key: sha(value) for key, value in after.items()},
        "_beforePayload": before,
        "_afterPayload": after,
    }


def hash_only() -> None:
    config = {
        "seed": 18731,
        "mapSize": "compact",
        "mapType": "archipelago",
        "hostileMode": "standard",
        "players": [
            {"civilization": "forge", "ai": False},
            {"civilization": "scholar", "ai": False},
            {"civilization": "iron", "ai": False},
            {"civilization": "merchant", "ai": False},
        ],
    }
    print(json.dumps({"hashes": [Runtime(config).state_hash() for _ in range(3)]}))


def install_trace(runtime: Runtime):
    telemetry = runtime.lua.globals().dofile("/lab/telemetry.lua")
    return telemetry.install(runtime.lua.table_from({"trace": True, "actionBudget": 64}))


def apply(runtime: Runtime, player: int, request: dict):
    return runtime.call(
        runtime.engine.applyAction,
        runtime.state,
        player,
        runtime.lua.table_from(request, recursive=True),
    )


def end_turn(runtime: Runtime, player: int):
    return runtime.call(runtime.engine.endTurn, runtime.state, player)


def surprise_operations(positions: dict) -> list[dict]:
    """The intended Surprise War sequence, including the scheduler handoff."""
    return [
        {
            "kind": "action",
            "player": 0,
            "request": {"action": "declareWar", "target": 1, "kind": "surprise"},
        },
        {"kind": "endTurn", "player": 0},
        {
            "kind": "action",
            "player": 1,
            "request": {
                "action": "move",
                "sx": positions["target"]["x"],
                "sy": positions["target"]["y"],
                "x": positions["attacker"]["x"],
                "y": positions["attacker"]["y"],
            },
        },
        {"kind": "endTurn", "player": 1},
    ]


def execute_surprise_operation(runtime: Runtime, operation: dict):
    if operation["kind"] == "endTurn":
        return end_turn(runtime, operation["player"])
    return apply(runtime, operation["player"], operation["request"])


def capture_checkpoint(runtime: Runtime, label: str) -> dict:
    canonical = runtime.lua.globals().LAB_CANONICAL
    return {
        "label": label,
        "state": runtime.call(canonical.encode, runtime.state),
        "observation0": runtime.call(canonical.encode, runtime.engine.observe(runtime.state, 0)),
        "observation1": runtime.call(canonical.encode, runtime.engine.observe(runtime.state, 1)),
        "proposals0": runtime.call(canonical.encode, runtime.engine.legalActions(runtime.state, 0)[0]),
    }


def surprise_replay() -> dict:
    left, right = Runtime(CONFIG), Runtime(CONFIG)
    left_fixture, right_fixture = fixture(left), fixture(right)
    left_positions = from_lua(left.call(left_fixture["setupSurprise"], left.state))
    right_positions = from_lua(right.call(right_fixture["setupSurprise"], right.state))
    left_trace, right_trace = install_trace(left), install_trace(right)
    left_operations = surprise_operations(left_positions)
    right_operations = surprise_operations(right_positions)
    checkpoints = []
    checkpoint_payloads = []
    outcomes = []
    response_movement_marked = False
    reaction_granted_before_handoff = False
    for operation_index, (left_operation, right_operation) in enumerate(
        zip(left_operations, right_operations)
    ):
        left_result = normalize_result(execute_surprise_operation(left, left_operation))
        right_result = normalize_result(execute_surprise_operation(right, right_operation))
        outcomes.append({"kind": left_operation["kind"],
                         "left": left_result, "right": right_result,
                         "equal": left_result == right_result})
        checkpoints.append({"left": left.state_hash(), "right": right.state_hash()})
        checkpoint_label = f"after-{operation_index}-{left_operation['kind']}"
        checkpoint_payloads.append({
            "label": checkpoint_label,
            "left": capture_checkpoint(left, checkpoint_label),
            "right": capture_checkpoint(right, checkpoint_label),
        })
        if left_operation["kind"] == "endTurn" and left_operation["player"] == 0:
            # A Surprise War grants the ended defender a reaction, but the
            # attacker still owns the war-group turn until it ends it. The
            # production actor pump consumes the response window only after
            # this legitimate scheduler handoff.
            reaction_granted_before_handoff = bool(left.state.scheduler.reactions[1])
            left.call(left.engine.pump, left.state)
            right.call(right.engine.pump, right.state)
            response_movement_marked = (
                left.state.units[2].responseMovementRound == left.state.round
            )
            checkpoints.append({"left": left.state_hash(), "right": right.state_hash()})
            checkpoint_payloads.append({
                "label": "after-pump-attacker-handoff",
                "left": capture_checkpoint(left, "after-pump-attacker-handoff"),
                "right": capture_checkpoint(right, "after-pump-attacker-handoff"),
            })
    left_dispatch = from_lua(left_trace)
    right_dispatch = from_lua(right_trace)

    # Selective replay: a fresh runtime replays the same accepted orders,
    # lifecycle finishes and actor-pump handoff.
    replay = Runtime(CONFIG)
    replay_fixture = fixture(replay)
    replay_positions = from_lua(replay.call(replay_fixture["setupSurprise"], replay.state))
    replay_trace = install_trace(replay)
    replay_operations = surprise_operations(replay_positions)
    replay_outcomes = []
    for index, operation in enumerate(replay_operations):
        replay_outcomes.append(normalize_result(execute_surprise_operation(replay, operation)))
        if operation["kind"] == "endTurn" and operation["player"] == 0:
            replay.call(replay.engine.pump, replay.state)
    replay_dispatch = from_lua(replay_trace)
    defender_move_accepted = bool(outcomes[2]["left"]["ok"])
    return {
        "positionsEqual": left_positions == right_positions,
        "outcomes": outcomes,
        "checkpointEqual": [item["left"] == item["right"] for item in checkpoints],
        "leftHash": left.state_hash(),
        "rightHash": right.state_hash(),
        "traceEqual": left_dispatch == right_dispatch,
        "replayOutcomeEqual": replay_outcomes == [item["left"] for item in outcomes],
        "replayStateEqual": replay.state_hash() == left.state_hash(),
        "replayTraceEqual": replay_dispatch == left_dispatch,
        "_trace": left_dispatch,
        "_checkpointPayloads": checkpoint_payloads,
        "reactionChecks": {
            "warActive": bool(left.state.diplomacy.wars[1].active),
            "reactionGrantedBeforeHandoff": reaction_granted_before_handoff,
            "responseMovementMarkedAfterPump": response_movement_marked,
            "defenderMoveAccepted": defender_move_accepted,
            "reactionConsumedAfterDefenderFinish": not bool(left.state.scheduler.reactions[1]),
            "reactionPathBlocked": not (response_movement_marked and defender_move_accepted),
        },
        "traceActionCount": len(left_dispatch.get("trace", [])),
    }


def deterministic_hash_seeds() -> dict:
    command = [sys.executable, str(HERE / "run_conformance_extensions.py"), "--hash-only"]
    records = {}
    for seed in ["0", "1", "42", "123"]:
        env = dict(os.environ, PYTHONHASHSEED=seed)
        completed = subprocess.run(command, cwd=REPOSITORY, env=env,
                                   text=True, capture_output=True, check=True)
        records[seed] = json.loads(completed.stdout)
    baseline = records["0"]["hashes"]
    return {"records": records, "allEqual": all(row["hashes"] == baseline for row in records.values())}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hash-only", action="store_true")
    parser.add_argument("--output", type=Path,
                        default=HERE / "results/conformance_extension.json")
    args = parser.parse_args()
    if args.hash_only:
        hash_only()
        return
    record = {
        "schemaVersion": 1,
        "fixtures": {
            "observer": "conformance_extension_fixture.lua:hideRival",
            "surpriseWar": "conformance_extension_fixture.lua:setupSurprise",
        },
        "config": CONFIG,
        "observerAdversarial": observer_adversarial(),
        "deterministicHashSeeds": deterministic_hash_seeds(),
        "surpriseWarReplay": surprise_replay(),
        "limitations": [
            "Lupa-only fast checks; no native/full-game launch was performed.",
            "The observer test mutates a hidden rival plan, stockpiles, city, unit and recipient-only event; it does not prove every future field is private.",
            "The replay is a two-player Surprise War reaction fixture, not a balance sample or complete network/save replay.",
        ],
    }
    # Keep the JSON result compact; the payloads remain available to the
    # native comparison driver by calling the fixture functions directly.
    for key in ["_beforePayload", "_afterPayload"]:
        record["observerAdversarial"].pop(key)
    record["surpriseWarReplay"].pop("_checkpointPayloads")
    record["surpriseWarReplay"].pop("_trace")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"observer": record["observerAdversarial"],
                      "hashSeedsEqual": record["deterministicHashSeeds"]["allEqual"],
                      "replay": record["surpriseWarReplay"],
                      "output": str(args.output)}))
    assert record["observerAdversarial"]["observationEqual"]
    assert record["observerAdversarial"]["proposalEqual"]
    assert record["deterministicHashSeeds"]["allEqual"]
    replay = record["surpriseWarReplay"]
    assert all(replay["checkpointEqual"]) and replay["traceEqual"]
    assert replay["replayOutcomeEqual"] and replay["replayStateEqual"] and replay["replayTraceEqual"]
    checks = replay["reactionChecks"]
    assert checks["warActive"] and checks["reactionGrantedBeforeHandoff"]
    assert checks["responseMovementMarkedAfterPump"] and checks["defenderMoveAccepted"]
    assert checks["reactionConsumedAfterDefenderFinish"] and not checks["reactionPathBlocked"]


if __name__ == "__main__":
    main()
