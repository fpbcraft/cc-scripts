-- FPBCRAFT TIDEBOUND / installer & updater
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
-- Optional: ref (main by default), --startup (opt-in automatic launch)
local args={...}
local ref,autostart="main",false
for _,a in ipairs(args)do
 if a=="--startup"then autostart=true
 elseif a=="--no-startup"then autostart=false
 else ref=a end
end
assert(ref:match("^[%w._/-]+$") and not ref:find("..",1,true),"Invalid git ref")
assert(http and http.get,"CC:Tweaked HTTP must be enabled")
local root="/tidebound"
local staging=root.."/.next"
local backup=root.."/.previous"
local base="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/tidebound/"
local files={"tidebound.lua","tidebound-kingdoms.lua","tidebound-classic.lua"}
local function drop(p)if fs.exists(p)then fs.delete(p)end end
local function write(path,data)
 local f,err=fs.open(path,"w");assert(f,"Write failed: "..path..": "..tostring(err))
 f.write(data);f.close()
end
local function read(path)
 local f=fs.open(path,"r");if not f then return nil end
 local data=f.readAll();f.close();return data
end
local function fetch(path)
 local h,err=http.get(base..path,nil,true)
 assert(h,"Download failed: "..path.." ("..tostring(err)..")")
 local code=h.getResponseCode and h.getResponseCode() or 200
 local content=h.readAll();h.close()
 assert(code==200 and content and #content>300,"HTTP "..tostring(code).." for "..path)
 assert(load(content,"@"..path,"t"),"Downloaded "..path.." has a syntax error")
 return content
end
print("TIDEBOUND: STELLAR FRONTIER / INSTALLER")
print("Source: fpbcraft/cc-scripts @ "..ref)
if not fs.exists(root)then fs.makeDir(root)end
-- Saves live directly in /tidebound/save.dat and are never moved/deleted.
drop(staging);fs.makeDir(staging)
local ok,err=pcall(function()
 for _,filename in ipairs(files)do
  write(fs.combine(staging,filename),fetch(filename))
  print("Downloaded "..filename)
 end
end)
if not ok then drop(staging);error("No files updated: "..tostring(err),0)end
-- All remote files have been fetched and parsed before changing the live install.
drop(backup);fs.makeDir(backup)
local movedOld={};local movedNew={}
local changed,reason=pcall(function()
 for _,filename in ipairs(files)do
  local target=fs.combine(root,filename)
  if fs.exists(target)then
   fs.move(target,fs.combine(backup,filename));movedOld[#movedOld+1]=filename
  end
  fs.move(fs.combine(staging,filename),target);movedNew[#movedNew+1]=filename
 end
end)
if not changed then
 for _,filename in ipairs(movedNew)do drop(fs.combine(root,filename))end
 for _,filename in ipairs(movedOld)do
  fs.move(fs.combine(backup,filename),fs.combine(root,filename))
 end
 drop(staging);drop(backup);error("Activation rolled back: "..tostring(reason),0)
end
drop(staging);drop(backup)
if autostart then
 local launcher="shell.run('/tidebound/tidebound.lua')\n"
 local startup="/startup.lua"
 local shadow="/startup"
 local old=fs.exists(startup) and read(startup) or nil
 local other=fs.exists(shadow) and read(shadow) or nil
 if other and other~=launcher then
  print("Not changing startup: unrelated /startup exists.")
  print("Launch manually or move the startup file and reinstall --startup.")
 elseif old and old~=launcher and fs.exists("/startup.tidebound-backup.lua") then
  print("Not changing startup: old backup path already exists.")
 else
  if old and old~=launcher then fs.copy(startup,"/startup.tidebound-backup.lua")end
  if other then drop(shadow)end
  write(startup,launcher)
  print("Autostart: enabled (previous startup retained if present)")
 end
else print("Autostart: unchanged (pass --startup to enable)")end
print("Installed! Run: /tidebound/tidebound.lua")
print("Previous game: /tidebound/tidebound-kingdoms.lua")
print("Saved galaxy remains at /tidebound/save.dat")