-- Install actual SHATTERED bootstrap using an in-memory CraftOS filesystem.
-- Verifies migration does not destroy old saves or overwrite new campaigns.
local files,dirs={}, {["/"]=true,["/tidebound"]=true}
local function norm(p)return p:gsub("//+","/")end
fs={}
function fs.exists(p)return files[p]~=nil or dirs[p]==true end
function fs.makeDir(p)dirs[p]=true end
function fs.getDir(p)return p:match("^(.*)/[^/]+$")or"/"end
function fs.combine(a,b)return norm(a.."/"..b)end
function fs.open(p,mode)
 if mode=="r"then if not files[p]then return nil end
  return {readAll=function()return files[p]end,close=function()end}
 end
 local bytes=""
 return {write=function(s)bytes=bytes..s end,close=function()files[p]=bytes end}
end
function fs.copy(a,b)
 assert(files[a],"Missing migration source: "..a)
 files[b]=files[a]
end
function fs.move(a,b)
 assert(files[a]~=nil,"Missing file to move: "..a)
 files[b]=files[a];files[a]=nil
end
function fs.delete(p)
 files[p]=nil;dirs[p]=nil
 for path in pairs(files)do
  if path:sub(1,#p+1)==p.."/"then files[path]=nil end
 end
 for path in pairs(dirs)do
  if path:sub(1,#p+1)==p.."/"then dirs[path]=nil end
 end
end
local names={"shattered.lua","display.lua","terminal_view.lua",
 "expanse-v5/content.lua","expanse-v5/events.lua","expanse-v5/sim.lua",
 "expanse-v5/render.lua","expanse-v5/theme.lua","expanse-v5/ui.lua"}
http={get=function(url)
 local name=url:match("/shattered/(.-)%?")
 if not name then name=url:match("/shattered/(.*)")end
 local expected=false
 for _,p in ipairs(names)do if p==name then expected=true end end
 assert(expected,"Installer requested unknown file: "..tostring(name))
 local body="-- "..name.." generated installer fixture - "..string.rep("x",80).."\nreturn true\n"
 return {getResponseCode=function()return 200 end,
 readAll=function()return body end,close=function()end}
end}
files["/tidebound/v5-save.dat"]="original space campaign"
files["/tidebound/v5-save.dat.bak"]="original campaign backup"
local installer=assert(loadfile("install-shattered.lua"))
assert(pcall(installer,"main","--no-startup"))
assert(files["/shattered/v5-save.dat"]=="original space campaign")
assert(files["/shattered/v5-save.dat.bak"]=="original campaign backup")
assert(files["/tidebound/v5-save.dat"]=="original space campaign")
assert(files["/shattered/shattered.lua"] and files["/shattered/expanse-v5/ui.lua"])
-- Running again must not replace a newer save in the new location.
files["/shattered/v5-save.dat"]="newer campaign"
assert(pcall(installer,"main","--no-startup"))
assert(files["/shattered/v5-save.dat"]=="newer campaign")
assert(files["/tidebound/v5-save.dat"]=="original space campaign")
assert(not fs.exists("/shattered/.install-next") and
 not fs.exists("/shattered/.install-previous"))
print("SHATTERED: legacy saves migrated once, never overwritten, installer repeatable.")
