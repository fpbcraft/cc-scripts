"""Behavior and safety tests for selective Lua regression planning."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).parent))
from ci_lua_select import plan, select, shard_count


class SelectiveLuaTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.write("games/civcraft/ai_tactics.lua", "return {}\n")
        self.write("games/civcraft/ai.lua", 'dofile("/games/civcraft/ai_tactics.lua")\n')
        self.write("games/civcraft/render.lua", "return {}\n")
        self.write("games/cogworks/engine.lua", "return {}\n")
        self.write("tests/civcraft_tactics_test.lua", 'dofile("games/civcraft/ai.lua")\n')
        self.write("tests/civcraft_render_batch_test.lua", 'dofile("games/civcraft/render.lua")\n')
        self.write("tests/cogworks_engine_test.lua", 'dofile("games/cogworks/engine.lua")\n')
        self.write("tests/core_test.lua", "assert(true)\n")
        self.write("tests/loader_test.lua", "assert(true)\n")
        self.write("tests/packages_test.lua", "assert(true)\n")

    def write(self, path, content):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content, encoding="utf-8")

    def pick(self, *paths):
        return select(self.root, list(paths))

    def test_transitive_civcraft_module(self):
        names, details, reason = self.pick("games/civcraft/ai_tactics.lua")
        self.assertIsNone(reason)
        self.assertIn("civcraft_tactics_test.lua", names)
        self.assertNotIn("civcraft_render_batch_test.lua", names)
        self.assertNotIn("cogworks_engine_test.lua", names)
        self.assertIn("core_test.lua", names)
        self.assertTrue(details["civcraft_tactics_test.lua"])

    def test_cogworks_isolation(self):
        names, _, reason = self.pick("games/cogworks/engine.lua")
        self.assertIsNone(reason)
        self.assertIn("cogworks_engine_test.lua", names)
        self.assertNotIn("civcraft_tactics_test.lua", names)

    def test_cross_domain_import(self):
        self.write("tests/cogworks_engine_test.lua", 'dofile("games/civcraft/ai.lua")\n')
        names, _, reason = self.pick("games/civcraft/ai_tactics.lua")
        self.assertIsNone(reason)
        self.assertIn("cogworks_engine_test.lua", names)

    def test_core_module_broadens_domain(self):
        names, _, reason = self.pick("games/civcraft/render.lua")
        self.assertIsNone(reason)
        self.assertIn("civcraft_tactics_test.lua", names)
        self.assertIn("civcraft_render_batch_test.lua", names)
        self.assertNotIn("cogworks_engine_test.lua", names)

    def test_unknown_dependent_broadens_domain(self):
        self.write("games/civcraft/unused.lua", "return true\n")
        names, _, reason = self.pick("games/civcraft/unused.lua")
        self.assertIsNone(reason)
        self.assertIn("civcraft_tactics_test.lua", names)
        self.assertIn("civcraft_render_batch_test.lua", names)

    def test_dynamic_import_broadens_domain(self):
        self.write("games/civcraft/ai_tactics.lua", "return dofile(path)\n")
        names, _, reason = self.pick("games/civcraft/ai_tactics.lua")
        self.assertIsNone(reason)
        self.assertIn("civcraft_render_batch_test.lua", names)
        self.assertNotIn("cogworks_engine_test.lua", names)

    def test_shared_code_and_ci_force_full(self):
        for changed in ("lib/fpb/runtime.lua", "scripts/ci_lua_select.py",
                        ".github/workflows/lua-check.yml", "tests/helpers/fixture.lua"):
            names, _, reason = self.pick(changed)
            self.assertIsNotNone(reason)
            self.assertEqual(len(names), 6)

    def test_unknown_config_forces_full(self):
        names, _, reason = self.pick("Makefile")
        self.assertIsNotNone(reason)
        self.assertEqual(len(names), 6)

    def test_docs_only_selects_no_tests(self):
        names, _, reason = self.pick("README.md", "games/civcraft/README.md")
        self.assertEqual(names, set())
        self.assertIsNone(reason)
        result = plan(self.root, names, {}, reason, 9)
        self.assertEqual(result["matrix"], {"include": []})
        self.assertFalse(result["run_tests"])

    def test_changed_test_only_plus_smoke(self):
        names, _, reason = self.pick("tests/cogworks_engine_test.lua")
        self.assertIsNone(reason)
        self.assertEqual(names, {
            "cogworks_engine_test.lua", "core_test.lua", "loader_test.lua",
            "packages_test.lua",
        })

    def test_deleted_or_unknown_test_forces_full(self):
        names, _, reason = self.pick("tests/civcraft_deleted_test.lua")
        self.assertIsNotNone(reason)
        self.assertEqual(len(names), 6)

    def test_zero_change_list_fails_open(self):
        names, _, reason = self.pick()
        self.assertIsNotNone(reason)
        self.assertEqual(len(names), 6)

    def test_shard_allocation(self):
        self.assertEqual(shard_count(set(), 9), 0)
        self.assertEqual(shard_count({"core_test.lua"}, 9), 1)
        self.assertEqual(shard_count({"civcraft_controls_test.lua"}, 9), 9)
        self.assertEqual(shard_count({"civcraft_hud_test.lua"}, 9), 2)
        result = plan(self.root, {"core_test.lua"}, {}, None, 9)
        self.assertEqual(result["matrix"]["include"], [{"shard": 0, "shards": 1}])
        self.assertEqual(result["tests"], ["tests/core_test.lua"])


if __name__ == "__main__":
    unittest.main()
