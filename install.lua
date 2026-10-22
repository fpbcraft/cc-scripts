-- FPBCRAFT CC:Tweaked factory installer / updater.
-- Run: wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install.lua
-- Optional: append a branch name for development builds.
local args={...}
local ref=args[1] or "main"
if not ref:match("^[a-zA-Z0-9._/-]+$") or ref:find("..",1,true) then
  error("Invalid branch/ref",0)
end
local root="/fpb-factory"
local nextDir="/fpb-factory.next"
local backup="/fpb-factory.backup"
local url="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/factory/"
local files={"main.lua","ui.lua","core.lua","devices.lua","completions.lua","remote.lua","layout.lua"}
local function fail(msg)
  printError("Installation failed: "..msg)
  error(msg,0)
end
local function write(path,bytes)
  local f,err=fs.open(path,"w")
  if not f then fail(tostring(err)) end
  f.write(bytes)
  f.close()
end
local function download(path,remote)
  local response,err=http.get(remote,nil,true)
  if not response then return false,tostring(err or "HTTP request failed") end
  local code=response.getResponseCode and response.getResponseCode() or 200
  if code~=200 then response.close();return false,"HTTP "..tostring(code) end
  local bytes=response.readAll()
  response.close()
  if not bytes or #bytes<20 then return false,"Empty or invalid response" end
  write(path,bytes)
  return true
end
local function clean(path)
  if fs.exists(path) then fs.delete(path) end
end
print("FPBCRAFT Factory Control installer")
print("Source: fpbcraft/cc-scripts ("..ref..")")
if not http then fail("ComputerCraft HTTP is disabled") end
clean(nextDir)
fs.makeDir(nextDir)
for _,name in ipairs(files) do
  write("/fpb-factory.install-progress","downloading "..name)
  local ok,err=download(fs.combine(nextDir,name),url..name)
  if not ok then clean(nextDir);fail(name..": "..err
     .."\nNote: a PRIVATE GitHub repository cannot be downloaded anonymously.") end
  print("Fetched "..name)
end
-- Ensure Basalt ships together with the application.
local function installBasalt()
  local path=fs.combine(nextDir,"basalt.lua")
  local success=shell.run("wget","run","https://basalt.madefor.cc/2.5/install.lua",
                          "minified",path)
  return success and fs.exists(path)
end
if not installBasalt() then
  clean(nextDir)
  fail("Basalt 2.5 installation failed; old version was not touched")
end
print("Installed Basalt 2.5 dependency")
-- Transfer live data before swapping; keep a full rollback backup.
if fs.exists(root) then
  if fs.exists(fs.combine(root,"data")) then
    fs.copy(fs.combine(root,"data"),fs.combine(nextDir,"data"))
  end
end
clean(backup)
if fs.exists(root) then fs.move(root,backup) end
local swapped,swapErr=pcall(fs.move,nextDir,root)
if not swapped then
  if fs.exists(backup) then fs.move(backup,root) end
  fail("Could not activate new version: "..tostring(swapErr))
end
clean("/fpb-factory.install-progress")
-- This computer is dedicated to the Factory Manager: ensure it launches on
-- every normal root-disk boot, even if another startup program existed.
-- Preserve older startup programs as backups; do not accidentally run an old
-- factory controller alongside the new one.
local launcher="shell.run('/fpb-factory/main.lua')\n"
local startup="/startup.lua"
local previous="/startup"
local function backupStartup(path,backupPath)
  if not fs.exists(path) then return end
  if fs.isDir and fs.isDir(path) then return end
  if fs.exists(backupPath) then fs.delete(backupPath) end
  fs.copy(path,backupPath)
end
-- An extensionless /startup file can shadow /startup.lua in CraftOS.
if fs.exists(previous) and not (fs.isDir and fs.isDir(previous)) then
  backupStartup(previous,"/startup.fpb-factory-backup")
  fs.delete(previous)
  print("Backed up older /startup entrypoint.")
end
local shouldWrite=true
if fs.exists(startup) then
  local f=fs.open(startup,"r")
  local current=f and f.readAll() or ""
  if f then f.close() end
  if current==launcher then
    shouldWrite=false
  else
    backupStartup(startup,"/startup.fpb-factory-backup.lua")
    print("Backed up previous startup.lua (will no longer run automatically).")
  end
end
if shouldWrite then
  local tempStartup="/startup.fpb-factory-next.lua"
  write(tempStartup,launcher)
  if fs.exists(startup) then fs.delete(startup) end
  fs.move(tempStartup,startup)
end
print("Auto-start configured: /startup.lua -> /fpb-factory/main.lua")
-- CraftOS may prefer boot scripts on a connected disk; warn explicitly.
if settings and settings.get and settings.get("shell.allow_startup")==false then
  print("WARNING: shell.allow_startup is disabled in CraftOS settings.")
  print("Enable it and save settings for automatic startup.")
end
print("Install/update complete")
print("Previous install: "..backup)
print("Run now: /fpb-factory/main.lua")
print("Or reboot to launch Factory Manager automatically.")
