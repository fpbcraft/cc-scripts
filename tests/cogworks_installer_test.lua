-- Mock CraftOS HTTP/filesystem to verify staged updates, rollback and save preservation.
local script=(arg and arg[0]) or ""
local root=script:match("^(.*)/tests/[^/]+$") or "."
local files,dirs={},{}
local brokenDownload,brokenMove=nil,nil
local function combine(a,b)return (a.."/"..b):gsub("//+","/")end
fs={}
function fs.exists(p)return files[p]~=nil or dirs[p]~=nil end
function fs.combine(a,b)return combine(a,b)end
function fs.getDir(p)return (p:match("^(.*)/[^/]*$") or "")end
function fs.makeDir(path)
 local acc=""
 for part in path:gmatch("[^/]+")do acc=acc.."/"..part;dirs[acc]=true end
end
function fs.delete(path)
 for p in pairs(files)do
  if p==path or p:sub(1,#path+1)==path.."/"then files[p]=nil end
 end
 for p in pairs(dirs)do
  if p==path or p:sub(1,#path+1)==path.."/"then dirs[p]=nil end
 end
end
function fs.move(from,to)
 if from==brokenMove then error("simulated filesystem failure")end
 assert(fs.exists(from),"missing source: "..from)
 if files[from]~=nil then files[to]=files[from];files[from]=nil;return end
 for p,v in pairs(files)do
  if p:sub(1,#from+1)==from.."/"then
   files[to..p:sub(#from+1)]=v;files[p]=nil
  end
 end
 fs.makeDir(to);fs.delete(from)
end
function fs.open(path,mode)
 if mode=="w"then
  local state=""
  return {write=function(s)state=state..s end,close=function()files[path]=state end}
 elseif mode=="r"then
  local data=files[path]
  if data==nil then return nil end
  return {readAll=function()return data end,close=function()end}
 end
end
http={}
function http.get(url)
 local path=url:match("/cogworks/(.*)$")
 if not path or path==brokenDownload then return nil,"simulated download error"end
 local f=assert(io.open(root.."/cogworks/"..path,"rb"),path)
 local data=f:read("*a");f:close()
 return {readAll=function()return data end,close=function()end,
  getResponseCode=function()return 200 end}
end
local checks=0
local function check(value,message)
 checks=checks+1;assert(value,"Installer check "..checks.." failed: "..message)
end
local install=assert(loadfile(root.."/install-cogworks.lua"))
fs.makeDir("/cogworks")
files["/cogworks/save.dat"]="PRESERVED PROGRESS"
fs.makeDir("/cogworks/saves")
files["/cogworks/saves/slot-1.dat"]="SLOT ONE"
files["/cogworks/settings.dat"]="CUSTOM SETTINGS"
install()
check(files["/cogworks/main.lua"]~=nil,"main installed")
check(files["/cogworks/render.lua"]~=nil,"renderer installed")
check(files["/cogworks/levels.lua"]~=nil,"levels installed")
check(files["/cogworks/app.lua"]~=nil and files["/cogworks/storage.lua"]~=nil,
 "Menus and storage installed")
check(files["/cogworks/expansion.lua"]~=nil,"Machine expansion installed")
check(files["/cogworks/tutorials.lua"]~=nil,"Ponder tutorials installed")
check(files["/cogworks/saves/slot-1.dat"]=="SLOT ONE","slot unaffected")
check(files["/cogworks/settings.dat"]=="CUSTOM SETTINGS","settings unaffected")
check(files["/cogworks/save.dat"]=="PRESERVED PROGRESS","progress unchanged")
check(not files["/startup.lua"],"no surprise autostart")
local original=files["/cogworks/main.lua"]
brokenDownload="levels.lua"
local ok=pcall(install)
check(not ok,"failed download rejected")
check(files["/cogworks/main.lua"]==original,"no partial activation after download failure")
check(files["/cogworks/save.dat"]=="PRESERVED PROGRESS","download failure preserved progress")
brokenDownload=nil
brokenMove="/cogworks/.install-next/render.lua"
ok=pcall(install)
check(not ok,"activation failure rejected")
check(files["/cogworks/main.lua"]==original,"activation failure restored previous code")
check(files["/cogworks/render.lua"]~=nil,"activation restored renderer")
check(files["/cogworks/save.dat"]=="PRESERVED PROGRESS","activation preserved progress")
brokenMove=nil
files["/startup.lua"]="shell.run('/other/main.lua')\n"
install("--startup")
check(files["/startup.lua"]=="shell.run('/other/main.lua')\n","unrelated startup untouched")
check(files["/cogworks/save.dat"]=="PRESERVED PROGRESS","upgrade preserves progress")
check(files["/cogworks/saves/slot-1.dat"]=="SLOT ONE","update retains save slots")
check(files["/cogworks/settings.dat"]=="CUSTOM SETTINGS","update retains settings")
fs.delete("/startup.lua")
install("--startup")
check(files["/startup.lua"]=="shell.run('/cogworks/main.lua')\n","autostart opt-in")
print("COGWORKS INSTALLER: "..checks.." checks passed")
