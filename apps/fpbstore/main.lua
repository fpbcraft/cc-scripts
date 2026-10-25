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
local launcher = module("apps.fpbstore.launcher")
if launcher.run(manager) == "reload" then
  -- Fresh loader/cache picks up the updated catalog and manager immediately.
  local loader = assert(loadfile("/apps/fpbstore/_lib/fpb/loader.lua"))()
  return loader.run("/apps/fpbstore", "main.lua", _ENV)
end
