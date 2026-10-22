-- FPBCRAFT Airship Navigation installer / updater (Basalt 2.5)
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-airship.lua
-- Optional: branch/ref as first arg, --no-startup to keep the current startup.
local args={...}
local ref="main"
local autoStartup=true
for _,a in ipairs(args) do
  if a=="--no-startup" then autoStartup=false
  else ref=a end
end
if not ref:match("^[%w._/-]+$") or ref:find("..",1,true) then
  error("Invalid Git ref",0)
end
local root="/fpb-airship"
local nextDir="/fpb-airship.next"
local backup="/fpb-airship.backup"
local url="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/airship/"
local function fail(msg)
  printError("Airship install failed: "..msg)
  error(msg,0)
end
local function remove(path)
  if fs.exists(path) then fs.delete(path) end
end
local function put(path,content)
  local handle,err=fs.open(path,"w")
  if not handle then fail("Cannot write "..path..": "..tostring(err)) end
  handle.write(content);handle.close()
end
local function download(path,uri)
  local response,err=http.get(uri,nil,true)
  if not response then return false,tostring(err or "network error") end
  local code=response.getResponseCode and response.getResponseCode() or 200
  if code~=200 then response.close();return false,"HTTP "..code end
  local bytes=response.readAll()
  response.close()
  if not bytes or #bytes<64 then return false,"Empty download" end
  put(path,bytes)
  return true
end
if not http then fail("Enable CC:Tweaked HTTP in the server config") end
print("FPBCRAFT AIRSHIP / INSTALL")
print("Source: fpbcraft/cc-scripts @ "..ref)
remove(nextDir)
fs.makeDir(nextDir)
for _,filename in ipairs({"autopilot.lua","ui.lua"}) do
  local ok,reason=download(fs.combine(nextDir,filename),url..filename)
  if not ok then
    remove(nextDir)
    fail(filename..": "..reason..". Repo must be publicly downloadable.")
  end
  print("Downloaded "..filename)
end
-- Same Basalt 2.5 distribution/install command used by factory/install.lua.
local basaltFile=fs.combine(nextDir,"basalt.lua")
local success=shell.run("wget","run","https://basalt.madefor.cc/2.5/install.lua",
  "minified",basaltFile)
if not success or not fs.exists(basaltFile) then
  remove(nextDir)
  fail("Basalt 2.5 download failed. Previous installation is unchanged.")
end
print("Basalt 2.5 ready")
-- Preserve all pilot data, including legacy computer-root installations.
local dataFiles={
  ".airship_avionics_route", ".airship_avionics_presets",
  ".airship_avionics_burners_settings",
  ".airship_autopilot_avionics_burners_calibration",
  ".airship_autopilot_avionics_calibration",
  "airship_autopilot_debug.log",
  ".airship_autopilot_control_error",
}
for _,filename in ipairs(dataFiles) do
  local source=fs.combine(root,filename)
  if not fs.exists(source) then
    -- The old standalone script often lives directly at /autopilot.lua.
    local legacy=fs.combine("/",filename)
    if fs.exists(legacy) then source=legacy end
  end
  if fs.exists(source) then
    fs.copy(source,fs.combine(nextDir,filename))
  end
end
remove(backup)
if fs.exists(root) then fs.move(root,backup) end
local ok,err=pcall(fs.move,nextDir,root)
if not ok then
  if fs.exists(backup) then fs.move(backup,root) end
  fail("Activation failed: "..tostring(err))
end
-- Autostart only on a dedicated airship computer. Existing startup scripts
-- are backed up, never silently discarded. --no-startup is available.
if autoStartup then
  local launcher="shell.run('/fpb-airship/autopilot.lua')\n"
  for _,path in ipairs({"/startup","/startup.lua"}) do
    if fs.exists(path) and not (fs.isDir and fs.isDir(path)) then
      local suffix=path=="/startup" and ".old" or ".lua.old"
      local destination="/startup.fpb-airship-backup"..suffix
      local h=fs.open(path,"r")
      local previous=h and h.readAll() or ""
      if h then h.close() end
      if previous~=launcher then
        if not fs.exists(destination) then fs.copy(path,destination) end
      end
      -- An extensionless startup can shadow startup.lua in CraftOS.
      if path=="/startup" then fs.delete(path) end
    end
  end
  put("/startup.lua",launcher)
  print("Startup: /fpb-airship/autopilot.lua")
else
  print("Startup unchanged (--no-startup)")
end
if settings and settings.get and settings.get("shell.allow_startup")==false then
  print("Warning: enable shell.allow_startup to start automatically")
end
print("Installed to "..root)
print("Previous version in "..backup)
print("Run: /fpb-airship/autopilot.lua")
