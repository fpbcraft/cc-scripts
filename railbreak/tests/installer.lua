-- Mock CraftOS filesystem and GitHub HTTP to validate atomic, opt-in installation.
local script=(arg and arg[0]) or ''
local root=script:match('^(.*)/railbreak/tests/[^/]+$') or '.'
local files,dirs={},{}
local failFile=nil
local bootFails=false;local bootChecks=0
shell={}
function shell.run(path,arg)
 bootChecks=bootChecks+1
 assert(path=='/railbreak/main.lua' and arg=='--test-api','incorrect boot invocation')
 return not bootFails and files['/railbreak/main.lua']~=nil and files['/railbreak/train/ui.lua']~=nil and files['/railbreak/train/info.lua']~=nil
end
local function combine(a,b)return (a..'/'..b):gsub('//+','/')end
local function getDir(p)return (p:match('^(.*)/[^/]*$') or '')end
fs={}
function fs.exists(path)return files[path]~=nil or dirs[path]~=nil end
function fs.combine(a,b)return combine(a,b)end
function fs.getDir(path)return getDir(path)end
function fs.makeDir(path)
 local accumulator=''
 for part in path:gmatch('[^/]+')do accumulator=accumulator..'/'..part;dirs[accumulator]=true end
end
function fs.delete(path)
 for k in pairs(files)do if k==path or k:sub(1,#path+1)==path..'/'then files[k]=nil end end
 for k in pairs(dirs)do if k==path or k:sub(1,#path+1)==path..'/'then dirs[k]=nil end end
end
function fs.move(from,to)
 assert(fs.exists(from),'missing move source '..from)
 if files[from]~=nil then files[to]=files[from];files[from]=nil;return end
 for k,v in pairs(files)do if k:sub(1,#from+1)==from..'/' then files[to..k:sub(#from+1)]=v;files[k]=nil end end
 fs.makeDir(to);fs.delete(from)
end
function fs.open(path,mode)
 if mode=='w'then
  local state='';return {write=function(t)state=state..t end,close=function()files[path]=state end}
 elseif mode=='r'then
  local data=files[path];if not data then return nil end
  return {readAll=function()return data end,close=function()end}
 end
end
http={}
function http.get(url)
 local path=url:match('/railbreak/(.*)$')
 if not path or path==failFile then return nil,'simulated failure' end
 local f=assert(io.open(root..'/railbreak/'..path,'rb'));local data=f:read('*a');f:close()
 return {readAll=function()return data end,close=function()end,getResponseCode=function()return 200 end}
end
local tests=0
local function ck(v,s)tests=tests+1;assert(v,'installer test '..tests..': '..s)end
local install=assert(loadfile(root..'/install-railbreak.lua'))
fs.makeDir('/railbreak/data');files['/railbreak/data/save.lua']='PRESERVE ME'
install()
ck(files['/railbreak/main.lua']~=nil,'main game installed')
ck(bootChecks==1,'CraftOS boot check ran after install')
ck(files['/railbreak/game/processing.lua']~=nil,'modules installed')
ck(files['/railbreak/train/info.lua']~=nil,'tooltips installed')
ck(files['/railbreak/data/save.lua']=='PRESERVE ME','save preserved')
ck(files['/startup.lua']==nil,'no forced autostart')
local original=files['/railbreak/main.lua']
failFile='game/state.lua'
local ok=pcall(install)
ck(not ok,'failed download rejected')
ck(files['/railbreak/main.lua']==original,'failed download did not replace code')
ck(files['/railbreak/data/save.lua']=='PRESERVE ME','failure preserved data')
failFile=nil;bootFails=true
local beforeBootFailure=files['/railbreak/main.lua']
local okBoot=pcall(install)
ck(not okBoot,'boot verification failure rejected')
ck(files['/railbreak/main.lua']==beforeBootFailure,'boot failure restored previous program')
ck(files['/railbreak/data/save.lua']=='PRESERVE ME','boot failure preserved saves')
bootFails=false;files['/startup.lua']='shell.run("/airship/main.lua")\n'
install('--startup')
ck(files['/startup.lua']=='shell.run("/airship/main.lua")\n','existing startup preserved')
ck(files['/railbreak/data/save.lua']=='PRESERVE ME','update preserves save')
ck(bootChecks==3,'boot check executed after both updates')
print('RAILBREAK INSTALLER: '..tests..' checks passed')
