-- One-command FPBCRAFT remote node installer/updater.
-- wget run <raw.../node/install.lua> [git_ref] [node_name]
local args={...}
local ref=args[1] or "main"
local label=args[2]
if not ref:match("^[%w._/-]+$") or ref:find("..",1,true) then
  error("Invalid Git reference",0)
end
local dest="/fpb-node"
local staged="/fpb-node.next"
local backup="/fpb-node.backup"
local address="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..
  ref.."/node/main.lua"
local function write(path,bytes)
  local f,err=fs.open(path,"w")
  if not f then error("Cannot write "..path..": "..tostring(err),0) end
  f.write(bytes)
  f.close()
end
local function read(path)
  if not fs.exists(path) or fs.isDir(path) then return nil end
  local f=fs.open(path,"r")
  if not f then return nil end
  local value=f.readAll();f.close()
  return value
end
local function fetch(url)
  local response,err=http.get(url,nil,true)
  if not response then error("Download failed: "..tostring(err),0) end
  local code=response.getResponseCode and response.getResponseCode() or 200
  local body=response.readAll()
  response.close()
  if code~=200 or not body or #body<100 then
    error("Download failed (HTTP "..tostring(code)..")",0)
  end
  return body
end
print("FPBCRAFT Remote Node installer")
print("Source: "..ref)
local script=fetch(address)
if fs.exists(staged) then fs.delete(staged) end
fs.makeDir(staged)
write(fs.combine(staged,"main.lua"),script)
local original=fs.combine(dest,"config.db")
local cfg={}
local raw=read(original)
if raw then
  local ok,result=pcall(textutils.unserialize,raw)
  if ok and type(result)=="table" then cfg=result end
end
if label and label~="" then cfg.name=label:sub(1,40) end
if not cfg.name or cfg.name=="" then
  cfg.name="Factory Node "..os.getComputerID()
end
write(fs.combine(staged,"config.db"),textutils.serialize(cfg))
-- Always retain an installation backup before swapping.
if fs.exists(backup) then fs.delete(backup) end
if fs.exists(dest) then fs.move(dest,backup) end
local ok,err=pcall(fs.move,staged,dest)
if not ok then
  if fs.exists(backup) then fs.move(backup,dest) end
  error("Activation failed: "..tostring(err),0)
end
-- Dedicated node computers always start this agent on boot. Existing startup
-- programs are backed up but not run simultaneously.
for _,p in ipairs({"/startup","/startup.lua"}) do
  if fs.exists(p) and not fs.isDir(p) then
    local backupName=p..".fpb-node-backup"
    if fs.exists(backupName) then fs.delete(backupName) end
    fs.copy(p,backupName)
    fs.delete(p)
  end
end
write("/startup.lua","shell.run('/fpb-node/main.lua')\n")
print("Installed node: "..cfg.name)
print("Startup: /fpb-node/main.lua")
print("Previous version: "..backup)
print("Reboot to start automatically or run /fpb-node/main.lua")
