#!/usr/bin/env python3
"""Run every Lua regression using deterministic, runtime-balanced CI shards.

Historical weights are approximate seconds from GitHub Actions run 40440634256.
Unknown/new tests receive a small default weight and are never skipped.
The exhaustive CivCraft controls suite runs on every shard, with two of its
18 layouts per shard (the same coverage as before).
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

# Keep the expensive test cases spread apart rather than assigning alphabetically.
# Update these weights after profiling; exact values do not affect test coverage.
SECONDS = {
    "civcraft_actions_test.lua": 9,
    "civcraft_animation_ui_test.lua": 92,
    "civcraft_biomes_test.lua": 44,
    "civcraft_controls_test.lua": 90,
    "civcraft_conversation_ui_test.lua": 60,
    "civcraft_diplomacy_test.lua": 13,
    "civcraft_economic_ai_test.lua": 14,
    "civcraft_expansion_test.lua": 20,
    "civcraft_expansion_ui_test.lua": 70,
    "civcraft_hud_test.lua": 109,
    "civcraft_observer_ui_test.lua": 82,
    "civcraft_presentation_test.lua": 64,
    "civcraft_progression_test.lua": 29,
    "civcraft_rules_ui_test.lua": 94,
    "civcraft_settings_test.lua": 72,
    "civcraft_tactics_test.lua": 100,
    "civcraft_turn_tasks_test.lua": 79,
    "civcraft_ui_test.lua": 58,
    "civcraft_zone_control_test.lua": 9,
}

CONTROLS = "civcraft_controls_test.lua"


def assign(tests, shard_count):
    """Longest-processing-time-first; stable name tie-breaker."""
    assignments = [[] for _ in range(shard_count)]
    cost = [SECONDS[CONTROLS]] * shard_count
    for test in sorted(
        (test for test in tests if test.name != CONTROLS),
        key=lambda test: (-SECONDS.get(test.name, 1), test.name),
    ):
        worker = min(range(shard_count), key=lambda idx: (cost[idx], idx))
        assignments[worker].append(test)
        cost[worker] += SECONDS.get(test.name, 1)
    controls = next((test for test in tests if test.name == CONTROLS), None)
    if controls:
        for worker in assignments:
            worker.append(controls)
    return assignments, cost


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shard", type=int, required=True)
    parser.add_argument("--shards", type=int, default=9)
    parser.add_argument("--list", action="store_true", help="Print assignments only")
    parser.add_argument("--selected-json", help="JSON list of selected test paths")
    args = parser.parse_args()
    if args.shards < 1 or not 0 <= args.shard < args.shards:
        parser.error("shard must be between 0 and shards - 1")
    all_tests = sorted(Path("tests").glob("*_test.lua"))
    if args.selected_json is not None:
        try:
            selected = json.loads(args.selected_json)
        except json.JSONDecodeError as error:
            parser.error(f"Invalid selected-tests JSON: {error}")
        if not isinstance(selected, list) or any(not isinstance(t, str) for t in selected):
            parser.error("Selected tests must be a JSON array of file paths")
        allowed = {test.as_posix(): test for test in all_tests}
        if len(set(selected)) != len(selected) or any(name not in allowed for name in selected):
            parser.error("Selected tests contain duplicate, missing or non-regression paths")
        tests = [allowed[name] for name in sorted(selected)]
    else:
        tests = all_tests
    if not tests:
        parser.error("no Lua regression tests selected")
    groups, costs = assign(tests, args.shards)
    assigned = groups[args.shard]
    if not assigned:
        parser.error("shard is empty")
    print(
        f"Shard {args.shard}/{args.shards}: {len(assigned)} tests, "
        f"estimated {costs[args.shard]} s",
        flush=True,
    )
    if args.list:
        for test in assigned:
            print(test, flush=True)
        return 0
    env = os.environ.copy()
    env["CIVCRAFT_CONTROLS_SHARD"] = str(args.shard)
    env["CIVCRAFT_CONTROLS_SHARDS"] = str(args.shards)
    for test in assigned:
        print(f"Running {test}", flush=True)
        start = time.monotonic()
        outcome = subprocess.run(["lua5.3", str(test)], env=env, check=False)
        print(f"TIME {test}: {time.monotonic() - start:.2f}s", flush=True)
        if outcome.returncode != 0:
            return outcome.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
