-- FPB Store package management. Operations work outside the UI for testing.
local C=require("fpbstore.catalog")
local M={catalog=C,REF="main",BASE="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"}
local function ensure(path)
 if not fs.exists(path)then fs.makeDir(path)end
end
local function fetch(url)
 assert(http and http.get,"HTTP must be enabled")
 -- Bust intermediary HTTP caches so versions and installers reflect main.
 local separator=url:find("?",1,true) and "&" or "?"
 local nonce=os.epoch and os.epoch("utc") or math.floor(os.clock()*1000)
 local response,err=http.get(url..separator.."fpbstore_cb="..tostring(nonce),nil,true)
 assert(response,"Download failed: "..tostring(err))
 local status=response.getResponseCode and response.getResponseCode()or 200
 local data=response.readAll();response.close()
 assert(status==200 and type(data)=="string" and #data>20,
  "HTTP "..tostring(status).." from "..url)
 return data
end
local function write(path,text)
 ensure(fs.getDir(path))
 local h,err=fs.open(path,"w")
 assert(h,err or ("Unable to write "..path))
 h.write(text);h.close()
end
function M.get(id)
 for _,app in ipairs(C.apps)do if app.id==id then return app end end
 return nil
end
function M.installed(app)
 return fs.exists(app.entry)
end
local latest={}
local checked=false
local function readVersion(app)
 local marker="/fpbstore/installed/"..app.id..".dat"
 if fs.exists(marker) then
  local h=fs.open(marker,"r")
  if h then
   local ok,t=pcall(textutils.unserialize,h.readAll());h.close()
   if ok and type(t)=="table" and type(t.version)=="string" then return t.version end
  end
 end
 -- Legacy/manual installs may not have a store marker. Read actual launcher's
 -- version comments when available; never assume a version for unknown files.
 local h=fs.open(app.entry,"r")
 if h then
  local header=h.read(400)or"";h.close()
  local found=header:match("[Vv](%d+%.%d+%.%d+)") or
   header:match("[Vv](%d+%.%d+)")
  if found then return found end
 end
 return nil
end
function M.refreshVersions(ref)
 ref=ref or M.REF
 assert(ref:match("^[%w%._/-]+$") and not ref:find("..",1,true),"Invalid ref")
 local ok,result=pcall(function()
  local source=fetch(M.BASE..ref.."/fpbstore/catalog.lua")
  local chunk,err=load(source,"@remote-catalog.lua","t",{})
  assert(chunk,err)
  local remote=chunk()
  assert(type(remote)=="table" and type(remote.apps)=="table",
   "Invalid remote catalog")
  local new={}
  for _,app in ipairs(remote.apps)do
   if type(app.id)=="string" and type(app.version)=="string" then
    new[app.id]=app.version
   end
  end
  return new
 end)
 if ok then latest=result;checked=true;return true end
 checked=true;return false,tostring(result)
end
local function parts(version)
 local a,b,c=tostring(version or ""):match("^(%d+)%.(%d+)%.?(%d*)$")
 if not a then return nil end
 return {tonumber(a),tonumber(b),tonumber(c) or 0}
end
local function newer(a,b)
 local x,y=parts(a),parts(b)
 if not x or not y then return false end
 for i=1,3 do
  if x[i]~=y[i] then return x[i]>y[i] end
 end
 return false
end
function M.status(app)
 local marker="/fpbstore/installed/"..app.id..".dat"
 local installed=M.installed(app)
 local current=installed and readVersion(app) or nil
 local available=latest[app.id] or app.version
 return {
  installed=installed,managed=fs.exists(marker),
  installedVersion=current,latestVersion=available,
  updateAvailable=installed and current~=nil and available~=nil and newer(available,current),
  versionUnknown=installed and current==nil,
  checked=checked,
 }
end
function M.install(app,ref)
 assert(app and M.get(app.id)==app,"Unrecognized app")
 ref=ref or M.REF
 assert(ref:match("^[%w%._/-]+$")and not ref:find("..",1,true),"Invalid ref")
 local code=fetch(M.BASE..ref.."/"..app.installer)
 local chunk,err=load(code,"@"..app.installer,"t")
 assert(chunk,"Invalid installer: "..tostring(err))
 -- Execute the fetched chunk directly so errors retain their Lua stack and
 -- message. shell.run collapses execution failures to a bare false.
 local ok,result=xpcall(function()
  return chunk(ref,"--no-startup")
 end,function(e)
  return tostring(e)..(debug and debug.traceback and ("\n"..debug.traceback()) or "")
 end)
 assert(ok,"Installation of "..app.name.." failed:\n"..tostring(result))
 assert(M.installed(app),"Installer returned without installing "..app.name)
 ensure("/fpbstore/installed")
 write("/fpbstore/installed/"..app.id..".dat",
  textutils.serialize({ref=ref,version=latest[app.id] or app.version,
   installedAt=os.epoch and os.epoch("utc")or 0}))
 return true
end
function M.launch(app)
 assert(app and M.get(app.id)==app and M.installed(app),"Game not installed")
 assert(shell and shell.run,"CraftOS shell required")
 return shell.run(app.entry)
end
function M.remove(app,deleteSaves)
 assert(app and M.get(app.id)==app,"Unrecognized app")
 local count=0
 -- Never delete the game root: unrecognized files may contain user work.
 for _,relative in ipairs(app.managedFiles)do
  assert(relative:match("^[%w%._/-]+$") and
   not relative:find("..",1,true) and relative:sub(1,1)~="/",
   "Unsafe managed file path")
  local path=fs.combine(app.root,relative)
  if fs.exists(path) and not fs.isDir(path)then
   fs.delete(path);count=count+1
  end
 end
 -- The default is preserve: opting in is explicit and UI-confirmed.
 if deleteSaves then
  for _,save in ipairs(app.saves)do
   assert(save:sub(1,#app.root+1)==app.root.."/","Unsafe save path")
   if fs.exists(save)then fs.delete(save)end
  end
 end
 local marker="/fpbstore/installed/"..app.id..".dat"
 if fs.exists(marker)then fs.delete(marker)end
 return count
end
function M.updateStore(ref)
 ref=ref or M.REF
 assert(ref:match("^[%w%._/-]+$") and not ref:find("..",1,true),"Invalid ref")
 local source=fetch(M.BASE..ref.."/install-fpbstore.lua")
 local fn,err=load(source,"@install-fpbstore.lua","t")
 assert(fn,err)
 local tmp="/fpbstore/.self-update.lua"
 write(tmp,source)
 local ok,result=pcall(function()return shell.run(tmp,ref)end)
 if fs.exists(tmp)then fs.delete(tmp)end
 assert(ok and result,"Store update failed")
 return true
end
return M
