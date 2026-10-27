"""Read-only pacing instrumentation must retain actual game trajectories."""
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/civcraft_lab'))
sys.path.insert(0, str(ROOT / 'games/civcraft/research/lab'))
from p1_pacing_study import OpeningRuntime, configurations
from run_fixed_personality_ablation import FixedPersonalityRuntime


class PacingProbeTests(unittest.TestCase):
    def check_backend(self, backend):
        for config in configurations(backend)[:2]:
            original, measured = FixedPersonalityRuntime(config), OpeningRuntime(config)
            for _ in range(5):
                original.pump()
                measured.pump()
                before = measured.state_hash()
                metric = measured.metrics()
                self.assertEqual(measured.state_hash(), before)
                self.assertEqual(measured.state_hash(), original.state_hash())
                self.assertIn('settlersTrained', metric['players'][0])
                original.advance()
                measured.advance()
                self.assertEqual(measured.state_hash(), original.state_hash())

    def test_lua53(self):
        self.check_backend('lua53')

    @unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension absent')
    def test_luajit(self):
        self.check_backend('luajit21')


if __name__ == '__main__':
    unittest.main()
