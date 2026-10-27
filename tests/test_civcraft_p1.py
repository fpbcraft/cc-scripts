"""P1 contract checks through the shared action and round boundaries."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/civcraft_lab'))
from runtime import Runtime


def fixture(version='p1'):
    runtime = Runtime({'seed':75123,'contentRules':version,'hostileMode':'off',
        'players':[{'civilization':'scholar','ai':False},{'civilization':'forge','ai':False}]})
    return runtime


def advance(runtime):
    for actor in (0,1):
        assert runtime.call(runtime.engine.endTurn,runtime.state,actor) is True
    runtime.advance()


class P1Tests(unittest.TestCase):
    def test_trade_forecast_does_not_mutate_workers_on_rejected_recruitment(self):
        runtime=fixture()
        p,c=runtime.state.players[1],runtime.state.cities[1]
        p.gold=0
        p.techs.mechanicalcrafting=True
        p.stockpile.brass=0
        runtime.state.world.resources=runtime.lua.table()
        c.buildings.market=True
        self.assertTrue(runtime.apply(0,{'action':'queue','kind':'project','id':'trade','cityX':c.x,'cityY':c.y})[0])
        # A claim can invalidate worked tiles before the next economy boundary.
        # A rejected order must not normalize those assignments as a side effect.
        c.worked['999:999']=True
        before=runtime.state_hash()
        self.assertFalse(runtime.apply(0,{'action':'queue','kind':'unit','id':'heavysiege','cityX':c.x,'cityY':c.y})[0])
        self.assertEqual(runtime.state_hash(),before)

    def test_profile_is_observed_and_baseline_remains_original(self):
        for version,science,settler in [('baseline',3,12),('p1',3,40)]:
            runtime=fixture(version)
            systems=runtime.lua.globals().dofile('/games/civcraft/systems.lua')
            p,c=runtime.state.players[1],runtime.state.cities[1]
            self.assertEqual(systems.centerYields(p,c,runtime.state).science,science)
            self.assertEqual(systems.projectCost('unit','settler',p),settler)
            self.assertEqual(runtime.observe(0).get('contentRules'), 'p1' if version=='p1' else None)
            c.capitalOf=None
            self.assertEqual(systems.centerYields(p,c,runtime.state).science,2 if version=='p1' else 3)

    def test_ponder_pause_conversion_and_checkpoint_replay(self):
        runtime=fixture()
        systems=runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        p,c=runtime.state.players[1],runtime.state.cities[1]
        p.civ='forge'
        c.worked=runtime.lua.table()
        c.foodStore=0
        c.buildings=runtime.lua.table_from({'farm':True,'library':True,'market':True})
        self.assertTrue(runtime.apply(0,{'action':'queue','kind':'project','id':'ponder','cityX':c.x,'cityY':c.y})[0])
        advance(runtime)
        self.assertEqual(p.scienceRate,4)
        self.assertIsNone(c.projectRemainders)
        self.assertTrue(runtime.apply(0,{'action':'researchTech','id':'mining'})[0])
        for _ in range(3): advance(runtime)
        self.assertEqual(c.projectRemainders.ponder,3)
        payload=runtime.canonical_state()
        advance(runtime)
        expected=runtime.state_hash()
        self.assertEqual(p.researchProgress.mining,17)
        runtime.restore(payload)
        advance(runtime)
        self.assertEqual(runtime.state_hash(),expected)

    def test_project_does_not_grant_a_new_game_profile_to_old_saves(self):
        runtime=fixture('baseline')
        p,c=runtime.state.players[1],runtime.state.cities[1]
        c.buildings.market=True
        before=runtime.state_hash()
        self.assertFalse(runtime.apply(0,{'action':'queue','kind':'project','id':'trade','cityX':c.x,'cityY':c.y})[0])
        self.assertEqual(before,runtime.state_hash())
        systems=runtime.lua.globals().dofile('/games/civcraft/systems.lua')
        runtime.call(systems.migrate,runtime.state)
        self.assertIsNone(p.contentRules)
        self.assertEqual(systems.projectCost('unit','settler',p),12)


if __name__=='__main__': unittest.main()
