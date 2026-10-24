-- IRONSPIRE v0.2.0 safe installer / updater
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-ironspire.lua
local args={...};local ref="main";local startup=false
for _,a in ipairs(args)do if a=="--startup"then startup=true elseif a=="--no-startup"then startup=false else ref=a end end
assert(ref:match("^[%w%._/-]+$") and not ref:find("..",1,true),"Invalid git ref")
assert(fs and http and http.get,"Enable HTTP on your CC:Tweaked computer")
local root="/ironspire";local stage=root.."/.install-stage";local backup=root.."/.install-backup"
local files={"main.lua","render.lua","map.lua","README.md"}
local remote="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/ironspire/"
local function remove(path)if fs.exists(path)then fs.delete(path)end end
local function write(path,value)
 local dir=fs.getDir(path);if not fs.exists(dir)then fs.makeDir(dir)end
 local h,e=fs.open(path,"w");assert(h,e);h.write(value);h.close()
end
local function get(path)
 local r,err=http.get(remote..path,nil,true);assert(r,"Download failed: "..path.." "..tostring(err))
 local status=r.getResponseCode and r.getResponseCode() or 200
 local value=r.readAll();r.close()
 assert(status==200 and value and #value>20,"Invalid download: "..path)
 if path:sub(-4)==".lua"then assert(load(value,"@"..path,"t"),"Invalid Lua syntax: "..path)end
 return value
end
if not fs.exists(root)then fs.makeDir(root)end
remove(stage);fs.makeDir(stage)
local ok,err=pcall(function()
 for _,path in ipairs(files)do write(fs.combine(stage,path),get(path));print(" + "..path)end
end)
if not ok then remove(stage);error("Installation aborted: "..tostring(err),0)end
remove(backup);fs.makeDir(backup)
local moved,new={},{}
local success,reason=pcall(function()
 for _,path in ipairs(files)do
  local dst,prior=fs.combine(root,path),fs.combine(backup,path)
  if fs.exists(dst)then fs.move(dst,prior);moved[#moved+1]=path end
  fs.move(fs.combine(stage,path),dst);new[#new+1]=path
 end
 local entry,why=loadfile(root.."/main.lua")
 assert(entry,"Boot check failed: "..tostring(why))
 if package and require then
  local good,api=pcall(entry,"--test-api")
  assert(good and type(api)=="table" and type(api.UI)=="table","Game API verification failed: "..tostring(api))
 end
end)
if not success then
 for _,path in ipairs(new)do remove(fs.combine(root,path))end
 for _,path in ipairs(moved)do fs.move(fs.combine(backup,path),fs.combine(root,path))end
 remove(stage);remove(backup);error("Update rolled back: "..tostring(reason),0)
end
remove(stage);remove(backup)
if startup then
 local launch="shell.run('/ironspire/main.lua')\n"
 if not fs.exists("/startup.lua")then write("/startup.lua",launch)
 else print("Existing startup.lua preserved.")end
end
print("IRONSPIRE installed. Start with /ironspire/main.lua")
print("Saves preserved under /ironspire/data/")
