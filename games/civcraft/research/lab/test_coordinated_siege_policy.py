"""Composition gate tests using actual content values and production validators."""
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from coordinated_siege_study import base_config, PARAMETERS
import military_competence_benchmark as military
from runtime import Runtime, from_lua


class SiegeCompositionTests(unittest.TestCase):
    def fixture(self):
        runtime = Runtime(base_config(95117, 0, 'coordinated'))
        military._fixture_setup(runtime, 'siege_breach')
        runtime.call(runtime.lua.eval('''function(state)
            local p = state.players[1]
            local target
            for _, city in ipairs(state.cities) do
                if city.owner == 1 and not city.village then target = city end
            end
            p.aiPlan = {primary='conquest', campaign={kind='city', owner=1,
                x=target.x, y=target.y, wallHP=100}}
            for _, u in ipairs(state.units) do
                if u.owner == 0 and u.kind == 'warrior' then u.kind = 'swordsman' end
            end
        end'''), runtime.state)
        return runtime

    def test_two_actual_swordsmen_allow_a_second_siege_recruit(self):
        runtime = self.fixture()
        runtime.lua.globals().dofile('/games/civcraft/research/lab/coordinated_siege_policy.lua').install(
            runtime.lua.table_from(PARAMETERS))
        choices = runtime.call(runtime.lua.eval('''function(state)
            local systems = dofile('/games/civcraft/systems.lua')
            local view = dofile('/games/civcraft/presentation.lua').capture(state, 0)
            local player = state.players[1]
            local city
            for _, c in ipairs(view.cities) do if c.owner == 0 then city = c; break end end
            return dofile('/games/civcraft/ai_production.lua').ranked(view, player, city, systems, true)
        end'''), runtime.state)[0]
        top = from_lua(choices)[0]
        self.assertEqual((top['kind'], top['id']), ('unit', 'catapult'))

    def test_invalid_quorum_is_rejected(self):
        runtime = self.fixture()
        policy = runtime.lua.globals().dofile('/games/civcraft/research/lab/coordinated_siege_policy.lua')
        with self.assertRaises(Exception):
            runtime.call(policy.install, runtime.lua.table_from({'siegeCount': 2, 'attackQuorum': 3}))


if __name__ == '__main__':
    unittest.main()
