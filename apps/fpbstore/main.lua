-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/apps/fpbstore/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/apps/fpbstore" then
  -- selene: allow(undefined_variable) -- Selene misidentifies chunk-level varargs.
  return bootstrap().run("/apps/fpbstore", "main.lua", _ENV, ...)
end
-- The launcher uses the same portable UI on every supported terminal.
local function module(name)
  if type(require) == "function" then
    return require(name)
  end
  return dofile("/" .. name:gsub("%.", "/") .. ".lua")
end
local manager = module("apps.fpbstore.manager")
if (...) == "--test-api" then
  return manager
end
-- Basalt 2.5 is the primary interface. The legacy text UI remains available
-- on existing installations until the Store's Basalt dependency is installed.
local runner
local ok, basalt = pcall(module, "basalt")
if ok and type(basalt) == "table" and type(basalt.getMainFrame) == "function"
  and type(basalt.run) == "function" and type(basalt.stop) == "function" then
  runner = module("apps.fpbstore.basalt_ui")
else
  runner = module("apps.fpbstore.launcher")
end
if runner.run(manager, basalt) == "reload" then
  -- Fresh loader/cache picks up the updated catalog and manager immediately.
  local loader = assert(loadfile("/apps/fpbstore/_lib/fpb/loader.lua"))()
  return loader.run("/apps/fpbstore", "main.lua", _ENV)
end
