"""Optional backend contract checks; standard CI need not install LuaJIT."""
import importlib.util
import sys
import unittest
import tempfile
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/civcraft_lab'))
from runtime import Runtime
from runner import play, write_run
from workers import run_bounded


def config(backend='luajit21'):
    return {'seed': 75123, 'runtimeBackend': backend, 'contentRules': 'p1', 'hostileMode': 'off',
            'players': [{'civilization': 'scholar'}, {'civilization': 'forge'}], 'maxRounds': 4}


class BackendValidationTests(unittest.TestCase):
    def test_batches_default_to_jit_and_preserve_explicit_reference(self):
        configs = [config(), config('lua53')]
        del configs[0]['runtimeBackend']
        with tempfile.TemporaryDirectory() as directory:
            with patch('workers.run_bounded', return_value=[]) as run:
                write_run(configs, Path(directory) / 'result.json')
        submitted = run.call_args.args[0]
        self.assertEqual([c['runtimeBackend'] for c in submitted], ['luajit21', 'lua53'])
        self.assertNotIn('runtimeBackend', configs[0])

    def test_unknown_backend_rejected(self):
        result = play(config('unknown'))
        self.assertEqual(result['status'], 'error')
        self.assertIn('runtimeBackend', result['error'])


@unittest.skipUnless(importlib.util.find_spec('lupa.luajit21'), 'Optional LuaJIT extension is not installed')
class LuaJITTests(unittest.TestCase):
    def test_detached_observation_and_rejected_action(self):
        runtime = Runtime(config())
        before = runtime.state_hash()
        view = runtime.observe(0)
        view['players'][0]['gold'] = -99
        self.assertEqual(runtime.state_hash(), before)
        self.assertFalse(runtime.apply(0, {'action': 'researchTech', 'id': 'netherite'})[0])
        self.assertEqual(runtime.state_hash(), before)

    def test_cross_backend_checkpoint(self):
        original = Runtime(config('lua53'))
        original.pump()
        original.advance()
        restored = Runtime(config())
        restored.restore(original.canonical_state())
        for _ in range(3):
            original.pump()
            restored.pump()
            self.assertEqual(original.state_hash(), restored.state_hash())
            original.advance()
            restored.advance()
            self.assertEqual(original.observe(0), restored.observe(0))

    def test_p1_contracts_under_jit(self):
        # Run the existing behavioral contracts, rather than duplicate the rule assertions.
        from tests import test_civcraft_p1
        from unittest.mock import patch
        def jit_runtime(settings):
            return Runtime(settings | {'runtimeBackend': 'luajit21'})
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(test_civcraft_p1.P1Tests)
        result = unittest.TestResult()
        with patch.object(test_civcraft_p1, 'Runtime', jit_runtime):
            suite.run(result)
        self.assertEqual(result.testsRun, 4)
        self.assertEqual(result.errors + result.failures, [])

    def test_small_instruction_budget_still_errors(self):
        result = play(config() | {'instructionBudget': 10000})
        self.assertEqual(result['status'], 'error')
        self.assertIn('LAB_INSTRUCTION_BUDGET', result['error'])

    def test_external_timeout_is_not_a_victory(self):
        settings = config() | {'mapSize': 'vast', 'wallSeconds': 1, 'maxRounds': 180,
                               'players': [{'civilization': 'forge'} for _ in range(4)]}
        result = run_bounded([settings], 1)[0]
        self.assertEqual(result['status'], 'timeout')
        self.assertNotIn('victoryReason', result)


if __name__ == '__main__':
    unittest.main()
