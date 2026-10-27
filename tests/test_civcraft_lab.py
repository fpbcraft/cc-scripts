"""Behavioral laboratory checks; run with Python's standard unittest runner."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runner import play
from runtime import Runtime, from_lua
from workers import run_bounded


def config(players=2):
    return {'seed': 75123, 'hostileMode': 'off',
            'players': [{'civilization': ['forge', 'scholar', 'iron', 'merchant'][i]}
                        for i in range(players)], 'maxRounds': 4}


class LaboratoryTests(unittest.TestCase):
    def test_real_initialization_includes_independent_villages(self):
        runtime = Runtime(config())
        self.assertGreater(len(list(runtime.state.cities.values())), 2)
        self.assertEqual(len(list(runtime.state.players.values())), 2)

    def test_two_three_and_four_player_lifecycle(self):
        for count in [2, 3, 4]:
            with self.subTest(players=count):
                runtime = Runtime(config(count))
                runtime.pump()
                runtime.advance()
                self.assertEqual(runtime.state.round, 2)

    def test_observation_is_detached_and_hides_rival_treasury(self):
        runtime = Runtime(config())
        runtime.state.players[2].gold = 987654321
        before = runtime.state_hash()
        observation = runtime.engine.observe(runtime.state, 0)
        for player in observation.players.values():
            if player.id == 1:
                self.assertNotEqual(player.gold, 987654321)
        observation.players[1].gold = -123
        self.assertEqual(runtime.state_hash(), before)

    def test_rejected_research_has_no_state_effect(self):
        runtime = Runtime(config())
        before = runtime.state_hash()
        outcome = runtime.apply(0, {'action': 'researchTech', 'id': 'netherite'})
        self.assertFalse(outcome[0])
        self.assertEqual(runtime.state_hash(), before)

    def test_proposals_do_not_change_state(self):
        runtime = Runtime(config())
        before = runtime.state_hash()
        proposals, coverage = runtime.engine.legalActions(runtime.state, 0)
        self.assertGreater(len(from_lua(proposals)), 0)
        self.assertIn('not exhaustive', coverage)
        self.assertEqual(runtime.state_hash(), before)

    def test_repeated_match_is_deterministic_and_cutoff_is_censored(self):
        first, second = play(config()), play(config())
        self.assertEqual(first['status'], 'censored')
        self.assertEqual(first['finalStateHash'], second['finalStateHash'])
        self.assertNotIn('victoryReason', first)
        self.assertGreater(first['dispatches']['accepted'], 0)

    def test_disabled_goal_does_not_become_policy_target(self):
        settings = config()
        settings['players'][0]['policy'] = {'goal': 'expedition'}
        settings['victories'] = {'expedition': False}
        runtime = Runtime(settings)
        runtime.pump()
        self.assertNotEqual(runtime.state.players[1].aiPlan.primary, 'expedition')

    def test_policy_changes_decisions_without_changing_initial_assets(self):
        settings = config()
        original = Runtime(settings)
        settings['players'][0]['policy'] = {'goal': 'expedition', 'weights': {'science': 2}}
        trained = Runtime(settings)
        self.assertEqual(original.state_hash(), trained.state_hash())
        trained.pump()
        self.assertEqual(trained.state.players[1].aiPlan.primary, 'expedition')

    def test_instruction_budget_reports_error_not_victory(self):
        settings = config()
        settings['instructionBudget'] = 10000
        result = play(settings)
        self.assertEqual(result['status'], 'error')
        self.assertIn('LAB_INSTRUCTION_BUDGET', result['error'])
        self.assertNotIn('victoryReason', result)

    def test_checkpoint_preserves_identical_continuation_and_independent_branches(self):
        original = Runtime(config())
        original.pump()
        original.advance()
        checkpoint = original.canonical_state()
        restored = Runtime(config())
        restored.restore(checkpoint)
        self.assertEqual(original.state_hash(), restored.state_hash())
        original.pump()
        restored.pump()
        original.advance()
        restored.advance()
        self.assertEqual(original.state_hash(), restored.state_hash())
        restored.state.players[1].gold = -99
        self.assertNotEqual(original.state_hash(), restored.state_hash())

    def test_bad_config_is_error_instead_of_silent_fallback(self):
        for invalid in [{'telemetryEvery': 0}, {'seed': 0.5}, {'mapType': 'bogus'}]:
            result = play(config() | invalid)
            self.assertEqual(result['status'], 'error')

    def test_worker_timeout_is_not_a_game_loss(self):
        settings = config(4) | {'mapSize': 'vast', 'wallSeconds': 1, 'maxRounds': 180}
        result = run_bounded([settings], 1)[0]
        self.assertEqual(result['status'], 'timeout')
        self.assertNotIn('victoryReason', result)


if __name__ == '__main__':
    unittest.main()
