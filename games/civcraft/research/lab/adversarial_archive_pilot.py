#!/usr/bin/env python3
"""Bounded archive-adaptation pilot; research artifact, not live AI training.

This driver deliberately imports the existing lab runner/evolution helpers
without changing tools/civcraft_lab. Training selection uses only TRAIN_SEED.
HOLDOUT_SEEDS are read only after the selected candidate and archive have been
written. Raw match records remain in /tmp; the repository receives a compact
summary and small Lua policy archives.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import sys
import time
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[4]
TOOLS = REPOSITORY / "tools" / "civcraft_lab"
sys.path.insert(0, str(TOOLS))

import evolve  # noqa: E402  (existing helper; do not duplicate its logic)
from runner import source_manifest, write_run  # noqa: E402


TRAIN_SEED = 451139
HOLDOUT_SEEDS = (808381, 919393)
ROUNDS = 180
WORKERS = 2
PILOT_SEED = 2026102602
FEATURES = ("food", "industry", "science", "gold")


def load_selected_archive() -> dict:
    path = REPOSITORY / "games/civcraft/research/lab/results/strategy_search_pilot.json"
    record = json.loads(path.read_text())
    selected = record["championHoldout"]["policy"]
    if selected.get("goal") != "expedition":
        raise RuntimeError("The archived source champion is not the selected expedition policy")
    return selected


def policy_id(policy: dict) -> str:
    return hashlib.sha256(json.dumps(policy, sort_keys=True).encode()).hexdigest()[:12]


def configs_against_mixture(policy: dict, seeds: tuple[int, ...], opponents: dict[str, dict]) -> tuple[list[dict], list[dict]]:
    configs, metadata = [], []
    for seed in seeds:
        for opponent_id, opponent in opponents.items():
            for seat in (0, 1):
                players = [
                    {"civilization": "forge", "policy": opponent},
                    {"civilization": "forge", "policy": opponent},
                ]
                players[seat] = {"civilization": "forge", "policy": policy}
                configs.append(
                    {
                        "seed": seed,
                        "mapType": "pangaea",
                        "mapSize": "compact",
                        "hostileMode": "off",
                        "maxRounds": ROUNDS,
                        "telemetryEvery": 10,
                        "players": players,
                    }
                )
                metadata.append({"seed": seed, "opponent": opponent_id, "candidateSeat": seat})
    return configs, metadata


def direct_configs(a: dict, b: dict, seeds: tuple[int, ...]) -> tuple[list[dict], list[dict]]:
    configs, metadata = [], []
    for seed in seeds:
        for a_seat in (0, 1):
            players = [
                {"civilization": "forge", "policy": a},
                {"civilization": "forge", "policy": b},
            ]
            if a_seat == 1:
                players[0], players[1] = players[1], players[0]
            configs.append(
                {
                    "seed": seed,
                    "mapType": "pangaea",
                    "mapSize": "compact",
                    "hostileMode": "off",
                    "maxRounds": ROUNDS,
                    "telemetryEvery": 10,
                    "players": players,
                }
            )
            metadata.append({"seed": seed, "aSeat": a_seat, "aId": "baseline-original", "bId": "selected-counter"})
    return configs, metadata


def credit(match: dict, seat: int) -> float | None:
    if match.get("status") != "finished":
        return None
    winners = match.get("winnerIds") or []
    if not winners:
        return 0.5
    return 1.0 / len(winners) if seat in winners else 0.0


def summarize_run(record: dict, metadata: list[dict], subject: str) -> dict:
    outcomes, credits, a_credits, b_credits = [], [], [], []
    for match, item in zip(record["matches"], metadata, strict=True):
        candidate_seat = item.get("candidateSeat")
        if candidate_seat is None:
            candidate_seat = item["aSeat"]
        value = credit(match, candidate_seat)
        if value is not None:
            credits.append(value)
        if "aSeat" in item:
            a_value = credit(match, item["aSeat"])
            b_value = credit(match, 1 - item["aSeat"])
            if a_value is not None and b_value is not None:
                a_credits.append(a_value)
                b_credits.append(b_value)
        outcomes.append(
            {
                **item,
                "status": match.get("status"),
                "round": match.get("round"),
                "winnerIds": match.get("winnerIds", []),
                "victoryReason": match.get("victoryReason"),
                "error": match.get("error"),
                "censorReason": match.get("censorReason"),
                "errorRound": match.get("errorRound"),
            }
        )
    finished = sum(1 for item in outcomes if item["status"] == "finished")
    censored = sum(1 for item in outcomes if item["status"] == "censored")
    errors = len(outcomes) - finished - censored
    valid = (
        finished == len(outcomes)
        and not record.get("sourceChangedDuringRun")
        and len(credits) == len(outcomes)
    )
    return {
        "subject": subject,
        "valid": valid,
        "fitness": sum(credits) / len(credits) if valid else None,
        "aFitness": sum(a_credits) / len(a_credits) if a_credits and valid else None,
        "bFitness": sum(b_credits) / len(b_credits) if b_credits and valid else None,
        "attempted": len(outcomes),
        "finished": finished,
        "censored": censored,
        "errors": errors,
        "sourceChangedDuringRun": record.get("sourceChangedDuringRun"),
        "elapsedSeconds": record.get("elapsedSeconds"),
        "sourceHash": record["source"]["luaSourceHash"],
        "outcomes": outcomes,
        "rawArtifact": subject,
    }


def run_evaluation(policy: dict, seeds: tuple[int, ...], opponents: dict[str, dict], raw_dir: Path, label: str) -> dict:
    configs, metadata = configs_against_mixture(policy, seeds, opponents)
    path = raw_dir / f"{label}-{policy_id(policy)}.json"
    record = write_run(configs, path, WORKERS)
    summary = summarize_run(record, metadata, str(path))
    return summary


def run_direct(a: dict, b: dict, seeds: tuple[int, ...], raw_dir: Path, label: str) -> dict:
    configs, metadata = direct_configs(a, b, seeds)
    path = raw_dir / f"{label}-{policy_id(a)}-{policy_id(b)}.json"
    record = write_run(configs, path, WORKERS)
    return summarize_run(record, metadata, str(path))


def archive_policy(directory: Path, identifier: str, policy: dict, evaluation: dict) -> dict:
    path = directory / f"{identifier}-{policy_id(policy)}.lua"
    evolve.export_lua(policy, path)
    return {
        "id": identifier,
        "policy": policy,
        "policyHash": policy_id(policy),
        "luaArtifact": str(path),
        "training": evaluation,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", type=Path, default=Path("/tmp/civcraft-adversarial-archive"))
    parser.add_argument(
        "--summary",
        type=Path,
        default=REPOSITORY / "games/civcraft/research/lab/results/adversarial_archive_adaptation_pilot.json",
    )
    args = parser.parse_args()
    raw_dir = args.raw_dir
    raw_dir.mkdir(parents=True, exist_ok=True)
    archive_dir = args.summary.parent / "adversarial_archive_candidates"
    archive_dir.mkdir(parents=True, exist_ok=True)

    selected = load_selected_archive()
    industrial = {"version": 1, "weights": dict.fromkeys(FEATURES, 1.0), "goal": "industrial"}
    conquest = {"version": 1, "weights": dict.fromkeys(FEATURES, 1.0), "goal": "conquest"}
    fixed_opponents = {"selected-archived-expedition": selected, "archived-industrial": industrial}
    initial = [
        ("selected-archived-expedition", selected),
        ("industrial-candidate", industrial),
        ("conquest-candidate", conquest),
    ]

    rng = random.Random(PILOT_SEED)
    history, valid_archive = [], []
    source_before = source_manifest()
    population = initial
    started = time.perf_counter()
    for generation in range(2):
        ranked = []
        for label, policy in population:
            evaluation = run_evaluation(policy, (TRAIN_SEED,), fixed_opponents, raw_dir, f"train-g{generation}-{label}")
            item = {"label": label, "generation": generation, "policy": policy, "evaluation": evaluation}
            ranked.append(item)
            if evaluation["valid"]:
                valid_archive.append(archive_policy(archive_dir, f"g{generation}-{label}", policy, evaluation))
        ranked.sort(
            key=lambda item: (
                item["evaluation"]["fitness"] if item["evaluation"]["valid"] else -1.0,
                item["label"],
            ),
            reverse=True,
        )
        if not ranked or not ranked[0]["evaluation"]["valid"]:
            raise RuntimeError("No valid training candidate; inspect errors/censoring before selection")
        history.append(ranked)
        champion = ranked[0]
        if generation == 0:
            population = [("selected-champion", champion["policy"])] + [
                (f"mutant-{index}", evolve.mutate(champion["policy"], rng, strategy_search=False))
                for index in (1, 2)
            ]

    selected_item = history[-1][0]
    selected_policy = selected_item["policy"]
    selected_archive = archive_policy(archive_dir, "selected-adapted", selected_policy, selected_item["evaluation"])
    # Holdout runs begin only after training selection and candidate archiving.
    holdout_baseline = run_direct(selected, selected, HOLDOUT_SEEDS, raw_dir, "holdout-original-vs-original")
    holdout_counter = run_direct(selected, selected_policy, HOLDOUT_SEEDS, raw_dir, "holdout-original-vs-selected-counter")
    source_after = source_manifest()

    summary = {
        "schemaVersion": 1,
        "purpose": "Bounded adversarial archive-adaptation pilot using archived expedition plus industrial mixture",
        "status": "executed-exploratory",
        "selection": {
            "trainSeeds": [TRAIN_SEED],
            "holdoutSeeds": list(HOLDOUT_SEEDS),
            "population": 3,
            "generations": 2,
            "workers": WORKERS,
            "rounds": ROUNDS,
            "pilotSeed": PILOT_SEED,
            "selectionUsedHoldout": False,
            "initialCandidates": [label for label, _ in initial],
            "fixedOpponents": list(fixed_opponents),
            "selectedLabel": selected_item["label"],
            "selectedPolicy": selected_policy,
        },
        "trainingHistory": history,
        "validArchivedCandidates": valid_archive + [selected_archive],
        "holdout": {
            "baselineOriginalVsOriginal": holdout_baseline,
            "baselineOriginalVsSelectedCounter": holdout_counter,
        },
        "source": {
            "before": source_before,
            "after": source_after,
            "sourceChangedDuringRun": source_before != source_after,
        },
        "throughput": {
            "elapsedSeconds": time.perf_counter() - started,
            "workers": WORKERS,
            "confounded": True,
            "note": "Do not use this concurrent pilot for throughput benchmarking; another run used three workers on the same host.",
        },
        "claimLimits": [
            "Selection used training seed 451139 only; holdout seeds 808381 and 919393 were read after selection.",
            "All matches are Forge versus Forge with hostiles off; no faction-generalization or hostile robustness claim.",
            "Invalid/censored/error matches are ineligible for fitness and remain in the error ledger.",
            "No live AI, gameplay rules, or tools/civcraft_lab files were changed.",
            "A holdout result is not a good result claim without larger replication and comparable opponents.",
        ],
    }
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"summary": str(args.summary), "selected": selected_policy, "holdoutBaselineA": holdout_counter["aFitness"], "holdoutSelectedB": holdout_counter["bFitness"]}))


if __name__ == "__main__":
    main()
