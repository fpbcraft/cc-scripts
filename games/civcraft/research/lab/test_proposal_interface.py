"""Focused research tests for the observer-only action proposal interface."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))
from runtime import Runtime, from_lua  # noqa: E402


def config() -> dict:
    return {
        "seed": 75123,
        "mapSize": "compact",
        "mapType": "continents",
        "hostileMode": "off",
        "players": [
            {"civilization": "forge", "ai": False},
            {"civilization": "scholar", "ai": False},
        ],
        "maxRounds": 4,
    }


def proposal_payload(runtime: Runtime, player_id: int = 0) -> tuple[list[dict], str, dict, str]:
    proposals, coverage = runtime.engine.legalActions(runtime.state, player_id)
    metadata = runtime.engine.legalActionMetadata()
    canonical = runtime.lua.globals().LAB_CANONICAL
    return (
        from_lua(proposals),
        coverage,
        from_lua(metadata),
        runtime.call(canonical.encode, proposals),
    )


class ProposalInterfaceTests(unittest.TestCase):
    def test_detached_observation_is_not_mutated(self):
        runtime = Runtime(config())
        view = runtime.call(runtime.engine.observe, runtime.state, 0)
        encode = runtime.lua.globals().LAB_CANONICAL.encode
        proposals = runtime.lua.globals().dofile('/lab/proposals.lua')
        before = runtime.call(encode, view)
        runtime.call(proposals.list, view, 0)
        self.assertEqual(before, runtime.call(encode, view))

    def test_finished_turn_excludes_ordinary_actions_but_keeps_council(self):
        runtime = Runtime(config())
        runtime.call(runtime.lua.eval('''function(state)
            for _, p in ipairs(state.players) do
                p.techs.currency, p.techs.commerce, p.techs.bronze = true, true, true
            end
            for _, city in ipairs(state.cities) do city.buildings.councilhall = true end
            state.council = nil
            dofile('/games/civcraft/council.lua').advance(state)
        end'''), runtime.state)
        self.assertTrue(runtime.call(runtime.engine.endTurn, runtime.state, 0))
        candidates, _, _, _ = proposal_payload(runtime)
        self.assertTrue(any(c['action'] == 'councilVote' for c in candidates))
        self.assertTrue(all(c['action'] in {
            'diplomaticReply', 'diplomaticCounter', 'councilVote', 'councilPropose'
        } for c in candidates))
        self_vote = next(c for c in candidates if c['action'] == 'councilVote'
                         and c.get('candidate') == 0 and c.get('candidate') is not False)
        self.assertTrue(runtime.apply(0, self_vote)[0])
        rival_proposal = next(c for c in candidates if c['action'] == 'councilPropose'
                              and c['kind'] == 'censure' and c['target'] == 1)
        self.assertTrue(runtime.apply(0, rival_proposal)[0])

    def test_waiting_war_actor_has_no_ordinary_candidates(self):
        runtime = Runtime(config())
        runtime.state.scheduler.groups = runtime.lua.table_from([
            {'order': [0, 1], 'active': 1}
        ], recursive=True)
        candidates, _, _, _ = proposal_payload(runtime)
        self.assertFalse(any(c['action'] in {'queue', 'move', 'heal', 'researchTech'}
                             for c in candidates))

    def test_metadata_declares_non_exhaustive_families_and_limits(self):
        runtime = Runtime(config())
        proposals, coverage, metadata, _ = proposal_payload(runtime)
        self.assertGreater(len(proposals), 0)
        self.assertIn("not exhaustive", coverage)
        self.assertFalse(metadata["exhaustive"])
        self.assertTrue(metadata["observerOnly"])
        self.assertIn("unitModes", metadata["families"])
        self.assertIn("diplomaticOffer", metadata["unbounded"])

    def test_proposals_are_read_only_and_do_not_leak_rival_private_state(self):
        runtime = Runtime(config())
        before_hash = runtime.state_hash()
        before = proposal_payload(runtime)
        rival = runtime.state.players[2]
        rival.gold = 987654321
        rival.stockpile = runtime.lua.table_from({"diamond": 777, "secret": 555}, recursive=True)
        rival.aiPlan = runtime.lua.table_from({"private": "do-not-leak"}, recursive=True)
        after = proposal_payload(runtime)
        self.assertNotEqual(runtime.state_hash(), before_hash)
        self.assertEqual(before[0], after[0])
        self.assertEqual(before[3], after[3])
        # Calling the adapter itself must not mutate the authoritative state.
        stable = runtime.state_hash()
        proposal_payload(runtime)
        self.assertEqual(runtime.state_hash(), stable)

    def test_representative_proposal_subset_is_accepted_by_authoritative_dispatcher(self):
        wanted = {"researchTech", "queue", "heal", "standby", "cancelRoute", "diplomaticTalk"}
        found = set()
        for action_name in wanted:
            runtime = Runtime(config())
            proposals, _, _, _ = proposal_payload(runtime)
            candidate = next((item for item in proposals if item["action"] == action_name), None)
            if candidate is None:
                continue
            outcome = runtime.apply(0, candidate)
            self.assertTrue(bool(outcome[0]), f"candidate rejected: {candidate!r}: {outcome!r}")
            found.add(action_name)
        self.assertGreaterEqual(found, {"researchTech", "queue", "heal", "standby", "cancelRoute"})


if __name__ == "__main__":
    unittest.main()
