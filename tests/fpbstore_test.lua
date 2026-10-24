package.path="./?.lua;./?/init.lua;"..package.path
local files,dirs={},{}
local downloads={}
fs={}
function fs.exists(path)return files[path]~=nil or dirs[path]~=nil end
function fs.isDir(path)return dirs[path]~=nil end
function fs.makeDir(path)dirs[path]=true end
function fs.getDir(path)return path:match("^(.*)/[^/]+$")or"/" end
function fs.combine(a,b)return a.."/"..b end
function fs.delete(path)files[path]=nil;dirs[path]=nil end
function fs.move(a,b)assert(files[a]~=nil);files[b]=files[a];files[a]=nil end
function fs.open(path,mode)
 if mode=="r"then
  if not files[path]then return nil end
  return {readAll=function()return files[path]end,read=function(n)return files[path]:sub(1,n or #files[path])end,close=function()end}
 end
 assert(mode=="w")
 local bytes=""
 return {write=function(t)bytes=bytes..t end,close=function()files[path]=bytes end}
end
textutils={serialize=function(t)return tostring(t.ref)end}
http={}
function http.get(url)
 downloads[#downloads+1]=url
 local appId=url:match("/install%-(%w+)%.lua")
 local paths={cogworks="/cogworks/main.lua",railbreak="/railbreak/main.lua",
  tidebound="/tidebound/tidebound.lua"}
 local path=paths[appId]
 local body=path and ("local file=fs.open("..string.format("%q",path)..
  ",'w');file.write('-- installed v1.0.0');file.close()") or
  "print('mock installer ok')"
 return {getResponseCode=function()return 200 end,
  readAll=function()return body end,close=function()end}
end
local runCount=0
shell={}
function shell.run(file,...)
 runCount=runCount+1
 local app=file:match("%.installer%-(%w+)%.lua")
 if app then
  local catalog=require("fpbstore.catalog")
  for _,v in ipairs(catalog.apps)do if v.id==app then
   files[v.entry]="game code"
  end end
 end
 return true
end
local M=require("fpbstore.manager")
assert(#M.catalog.apps>=3,"Catalog must contain the original three games")
assert(M.storeStatus().installedVersion=="1.1.0",
 "Store's installed version should be displayed")
local old={"cogworks","railbreak","tidebound"}
for i,id in ipairs(old)do
 local app=assert(M.get(id))
 assert(app.id==id and M.get("nonexistent")==nil)
 assert(not M.installed(app))
 M.install(app)
 assert(M.installed(app),"Game installed")
 assert(M.status(app).managed,"Metadata created")
 assert(downloads[i]:find(app.installer,1,true),"Correct installer fetched")
 assert(M.launch(app),"Launch works")
 local preserve=app.saves[1]
 files[preserve]="important save data"
 local unknown=app.root.."/personal-notes.txt"
 files[unknown]="user-created"
 local removed=M.remove(app,false)
 assert(removed>=1,"Known code removed")
 assert(not M.installed(app),"Entry point removed")
 assert(files[preserve]=="important save data","Save survives uninstall")
 assert(files[unknown]=="user-created","Unknown user file survives")
 assert(not M.status(app).managed,"Metadata removed")
end
assert(runCount==3,"Three games launched after direct installer execution")
local ok=pcall(function()M.install({id="unknown"})end)
assert(not ok,"Arbitrary catalog entries rejected")
-- Remote versions can identify both game and store updates without
-- overwriting any local installation metadata.
local initialStore=M.storeStatus()
assert(initialStore.installedVersion=="1.1.0")
local remoteCatalog=[[return {storeVersion="1.2.0",apps={
 {id="cogworks",version="1.2.0"},{id="railbreak",version="2.0.6"},
 {id="tidebound",version="5.1"}}}]]
local priorHttp=http.get
http.get=function(url)
 if url:find("/fpbstore/catalog.lua",1,true)then
  return {getResponseCode=function()return 200 end,
   readAll=function()return remoteCatalog end,close=function()end}
 end
 return priorHttp(url)
end
assert(M.refreshVersions(),"Remote catalog check")
assert(M.storeStatus().updateAvailable,"Detect newer Store release")
local cog=M.get("cogworks")
files[cog.entry]="-- COGWORKS v1.0.0\\nprint('game')"
local v=M.status(cog)
assert(v.installedVersion=="1.0.0" and v.latestVersion=="1.2.0"
 and v.updateAvailable,"Detect installed and latest game versions")
print("FPB STORE: catalog, install, run, uninstall and save-preservation passed.")
