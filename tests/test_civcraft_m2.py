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

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension is not installed')
    def test_builder_work_and_saved_queue_match_under_jit(self):
        config = {'seed': 75123, 'contentRules': 'balance3', 'hostileMode': 'off',
                  'players': [{'civilization': 'verdant'}, {'civilization': 'forge'}]}
        reference = Runtime(config | {'runtimeBackend': 'lua53'})
        accelerated = Runtime(config | {'runtimeBackend': 'luajit21'})
        prepare = reference.lua.eval("""function(state)
            local systems=dofile('/games/civcraft/systems.lua')
            local works=dofile('/games/civcraft/tile_improvements.lua')
            local world=dofile('/games/civcraft/world.lua')
            local hex=dofile('/games/civcraft/hex.lua')
            local player=state.players[1]
            player.techs.agriculture=true
            for _,city in ipairs(state.cities) do
                if city.owner==player.id then
                    for _,tile in ipairs(systems.workable(state,city)) do
                        if works.canPlace(state,player,'farm',tile.x,tile.y,systems) then
                            local unit={id=state.nextId,owner=player.id,kind='builder',charges=3,
                                        x=tile.x,y=tile.y,movesLeft=0,moved=true,hp=100}
                            state.nextId=state.nextId+1
                            state.units[#state.units+1]=unit
                            world.reveal(state,hex,systems)
                            return unit.id,tile.x,tile.y
                        end
                    end
                end
            end
            error('Expected one eligible development tile')
        end""")
        unit_id, x, y = reference.call(prepare, reference.state)
        accelerated.restore(reference.canonical_state())
        request = {'action': 'queueWork', 'unitID': unit_id, 'x': x, 'y': y,
                   'tileX': x, 'tileY': y, 'kind': 'farm'}
        self.assertTrue(reference.apply(0, request)[0])
        self.assertTrue(accelerated.apply(0, request)[0])
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        accelerated.restore(reference.canonical_state())
        saved_builder = next(u for u in accelerated.state.units.values() if u.id == unit_id)
        self.assertEqual(saved_builder.charges, 3)
        self.assertEqual(saved_builder.workQueue.tasks[1].kind, 'farm')
        reference.pump()
        accelerated.pump()
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        reference.advance()
        accelerated.advance()
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        reference.pump()
        accelerated.pump()
        self.assertEqual(reference.state_hash(), accelerated.state_hash())
        completed_builder = next(u for u in accelerated.state.units.values() if u.id == unit_id)
        self.assertEqual(completed_builder.charges, 2)
        self.assertEqual(reference.observe(0), accelerated.observe(0))


if __name__ == '__main__':
    unittest.main()
