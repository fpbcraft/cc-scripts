-- FPBCRAFT factory entry point. Kept tiny for crash reporting and updates.
local dir=fs.getDir(shell.getRunningProgram())
local function load(name)
  return dofile(fs.combine(dir,name..".lua"))
end
local core=load("core").new(dir)
local ok,err=xpcall(function()
  load("ui").run(core)
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
