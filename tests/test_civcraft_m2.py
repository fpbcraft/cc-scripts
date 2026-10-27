"""Short shared-rule compatibility checks, not balance simulations."""
import importlib.util
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime


class DevelopmentTests(unittest.TestCase):
    def test_checkpoint_retains_development_economy(self):
        config = {'seed': 75123, 'contentRules': 'balance2', 'hostileMode': 'off',
                  'players': [{'civilization': 'scholar'}, {'civilization': 'forge'}]}
        runtime = Runtime(config)
        payload = runtime.canonical_state()
        restored = Runtime(config | {'contentRules': 'balance1'})
        restored.restore(payload)
        systems = restored.lua.globals().dofile('/games/civcraft/systems.lua')
        self.assertEqual(systems.projectCost('unit', 'settler', restored.state.players[1]), 28)
        self.assertEqual(restored.state.contentRules, 'balance2')
        self.assertEqual(restored.state_hash(), runtime.state_hash())

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension is not installed')
    def test_development_checkpoint_and_round_boundaries_match(self):
        config = {'seed': 75123, 'contentRules': 'balance2', 'hostileMode': 'off',
                  'players': [{'civilization': 'scholar'}, {'civilization': 'forge'}]}
        reference = Runtime(config | {'runtimeBackend': 'lua53'})
        accelerated = Runtime(config | {'runtimeBackend': 'luajit21'})
        for _ in range(3):
            self.assertEqual(reference.state_hash(), accelerated.state_hash())
            reference.pump()
            accelerated.pump()
            self.assertEqual(reference.state_hash(), accelerated.state_hash())
            reference.advance()
            accelerated.advance()
        accelerated.restore(reference.canonical_state())
        self.assertEqual(reference.observe(0), accelerated.observe(0))
        self.assertEqual(accelerated.state.contentRules, 'balance2')


if __name__ == '__main__':
    unittest.main()
