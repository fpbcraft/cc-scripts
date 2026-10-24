-- FPB Store bootstrap / repeatable installer.
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-fpbstore.lua
-- Install once, then execute: store
local args={...}
local ref=args[1]or"main"
assert(type(ref)=="string" and ref:match("^[%w%._/-]+$") and
 not ref:find("..",1,true),"Invalid branch or tag")
assert(http and http.get,"Enable HTTP in CraftOS settings")
local root="/fpbstore"
local base="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/fpbstore/"
local paths={"main.lua","catalog.lua","manager.lua","README.md"}
local stage=root.."/.install-next"
local backup=root.."/.install-previous"
local function remove(path)if fs.exists(path)then fs.delete(path)end end
local function ensure(path)if not fs.exists(path)then fs.makeDir(path)end end
local function write(path,data)
 ensure(fs.getDir(path))
 local f,err=fs.open(path,"w")
 assert(f,err or "Unable to write "..path)
 f.write(data);f.close()
end
local function fetch(path)
 local response,err=http.get(base..path,nil,true)
 assert(response,"Download error: "..path.." "..tostring(err))
 local code=response.getResponseCode and response.getResponseCode() or 200
 local data=response.readAll();response.close()
 assert(code==200 and type(data)=="string" and #data>10,
  "HTTP "..tostring(code).." for "..path)
 if path:sub(-4)==".lua"then
  local fn,reason=load(data,"@"..path,"t")
  assert(fn,"Lua syntax error in "..path..": "..tostring(reason))
 end
 return data
end
ensure(root)
remove(stage);ensure(stage)
local ok,err=pcall(function()
 for _,file in ipairs(paths)do
  write(fs.combine(stage,file),fetch(file))
  print(" + "..file)
 end
end)
if not ok then remove(stage);error("No files changed: "..tostring(err),0)end
remove(backup);ensure(backup)
local old,new={},{}
local success,reason=pcall(function()
 for _,file in ipairs(paths)do
  local target=fs.combine(root,file)
  if fs.exists(target)then
   fs.move(target,fs.combine(backup,file));old[#old+1]=file
  end
  fs.move(fs.combine(stage,file),target);new[#new+1]=file
 end
end)
if not success then
 for _,file in ipairs(new)do remove(fs.combine(root,file))end
 for _,file in ipairs(old)do
  local prior=fs.combine(backup,file)
  if fs.exists(prior)then fs.move(prior,fs.combine(root,file))end
 end
 remove(stage);remove(backup)
 error("Store install rolled back: "..tostring(reason),0)
end
remove(stage);remove(backup)
-- Alias creation is opt-in to the name when no other program owns it.
local launcher="/store.lua"
local wrapper="shell.run('/fpbstore/main.lua')\n"
if not fs.exists(launcher)then
 write(launcher,wrapper)
 print("Launcher created: /store.lua")
else
 local f=fs.open(launcher,"r")
 local existing=f and f.readAll() or ""
 if f then f.close()end
 if existing~=wrapper then
  print("Existing /store.lua retained; launch /fpbstore/main.lua")
 end
end
print("FPB Store installed. Run: store")
print("Game installations and saves are unchanged.")
