-- COGWORKS / safe one-command installer & updater for CC:Tweaked.
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-cogworks.lua
-- Optional: <branch-or-tag> --startup (never overwrite an unrelated startup script)
local args={...}
local ref="main";local startup=false
for _,arg in ipairs(args)do
 if arg=="--startup"then startup=true
 elseif arg=="--no-startup"then startup=false
 else ref=arg end
end
assert(ref:match("^[%w%._/-]+$") and not ref:find("..",1,true),"Invalid ref")
assert(http and http.get,"Enable HTTP in CC:Tweaked to install COGWORKS")
local root="/cogworks";local stage=root.."/.install-next";local backup=root.."/.install-backup"
local base="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/cogworks/"
local files={"main.lua","display.lua","terminal_view.lua","app.lua","storage.lua","engine.lua","levels.lua","expansion.lua","tutorials.lua","render.lua","README.md"}
local function remove(path)if fs.exists(path)then fs.delete(path)end end
local function mkdir(path)if not fs.exists(path)then fs.makeDir(path)end end
local function write(path,data)
 mkdir(fs.getDir(path))
 local h,err=fs.open(path,"w");assert(h,err or ("Unable to write "..path))
 h.write(data);h.close()
end
local function fetch(path)
 local h,err=http.get(base..path,nil,true)
 assert(h,"Download failed for "..path..": "..tostring(err))
 local code=h.getResponseCode and h.getResponseCode() or 200
 local body=h.readAll();h.close()
 assert(code==200 and body and #body>10,"Bad response for "..path..": "..tostring(code))
 if path:sub(-4)==".lua"then
  local chunk,reason=load(body,"@"..path,"t")
  assert(chunk,"Invalid Lua in "..path..": "..tostring(reason))
 end
 return body
end
print("COGWORKS: KINETIC LAB / INSTALLER")
print("Source: fpbcraft/cc-scripts @ "..ref)
mkdir(root);remove(stage);mkdir(stage)
local success,reason=pcall(function()
 for _,file in ipairs(files)do
  write(fs.combine(stage,file),fetch(file))
  print(" + "..file)
 end
end)
if not success then remove(stage);error("Install aborted; old files untouched: "..tostring(reason),0)end
remove(backup);mkdir(backup)
local movedOld,movedNew={},{}
local activated,issue=pcall(function()
 for _,file in ipairs(files)do
  local target=fs.combine(root,file)
  if fs.exists(target)then
   fs.move(target,fs.combine(backup,file));movedOld[#movedOld+1]=file
  end
  fs.move(fs.combine(stage,file),target);movedNew[#movedNew+1]=file
 end
end)
if not activated then
 for _,file in ipairs(movedNew)do remove(fs.combine(root,file))end
 for _,file in ipairs(movedOld)do
  local original=fs.combine(backup,file)
  if fs.exists(original)then fs.move(original,fs.combine(root,file))end
 end
 remove(stage);remove(backup)
 error("Install rolled back: "..tostring(issue),0)
end
remove(stage);remove(backup)
if startup then
 local target="/startup.lua"
 local launcher="shell.run('/cogworks/main.lua')\n"
 local existing=nil
 if fs.exists(target)then
  local h=fs.open(target,"r");if h then existing=h.readAll();h.close()end
 end
 if fs.exists("/startup")then
  print("Autostart unchanged: /startup already exists.")
 elseif existing and existing~=launcher then
  print("Autostart unchanged: unrelated /startup.lua exists.")
 else
  if not existing then write(target,launcher)end
  print("Autostart enabled.")
 end
end
print("Installed. Run: /cogworks/main.lua")
print("Old /cogworks/save.dat and all /cogworks/saves/ are preserved.")
