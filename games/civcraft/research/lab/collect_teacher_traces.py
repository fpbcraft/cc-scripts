#!/usr/bin/env python3
"""Collect actual ranked teacher decisions from observer projections.

This uses the installed source modules through the existing Lupa Runtime.  It
does not alter gameplay modules: `Production.ranked` and `Research.ranked` are
called for the current state, their candidate scores are retained, and the
game then proceeds through the ordinary authoritative AI turn.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
from runner import source_manifest  # noqa: E402
from runtime import Runtime, from_lua  # noqa: E402
from policy_format_comparison import FEATURES, extract_observer_features  # noqa: E402


def _label(kind: str, item: dict) -> str:
    return f"{kind}:{item['id']}"


def _candidate_rows(items: list[dict], kind: str) -> tuple[list[str], list[dict]]:
    labels, candidates = [], []
    for rank, item in enumerate(items):
        label = _label(kind, item)
        labels.append(label)
        candidates.append({
            "label": label, "rank": rank, "score": float(item.get("score", 0)),
            "turns": int(item.get("turns", 0) or 0),
            "kind": item.get("kind", kind), "id": item.get("id"),
            "tileX": item.get("tileX"), "tileY": item.get("tileY"),
        })
    return labels, candidates


def _config(seed: int) -> dict:
    return {
        "seed": seed, "mapSize": "compact", "mapType": "pangaea",
        "hostileMode": "off", "maxRounds": 180, "telemetryEvery": 10,
        "players": [{"civilization": "forge"}, {"civilization": "forge"}],
    }


def collect(seed: int) -> dict:
    runtime = Runtime(_config(seed))
    cache = runtime.lua.globals().__civcraftModuleCache
    systems = cache["/games/civcraft/systems.lua"]
    production = cache["/games/civcraft/ai_production.lua"]
    research = cache["/games/civcraft/ai_research.lua"]
    helper = runtime.lua.eval("""
      function(production, research, settlement, view, player, city, systems)
        local canExpand = settlement.available(view, player, city, systems)
        local prod = production.ranked(view, player, city, systems, canExpand)
        local tech = research.ranked(view, player, systems)
        local yields = systems.yields(player, city, view, dofile('/games/civcraft/hex.lua'))
        return prod, tech, yields, systems.treasury(player, view), canExpand
      end
    """)
    settlement = cache["/games/civcraft/ai_settlement.lua"]
    records: list[dict] = []
    rounds = 0
    while not runtime.finished() and int(runtime.state.round) <= 180:
        round_value = int(runtime.state.round)
        for player in runtime.state.players.values():
            player_id = int(player.id)
            view_lua = runtime.call(runtime.engine.observe, runtime.state, player_id)
            view = from_lua(view_lua)
            own = next(p for p in view.get("players", []) if p.get("id") == player_id)
            own_cities = [c for c in runtime.state.cities.values() if int(c.owner) == player_id]
            total_industry = total_science = 0.0
            city_decisions = []
            research_candidates = []
            treasury_net = 0.0
            for city in own_cities:
                prod_lua, tech_lua, yields_lua, treasury_lua, can_expand = runtime.call(
                    helper, production, research, settlement, view_lua, player, city, systems)
                yields = from_lua(yields_lua)
                treasury = from_lua(treasury_lua)
                total_industry += float(yields.get("industry", 0))
                total_science += float(yields.get("science", 0))
                treasury_net = float(treasury.get("net", 0))
                prod = from_lua(prod_lua)
                labels, candidates = _candidate_rows(prod, "production")
                if labels:
                    city_decisions.append((city, labels, candidates, bool(can_expand)))
                if not research_candidates:
                    research_candidates = _candidate_rows(from_lua(tech_lua), "research")
            # Research is one decision per player and uses actual Research.ranked.
            # Build every production vector from the complete own-city totals,
            # matching the Lua adapter's Systems.yields aggregation exactly.
            def enriched_features(labels):
                enriched = dict(view)
                enriched["players"] = [dict(p) for p in view.get("players", [])]
                enriched_own = next(p for p in enriched["players"] if p.get("id") == player_id)
                enriched_own.update({"industry": total_industry, "scienceRate": total_science,
                                     "treasuryNet": treasury_net, "techs": own.get("techs", {})})
                return extract_observer_features(enriched, labels, player_id)
            for city, labels, candidates, can_expand in city_decisions:
                features, missing = enriched_features(labels)
                records.append({"schema_version": "observer-ranked-decision-v1",
                                "game_id": f"teacher-{seed}", "seed": seed,
                                "round": round_value, "seat": player_id,
                                "faction": own.get("civ", "forge"), "kind": "production",
                                "city_id": int(city.id), "features": features,
                                "feature_names": list(FEATURES), "legal_actions": labels,
                                "candidate_scores": candidates,
                                "teacher_action": labels[0], "teacher_policy_id": "source-ai-ranked",
                                "source_kind": "archived_decision_trace",
                                "source_hash": source_manifest()["luaSourceHash"],
                                "missing_optional_fields": missing,
                                "can_expand": can_expand})
            labels, candidates = research_candidates if research_candidates else ([], [])
            if labels:
                features, missing = enriched_features(labels)
                records.append({"schema_version": "observer-ranked-decision-v1",
                                "game_id": f"teacher-{seed}", "seed": seed,
                                "round": round_value, "seat": player_id,
                                "faction": own.get("civ", "forge"), "kind": "research",
                                "features": features, "feature_names": list(FEATURES),
                                "legal_actions": labels, "candidate_scores": candidates,
                                "teacher_action": labels[0], "teacher_policy_id": "source-ai-ranked",
                                "source_kind": "archived_decision_trace",
                                "source_hash": source_manifest()["luaSourceHash"],
                                "missing_optional_fields": missing})
        runtime.pump()
        rounds += 1
        if runtime.finished() or int(runtime.state.round) >= 180:
            break
        runtime.advance()
    return {"seed": seed, "rounds": rounds, "records": records,
            "status": "finished" if runtime.finished() else "censored",
            "victoryReason": runtime.state.victoryReason,
            "winnerIds": from_lua(runtime.state.winnerIDs or runtime.lua.table()) or [],
            "source": source_manifest()}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train-seeds", default="75123,18731")
    parser.add_argument("--holdout-seeds", default="95117,808381")
    parser.add_argument("--out", type=Path, default=HERE / "datasets/teacher_traces_actual.jsonl")
    parser.add_argument("--summary", type=Path, default=HERE / "results/teacher_trace_collection.json")
    args = parser.parse_args()
    train = [int(x) for x in args.train_seeds.split(",") if x]
    holdout = [int(x) for x in args.holdout_seeds.split(",") if x]
    games = []
    for split, seeds in (("train", train), ("holdout", holdout)):
        for seed in seeds:
            print(json.dumps({"event": "start", "split": split, "seed": seed}), flush=True)
            result = collect(seed)
            result["split"] = split
            games.append(result)
            print(json.dumps({"event": "complete", "split": split, "seed": seed,
                              "status": result["status"], "rounds": result["rounds"],
                              "records": len(result["records"])}), flush=True)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as handle:
        for game in games:
            for record in game["records"]:
                record["split"] = game["split"]
                handle.write(json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n")
    summary = {"status": "actual_observer_traces", "train_seeds": train, "holdout_seeds": holdout,
               "games": [{k: g[k] for k in ("seed", "split", "rounds", "status", "victoryReason", "winnerIds")}
                         for g in games],
               "records": sum(len(g["records"]) for g in games),
               "source_changed_during_run": len({g["source"]["luaSourceHash"] for g in games}) != 1,
               "dataset_sha256": hashlib.sha256(args.out.read_bytes()).hexdigest()}
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
