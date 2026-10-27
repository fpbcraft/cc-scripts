#!/usr/bin/env python3
"""Source-frozen supervised outcome-model study.

This driver is prepared for a later launch signal.  It uses the actual
``tools/civcraft_lab.runner`` through bounded spawned workers and never feeds
the privileged critic back into the playing policy.  ``--prepare-manifest`` is
the only mode intended to run during study preparation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import random
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
MANIFEST_PATH = HERE / "outcome_model_manifest.json"
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
from runner import source_manifest  # noqa: E402
import workers  # noqa: E402


ROUNDS = (31, 61, 91)
FEATURES = (
    "population", "industry", "science", "technologies", "combatPower",
    "unitCount", "buildings", "gold", "score",
)
L2 = 0.1
ITERATIONS = 1000
LEARNING_RATE = 0.1
TEMPERATURE_GRID = tuple(math.exp(-4 + 8 * index / 800) for index in range(801))
BOOTSTRAP_REPLICATES = 2000
BOOTSTRAP_SEED = 20261027

TRAIN_SEEDS = (120311, 120317, 120323, 120331, 120337, 120347,
               120349, 120367, 120377, 120391, 120397, 120401)
CALIBRATION_SEEDS = (220411, 220423, 220427, 220429, 220441, 220447)
TEST_SEEDS = (320461, 320471, 320477, 320489, 320491, 320503)

SELECTED_SOURCE = RESULTS / "strategy_search_pilot.json"
ADAPTED_SOURCE = RESULTS / "adversarial_archive_adaptation_pilot.json"
SELECTED_POLICY = json.loads(SELECTED_SOURCE.read_text())["championHoldout"]["policy"]
ADAPTED_POLICY = json.loads(ADAPTED_SOURCE.read_text())["selection"]["selectedPolicy"]
INDUSTRIAL_POLICY = {"version": 1, "goal": "industrial"}
POLICIES = {
    "selected-expedition": SELECTED_POLICY,
    "adapted-expedition": ADAPTED_POLICY,
    "industrial": INDUSTRIAL_POLICY,
}
MATCHUPS = (
    ("selected-expedition", "industrial"),
    ("selected-expedition", "adapted-expedition"),
)


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def payload_sha(payload: Any) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def policy_manifest() -> dict:
    return {
        "selected-expedition": {
            "policy": SELECTED_POLICY,
            "source": str(SELECTED_SOURCE.relative_to(ROOT)),
            "sourceSha256": file_sha(SELECTED_SOURCE),
        },
        "adapted-expedition": {
            "policy": ADAPTED_POLICY,
            "source": str(ADAPTED_SOURCE.relative_to(ROOT)),
            "sourceSha256": file_sha(ADAPTED_SOURCE),
        },
        "industrial": {
            "policy": INDUSTRIAL_POLICY,
            "source": "pre-registered literal policy in outcome_model_study.py",
            "sourceSha256": payload_sha(INDUSTRIAL_POLICY),
        },
    }


def split_manifest() -> dict:
    return {
        "train": list(TRAIN_SEEDS),
        "calibration": list(CALIBRATION_SEEDS),
        "test": list(TEST_SEEDS),
    }


def study_configuration() -> dict:
    return {
        "mapSize": "compact",
        "mapType": "pangaea",
        "hostileMode": "off",
        "maxRounds": 180,
        "telemetryEvery": 1,
        "wallSeconds": 180,
        "civilizations": ["forge", "forge"],
        "matchups": [list(matchup) for matchup in MATCHUPS],
        "seatRotation": [0, 1],
        "snapshots": list(ROUNDS),
    }


def prepare_manifest() -> dict:
    manifest = {
        "schemaVersion": 1,
        "status": "prepared-not-run",
        "createdAt": "2026-10-27",
        "purpose": "Privileged supervised win-probability diagnostic from actual games",
        "split": split_manifest(),
        "configuration": study_configuration(),
        "policies": policy_manifest(),
        "modelProtocol": {
            "features": list(FEATURES),
            "featureTransform": "signed log1p player0-player1 differences",
            "fit": "stdlib L2 logistic regression, no intercept, fixed hyperparameters",
            "l2": L2,
            "iterations": ITERATIONS,
            "learningRate": LEARNING_RATE,
            "temperatureGrid": {"logMin": -4, "logMax": 4, "steps": 801},
            "bootstrapReplicates": BOOTSTRAP_REPLICATES,
            "bootstrapSeed": BOOTSTRAP_SEED,
            "clusterUnit": "test map seed; exactly six test blocks",
        },
        "sourceManifestBeforeRun": source_manifest(),
        "scriptSha256BeforeRun": file_sha(Path(__file__)),
        "inputSourceSha256": {
            "selectedPolicySource": file_sha(SELECTED_SOURCE),
            "adaptedPolicySource": file_sha(ADAPTED_SOURCE),
        },
        "limits": [
            "All games are Forge versus Forge on compact Pangaea with hostile mode off.",
            "There are 24 disjoint map seeds: 12 train, 6 calibration, 6 final test.",
            "Each seed has two matchups and two seat rotations, yielding 4 games per block and 96 games total.",
            "Features are privileged critic inputs and are never supplied to a playing policy.",
            "Rows remain ordered by map block, matchup, seat and snapshot; no row shuffle is permitted.",
        ],
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest


def config_for(seed: int, first: str, second: str, seat: int) -> dict:
    records = [
        {"civilization": "forge", "policy": POLICIES[first], "policyId": first},
        {"civilization": "forge", "policy": POLICIES[second], "policyId": second},
    ]
    if seat == 1:
        records.reverse()
    config = study_configuration()
    config.update({
        "seed": seed,
        "players": records,
        "matchup": f"{first}-vs-{second}",
        "seatRotation": seat,
    })
    return config


def split_configs(split: str) -> list[dict]:
    seeds = split_manifest()[split]
    configs = []
    for seed in seeds:
        for first, second in MATCHUPS:
            for seat in (0, 1):
                configs.append(config_for(seed, first, second, seat))
    return configs


def feature_vector(players: list[dict]) -> list[float]:
    if len(players) != 2:
        raise ValueError("Outcome model requires exactly two players")
    return [
        math.log1p(max(0, players[0].get(key, 0)))
        - math.log1p(max(0, players[1].get(key, 0)))
        for key in FEATURES
    ]


def winner_credit(match: dict, player_id: int) -> float:
    winners = match.get("winnerIds") or []
    return (1 / len(winners) if player_id in winners else 0.0) if winners else 0.5


def rows_from_matches(matches: list[dict], split: str) -> list[dict]:
    rows = []
    for match_index, match in enumerate(matches):
        if match.get("status") != "finished":
            raise ValueError(f"{split} contains non-finished match {match_index}: {match.get('status')}")
        for round_number in ROUNDS:
            turn = next((row for row in match.get("turns", []) if row.get("round") == round_number), None)
            if not turn or turn.get("phase") != "game":
                raise ValueError(f"{split} missing pre-outcome snapshot {round_number} for match {match_index}")
            rows.append({
                "split": split,
                "match": match_index,
                "seed": match["config"]["seed"],
                "matchup": match["config"]["matchup"],
                "seatRotation": match["config"]["seatRotation"],
                "round": round_number,
                "x": feature_vector(turn["players"]),
                "y": winner_credit(match, 0),
                "weight": 0.0,
            })
    rows_per_seed: dict[int, int] = {}
    for row in rows:
        rows_per_seed[row["seed"]] = rows_per_seed.get(row["seed"], 0) + 1
    for row in rows:
        row["weight"] = 1 / rows_per_seed[row["seed"]]
    return rows


def sigmoid(value: float) -> float:
    return 1 / (1 + math.exp(-max(-40, min(40, value))))


def logits(rows: list[dict], weights: list[float]) -> list[float]:
    return [sum(weight * value for weight, value in zip(weights, row["x"], strict=True)) for row in rows]


def fit_logistic(rows: list[dict]) -> list[float]:
    weights = [0.0] * len(FEATURES)
    total_weight = sum(row["weight"] for row in rows)
    for _ in range(ITERATIONS):
        gradient = [L2 * weight for weight in weights]
        for row in rows:
            prediction = sigmoid(sum(weight * value for weight, value in zip(weights, row["x"], strict=True)))
            scale = row["weight"] / total_weight
            for index, value in enumerate(row["x"]):
                gradient[index] += (prediction - row["y"]) * value * scale
        weights = [weight - LEARNING_RATE * value for weight, value in zip(weights, gradient, strict=True)]
    return weights


def metrics(rows: list[dict], predictions: list[float]) -> dict:
    if not rows:
        return {"rows": 0, "brier": None, "logLoss": None, "accuracy": None, "reliability": []}
    brier = sum((prediction - row["y"]) ** 2 for prediction, row in zip(predictions, rows, strict=True)) / len(rows)
    log_loss = -sum(
        row["y"] * math.log(max(1e-12, prediction))
        + (1 - row["y"]) * math.log(max(1e-12, 1 - prediction))
        for prediction, row in zip(predictions, rows, strict=True)
    ) / len(rows)
    reliability = []
    for low, high in ((0, 0.25), (0.25, 0.5), (0.5, 0.75), (0.75, 1.000001)):
        selected = [index for index, prediction in enumerate(predictions) if low <= prediction < high]
        if selected:
            reliability.append({
                "range": [low, min(1, high)],
                "count": len(selected),
                "meanPrediction": sum(predictions[index] for index in selected) / len(selected),
                "observedWinCredit": sum(rows[index]["y"] for index in selected) / len(selected),
            })
    return {
        "rows": len(rows),
        "brier": brier,
        "logLoss": log_loss,
        "accuracy": sum((prediction >= 0.5) == (row["y"] >= 0.5)
                         for prediction, row in zip(predictions, rows, strict=True)) / len(rows),
        "reliability": reliability,
    }


def temperature_fit(rows: list[dict], weights: list[float]) -> float:
    raw_logits = logits(rows, weights)
    best_temperature, best_loss = None, float("inf")
    for temperature in TEMPERATURE_GRID:
        predictions = [sigmoid(logit / temperature) for logit in raw_logits]
        loss = metrics(rows, predictions)["logLoss"]
        if loss < best_loss or (loss == best_loss and (best_temperature is None or temperature < best_temperature)):
            best_temperature, best_loss = temperature, loss
    assert best_temperature is not None
    return best_temperature


def evaluate_models(train: list[dict], calibration: list[dict], test: list[dict]) -> dict:
    weights = fit_logistic(train)
    temperature = temperature_fit(calibration, weights)
    prior = sum(row["y"] * row["weight"] for row in train) / sum(row["weight"] for row in train)
    raw_test_logits = logits(test, weights)
    uncalibrated = [sigmoid(value) for value in raw_test_logits]
    calibrated = [sigmoid(value / temperature) for value in raw_test_logits]
    constant = [prior] * len(test)
    return {
        "weights": weights,
        "prior": prior,
        "temperature": temperature,
        "test": {
            "constantPrior": metrics(test, constant),
            "uncalibrated": metrics(test, uncalibrated),
            "calibrated": metrics(test, calibrated),
        },
    }


def bootstrap_ci(rows: list[dict], weights: list[float], temperature: float, prior: float) -> dict:
    grouped: dict[int, list[dict]] = {}
    for row in rows:
        grouped.setdefault(row["seed"], []).append(row)
    seeds = sorted(grouped)
    rng = random.Random(BOOTSTRAP_SEED)
    values = {name: {metric: [] for metric in ("brier", "logLoss")}
              for name in ("constantPrior", "uncalibrated", "calibrated")}
    for _ in range(BOOTSTRAP_REPLICATES):
        sampled = [row for seed in (rng.choice(seeds) for _ in seeds) for row in grouped[seed]]
        logits_sample = logits(sampled, weights)
        predictions = {
            "constantPrior": [prior] * len(sampled),
            "uncalibrated": [sigmoid(value) for value in logits_sample],
            "calibrated": [sigmoid(value / temperature) for value in logits_sample],
        }
        for name, values_for_model in predictions.items():
            record = metrics(sampled, values_for_model)
            for metric in ("brier", "logLoss"):
                values[name][metric].append(record[metric])
    intervals = {}
    for name, metric_values in values.items():
        intervals[name] = {}
        for metric, samples in metric_values.items():
            samples.sort()
            intervals[name][metric] = {
                "mean": sum(samples) / len(samples),
                "ci95": [samples[int(0.025 * len(samples))], samples[int(0.975 * len(samples)) - 1]],
                "clusters": len(seeds),
                "replicates": BOOTSTRAP_REPLICATES,
            }
    return {"testSeeds": seeds, "intervals": intervals}


def write_batch(path: Path, split: str, configs: list[dict], matches: list[dict], source: dict) -> None:
    payload = {
        "schemaVersion": 1,
        "split": split,
        "sourceManifestBeforeRun": source,
        "configuration": study_configuration(),
        "configs": configs,
        "matches": matches,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def run_study(args: argparse.Namespace) -> None:
    if not MANIFEST_PATH.exists():
        raise SystemExit("Prepare the frozen manifest first with --prepare-manifest")
    frozen = json.loads(MANIFEST_PATH.read_text())
    source_before = source_manifest()
    if source_before != frozen["sourceManifestBeforeRun"]:
        raise SystemExit("Source changed after manifest preparation; refusing to launch")
    raw_dir = args.raw_dir
    raw_dir.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    batches = {}
    for split in ("train", "calibration", "test"):
        path = raw_dir / f"{split}.json"
        configs = split_configs(split)
        if args.resume and path.exists():
            payload = json.loads(path.read_text())
            if payload.get("sourceManifestBeforeRun") != source_before:
                raise SystemExit(f"Refusing stale resume file: {path}")
            matches = payload["matches"]
        else:
            matches = workers.run_bounded(configs, args.workers)
            write_batch(path, split, configs, matches, source_before)
        batches[split] = {"configs": configs, "matches": matches, "rawArtifact": str(path)}
    source_after = source_manifest()
    rows = {split: rows_from_matches(batch["matches"], split) for split, batch in batches.items()}
    fit = evaluate_models(rows["train"], rows["calibration"], rows["test"])
    bootstrap = bootstrap_ci(rows["test"], fit["weights"], fit["temperature"], fit["prior"])
    result = {
        "schemaVersion": 1,
        "purpose": frozen["purpose"],
        "sourceManifestBeforeRun": source_before,
        "sourceManifestAfterRun": source_after,
        "sourceChangedDuringRun": source_before != source_after,
        "scriptSha256BeforeRun": frozen["scriptSha256BeforeRun"],
        "scriptSha256AfterRun": file_sha(Path(__file__)),
        "inputSourceSha256": frozen["inputSourceSha256"],
        "configuration": frozen["configuration"],
        "split": frozen["split"],
        "policies": frozen["policies"],
        "model": {
            "features": list(FEATURES), "l2": L2, "iterations": ITERATIONS,
            "learningRate": LEARNING_RATE, "weights": fit["weights"],
            "temperature": fit["temperature"], "prior": fit["prior"],
            "weighting": "each snapshot row weighted by inverse row count of its map seed; no row shuffle",
        },
        "testMetrics": fit["test"],
        "clusterBootstrap": bootstrap,
        "batches": {split: {"rawArtifact": batch["rawArtifact"], "games": len(batch["matches"])}
                    for split, batch in batches.items()},
        "elapsedSeconds": time.perf_counter() - started,
        "limits": frozen["limits"] + [
            "The calibration temperature is selected only on six calibration map blocks; no test row informs it.",
            "Bootstrap resamples exactly six test map seeds as clusters, never individual snapshot rows.",
            "The critic is privileged and associative; this is not a gameplay policy or causal intervention model.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if result["sourceChangedDuringRun"]:
        raise SystemExit("Source changed during outcome study; inspect separate batch artifacts")
    print(json.dumps({"output": str(args.output), "rawDir": str(raw_dir),
                      "elapsedSeconds": result["elapsedSeconds"], "sourceChangedDuringRun": False}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare-manifest", action="store_true")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--raw-dir", type=Path, default=Path("/tmp/civcraft-outcome-model"))
    parser.add_argument("--output", type=Path, default=RESULTS / "outcome_model_study.json")
    args = parser.parse_args()
    if args.prepare_manifest == args.run:
        raise SystemExit("Choose exactly one of --prepare-manifest or --run")
    if args.prepare_manifest:
        manifest = prepare_manifest()
        print(json.dumps({"manifest": str(MANIFEST_PATH), "status": manifest["status"],
                          "sourceHead": manifest["sourceManifestBeforeRun"]["head"]}))
        return
    if args.workers <= 0:
        raise SystemExit("--workers must be positive")
    run_study(args)


if __name__ == "__main__":
    main()
