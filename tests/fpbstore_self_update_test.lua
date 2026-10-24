-- Full FPB Store bootstrap regression for CraftOS iOS without `package`.
-- This executes the real installer against a simulated CraftOS filesystem and
-- HTTP layer, rather than merely checking for Lua syntax or matching strings.
local source=assert(loadfile("install-fpbstore.lua"))
local files,dirs={}, {["/"]=true,["/fpbstore"]=true}
local function normal(path)return path:gsub("//+","/")end
fs={}
function fs.combine(a,b)return normal(a.."/"..b)end
function fs.getDir(path)return path:match("^(.*)/[^/]+$") or "/" end
function fs.exists(path)return files[path]~=nil or dirs[path]==true end
function fs.makeDir(path)dirs[path]=true end
function fs.delete(path)
 files[path]=nil;dirs[path]=nil
 for p in pairs(files)do
  if p:sub(1,#path+1)==path.."/"then files[p]=nil end
 end
 for p in pairs(dirs)do
  if p:sub(1,#path+1)==path.."/"then dirs[p]=nil end
 end
end
function fs.move(a,b)
 assert(fs.exists(a),"Move source missing: "..a)
 if dirs[a] then dirs[b]=true;dirs[a]=nil
 else files[b]=files[a];files[a]=nil end
end
function fs.open(path,mode)
 if mode=="r"then
  if not files[path]then return nil end
  return {readAll=function()return files[path]end,close=function()end}
 end
 assert(mode=="w")
 local contents=""
 return {write=function(str)contents=contents..str end,
  close=function()files[path]=contents end}
end
local responseBodies={
 ["main.lua"]="-- new main\nprint('new store')\n",
 ["basalt_ui.lua"]="-- basalt frontend\nreturn {run=function()end}\n",
 ["catalog.lua"]="-- catalog\nreturn {apps={},storeVersion='1.2.0'}\n",
 ["manager.lua"]="-- manager\nreturn {install=function()end}\n",
 ["README.md"]="# Store updated"
}
local requests=0
http={}
function http.get(url)
 requests=requests+1
 if url:find("api.github.com",1,true)then
  return {readAll=function()return "not-json"end,close=function()end}
 end
 local file=url:match("/fpbstore/([^/?]+)")
 local data=responseBodies[file]
 if not data then return nil,"Not found: "..url end
 return {readAll=function()return data end,
  getResponseCode=function()return 200 end,close=function()end}
end
textutils={unserializeJSON=function()return nil end}
files["/fpbstore/main.lua"]="OLD MAIN"
files["/fpbstore/catalog.lua"]="OLD CATALOG"
files["/fpbstore/installed/cogworks.dat"]="PRESERVED SAVE MARKER"
dirs["/fpbstore/installed"]=true
files["/store.lua"]="shell.run('/fpbstore/main.lua')\n"
local priorPackage=package
package=nil
local ok,reason=pcall(source,"main")
package=priorPackage
assert(ok,"Installer must succeed without package: "..tostring(reason))
assert(files["/fpbstore/main.lua"]==responseBodies["main.lua"],"New main installed")
assert(files["/fpbstore/catalog.lua"]==responseBodies["catalog.lua"],"New catalog installed")
assert(files["/fpbstore/basalt_ui.lua"]==responseBodies["basalt_ui.lua"],"All modules installed")
assert(files["/fpbstore/installed/cogworks.dat"]=="PRESERVED SAVE MARKER",
 "Existing game metadata preserved")
assert(files["/store.lua"]:find("loadfile",1,true),"Legacy shortcut upgraded")
assert(not fs.exists("/fpbstore/.install-next") and
 not fs.exists("/fpbstore/.install-previous"),"Staging directories cleaned")
assert(requests>=5,"Downloaded all components")
-- Re-run the complete bootstrap as a self-update, still without package.
responseBodies["main.lua"]="-- newer main\nprint('version 2')\n"
package=nil
ok,reason=pcall(source,"main")
package=priorPackage
assert(ok,"Repeated self-update without package failed: "..tostring(reason))
assert(files["/fpbstore/main.lua"]==responseBodies["main.lua"],
 "Repeated update replaces old code")
print("FPB Store: full initial bootstrap + repeat self-update pass without package.")
