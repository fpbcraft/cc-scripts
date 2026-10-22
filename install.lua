-- FPBCRAFT Factory Manager: low-disk, no-backup install/update.
local ref=({...})[1] or "main"
assert(ref:match("^[%w._/-]+$") and not ref:find("..",1,true),"Invalid git ref")
local root="/fpb-factory"
local base="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/factory/"
local names={"main.lua","ui.lua","core.lua","devices.lua","completions.lua",
  "remote.lua","auth.lua","layout.lua"}
local function remove(path)
  if fs.exists(path) then fs.delete(path) end
end
local function read(path)
  if not fs.exists(path) then return nil end
  local f=fs.open(path,"r")
  if not f then return nil end
  local value=f.readAll();f.close();return value
end
local function write(path,value)
  local f,err=fs.open(path,"w")
  assert(f,"Cannot write "..path..": "..tostring(err))
  f.write(value);f.close()
end
local function fetch(url)
  local h,err=http.get(url,nil,true)
  assert(h,"Download failed: "..tostring(err))
  local code=h.getResponseCode and h.getResponseCode() or 200
  local value=h.readAll();h.close()
  assert(code==200 and value and #value>20,"HTTP "..tostring(code).." at "..url)
  return value
end
local startup="/startup.lua"
local launcher="shell.run('/fpb-factory/main.lua')\n"
local oldStartup=read(startup)
local shadow=read("/startup")
-- No backup policy: reject unrelated startup scripts rather than deleting them.
if oldStartup and oldStartup~=launcher and
   not oldStartup:find("factory.lua",1,true) and
   not oldStartup:find("/fpb-factory/",1,true) then
  error("Unrelated /startup.lua exists. Move it yourself before installing. No backups are made.",0)
end
if shadow and not shadow:find("factory",1,true) then
  error("Unrelated extensionless /startup exists. Resolve it manually.",0)
end
print("FPBCRAFT Factory Manager updater (no backups)")
print("Source: "..ref)
-- Keep the active data directory, but reclaim space from old installer copies.
if not fs.exists(root) then fs.makeDir(root) end
if fs.exists("/fpb-factory.backup") and not fs.exists(root.."/data") and
   fs.exists("/fpb-factory.backup/data") then
  fs.move("/fpb-factory.backup/data",root.."/data")
end
remove("/fpb-factory.backup")
remove("/fpb-factory.next")
remove("/fpb-factory.install-progress")
remove("/startup.fpb-factory-backup")
remove("/startup.fpb-factory-backup.lua")
print("Removed old installer backups/staging to free disk space")
-- Fetch and parse-validate every script in memory before altering active files.
local downloaded={}
for _,name in ipairs(names) do
  local source=fetch(base..name)
  local chunk,err=load(source,"@"..name,"t")
  assert(chunk,"Syntax error in downloaded "..name..": "..tostring(err))
  downloaded[name]=source
  print("Fetched "..name)
end
-- Atomic per-file replace: only one temporary source file at a time.
-- Existing /data is never duplicated or deleted.
for _,name in ipairs(names) do
  local target=fs.combine(root,name)
  local temp=target..".new"
  remove(temp)
  write(temp,downloaded[name])
  remove(target)
  fs.move(temp,target)
  downloaded[name]=nil
end
-- Reuse installed Basalt. Only download dependency on first installation.
if not fs.exists(root.."/basalt.lua") then
  print("Installing Basalt...")
  local ok=shell.run("wget","run","https://basalt.madefor.cc/2.5/install.lua",
    "minified",root.."/basalt.lua")
  assert(ok and fs.exists(root.."/basalt.lua"),"Basalt installer failed")
end
if shadow then remove("/startup") end
if oldStartup~=launcher then
  local tmp="/startup.fpb-factory-next.lua"
  remove(tmp);write(tmp,launcher)
  remove(startup);fs.move(tmp,startup)
end
print("Factory Manager installed without a backup.")
print("Existing data retained at "..root.."/data")
print("Auto-start enabled. Run reboot to use the update.")
