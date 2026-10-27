"""Opening interventions share checkpoints and use ordinary validated queues."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
sys.path.insert(0, str(ROOT / 'games/civcraft/research/lab'))
from p1_opening_adaptation import configurations, run_condition
from runtime import Runtime


class OpeningAdaptationTests(unittest.TestCase):
    def test_scout_queue_preserves_assets_and_distinguishes_actual_completion(self):
        config = configurations('train')[0] | {'runtimeBackend': 'lua53', 'maxRounds': 6}
        result = run_condition(config)
        control, scout = result['arms']
        self.assertEqual(control['startHash'], result['startHash'])
        self.assertEqual(scout['startHash'], result['startHash'])
        self.assertEqual(scout['status'], 'censored')
        self.assertIsNone(scout['targetWinCredit'])
        self.assertIn('firstScout', scout['milestones'])
        self.assertTrue(scout['earlyQueueOrders'][0]['accepted'])
        self.assertEqual(scout['earlyQueueOrders'][0]['request']['id'], 'scout')
        original = Runtime(config)
        player, city = original.state.players[1], original.state.cities[1]
        assets = (player.gold, len(list(original.state.units.values())), city.population)
        self.assertTrue(original.apply(0, scout['request'])[0])
        self.assertEqual(assets, (player.gold, len(list(original.state.units.values())), city.population))

    def test_locked_farm_is_unavailable_without_granting_a_technology(self):
        config = configurations('train')[0] | {'runtimeBackend': 'lua53', 'maxRounds': 2, 'openings': ['farm']}
        result = run_condition(config)
        self.assertEqual(result['arms'][0]['status'], 'unavailable')
        self.assertEqual(result['status'], 'incomplete')
        p1 = run_condition(config | {'contentRules': 'p1'})
        self.assertEqual(p1['arms'][0]['status'], 'censored')
        self.assertTrue(p1['arms'][0]['earlyQueueOrders'][0]['accepted'])


if __name__ == '__main__':
    unittest.main()
