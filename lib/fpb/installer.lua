-- Install code and private library dependencies, preserving all user-owned data.
local I={}
local BASE='https://raw.githubusercontent.com/fpbcraft/cc-scripts/'
local function mkdir(path)if path~='' and not fs.exists(path)then fs.makeDir(path)end end
local function remove(path)if fs.exists(path)then fs.delete(path)end end
local function read(path)
 if not fs.exists(path) or fs.isDir(path)then return nil end
 local h=assert(fs.open(path,'r'));local s=h.readAll();h.close();return s
end
local function write(path,data)
 mkdir(fs.getDir(path))
 local h,err=fs.open(path,'w');assert(h,err or ('Cannot write '..path))
 h.write(data);h.close()
end
local function validPath(path)
 assert(type(path)=='string' and path:match('^[%w._/-]+$') and
  not path:find('..',1,true) and path:sub(1,1)~='/','Unsafe manifest path')
 return path
end
local function fetch(ref,path)
 local nonce=os.epoch and os.epoch('utc') or math.floor(os.clock()*1000)
 local url=BASE..ref..'/'..validPath(path)..'?fpb_cb='..nonce
 local h,err=http.get(url,nil,true);assert(h,'Download failed: '..path..': '..tostring(err))
 local status=h.getResponseCode and h.getResponseCode() or 200
 local body=h.readAll();h.close()
 assert(status==200 and type(body)=='string' and #body>0,'HTTP '..status..' for '..path)
 if path:sub(-4)=='.lua'then assert(load(body,'@'..path,'t'),'Invalid Lua: '..path)end
 return body
end
local function migration(spec)
 local marker=spec.root..'/.layout-v2'
 if fs.exists(marker)then return {} end
 local pending,byDestination={},{}
 local function collect(source,destination)
  if not fs.exists(source)then return end
  if fs.isDir(source)then
   assert(not fs.exists(destination) or fs.isDir(destination),'Migration conflict: '..destination)
   for _,name in ipairs(fs.list(source))do collect(source..'/'..name,destination..'/'..name)end
   return
  end
  local body=assert(read(source))
  if fs.exists(destination)then
   assert(not fs.isDir(destination) and read(destination)==body,
    'Migration conflict: '..source..' -> '..destination..'. Move one copy before reinstalling.')
  elseif byDestination[destination]then
   assert(byDestination[destination]==body,'Conflicting legacy data for '..destination)
  else
   byDestination[destination]=body
   pending[#pending+1]={path=destination,body=body}
  end
 end
 for _,name in ipairs(spec.data)do collect(spec.legacy..'/'..name,spec.root..'/'..name)end
 if spec.id=='shattered'then
  for _,name in ipairs(spec.data)do collect('/tidebound/'..name,spec.root..'/'..name)end
 elseif spec.id=='airship'then
  for _,name in ipairs(spec.data)do
   if not fs.exists(spec.legacy..'/'..name)then collect('/'..name,spec.root..'/'..name)end
  end
 end
 return pending
end
local function startupPlan(spec,enabled)
 if not enabled then return nil end
 local command="local f,e=loadfile('"..spec.root..'/'..spec.entry.."');assert(f,e);return f("..
  (spec.id=='civcraft' and "'host'" or '')..")\n"
 for _,path in ipairs({'/startup','/startup.lua'})do
  local current=read(path)
  if current and current~=command then
   -- Only replace the exact launcher shapes produced by earlier installers.
   local target=current:match("^shell%.run%(['\"]([^'\"]+)['\"]")
   local owned=target==spec.legacy..'/'..spec.entry or target==spec.root..'/'..spec.entry
   owned=owned and current:match('^shell%.run%([^\n]*%)%s*$')~=nil
   if not owned then
    if spec.lowDisk then error('Unrelated '..path..' exists; move it before installing.',0)end
    print('Autostart unchanged: unrelated '..path..' exists.');return nil
   end
  elseif fs.exists(path) and fs.isDir(path)then
   error('Startup path is a directory: '..path,0)
  end
 end
 return command
end
function I.install(id,ref,args)
 assert(type(ref)=='string' and ref:match('^[%w._/-]+$') and not ref:find('..',1,true),'Invalid ref')
 local manifests=assert(load(fetch(ref,'lib/fpb/packages.lua'),'@packages','t',{ipairs=ipairs}))()
 local spec=assert(manifests.packages[id],'Unknown package: '..tostring(id))
 local enabled=spec.startup
 for _,a in ipairs(args or {})do
  if a=='--startup'then enabled=true elseif a=='--no-startup'then enabled=false end
 end
 local startup=startupPlan(spec,enabled)
 local pending=migration(spec) -- Preflight before downloading or replacing code.
 local paths,sources={},{}
 for _,file in ipairs(spec.files)do
  validPath(file);paths[#paths+1]=file;sources[file]=spec.source..'/'..file
 end
 -- The node's old auth import is an adapter over the shared protocol module.
 if id=='node'then sources['auth.lua']='apps/factory/auth.lua'end
 for _,name in ipairs(spec.libraries)do
  local path='_lib/fpb/'..validPath(name)..'.lua'
  paths[#paths+1]=path;sources[path]='lib/fpb/'..name..'.lua'
 end
 local stage,backup=spec.root..'/.install-next',spec.root..'/.install-backup'
 -- An interrupted staged transaction must be recovered, never discarded.
 if fs.exists(backup)then
  error('Interrupted install at '..backup..'. Restore its files before retrying.',0)
 end
 local downloaded={}
 local ok,err=pcall(function()
  for _,path in ipairs(paths)do
   local body=fetch(ref,sources[path])
   if spec.lowDisk then downloaded[path]=body else write(stage..'/'..path,body)end
   print(' + '..path)
  end
  if spec.basalt and not fs.exists(spec.root..'/basalt.lua')then
   assert(shell and shell.run,'Basalt installation requires the CraftOS shell')
   mkdir(stage)
   assert(shell.run('wget','run','https://basalt.madefor.cc/2.5/install.lua',
    'minified',stage..'/basalt.lua') and fs.exists(stage..'/basalt.lua'),'Basalt installation failed')
   assert(load(read(stage..'/basalt.lua'),'@basalt','t'),'Invalid Basalt download')
   paths[#paths+1]='basalt.lua'
   if spec.lowDisk then downloaded['basalt.lua']=read(stage..'/basalt.lua')end
  end
 end)
 if not ok then remove(stage);error('Download aborted; active files untouched: '..tostring(err),0)end
 local old,new,copied={},{},{}
 local activated,reason=pcall(function()
  mkdir(spec.root)
  for _,item in ipairs(pending)do
   copied[#copied+1]=item.path;write(item.path,item.body)
  end
  for _,path in ipairs(paths)do
   local target=spec.root..'/'..path
   if spec.lowDisk then
    local temp=target..'.new';write(temp,downloaded[path])
    remove(target);fs.move(temp,target);downloaded[path]=nil
   else
    if fs.exists(target)then
     mkdir(fs.getDir(backup..'/'..path));fs.move(target,backup..'/'..path);old[#old+1]=path
    end
    mkdir(fs.getDir(target));fs.move(stage..'/'..path,target);new[#new+1]=path
   end
  end
  if id=='railbreak' or id=='ironspire'then
   local loader=assert(loadfile(spec.root..'/_lib/fpb/loader.lua'))()
   local api=loader.run(spec.root,spec.entry,_ENV,'--test-api')
   assert(type(api)=='table' and api.UI,'Installed API health check failed')
  end
  if id=='node' and args and args.label then
   local path=spec.root..'/config.db'
   local value=read(path);local cfg=value and textutils.unserialize(value) or {}
   assert(type(cfg)=='table','Invalid existing node configuration')
   cfg.name=args.label:sub(1,40);write(path,textutils.serialize(cfg))
  end
  if not fs.exists(spec.root..'/.layout-v2')then write(spec.root..'/.layout-v2','migration complete\n')end
 end)
 if not activated then
  if not spec.lowDisk then
   for _,path in ipairs(new)do remove(spec.root..'/'..path)end
   for _,path in ipairs(old)do fs.move(backup..'/'..path,spec.root..'/'..path)end
  end
  for _,path in ipairs(copied)do remove(path)end
  remove(stage);remove(backup)
  error((spec.lowDisk and 'Install stopped (no backups): ' or 'Install rolled back: ')..tostring(reason),0)
 end
 remove(stage);remove(backup)
 if startup then
  write('/startup.fpb-next.lua',startup)
  remove('/startup.lua');fs.move('/startup.fpb-next.lua','/startup.lua');remove('/startup')
 end
 print('Installed '..id..' at '..spec.root..' @ '..ref)
 print('Run: '..spec.root..'/'..spec.entry)
 print('Legacy data retained at '..spec.legacy)
 return true
end
return I
