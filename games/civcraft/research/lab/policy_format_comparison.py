#!/usr/bin/env python3
"""Offline, observer-safe policy-format comparison for CivCraft.

This module deliberately does not import the game runtime or launch a match.
It prepares decision labels, fits three compact formats on a small fixture, and
provides exporters/benchmarks for a later native CraftOS run.  The fixture is a
contract test, not evidence of full-game strength.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import time
import tracemalloc
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence


ROOT = Path(__file__).resolve().parent
DATASET = ROOT / "datasets" / "policy_format_fixture.jsonl"
FORMATS = ROOT / "formats"
RESULTS = ROOT / "results"

SCHEMA_VERSION = "observer-strategic-v1"
FEATURES = (
    "round_fraction", "age_fraction", "cities", "population", "industry",
    "science", "gold", "treasury_net", "technologies", "buildings",
    "unit_count", "combat_power", "idle_cities", "research_progress",
    "legal_action_count",
)

# Every feature is computed from Presentation.capture/World.forPlayer, or from
# the legal-action list already supplied to the controller.  No rival totals,
# hidden map state, metrics.lua, or authoritative state are accepted.
FEATURE_SOURCES = {
    "round_fraction": "view.round / view.roundLimit",
    "age_fraction": "own_player.age / 6 (bounded)",
    "cities": "count(view.cities where owner == observerID)",
    "population": "sum(own city.population)",
    "industry": "own_player.wood (public own resource; zero if absent)",
    "science": "own_player.scienceRate",
    "gold": "own_player.gold",
    "treasury_net": "observer-safe own treasury if supplied by adapter",
    "technologies": "count(own_player.technologies/researched)",
    "buildings": "count own city building entries",
    "unit_count": "count(view.units where owner == observerID)",
    "combat_power": "sum publicAttack for own units",
    "idle_cities": "count(own cities where productionIdle)",
    "research_progress": "mean own researchProgress fraction when supplied",
    "legal_action_count": "len(legal_actions)",
}

PRIVILEGED_KEYS = {
    "metrics", "state", "world_state", "all_players", "opponent_totals",
    "authoritative", "debug", "diagnostics", "hidden_map", "raw_state",
}

ACTION_LABELS = (
    "research:agriculture", "research:mining", "research:sailing",
    "research:writing", "production:settler", "production:warrior",
    "production:library", "production:mine", "production:station",
    "production:bank",
)

TEACHER_ARCHIVE = [
    {
        "id": "selected-archived-expedition",
        "artifact": "selected_policy.lua",
        "source": "results/strategy_search_pilot.json",
        "goal": "expedition",
        "kind": "archived_policy",
        "source_hash": "9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f",
    },
    {
        "id": "adapted-expedition-b4f3d28b1297",
        "artifact": "results/adversarial_archive_adaptation_pilot.json",
        "goal": "expedition",
        "kind": "archived_policy",
        "source_hash": "9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f",
    },
    {
        "id": "archived-industrial",
        "artifact": "results/strategy_search_pilot.json:baseline",
        "goal": "industrial",
        "kind": "archived_policy",
        "source_hash": "9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f",
    },
    {
        "id": "archived-conquest",
        "artifact": "results/strategy_search_pilot.json:conquest-candidate",
        "goal": "conquest",
        "kind": "archived_policy",
        "source_hash": "9b12a1a22939d9e06834dff3743756f7b864eb3e12f40aaa109917ab1f0af38f",
    },
]


def _num(value: Any, default: float = 0.0) -> float:
    try:
        result = float(value)
        return result if math.isfinite(result) else default
    except (TypeError, ValueError):
        return default


def _own_player(view: dict[str, Any], player_id: Any | None) -> dict[str, Any]:
    observer = player_id if player_id is not None else view.get("observerID")
    for player in view.get("players", []) or []:
        if player.get("id") == observer:
            return player
    # A direct own-player projection is accepted by adapters that do not expose
    # the players array, but never infer an arbitrary player from the list.
    own = view.get("player") or view.get("self")
    return own if isinstance(own, dict) else {}


def _fraction(value: Any, denominator: Any, default: float = 0.0) -> float:
    d = _num(denominator)
    return max(0.0, min(1.0, _num(value) / d)) if d > 0 else default


def validate_observer_view(view: dict[str, Any]) -> None:
    """Reject known privileged envelopes before a feature extractor sees them."""
    if not isinstance(view, dict):
        raise ValueError("observer view must be a mapping")
    bad = PRIVILEGED_KEYS.intersection(view)
    if bad:
        raise ValueError("privileged fields supplied to policy: " + ", ".join(sorted(bad)))


def extract_observer_features(
    view: dict[str, Any], legal_actions: Sequence[str], player_id: Any | None = None
) -> tuple[list[float], list[str]]:
    """Extract a fixed normalized vector and report absent optional fields.

    Missing fields are explicit rather than guessed from rivals.  This makes
    replay labels reproducible across old saves and future presentation schema.
    """
    validate_observer_view(view)
    observer = player_id if player_id is not None else view.get("observerID")
    own = _own_player(view, observer)
    cities = [c for c in view.get("cities", []) or [] if c.get("owner") == observer]
    units = [u for u in view.get("units", []) or [] if u.get("owner") == observer]
    missing: list[str] = []

    def field(name: str, *aliases: str) -> Any:
        for key in (name, *aliases):
            if key in own:
                return own[key]
        missing.append(name)
        return 0

    round_value = _num(view.get("round"))
    round_limit = _num(view.get("roundLimit"), 180)
    age = _num(field("age"))
    population = sum(_num(c.get("population")) for c in cities)
    buildings = sum(len(c.get("buildings", {}) or {}) for c in cities)
    combat = sum(_num(u.get("publicAttack", u.get("attack"))) for u in units)
    idle = sum(1 for c in cities if c.get("productionIdle") or c.get("idle"))
    progress = field("researchProgress", "technologiesProgress")
    if isinstance(progress, dict):
        vals = [_num(v) for v in progress.values()]
        progress_value = sum(vals) / max(1, len(vals)) / 100.0 if vals else 0.0
    else:
        progress_value = _num(progress)
        if progress_value > 1:
            progress_value /= 100.0
    techs = field("technologies", "researched", "techs")
    tech_count = len(techs) if isinstance(techs, (list, dict, set, tuple)) else _num(techs)
    vector = [
        max(0.0, min(1.0, round_value / max(1.0, round_limit))),
        max(0.0, min(1.0, age / 6.0)),
        min(1.0, len(cities) / 8.0),
        min(1.0, population / 32.0),
        min(1.0, _num(field("wood", "industry")) / 40.0),
        min(1.0, _num(field("scienceRate", "science")) / 40.0),
        max(0.0, min(1.0, _num(field("gold")) / 200.0)),
        max(0.0, min(1.0, _num(field("treasuryNet", "netGold")) / 20.0 + 0.5)),
        min(1.0, tech_count / 30.0),
        min(1.0, buildings / 24.0),
        min(1.0, len(units) / 24.0),
        min(1.0, combat / 160.0),
        min(1.0, idle / 8.0),
        max(0.0, min(1.0, progress_value)),
        min(1.0, len(legal_actions) / 16.0),
    ]
    return vector, sorted(set(missing))


def _fixture_view(index: int) -> tuple[dict[str, Any], list[str], str]:
    phase = index % 4
    goal = ("expedition", "industrial", "conquest", "diplomatic")[index % 4]
    round_value = (index * 17) % 170 + 1
    cities = 1 + (index % 5)
    city_rows = [{"owner": 1, "population": 2 + ((index + j) % 5),
                  "buildings": {"walls": j % 2 == 0},
                  "productionIdle": (index + j) % 3 == 0} for j in range(cities)]
    units = [{"owner": 1, "publicAttack": 8 + ((index * 3 + j) % 15)}
             for j in range((index * 2) % 7)]
    legal = list(ACTION_LABELS)
    if phase == 0:
        legal = [a for a in legal if not a.endswith(":bank")]
    elif phase == 1:
        legal = [a for a in legal if not a.endswith(":settler")]
    elif phase == 2:
        legal = [a for a in legal if not a.endswith(":library")]
    else:
        legal = [a for a in legal if not a.endswith(":warrior")]
    player = {
        "id": 1, "age": min(6, 1 + index // 12), "wood": 4 + (index * 7) % 35,
        "scienceRate": 3 + (index * 5) % 32, "gold": (index * 31) % 210,
        "treasuryNet": -6 + (index * 4) % 25,
        "technologies": ["t%d" % n for n in range(index % 12)],
        "researchProgress": {"t%d" % (index % 6): (index * 13) % 100},
    }
    view = {"observerID": 1, "round": round_value, "roundLimit": 180,
            "players": [player], "cities": city_rows, "units": units}
    # This label is a varying ranked choice, intentionally not a constant
    # replay of one action. It stands in for the later teacher trace importer.
    if goal == "expedition":
        action = ("research:sailing", "research:writing", "production:library")[index % 3]
    elif goal == "industrial":
        action = ("production:mine", "production:station", "production:bank")[index % 3]
    elif goal == "conquest":
        action = ("production:warrior", "production:settler", "research:mining")[index % 3]
    else:
        action = ("research:agriculture", "research:writing", "production:station")[index % 3]
    if action not in legal:
        action = legal[index % len(legal)]
    teacher = ("selected-archived-expedition", "archived-industrial",
               "archived-conquest", "adapted-expedition-b4f3d28b1297")[index % 4]
    return view, legal, action + "|" + teacher + "|" + goal


def make_fixture(path: Path = DATASET, count: int = 64) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []
    for index in range(count):
        view, legal, label = _fixture_view(index)
        action, teacher, goal = label.split("|")
        features, missing = extract_observer_features(view, legal)
        rows.append({"schema_version": SCHEMA_VERSION, "sample_id": index,
                     "feature_names": list(FEATURES), "features": features,
                     "legal_actions": legal, "teacher_action": action,
                     "teacher_policy_id": teacher, "intended_goal": goal,
                     "missing_optional_fields": missing,
                     "source_kind": "fixture_observer_projection",
                     "teacher_label_source": "ranked-research-label-fixture"})
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["teacher_action"]] = counts.get(row["teacher_action"], 0) + 1
    return {"records": len(rows), "actions": counts,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "source_kind": "fixture_observer_projection"}


def load_records(path: Path = DATASET) -> list[dict[str, Any]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    for row in rows:
        if row.get("schema_version") != SCHEMA_VERSION:
            raise ValueError("unsupported record schema")
        if tuple(row.get("feature_names", [])) != FEATURES:
            raise ValueError("feature order/checksum mismatch")
        if set(row.get("teacher_action", "")) and row["teacher_action"] not in ACTION_LABELS:
            raise ValueError("unknown action label")
        if not set(row.get("legal_actions", [])).issuperset({row["teacher_action"]}):
            raise ValueError("teacher label is not legal")
    return rows


def load_teacher_decision_records(path: Path) -> list[dict[str, Any]]:
    """Import real archived decision labels without accepting privileged data.

    Input is JSONL with ``observation``, ``legal_actions``, ``teacher_action``
    and ``teacher_policy_id``.  The observation is projected immediately and
    only the fixed vector is retained in the training record.
    """
    result = []
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines()):
        if not line.strip():
            continue
        raw = json.loads(line)
        observation = raw.get("observation")
        legal = raw.get("legal_actions")
        action = raw.get("teacher_action")
        if not isinstance(observation, dict) or not isinstance(legal, list) or action not in ACTION_LABELS:
            raise ValueError(f"invalid teacher decision record at line {index + 1}")
        if action not in legal:
            raise ValueError(f"teacher action is illegal at line {index + 1}")
        features, missing = extract_observer_features(observation, legal)
        result.append({"schema_version": SCHEMA_VERSION, "sample_id": raw.get("sample_id", index),
                       "feature_names": list(FEATURES), "features": features,
                       "legal_actions": legal, "teacher_action": action,
                       "teacher_policy_id": str(raw.get("teacher_policy_id", "unknown")),
                       "missing_optional_fields": missing,
                       "source_kind": "archived_decision_trace",
                       "teacher_label_source": "archived_observer_trace"})
    if not result:
        raise ValueError("teacher decision file contained no records")
    return result


def _one_hot(rows: list[dict[str, Any]]) -> dict[str, int]:
    return {action: i for i, action in enumerate(ACTION_LABELS)}


def legal_fallback(predicted: str, legal_actions: Sequence[str], candidates: Sequence[dict] | None = None) -> tuple[str, bool]:
    legal = sorted(set(str(a) for a in legal_actions if a in ACTION_LABELS))
    if not legal:
        return "noop", predicted != "noop"
    if predicted in legal:
        return predicted, False
    if candidates:
        ranked = sorted((c for c in candidates if c.get("label") in legal),
                        key=lambda c: (-float(c.get("score", 0)), str(c.get("label"))))
        if ranked:
            return str(ranked[0]["label"]), True
    return legal[0], True


def _masked_index(scores: Sequence[float], legal: Sequence[str]) -> int | None:
    allowed = {a for a in legal if a in ACTION_LABELS}
    if not allowed:
        return None
    return max((i for i, action in enumerate(ACTION_LABELS) if action in allowed),
               key=lambda i: (scores[i], -i))


def _candidate_scores(candidates: Sequence[dict] | None, weight: float) -> dict[str, float]:
    if not candidates or not weight:
        return {}
    scale = max(1.0, max(abs(float(c.get("score", 0))) for c in candidates))
    return {str(c["label"]): weight * float(c.get("score", 0)) / scale for c in candidates}


class WeightsPolicy:
    format_name = "weights"

    def __init__(self, weights: list[list[float]], bias: list[float], candidate_weight: float = 0.0):
        self.weights, self.bias, self.candidate_weight = weights, bias, candidate_weight

    @classmethod
    def fit(cls, rows: list[dict[str, Any]], epochs: int = 18) -> "WeightsPolicy":
        m, n = len(ACTION_LABELS), len(FEATURES)
        w, b = [[0.0] * n for _ in range(m)], [0.0] * m
        labels = _one_hot(rows)
        for epoch in range(epochs):
            for row in rows:
                x, target = row["features"], labels[row["teacher_action"]]
                scores = [sum(a * z for a, z in zip(w[i], x)) + b[i] for i in range(m)]
                pred = max(range(m), key=lambda i: (scores[i], -i))
                if pred != target:
                    rate = 0.18 / (1.0 + epoch * 0.10)
                    for j, value in enumerate(x):
                        w[target][j] += rate * value
                        w[pred][j] -= rate * value
                    b[target] += rate
                    b[pred] -= rate
        return cls(w, b, 0.5)

    def raw(self, x: Sequence[float]) -> list[float]:
        return [sum(a * z for a, z in zip(row, x)) + bias for row, bias in zip(self.weights, self.bias)]

    def predict(self, x: Sequence[float], legal: Sequence[str], candidates: Sequence[dict] | None = None) -> tuple[str, bool]:
        scores = self.raw(x)
        bonus = _candidate_scores(candidates, self.candidate_weight)
        scores = [score + bonus.get(action, 0.0) for score, action in zip(scores, ACTION_LABELS)]
        index = _masked_index(scores, legal)
        predicted = ACTION_LABELS[index] if index is not None else "noop"
        return legal_fallback(predicted, legal, candidates)

    def payload(self) -> dict[str, Any]:
        return {"format": self.format_name, "schema_version": SCHEMA_VERSION,
                "features": list(FEATURES), "actions": list(ACTION_LABELS),
                "weights": self.weights, "bias": self.bias,
                "candidate_weight": self.candidate_weight}


class RuleTreePolicy:
    format_name = "rule_tree"

    def __init__(self, tree: dict[str, Any], default: str):
        self.tree, self.default = tree, default

    @classmethod
    def fit(cls, rows: list[dict[str, Any]], depth: int = 2) -> "RuleTreePolicy":
        def build(subset: list[dict[str, Any]], remaining: int, used: set[int]) -> dict[str, Any]:
            counts = {a: sum(r["teacher_action"] == a for r in subset) for a in ACTION_LABELS}
            majority = max(ACTION_LABELS, key=lambda a: (counts[a], -ACTION_LABELS.index(a)))
            if remaining == 0 or len({r["teacher_action"] for r in subset}) <= 1 or len(subset) < 4:
                return {"leaf": majority}
            parent_impurity = 1.0 - sum((v / len(subset)) ** 2 for v in counts.values())
            best: tuple[float, int, float] | None = None
            for feature in range(len(FEATURES)):
                if feature in used:
                    continue
                values = sorted({float(r["features"][feature]) for r in subset})
                for threshold in values[:-1]:
                    left = [r for r in subset if r["features"][feature] <= threshold]
                    right = [r for r in subset if r["features"][feature] > threshold]
                    if not left or not right:
                        continue
                    def gini(part: list[dict[str, Any]]) -> float:
                        c = sum(part.count(r) for r in [])  # deterministic no-op; avoids hidden state
                        del c
                        tally = {a: sum(r["teacher_action"] == a for r in part) for a in ACTION_LABELS}
                        return 1.0 - sum((v / len(part)) ** 2 for v in tally.values())
                    gain = parent_impurity - len(left) / len(subset) * gini(left) - len(right) / len(subset) * gini(right)
                    candidate = (gain, -feature, -threshold)
                    if best is None or candidate > best:
                        best = candidate
                        best_feature, best_threshold, best_left, best_right = feature, threshold, left, right
            if best is None or best[0] <= 1e-9:
                return {"leaf": majority}
            return {"feature": best_feature, "threshold": best_threshold,
                    "left": build(best_left, remaining - 1, used | {best_feature}),
                    "right": build(best_right, remaining - 1, used | {best_feature})}
        return cls(build(rows, depth, set()), max(set(r["teacher_action"] for r in rows), key=lambda a: ACTION_LABELS.index(a)))

    def _raw(self, x: Sequence[float], node: dict[str, Any]) -> str:
        while "leaf" not in node:
            node = node["left"] if x[node["feature"]] <= node["threshold"] else node["right"]
        return node["leaf"]

    def predict(self, x: Sequence[float], legal: Sequence[str], candidates: Sequence[dict] | None = None) -> tuple[str, bool]:
        predicted = self._raw(x, self.tree)
        if predicted not in legal and candidates:
            # A rule leaf is a prior; candidate rank/score supplies the
            # observer-visible local choice when that prior is unavailable.
            return legal_fallback(predicted, legal, candidates)
        return legal_fallback(predicted, legal, candidates)

    def payload(self) -> dict[str, Any]:
        return {"format": self.format_name, "schema_version": SCHEMA_VERSION,
                "features": list(FEATURES), "actions": list(ACTION_LABELS),
                "tree": self.tree, "default": self.default}


class TinyQuantizedMLP:
    format_name = "tiny_quantized_mlp"

    def __init__(self, hidden: list[list[int]], output: list[list[int]],
                 hidden_scale: float, output_scale: float, bias: list[int], candidate_weight: float = 0.0):
        self.hidden, self.output = hidden, output
        self.hidden_scale, self.output_scale, self.bias = hidden_scale, output_scale, bias
        self.candidate_weight = candidate_weight

    @classmethod
    def fit(cls, rows: list[dict[str, Any]], hidden_size: int = 8) -> "TinyQuantizedMLP":
        # A deterministic low-cost teacher-distillation surrogate: hidden units
        # are signed feature projections, output rows are action centroids. It
        # is intentionally not a lookup table and remains exportable as int8.
        n = len(FEATURES)
        hidden = [[((i * 17 + j * 11) % 31) - 15 for j in range(n)] for i in range(hidden_size)]
        hscale = 15.0
        activations = []
        for row in rows:
            h = [max(0.0, sum(q * x for q, x in zip(unit, row["features"])) / hscale) for unit in hidden]
            activations.append((row["teacher_action"], h))
        output = [[0] * hidden_size for _ in ACTION_LABELS]
        groups = {a: [h for label, h in activations if label == a] for a in ACTION_LABELS}
        for i, action in enumerate(ACTION_LABELS):
            if groups[action]:
                mean = [sum(h[j] for h in groups[action]) / len(groups[action]) for j in range(hidden_size)]
                output[i] = [max(-127, min(127, round(v * 12))) for v in mean]
        return cls(hidden, output, hscale, 12.0, [0] * len(ACTION_LABELS), 0.5)

    def raw(self, x: Sequence[float]) -> list[float]:
        h = [max(0.0, sum(q * value for q, value in zip(unit, x)) / self.hidden_scale) for unit in self.hidden]
        return [sum(q * value for q, value in zip(row, h)) / self.output_scale + self.bias[i]
                for i, row in enumerate(self.output)]

    def predict(self, x: Sequence[float], legal: Sequence[str], candidates: Sequence[dict] | None = None) -> tuple[str, bool]:
        scores = self.raw(x)
        bonus = _candidate_scores(candidates, self.candidate_weight)
        scores = [score + bonus.get(action, 0.0) for score, action in zip(scores, ACTION_LABELS)]
        index = _masked_index(scores, legal)
        predicted = ACTION_LABELS[index] if index is not None else "noop"
        return legal_fallback(predicted, legal, candidates)

    def payload(self) -> dict[str, Any]:
        return {"format": self.format_name, "schema_version": SCHEMA_VERSION,
                "features": list(FEATURES), "actions": list(ACTION_LABELS),
                "hidden": self.hidden, "output": self.output,
                "hidden_scale": self.hidden_scale, "output_scale": self.output_scale,
                "bias": self.bias, "candidate_weight": self.candidate_weight}


def fit_all(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {"weights": WeightsPolicy.fit(rows), "rule_tree": RuleTreePolicy.fit(rows),
            "tiny_quantized_mlp": TinyQuantizedMLP.fit(rows)}


def fixture_score(policy: Any, rows: list[dict[str, Any]]) -> dict[str, Any]:
    correct = fallbacks = 0
    predictions: list[str] = []
    for row in rows:
        action, fallback = policy.predict(row["features"], row["legal_actions"], row.get("candidate_scores"))
        predictions.append(action)
        correct += action == row["teacher_action"]
        fallbacks += fallback
    return {"records": len(rows), "teacher_agreement": correct / max(1, len(rows)),
            "fallbacks": fallbacks, "fallback_rate": fallbacks / max(1, len(rows)),
            "distinct_predictions": len(set(predictions)),
            "prediction_histogram": {a: predictions.count(a) for a in sorted(set(predictions))}}


def export_lua(policy: Any, path: Path) -> int:
    """Export self-contained Lua inference with legal-action fallback."""
    payload = json.dumps(policy.payload(), sort_keys=True, separators=(",", ":"))
    # JSON is valid Lua table syntax only for strings/arrays with a tiny decoder
    # unavailable in CraftOS, so generate a Lua return table through literals.
    def lua(v: Any) -> str:
        if isinstance(v, dict):
            return "{" + ",".join("[" + lua(str(k)) + "]=" + lua(x) for k, x in v.items()) + "}"
        if isinstance(v, list):
            return "{" + ",".join(lua(x) for x in v) + "}"
        if isinstance(v, str):
            return json.dumps(v)
        if isinstance(v, bool):
            return "true" if v else "false"
        if v is None:
            return "nil"
        return repr(float(v)) if isinstance(v, float) else str(v)
    table = lua(policy.payload())
    source = """-- Generated offline policy format; observer-safe vector and ranked candidates only.\nlocal M = %s\nlocal function legal(action, actions, candidates)\n  for _, candidate in ipairs(actions or {}) do if candidate == action then return action, false end end\n  local selected, best = nil, -math.huge\n  for _, candidate in ipairs(candidates or {}) do\n    if candidate.label and candidate.score and candidate.score > best then selected, best = candidate.label, candidate.score end\n  end\n  if selected then return selected, true end\n  local first = nil\n  for _, candidate in ipairs(actions or {}) do if first == nil or candidate < first then first = candidate end end\n  return first or \"noop\", true\nend\nlocal function candidateBonus(label, candidates)\n  if not candidates or not M.candidate_weight then return 0 end\n  local scale, value = 1, 0\n  for _, candidate in ipairs(candidates) do scale=math.max(scale, math.abs(candidate.score or 0)) end\n  for _, candidate in ipairs(candidates) do if candidate.label == label then value=(candidate.score or 0)/scale end end\n  return value * M.candidate_weight\nend\nfunction M.predict(f, actions, candidates)\n  local scores = {}\n  if M.format == \"weights\" then\n    for i, row in ipairs(M.weights) do local s=(M.bias[i] or 0)+candidateBonus(M.actions[i],candidates); for j,v in ipairs(row) do s=s+v*(f[j] or 0) end; scores[i]=s end\n  elseif M.format == \"tiny_quantized_mlp\" then\n    local h={}; for i,row in ipairs(M.hidden) do local s=0; for j,q in ipairs(row) do s=s+q*(f[j] or 0) end; h[i]=math.max(0,s/(M.hidden_scale or 1)) end\n    for i,row in ipairs(M.output) do local s=(M.bias[i] or 0)+candidateBonus(M.actions[i],candidates); for j,q in ipairs(row) do s=s+q*h[j]/(M.output_scale or 1) end; scores[i]=s end\n  else\n    local node=M.tree; while node.leaf == nil do node=(f[node.feature+1] or 0) <= node.threshold and node.left or node.right end; return legal(node.leaf,actions,candidates)\n  end\n  local best,bestScore=nil,-math.huge; for i,action in ipairs(M.actions) do for _,allowed in ipairs(actions or {}) do if action == allowed and scores[i] > bestScore then best,bestScore=i,scores[i] end end end\n  return legal(best and M.actions[best] or \"noop\", actions, candidates)\nend\nreturn M\n""" % table
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    return len(source.encode())


