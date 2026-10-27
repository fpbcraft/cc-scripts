"""M1 profiles, observer scope, real action boundaries and backend checkpoint parity."""
import importlib.util
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/civcraft_lab'))
from runtime import Runtime


def fixture(backend='lua53',version='balance1'):
    return Runtime({'seed':75123,'runtimeBackend':backend,'contentRules':version,'hostileMode':'off',
        'players':[{'civilization':'forge'},{'civilization':'scholar'}]})


class M1Tests(unittest.TestCase):
    def test_version_is_public_and_retired_goals_cannot_be_selected(self):
        runtime=fixture()
        rules=runtime.lua.globals().dofile('/games/civcraft/campaign_rules.lua')
        view=runtime.observe(0)
        self.assertEqual(view['contentRules'],'balance1')
        self.assertEqual(view['roundLimit'],250)
        self.assertFalse(rules.enabled(runtime.state,'industrial'))
        self.assertFalse(rules.enabled(runtime.state,'diplomatic'))
        runtime.pump()
        for p in runtime.state.players.values():
            self.assertNotIn(p.aiPlan.primary,('industrial','diplomatic'))

    def test_old_profile_restoration_does_not_select_new_rules(self):
        original=fixture(version='p1')
        original.pump()
        payload=original.canonical_state()
        resumed=fixture()
        resumed.restore(payload)
        systems=resumed.lua.globals().dofile('/games/civcraft/systems.lua')
        resumed.call(systems.migrate,resumed.state)
        self.assertEqual(resumed.state.contentRules,'p1')
        self.assertEqual(resumed.state.roundLimit,180)
        original.advance()
        resumed.advance()
        self.assertEqual(original.state_hash(),resumed.state_hash())

    def test_score_is_mandatory_at_new_deadline(self):
        runtime=fixture()
        runtime.state.victories=runtime.lua.table_from({'score':False,'industrial':True,'diplomatic':True})
        victory=runtime.lua.globals().dofile('/games/civcraft/victory.lua')
        runtime.state.round=249
        runtime.call(victory.check,runtime.state,False)
        self.assertEqual(runtime.state.phase,'game')
        runtime.state.round=250
        runtime.call(victory.check,runtime.state,False)
        self.assertEqual(runtime.state.phase,'over')
        self.assertIn('SCORE',runtime.state.victoryReason)

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'),'Optional LuaJIT extension absent')
    def test_m1_short_cross_backend_continuation(self):
        original,resumed=fixture(),fixture('luajit21')
        original.pump()
        original.advance()
        resumed.restore(original.canonical_state())
        for _ in range(3):
            original.pump();resumed.pump()
            self.assertEqual(original.state_hash(),resumed.state_hash())
            self.assertEqual(original.observe(0),resumed.observe(0))
            original.advance();resumed.advance()
            self.assertEqual(original.state_hash(),resumed.state_hash())


if __name__=='__main__':unittest.main()
