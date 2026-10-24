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
  return {readAll=function()return files[path]end,close=function()end}
 end
 assert(mode=="w")
 local bytes=""
 return {write=function(t)bytes=bytes..t end,close=function()files[path]=bytes end}
end
textutils={serialize=function(t)return tostring(t.ref)end}
http={}
function http.get(url)
 downloads[#downloads+1]=url
 return {getResponseCode=function()return 200 end,
  readAll=function()return "print('mock installer ok')\n"end,close=function()end}
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
assert(#M.catalog.apps==3,"Initial catalog has three apps")
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
assert(runCount==6,"Three installs and three launches")
local ok=pcall(function()M.install({id="unknown"})end)
assert(not ok,"Arbitrary catalog entries rejected")
print("FPB STORE: catalog, install, run, uninstall and save-preservation passed.")