def benchmark_isolated(policies: dict[str, Any], rows: list[dict[str, Any]], iterations: int = 2500) -> dict[str, Any]:
    """Python-only smoke benchmark; native CraftOS benchmark remains pending."""
    result: dict[str, Any] = {"status": "fixture_only", "iterations": iterations, "formats": {}}
    for name, policy in policies.items():
        tracemalloc.start()
        samples: list[int] = []
        fallbacks = 0
        for i in range(iterations):
            row = rows[i % len(rows)]
            start = time.perf_counter_ns()
            _, fallback = policy.predict(row["features"], row["legal_actions"])
            samples.append(time.perf_counter_ns() - start)
            fallbacks += fallback
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        result["formats"][name] = {"p50_ns": int(statistics.median(samples)),
                                    "p95_ns": int(sorted(samples)[int(.95 * len(samples)) - 1]),
                                    "peak_traced_bytes": peak, "fallbacks": fallbacks,
                                    "fallback_rate": fallbacks / iterations}
    return result


def write_manifest() -> None:
    path = ROOT / "datasets" / "teacher_archive_manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"schema_version": SCHEMA_VERSION, "teachers": TEACHER_ARCHIVE,
                                "label_ingestion": {"required": ["observation", "legal_actions", "teacher_action", "teacher_policy_id"],
                                                     "reject_privileged": sorted(PRIVILEGED_KEYS),
                                                     "fixture_is_not_game_trace": True}}, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--make-fixture", action="store_true")
    parser.add_argument("--out", type=Path, default=RESULTS / "policy_format_offline_comparison.json")
    args = parser.parse_args()
    summary = make_fixture() if args.make_fixture or not DATASET.exists() else {"sha256": hashlib.sha256(DATASET.read_bytes()).hexdigest()}
    write_manifest()
    rows = load_records()
    policies = fit_all(rows)
    exports = {}
    for name, policy in policies.items():
        target = FORMATS / (name + ".lua")
        exports[name] = {"path": str(target.relative_to(ROOT)), "bytes": export_lua(policy, target),
                         "fixture_score": fixture_score(policy, rows)}
    result = {"status": "prepared_fixture_only", "native_benchmark_status": "pending_parent_signal",
              "full_game_retention_status": "pending_parent_signal", "dataset": summary,
              "feature_schema": {"version": SCHEMA_VERSION, "features": list(FEATURES)},
              "formats": exports, "isolated_python_benchmark": benchmark_isolated(policies, rows),
              "claim_limits": ["Fixture agreement is not full-game retention.",
                               "No native game or costly training was launched.",
                               "Teacher labels are fixture-ranked until imported from archived decision traces."]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
