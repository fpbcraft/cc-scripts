#!/usr/bin/env python3
"""Offline reducer for later matched full-game retention artifacts.

It consumes completed JSON artifacts; it never starts a game.  Missing or
invalid games stay in the error/censor ledger rather than silently becoming
losses.  This is intentionally small so the parent can call it after the
native comparison has been approved.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


VALID = {"finished"}


def _games(payload: dict[str, Any]) -> list[dict[str, Any]]:
    for key in ("games", "outcomes", "matches"):
        if isinstance(payload.get(key), list):
            return payload[key]
    raise ValueError("artifact has no games/outcomes/matches list")


def reduce_artifact(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    games = _games(payload)
    valid, censored, errors = [], [], []
    for game in games:
        status = game.get("status")
        if status in VALID:
            valid.append(game)
        elif status in {"censored", "timeout"}:
            censored.append(game)
        else:
            errors.append(game)
    routes = Counter(str(g.get("victoryReason") or g.get("victory_reason") or "unknown") for g in valid)
    fallback = sum(int(g.get("fallbacks", g.get("fallback_count", 0)) or 0) for g in valid)
    decisions = sum(int(g.get("decisions", g.get("decision_count", 0)) or 0) for g in valid)
    return {"path": str(path), "attempted": len(games), "finished": len(valid),
            "censored": len(censored), "errors": len(errors),
            "valid_rate": len(valid) / max(1, len(games)), "routes": dict(sorted(routes.items())),
            "fallback_rate": fallback / max(1, decisions),
            "claimable": bool(valid) and not errors}


def compare(teacher: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    # This reducer compares retention diagnostics, not winners from unequal
    # seats. Route-conditioned victory fairness must be computed from the
    # richer per-faction/per-route ledger before any aggregated claim.
    return {"teacher": teacher, "candidate": candidate,
            "delta_finished_rate": candidate["valid_rate"] - teacher["valid_rate"],
            "delta_fallback_rate": candidate["fallback_rate"] - teacher["fallback_rate"],
            "status": "artifact_reduction_only",
            "full_game_strength_claim": False}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("teacher", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    output = compare(reduce_artifact(args.teacher), reduce_artifact(args.candidate))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
