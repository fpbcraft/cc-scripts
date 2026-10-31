"""Material reservation/checkpoint correctness and LuaJIT parity, not balance studies."""
import importlib.util
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime, from_lua


def fixture(backend='lua53'):
    return Runtime({'seed': 75123, 'runtimeBackend': backend, 'mapSize': 'compact',
                    'hostileMode': 'off', 'players': [{'civilization': 'forge', 'ai': False},
                                                     {'civilization': 'scholar', 'ai': False}]})


class MaterialReservationTests(unittest.TestCase):
    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension absent')
    def test_ordered_reservations_match_across_backends(self):
        outputs = []
        for backend in ('lua53', 'luajit21'):
            runtime = fixture(backend)
            module = runtime.lua.globals().dofile('/games/civcraft/resource_reservations.lua')
            operations = [{'owner': 1, 'cityID': city, 'buildingID': 'mixer', 'priority': 3,
                           'inputs': {'copper': 1, 'zinc': 1}, 'outputs': {'brass': 2}}
                          for city in (3, 1, 2)]
            plan = runtime.call(module.plan, runtime.lua.table_from({'copper': 2, 'zinc': 2, 'brass': 6}),
                                1, runtime.lua.table_from(operations, recursive=True))
            outputs.append(from_lua(plan))
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[0]['stock']['brass'], 10)
        self.assertEqual(outputs[0]['operations'][2]['reason'], 'output_cap')

    def prepare(self, runtime):
        settler = next(u for u in runtime.state.units.values() if u.owner == 0 and u.kind == 'settler')
        self.assertTrue(runtime.apply(0, {'action': 'found', 'unitID': settler.id,
                                         'x': settler.x, 'y': settler.y})[0])
        city = next(c for c in runtime.state.cities.values() if c.owner == 0)
        player = runtime.state.players[1]
        player.techs.steampower, player.stockpile.coal = True, 9
        runtime.state.world.resources[f'{city.x}:{city.y}'] = 'coal'
        runtime.call(runtime.lua.eval('''function(state)
            dofile('/games/civcraft/world.lua').reveal(state,
                dofile('/games/civcraft/hex.lua'), dofile('/games/civcraft/systems.lua'))
        end'''), runtime.state)

    def forecast(self, runtime):
        return from_lua(runtime.call(runtime.lua.eval('''function(state)
            local view=dofile('/games/civcraft/world.lua').forPlayer(state,0)
            local player
            for _, p in ipairs(view.players) do if p.id==0 then player=p end end
            return dofile('/games/civcraft/systems.lua').economy(player,view)
        end'''), runtime.state))

    def test_owned_forecasts_are_read_only_and_ignore_private_rival_stock(self):
        runtime = fixture()
        self.prepare(runtime)
        before = runtime.state_hash()
        forecast = self.forecast(runtime)
        self.assertEqual(runtime.state_hash(), before)
        self.assertEqual(forecast['resourcePlan']['snapshot']['coal'], 10)
        self.assertEqual(forecast['strategic']['coal'], 1)
        runtime.state.players[2].stockpile.coal = 999
        self.assertEqual(self.forecast(runtime), forecast)

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension absent')
    def test_checkpoint_rebuilds_identical_owned_forecast(self):
        runtime = fixture()
        self.prepare(runtime)
        restored = fixture('luajit21')
        restored.restore(runtime.canonical_state())
        self.assertEqual(runtime.state_hash(), restored.state_hash())
        self.assertEqual(self.forecast(runtime), self.forecast(restored))


if __name__ == '__main__':
    unittest.main()
