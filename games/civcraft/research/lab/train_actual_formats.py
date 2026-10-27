#!/usr/bin/env python3
"""Fit/export compact formats on actual source-ranked teacher traces."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import policy_format_comparison as pf
from policy_format_comparison import (FORMATS, RESULTS, FEATURES,
                                      RuleTreePolicy, TinyQuantizedMLP, WeightsPolicy,
                                      benchmark_isolated, export_lua, fixture_score)

HERE = Path(__file__).resolve().parent


def load_actual(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("schema_version") != "observer-ranked-decision-v1":
            raise ValueError("not an actual observer-ranked trace")
        if tuple(row.get("feature_names", [])) != FEATURES:
            raise ValueError("feature schema mismatch")
        if row["teacher_action"] not in row["legal_actions"]:
            raise ValueError("illegal teacher label")
        if not row.get("candidate_scores"):
            raise ValueError("actual trace is missing candidate scores")
        rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=HERE / "datasets/teacher_traces_actual.jsonl")
    parser.add_argument("--out", type=Path, default=HERE / "results/actual_policy_format_comparison.json")
    args = parser.parse_args()
    all_rows = load_actual(args.dataset)
    train = [r for r in all_rows if r.get("split") == "train"]
    holdout = [r for r in all_rows if r.get("split") == "holdout"]
    if not train or not holdout:
        raise ValueError("complete-game train/holdout split required")
    # Actual source ranking exposes the complete current content set, not the
    # ten-action fixture vocabulary. Freeze this vocabulary from train only so
    # holdout cannot introduce labels unseen during fitting.
    train_actions = sorted({a for r in train for a in r["legal_actions"]})
    pf.ACTION_LABELS = tuple(train_actions)
    unknown_holdout = sorted({r["teacher_action"] for r in holdout} - set(train_actions))
    if unknown_holdout:
        raise ValueError("holdout contains unseen action labels: " + ", ".join(unknown_holdout))
    policies = {"weights": WeightsPolicy.fit(train), "rule_tree": RuleTreePolicy.fit(train),
                "tiny_quantized_mlp": TinyQuantizedMLP.fit(train)}
    formats = {}
    for name, policy in policies.items():
        target = FORMATS / ("actual_" + name + ".lua")
        bytes_written = export_lua(policy, target)
        formats[name] = {"path": str(target.relative_to(HERE)), "bytes": bytes_written,
                         "train": fixture_score(policy, train),
                         "holdout": fixture_score(policy, holdout)}
    # Small Lua-side replay set for native prediction parity. It uses actual
    # held-out observer vectors, legal candidate labels and source-ranked
    # candidate scores, never hidden state.
    def lua(value):
        if isinstance(value, dict):
            return "{" + ",".join("[" + json.dumps(str(k)) + "]=" + lua(v) for k, v in value.items()) + "}"
        if isinstance(value, list):
            return "{" + ",".join(lua(v) for v in value) + "}"
        if isinstance(value, str):
            return json.dumps(value)
        if isinstance(value, bool):
            return "true" if value else "false"
        if value is None:
            return "nil"
        return repr(float(value)) if isinstance(value, float) else str(value)
    native_rows = []
    for row in holdout:
        expected = {name: policy.predict(row["features"], row["legal_actions"], row["candidate_scores"])[0]
                    for name, policy in policies.items()}
        native_rows.append({"features": row["features"], "actions": row["legal_actions"],
                            "candidates": row["candidate_scores"], "expected": expected})
    native_path = HERE / "datasets/actual_holdout_vectors.lua"
    native_path.write_text("return " + lua(native_rows) + "\n", encoding="utf-8")
    result = {
        "status": "actual_teacher_trace_training",
        "dataset": {"path": str(args.dataset), "sha256": hashlib.sha256(args.dataset.read_bytes()).hexdigest(),
                    "records": len(all_rows), "train_records": len(train), "holdout_records": len(holdout),
                    "action_vocabulary": train_actions,
                    "train_games": sorted({r["game_id"] for r in train}),
                    "holdout_games": sorted({r["game_id"] for r in holdout})},
        "formats": formats,
        "isolated_python_benchmark": benchmark_isolated(policies, holdout),
        "claim_limits": ["Teacher agreement is decision-trace retention, not full-game outcome retention.",
                         "Candidate scores are preserved in the source trace; this first compact fit uses the fixed observer vector.",
                         "Native and full-game comparisons are separate pending runs.",
                         "Native replay vectors are held-out observer projections, not synthetic fixture rows."],
        "native_holdout_vectors": {"path": str(native_path.relative_to(HERE)), "records": len(native_rows),
                                   "sha256": hashlib.sha256(native_path.read_bytes()).hexdigest()},
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
