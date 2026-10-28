"""Deterministic specialization correctness/parity fixtures; no balance experiments."""
import importlib.util
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime


def fixture(backend='lua53'):
    return Runtime({'seed': 75123, 'mapSize': 'compact', 'contentRules': 'balance5',
                    'runtimeBackend': backend, 'hostileMode': 'off',
                    'players': [{'civilization': 'verdant', 'ai': False},
                                {'civilization': 'forge', 'ai': False}]})


class SpecializationTests(unittest.TestCase):
    def prepare(self, runtime):
        traveler = next(u for u in runtime.state.units.values()
                        if u.owner == 0 and u.kind == 'settler')
        self.assertTrue(runtime.apply(0, {'action': 'found', 'unitID': traveler.id,
                                         'x': traveler.x, 'y': traveler.y})[0])
        prepare = runtime.lua.eval("""function(state)
            local systems=dofile('/games/civcraft/systems.lua')
            local sites=dofile('/games/civcraft/specialty_sites.lua')
            local world=dofile('/games/civcraft/world.lua')
            local hex=dofile('/games/civcraft/hex.lua')
            local p=state.players[1]
            for id in pairs(systems.techs) do p.techs[id]=true end
            for _,c in ipairs(state.cities) do if c.owner==0 then
                c.population=7; c.buildings.library=true
                world.reveal(state,hex,systems)
                for _,n in ipairs(hex.neighbours(c.x,c.y,state)) do
                    if sites.canPlace(state,p,c,'works',n.x,n.y) then return c.id,n.x,n.y end
                end
            end end
            error('Expected legal specialty tile')
        end""")
        return runtime.call(prepare, runtime.state)

    def test_proposals_are_detached_and_site_actions_use_shared_dispatch(self):
        runtime = fixture()
        city_id, x, y = self.prepare(runtime)
        before = runtime.canonical_state()
        proposals, _ = runtime.engine.legalActions(runtime.state, 0)
        self.assertEqual(before, runtime.canonical_state())
        self.assertTrue(any(p.action == 'placeSite' for p in proposals.values()))
        self.assertTrue(runtime.apply(0, {'action': 'placeSite', 'city': city_id,
                                         'kind': 'works', 'x': x, 'y': y})[0])
        before = runtime.canonical_state()
        self.assertFalse(runtime.apply(0, {'action': 'placeSite', 'city': city_id,
                                          'kind': 'works', 'x': x, 'y': y})[0])
        self.assertEqual(before, runtime.canonical_state())
        restored = fixture()
        restored.restore(runtime.canonical_state())
        self.assertEqual(runtime.state_hash(), restored.state_hash())
        self.assertEqual(runtime.observe(0), restored.observe(0))

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'),
                         'Optional LuaJIT extension is not installed')
    def test_ordered_sites_redevelopment_and_saved_progress_match_jit(self):
        reference, accelerated = fixture(), fixture('luajit21')
        city_id, x, y = self.prepare(reference)
        accelerated.restore(reference.canonical_state())
        def apply(request, expected=True):
            self.assertEqual(reference.apply(0, request)[0], expected)
            self.assertEqual(accelerated.apply(0, request)[0], expected)
            self.assertEqual(reference.state_hash(), accelerated.state_hash())
            self.assertEqual(reference.observe(0), accelerated.observe(0))
        apply({'action': 'placeSite', 'city': city_id, 'kind': 'works', 'x': x, 'y': y})
        apply({'action': 'placeSite', 'city': city_id, 'kind': 'works', 'x': x, 'y': y}, False)
        finish = """function(state,cityId,amount)
            local sites=dofile('/games/civcraft/specialty_sites.lua')
            for _,c in ipairs(state.cities) do if c.id==cityId then
                return sites.advance(state,state.players[1],c,amount)
            end end
        end"""
        for runtime in (reference, accelerated):
            self.assertTrue(runtime.call(runtime.lua.eval(finish), runtime.state, city_id, 30)[0])
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        apply({'action': 'redevelopSite', 'city': city_id, 'siteId': 1,
               'kind': 'knowledge', 'x': x, 'y': y})
        for runtime in (reference, accelerated):
            self.assertFalse(runtime.call(runtime.lua.eval(finish), runtime.state, city_id, 12))
        apply({'action': 'queue', 'kind': 'project', 'id': 'ponder',
               'cityX': next(c.x for c in reference.state.cities.values() if c.id == city_id),
               'cityY': next(c.y for c in reference.state.cities.values() if c.id == city_id)})
        accelerated.restore(reference.canonical_state())
        apply({'action': 'resumeSite', 'city': city_id, 'projectId': 2})
        for runtime in (reference, accelerated):
            self.assertTrue(runtime.call(runtime.lua.eval(finish), runtime.state, city_id, 33)[0])
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        self.assertEqual(reference.observe(0), accelerated.observe(0))


if __name__ == '__main__':
    unittest.main()
