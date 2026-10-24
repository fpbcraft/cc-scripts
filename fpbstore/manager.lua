-- FPB Store package management. Operations work outside the UI for testing.
local C=require("fpbstore.catalog")
local M={catalog=C,REF="main",BASE="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"}
local function ensure(path)
 if not fs.exists(path)then fs.makeDir(path)end
end
local function fetch(url)
 assert(http and http.get,"HTTP must be enabled")
 local response,err=http.get(url,nil,true)
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
function M.status(app)
 local marker="/fpbstore/installed/"..app.id..".dat"
 return {installed=M.installed(app),managed=fs.exists(marker)}
end
function M.install(app,ref)
 assert(app and M.get(app.id)==app,"Unrecognized app")
 ref=ref or M.REF
 assert(ref:match("^[%w%._/-]+$")and not ref:find("..",1,true),"Invalid ref")
 local code=fetch(M.BASE..ref.."/"..app.installer)
 local chunk,err=load(code,"@"..app.installer,"t")
 assert(chunk,"Invalid installer: "..tostring(err))
 ensure("/fpbstore")
 local file="/fpbstore/.installer-"..app.id..".lua"
 write(file,code)
 -- shell.run gives the installer the same CraftOS environment as wget run.
 local ok,result=pcall(function()
  assert(shell and shell.run,"CraftOS shell required")
  return shell.run(file,ref,"--no-startup")
 end)
 if fs.exists(file)then fs.delete(file)end
 assert(ok and result,"Installation failed: "..tostring(ok and result or result))
 assert(M.installed(app),"Installer returned without installing "..app.name)
 ensure("/fpbstore/installed")
 write("/fpbstore/installed/"..app.id..".dat",
  textutils.serialize({ref=ref,installedAt=os.epoch and os.epoch("utc")or 0}))
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
