"""Cityless opening contracts and short shared-runtime conformance; no balance study."""
import importlib.util
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime


def fixture(backend='lua53'):
    return Runtime({'seed': 75123, 'mapSize': 'compact', 'contentRules': 'balance4',
                    'runtimeBackend': backend, 'hostileMode': 'off',
                    'players': [{'civilization': 'verdant'}, {'civilization': 'forge'}]})


class OpeningTests(unittest.TestCase):
    def test_cityless_checkpoint_and_founder_cost(self):
        original = fixture()
        self.assertFalse(any(c.owner == 0 for c in original.state.cities.values()))
        units = [u for u in original.state.units.values() if u.owner == 0]
        self.assertCountEqual([u.kind for u in units], ['settler', 'warrior'])
        restored = fixture()
        restored.restore(original.canonical_state())
        traveler = next(u for u in restored.state.units.values() if u.owner == 0 and u.kind == 'settler')
        self.assertTrue(restored.apply(0, {'action': 'found', 'unitID': traveler.id,
                                         'x': traveler.x, 'y': traveler.y})[0])
        capital = next(c for c in restored.state.cities.values() if c.owner == 0)
        self.assertEqual(capital.capitalOf, 0)
        self.assertEqual(capital.hp, 200)
        self.assertEqual(restored.state.players[1].settlersTrained, 0)
        self.assertEqual((restored.state.world.width, restored.state.world.height), (32, 22))

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension is not installed')
    def test_first_foundation_and_ai_start_match_under_jit(self):
        reference, accelerated = fixture(), fixture('luajit21')
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        traveler = next(u for u in reference.state.units.values() if u.owner == 0 and u.kind == 'settler')
        request = {'action': 'found', 'unitID': traveler.id, 'x': traveler.x, 'y': traveler.y}
        self.assertTrue(reference.apply(0, request)[0])
        self.assertTrue(accelerated.apply(0, request)[0])
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        reference.pump()
        accelerated.pump()
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        reference.advance()
        accelerated.advance()
        self.assertEqual(reference.observe(0), accelerated.observe(0))
        self.assertEqual(reference.state_hash(), accelerated.state_hash())


if __name__ == '__main__':
    unittest.main()
