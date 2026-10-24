-- Regression test: CraftOS injects require per shell program, not globally.
-- main.lua must load its modules through that injected require (not dofile).
local loaded={}
local core={
  shutdown=function() loaded.shutdown=true end,
}
local modules={
  core={new=function(dir)
    assert(dir=="factory","unexpected module data directory: "..tostring(dir))
    loaded.created=true
    return core
  end},
  ui={run=function(actual)
    assert(actual==core)
    loaded.ran=true
  end},
}
local env={
  shell={getRunningProgram=function() return "apps/factory/main.lua" end},
  fs={getDir=function(path)
    assert(path=="apps/factory/main.lua")
    return "factory"
  end},
  require=function(name)
    assert(modules[name],"Unexpected require: "..tostring(name))
    loaded[name]=(loaded[name] or 0)+1
    return modules[name]
  end,
}
setmetatable(env,{__index=_G})
local chunk=assert(loadfile("apps/factory/main.lua","t",env))
chunk()
assert(loaded.core==1 and loaded.ui==1 and loaded.created and loaded.ran and loaded.shutdown)
print("CraftOS module loader test passed")
