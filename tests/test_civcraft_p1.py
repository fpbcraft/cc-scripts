"""P1 contract checks through the shared action and round boundaries."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/civcraft_lab'))
from runtime import Runtime


def fixture(version='p1'):
    runtime = Runtime({'seed':75123,'contentRules':version,'hostileMode':'off',
        'players':[{'civilization':'scholar','ai':False},{'civilization':'forge','ai':False}]})
    for actor in (0, 1):
        settler = next(u for u in runtime.state.units.values()
                       if u.owner == actor and u.kind == 'settler')
        assert runtime.apply(actor, {'action': 'found', 'unitID': settler.id,
                                    'x': settler.x, 'y': settler.y})[0]
    return runtime


def advance(runtime):
    for actor in (0,1):
        assert runtime.call(runtime.engine.endTurn,runtime.state,actor) is True
    runtime.advance()


class P1Tests(unittest.TestCase):
    def test_trade_forecast_does_not_mutate_workers_on_rejected_recruitment(self):
        runtime=fixture()
        p = runtime.state.players[1]
        c = next(c for c in runtime.state.cities.values() if c.owner == 0)
        p.gold=0
        p.techs.mechanicalcrafting=True
        p.stockpile.brass=0
        runtime.state.world.resources=runtime.lua.table()
        c.buildings.market=True
        self.assertTrue(runtime.apply(0,{'action':'queue','kind':'project','id':'trade','cityX':c.x,'cityY':c.y})[0])
        # A claim can invalidate worked tiles before the next economy boundary.
        # A rejected order must not normalize those assignments as a side effect.
        c.worked = runtime.lua.table_from({'999:999': True})
        before=runtime.state_hash()
        self.assertFalse(runtime.apply(0,{'action':'queue','kind':'unit','id':'heavysiege','cityX':c.x,'cityY':c.y})[0])
        self.assertEqual(runtime.state_hash(),before)

    def test_historical_profile_inputs_use_current_rules(self):
        for version in ('baseline', 'p1'):
            runtime = fixture(version)
            systems = runtime.lua.globals().dofile('/games/civcraft/systems.lua')
            p = runtime.state.players[1]
            c = next(c for c in runtime.state.cities.values() if c.owner == 0)
            self.assertEqual(systems.centerYields(p, c, runtime.state).science, 3)
            self.assertEqual(systems.projectCost('unit', 'settler', p), 28)
            self.assertEqual(runtime.observe(0)['contentRules'], 'balance5')

    def test_ponder_pause_conversion_and_checkpoint_replay(self):
        runtime=fixture()
        systems=runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        p = runtime.state.players[1]
        c = next(c for c in runtime.state.cities.values() if c.owner == 0)
        p.civ='forge'
        c.worked=runtime.lua.table()
        c.foodStore=0
        c.buildings=runtime.lua.table_from({'library':True,'market':True})
        self.assertTrue(runtime.apply(0,{'action':'queue','kind':'project','id':'ponder','cityX':c.x,'cityY':c.y})[0])
        advance(runtime)
        self.assertGreater(p.scienceRate, 0)
        self.assertIsNone(c.projectRemainders)
        self.assertTrue(runtime.apply(0,{'action':'researchTech','id':'mining'})[0])
        for _ in range(3): advance(runtime)
        self.assertGreaterEqual(c.projectRemainders.ponder, 0)
        payload=runtime.canonical_state()
        advance(runtime)
        expected=runtime.state_hash()
        runtime.restore(payload)
        advance(runtime)
        self.assertEqual(runtime.state_hash(),expected)

    def test_migrated_profile_can_use_current_civilian_projects(self):
        runtime = fixture('baseline')
        p = runtime.state.players[1]
        c = next(c for c in runtime.state.cities.values() if c.owner == 0)
        c.buildings.market = True
        self.assertTrue(runtime.apply(0, {'action': 'queue', 'kind': 'project',
                                         'id': 'trade', 'cityX': c.x, 'cityY': c.y})[0])
        self.assertEqual(p.contentRules, 'balance5')


if __name__=='__main__': unittest.main()
