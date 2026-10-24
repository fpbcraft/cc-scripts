-- FPBCRAFT RAILBREAK / safe one-command installer and updater (v2.0.7)
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-railbreak.lua
-- Optional: <git ref> --startup. Existing startup scripts are never silently overwritten.
local args={...}
local ref='main';local startup=false
for _,a in ipairs(args)do
 if a=='--startup' then startup=true
 elseif a=='--no-startup' then startup=false
 else ref=a end
end
assert(ref:match('^[%w%._/-]+$') and not ref:find('..',1,true),'Invalid branch/tag ref')
assert(http and http.get,'Enable CC:Tweaked HTTP to install RAILBREAK')
assert(fs,'Installer requires CraftOS filesystem')
local ROOT='/railbreak';local NEXT=ROOT..'/.install-next';local PREVIOUS=ROOT..'/.install-backup'
local remote='https://raw.githubusercontent.com/fpbcraft/cc-scripts/'..ref..'/railbreak/'
local files={
 'main.lua','display.lua','terminal_view.lua','core/util.lua','content/catalog.lua','game/state.lua','game/kinetics.lua',
 'game/processing.lua','game/commands.lua','render/canvas.lua','ui/app.lua',
 'platform/storage.lua','README.md','QUICKSTART.txt',
 'classic.lua','train/catalog.lua','train/state.lua','train/rules.lua',
 'train/render.lua','train/art.lua','train/ui.lua','train/info.lua','train/storage.lua',
}
local function delete(path)if fs.exists(path)then fs.delete(path)end end
local function write(path,contents)
 local dir=fs.getDir(path);if dir and dir~='' and not fs.exists(dir)then fs.makeDir(dir)end
 local h,err=fs.open(path,'w');assert(h,err or 'Cannot write '..path)
 h.write(contents);h.close()
end
local function fetch(file)
 local response,err=http.get(remote..file,nil,true)
 assert(response,'Download failed: '..file..' '..tostring(err))
 local status=response.getResponseCode and response.getResponseCode() or 200
 local text=response.readAll();response.close()
 assert(status==200 and text and #text>10,'Bad HTTP response '..tostring(status)..' for '..file)
 if file:sub(-4)=='.lua' then
  local valid,reason=load(text,'@'..file,'t')
  assert(valid,'Lua syntax error in '..file..': '..tostring(reason))
 end
 return text
end
print('RAILBREAK: TRAIN-FIRST EDITION v2.0.6')
print('Installing from fpbcraft/cc-scripts @ '..ref)
if not fs.exists(ROOT) then fs.makeDir(ROOT) end
delete(NEXT);fs.makeDir(NEXT)
local ok,err=pcall(function()
 for _,file in ipairs(files)do
  write(fs.combine(NEXT,file),fetch(file))
  print(' + '..file)
 end
end)
if not ok then delete(NEXT);error('Nothing updated: '..tostring(err),0)end
-- Stage complete and validated: replace code files only, never /railbreak/data.
delete(PREVIOUS);fs.makeDir(PREVIOUS)
local old,new={},{}
local success,reason=pcall(function()
 for _,file in ipairs(files)do
  local target=fs.combine(ROOT,file);local prior=fs.combine(PREVIOUS,file)
  if fs.exists(target)then
   if not fs.exists(fs.getDir(prior))then fs.makeDir(fs.getDir(prior))end
   fs.move(target,prior);old[#old+1]=file
  end
  if not fs.exists(fs.getDir(target))then fs.makeDir(fs.getDir(target))end
  fs.move(fs.combine(NEXT,file),target);new[#new+1]=file
 end
 -- Execute the just-installed entry point with CraftOS's real package loader.
 -- A syntax check alone cannot catch module search-path mistakes.
 -- CraftOS iOS may run downloaded installers without a shell object.
 -- loadfile exercises the actual installed game modules in the same way as
 -- shell.run, but does not require the caller to be inside a shell.
 local entry,loadErr=loadfile(ROOT..'/main.lua')
 assert(entry,'Cannot load installed game: '..tostring(loadErr))
 local verified,api=pcall(entry,'--test-api')
 assert(verified,'Train boot verification failed: '..tostring(api))
 assert(type(api)=='table' and api.UI and api.State and api.Rules,
   'Boot verification returned no train game API')
 print('Boot check: train modules and screen rendering verified.')
end)
if not success then
 for _,file in ipairs(new)do delete(fs.combine(ROOT,file))end
 for _,file in ipairs(old)do
  local prior=fs.combine(PREVIOUS,file);local destination=fs.combine(ROOT,file)
  if fs.exists(prior)then fs.move(prior,destination)end
 end
 delete(NEXT);delete(PREVIOUS);error('Activation rolled back: '..tostring(reason),0)
end
delete(NEXT);delete(PREVIOUS)
if startup then
 local path='/startup.lua'
 local launcher="shell.run('/railbreak/main.lua')\n"
 if fs.exists(path)then
  local h=fs.open(path,'r');local existing=h and h.readAll() or '';if h then h.close()end
  if existing~=launcher then
   print('Startup unchanged: existing /startup.lua belongs to another program.')
   print('Use a dedicated game computer or configure your own startup.')
  else print('Autostart already configured.')end
 else
  write(path,launcher);print('Autostart enabled for this dedicated computer.')
 end
end
print('RAILBREAK v2.0.6 verified. Execute: /railbreak/main.lua')
print('Train save: /railbreak/data/train-save.lua')
print('Old factory game: /railbreak/classic.lua')
print('Legacy saves in /railbreak/data/ are preserved.')
