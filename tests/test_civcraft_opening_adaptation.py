"""Current opening queues preserve assets and checkpoint progress; no balance study."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime


def found_capitals(runtime):
    for player in runtime.state.players.values():
        settler = next(u for u in runtime.state.units.values()
                       if u.owner == player.id and u.kind == 'settler')
        assert runtime.apply(player.id, {'action': 'found', 'unitID': settler.id,
                                        'x': settler.x, 'y': settler.y})[0]
    return runtime


class OpeningAdaptationTests(unittest.TestCase):
    def fixture(self, profile='balance5'):
        return found_capitals(Runtime({'seed': 75123, 'contentRules': profile,
            'hostileMode': 'off', 'players': [{'civilization': 'forge', 'ai': False},
                                           {'civilization': 'scholar', 'ai': False}]}))

    def test_scout_queue_preserves_assets_and_checkpoint_progress(self):
        runtime = self.fixture()
        player = runtime.state.players[1]
        city = next(c for c in runtime.state.cities.values() if c.owner == 0)
        assets = (player.gold, len(list(runtime.state.units.values())), city.population)
        self.assertTrue(runtime.apply(0, {'action': 'queue', 'kind': 'unit', 'id': 'scout',
                                         'cityX': city.x, 'cityY': city.y})[0])
        self.assertEqual(assets, (player.gold, len(list(runtime.state.units.values())), city.population))
        checkpoint = runtime.canonical_state()
        restored = self.fixture()
        restored.restore(checkpoint)
        self.assertEqual(runtime.state_hash(), restored.state_hash())
        systems = runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        other = restored.lua.globals().dofile('/games/civcraft/systems.lua')
        for _ in range(30):
            if city.project is None:
                break
            runtime.call(systems.production, runtime.state, runtime.lua.globals().dofile('/games/civcraft/hex.lua'))
            restored.call(other.production, restored.state, restored.lua.globals().dofile('/games/civcraft/hex.lua'))
            self.assertEqual(runtime.state_hash(), restored.state_hash())
        self.assertIsNone(city.project)
        self.assertTrue(any(u.owner == 0 and u.kind == 'scout' for u in runtime.state.units.values()))

    def test_retired_farm_queue_is_rejected_under_historical_inputs(self):
        for profile in ('baseline', 'p1'):
            runtime = self.fixture(profile)
            city = next(c for c in runtime.state.cities.values() if c.owner == 0)
            before = runtime.state_hash()
            self.assertFalse(runtime.apply(0, {'action': 'queue', 'kind': 'building', 'id': 'farm',
                                              'cityX': city.x, 'cityY': city.y})[0])
            self.assertEqual(before, runtime.state_hash())

if __name__ == '__main__':
    unittest.main()
