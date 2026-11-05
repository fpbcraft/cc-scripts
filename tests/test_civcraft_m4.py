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


    def prepare_machine(self, runtime):
        self.prepare(runtime)
        return runtime.call(runtime.lua.eval("""function(state)
            local systems=dofile('/games/civcraft/systems.lua')
            local sites=dofile('/games/civcraft/specialty_sites.lua')
            local actions=dofile('/games/civcraft/actions.lua')
            local hex=dofile('/games/civcraft/hex.lua')
            local world=dofile('/games/civcraft/world.lua')
            local player=state.players[1]
            for id in pairs(systems.techs) do player.techs[id]=true end
            local city
            for _, c in ipairs(state.cities) do if c.owner==0 then city=c end end
            world.reveal(state,hex,systems)
            for _, n in ipairs(hex.neighbours(city.x,city.y,state)) do
                if sites.canPlace(state,player,city,'works',n.x,n.y) then
                    assert(actions.apply(state,0,{action='placeSite',city=city.id,
                        kind='works',x=n.x,y=n.y},systems))
                    city.siteProjects[city.project.id].progress=100
                    systems.production(state,hex)
                    city.buildings.burner,city.buildings.mixer=true,true
                    systems.migrate(state)
                    return city.id
                end
            end
            error('Expected legal Works fixture')
        end"""), runtime.state)

    def test_rejected_machine_orders_preserve_entire_state(self):
        runtime = fixture()
        city = self.prepare_machine(runtime)
        for actor, fields in [(0, {'action': 'setMachinePriority', 'priority': 0}),
                              (0, {'action': 'setMachinePriority', 'priority': 5}),
                              (0, {'action': 'setMachinePriority', 'priority': 1.5}),
                              (0, {'action': 'setMachineEnabled', 'enabled': 1}),
                              (0, {'action': 'selectMachineRecipe', 'recipe': 'unknown'}),
                              (1, {'action': 'setMachineEnabled', 'enabled': False})]:
            before = runtime.state_hash()
            self.assertFalse(runtime.apply(actor, {'city': city, 'building': 'mixer'} | fields)[0])
            self.assertEqual(runtime.state_hash(), before)
        runtime.state.players[1].techs.brassworking = None
        before = runtime.state_hash()
        self.assertFalse(runtime.apply(0, {'action': 'selectMachineRecipe', 'city': city,
                                          'building': 'mixer', 'recipe': 'brass'})[0])
        self.assertEqual(runtime.state_hash(), before)

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension absent')
    def test_machine_actions_and_checkpoint_replay_match_jit(self):
        reference, accelerated = fixture(), fixture('luajit21')
        city = self.prepare_machine(reference)
        accelerated.restore(reference.canonical_state())
        for fields in [{'action': 'selectMachineRecipe', 'recipe': 'brass'},
                       {'action': 'setMachinePriority', 'priority': 2},
                       {'action': 'setMachineEnabled', 'enabled': False},
                       {'action': 'setMachineEnabled', 'enabled': True}]:
            request = {'city': city, 'building': 'mixer'} | fields
            self.assertTrue(reference.apply(0, request)[0])
            self.assertTrue(accelerated.apply(0, request)[0])
            self.assertEqual(reference.state_hash(), accelerated.state_hash())
            self.assertEqual(reference.observe(0), accelerated.observe(0))
            accelerated.restore(reference.canonical_state())
            self.assertEqual(reference.state_hash(), accelerated.state_hash())


    def prepare_powered_machine(self, runtime):
        city = self.prepare_machine(runtime)
        runtime.call(runtime.lua.eval("""function(state,cityID)
            local systems=dofile('/games/civcraft/systems.lua')
            for _, c in ipairs(state.cities) do if c.id==cityID then
                c.buildings.waterwheel,c.buildings.press,c.buildings.steamplant=true,true,true
            end end
            state.players[1].stockpile.coal=1
            state.players[1].stockpile.copper=1
            state.players[1].stockpile.zinc=1
            systems.migrate(state)
        end"""), runtime.state, city)
        self.assertTrue(runtime.apply(0, {'action': 'selectMachineRecipe', 'city': city,
                                         'building': 'mixer', 'recipe': 'brass'})[0])
        return city

    def machine_forecast(self, runtime):
        systems = runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        return from_lua(runtime.call(systems.machineForecast, runtime.state, 0))

    def test_selected_machine_forecast_and_preview_preserve_complete_state(self):
        runtime = fixture()
        city = self.prepare_powered_machine(runtime)
        systems = runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        before = runtime.state_hash()
        forecast = self.machine_forecast(runtime)
        raw_preview = runtime.call(systems.previewMachine, runtime.state, 0, city, 'mixer', 'industry')
        preview = from_lua(raw_preview)
        preview_economy = from_lua(runtime.call(systems.economy, runtime.state.players[1], runtime.state, raw_preview))
        self.assertEqual(preview_economy['industry'], forecast['economy']['industry'] + 2)
        self.assertEqual(runtime.state_hash(), before)
        self.assertEqual(forecast['plan']['stock']['brass'], 2)
        self.assertEqual(preview['stock']['copper'], 1)
        self.assertEqual(preview['effects'][str(city)]['industry'], forecast['plan']['effects'][str(city)]['industry'] + 2)
        runtime.state.players[2].stockpile.coal = 999
        self.assertEqual(self.machine_forecast(runtime), forecast)

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension absent')
    def test_machine_effects_fuel_and_preview_match_jit_checkpoint(self):
        reference, accelerated = fixture(), fixture('luajit21')
        city = self.prepare_powered_machine(reference)
        accelerated.restore(reference.canonical_state())
        self.assertEqual(self.machine_forecast(reference), self.machine_forecast(accelerated))
        previews = []
        for runtime in (reference, accelerated):
            systems = runtime.lua.globals().dofile('/games/civcraft/systems.lua')
            before = runtime.state_hash()
            previews.append(from_lua(runtime.call(systems.previewMachine, runtime.state, 0, city, 'mixer', 'industry')))
            self.assertEqual(runtime.state_hash(), before)
        self.assertEqual(previews[0], previews[1])


if __name__ == '__main__':
    unittest.main()
