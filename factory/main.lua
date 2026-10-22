-- FPBCRAFT factory entry point. Kept tiny for crash reporting and updates.
local dir=fs.getDir(shell.getRunningProgram())
-- Use the per-program require injected by the CraftOS shell. Unlike dofile(),
-- require() gives each module a module environment with require/package available.
-- This is required by Basalt 2.5 and its optional chart modules.
local core=require("core").new(dir)
local ok,err=xpcall(function()
  require("ui").run(core)
end,debug.traceback)
core:shutdown()
if not ok then
  term.redirect(term.native())
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  print("FPBCRAFT factory controller crashed:")
  print(err)
  local path=fs.combine(core.dir,"crash.log")
  local f=fs.open(path,"w")
  if f then
    f.write(tostring(err))
    f.close()
    print("Saved error to "..path)
  end
  error("Factory UI stopped",0)
end
