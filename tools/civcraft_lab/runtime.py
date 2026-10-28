"""Isolated Lua 5.3 execution of the same modules installed in CraftOS."""
from __future__ import annotations

import hashlib
import importlib
from pathlib import Path
from typing import Any

try:
    from lupa.lua53 import lua_type
except ImportError as exc:
    raise ImportError("Install tools/civcraft_lab/requirements.txt; Lua 5.3 Lupa is required") from exc

REPOSITORY = Path(__file__).resolve().parents[2]
BOOTSTRAP = """
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return {n=select('#', ...), ...} end
local native = dofile
dofile = function(path)
    if path:match('^/games/civcraft/') then return native(LAB_ROOT .. path) end
    if path:match('^/lab/') then
        return native(LAB_ROOT .. '/tools/civcraft_lab/' .. path:sub(6))
    end
    return native(path)
end
dofile('/games/civcraft/module_cache.lua').install(_G)
math.random = function() error('Uncontrolled math.random in deterministic simulation') end
math.randomseed = function() error('Use an explicit policy RNG stream') end
LAB_ENGINE = dofile('/lab/engine.lua')
LAB_CANONICAL = dofile('/lab/canonical.lua')
"""


def from_lua(value: Any) -> Any:
    value_type = lua_type(value)
    if value_type is None and type(value).__module__ == 'lupa.luajit21':
        value_type = importlib.import_module('lupa.luajit21').lua_type(value)
    if value_type != "table":
        return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and set(keys) == set(range(1, len(keys) + 1)):
        return [from_lua(value[i]) for i in range(1, len(keys) + 1)]
    return {str(key): from_lua(value[key]) for key in keys}


class Runtime:
    """One independent module cache and authoritative state per match."""

    def __init__(self, config: dict, *, instruction_budget: int = 200_000_000):
        if not isinstance(config, dict) or not isinstance(config.get('players'), list):
            raise ValueError('Configuration requires a player list')
        for field, default in [('maxRounds', 270), ('telemetryEvery', 1),
                               ('actionBudget', 4096), ('wallSeconds', 180)]:
            value = config.get(field, default)
            if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
                raise ValueError(f'{field} must be a positive integer')
        seed = config.get('seed', 12345)
        if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed < 2147483647:
            raise ValueError('World seed must be an integer in [0, 2147483647)')
        backend = config.get('runtimeBackend', 'lua53')
        if backend not in ('lua53', 'luajit21'):
            raise ValueError('runtimeBackend must be lua53 or luajit21')
        try:
            module = importlib.import_module('lupa.' + backend)
        except ImportError as exc:
            raise ImportError(f'Lupa backend {backend} is not installed; see LUAJIT_BACKEND.md') from exc
        self.lua = module.LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
        self.backend = backend
        self.runtime_info = {'backend': backend, 'luaVersion': self.lua.eval('_VERSION'),
                             'jitVersion': self.lua.eval('jit and jit.version or nil'),
                             'extensionSha256': hashlib.sha256(Path(module.__file__).read_bytes()).hexdigest()}
        self.lua.globals().LAB_ROOT = str(REPOSITORY)
        self.lua.execute(BOOTSTRAP)
        self.engine = self.lua.globals().LAB_ENGINE
        self.lua.globals().dofile('/lab/policies.lua').install(
            self.lua.table_from(config['players'], recursive=True))
        self._run_budgeted = self.lua.eval("""function(fn, limit, ...)
            local spent = 0
            debug.sethook(function()
                spent = spent + 10000
                if spent > limit then error('LAB_INSTRUCTION_BUDGET') end
            end, '', 10000)
            local results = table.pack(pcall(fn, ...))
            debug.sethook()
            if not results[1] then error(results[2], 0) end
            return table.unpack(results, 2, results.n)
        end""")
        self.instruction_budget = instruction_budget
        self.state = self.call(self.engine.newGame, self.lua.table_from(config, recursive=True))

    def call(self, function, *args):
        return self._run_budgeted(function, self.instruction_budget, *args)

    def observe(self, player_id: int):
        return from_lua(self.call(self.engine.observe, self.state, player_id))

    def apply(self, player_id: int, action: dict):
        return self.call(self.engine.applyAction, self.state, player_id,
                         self.lua.table_from(action, recursive=True))

    def pump(self):
        self.call(self.engine.pump, self.state)

    def advance(self):
        self.call(self.engine.advance, self.state)

    def metrics(self):
        return from_lua(self.call(self.engine.metrics, self.state))

    def canonical_state(self) -> str:
        return self.call(self.lua.globals().LAB_CANONICAL.encode, self.state)

    def state_hash(self) -> str:
        return hashlib.sha256(self.canonical_state().encode()).hexdigest()

    def restore(self, payload: str):
        """Restore a trusted research checkpoint; live saves retain their actual format."""
        restored = self.call(self.lua.globals().LAB_CANONICAL.decode, payload)
        if restored.version != 6 or restored.ruleset != 'create':
            raise ValueError('Unsupported research state schema')
        self.state = restored

    def finished(self) -> bool:
        return bool(self.engine.isFinished(self.state))
