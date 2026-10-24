-- FPBCRAFT TIDEBOUND installer/updater v5.3
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
-- Optional: <branch-or-tag> [--startup]; never changes startup by default.
local args={...};local ref,autostart='main',false
for _,a in ipairs(args)do
 if a=='--startup' then autostart=true
 elseif a=='--no-startup' then autostart=false
 else ref=a end
end
assert(ref:match('^[%w._/-]+$') and not ref:find('..',1,true),'Invalid git ref')
assert(http and http.get,'Enable HTTP in CC:Tweaked config')
local root='/tidebound';local nextDir=root..'/.install-next';local backup=root..'/.install-previous'
local origin='https://raw.githubusercontent.com/fpbcraft/cc-scripts/'..ref..'/tidebound/'
local files={
 'tidebound.lua','display.lua','terminal_view.lua',
 'expanse-v5/content.lua','expanse-v5/events.lua','expanse-v5/sim.lua',
 'expanse-v5/render.lua','expanse-v5/ui.lua'
}
local function remove(path)if fs.exists(path)then fs.delete(path)end end
local function write(path,bytes)
 local parent=fs.getDir(path);if parent~='' and not fs.exists(parent)then fs.makeDir(parent)end
 local h,err=fs.open(path,'w');assert(h,'Cannot write '..path..': '..tostring(err))
 h.write(bytes);h.close()
end
local function read(path)
 local h=fs.open(path,'r');if not h then return nil end
 local data=h.readAll();h.close();return data
end
local function fetch(name)
 local response,err=http.get(origin..name,nil,true)
 assert(response,'Download failed for '..name..': '..tostring(err))
 local status=response.getResponseCode and response.getResponseCode() or 200
 local body=response.readAll();response.close()
 assert(status==200 and body and #body>60,'HTTP '..status..' downloading '..name)
 local fn,syntaxError=load(body,'@'..name,'t')
 assert(fn,'Syntax error in '..name..': '..tostring(syntaxError))
 return body
end
print('SHATTERED EXPANSE / V5 INSTALLER')
print('Source: '..ref)
if not fs.exists(root)then fs.makeDir(root)end
-- Recover from a computer shutdown while replacing a previous version.
if fs.exists(backup)then
 for _,name in ipairs(files)do
  local previous=fs.combine(backup,name)
  local installed=fs.combine(root,name)
  if fs.exists(previous) and not fs.exists(installed)then
   local parent=fs.getDir(installed)
   if not fs.exists(parent)then fs.makeDir(parent)end
   fs.move(previous,installed)
  end
 end
end
remove(nextDir);fs.makeDir(nextDir)
local ok,err=pcall(function()
 for _,name in ipairs(files)do
  write(fs.combine(nextDir,name),fetch(name));print('Checked '..name)
 end
end)
if not ok then remove(nextDir);error('Download failed; old game unchanged: '..tostring(err),0)end
remove(backup);fs.makeDir(backup)
local archived,installed={},{}
local activated,why=pcall(function()
 for _,name in ipairs(files)do
  local dest=fs.combine(root,name);local old=fs.combine(backup,name)
  if fs.exists(dest)then
   local folder=fs.getDir(old);if not fs.exists(folder)then fs.makeDir(folder)end
   fs.move(dest,old);archived[#archived+1]=name
  end
  local folder=fs.getDir(dest);if not fs.exists(folder)then fs.makeDir(folder)end
  fs.move(fs.combine(nextDir,name),dest);installed[#installed+1]=name
 end
end)
if not activated then
 for _,name in ipairs(installed)do remove(fs.combine(root,name))end
 for _,name in ipairs(archived)do
  local old=fs.combine(backup,name);if fs.exists(old)then fs.move(old,fs.combine(root,name))end
 end
 remove(nextDir);remove(backup);error('Installation rolled back: '..tostring(why),0)
end
remove(nextDir);remove(backup)
-- Retire obsolete game executables without deleting any save file.
for _,legacy in ipairs({
 'tidebound-shattered-v4.lua','tidebound-stellar-frontier.lua',
 'tidebound-kingdoms.lua','tidebound-classic.lua',
 'expanse/content.lua','expanse/events.lua','expanse/sim.lua',
 'expanse/render.lua','expanse/ui.lua'
})do remove(fs.combine(root,legacy))end
if autostart then
 local launcher="shell.run('/tidebound/tidebound.lua')\n"
 local prior=fs.exists('/startup.lua') and read('/startup.lua') or nil
 local shadow=fs.exists('/startup') and read('/startup') or nil
 if shadow and shadow~=launcher then print('Startup not changed: unrelated /startup exists.')
 elseif prior and prior~=launcher and fs.exists('/startup.tidebound-backup.lua')then
  print('Startup not changed: previous backup exists.')
 else
  if prior and prior~=launcher then fs.copy('/startup.lua','/startup.tidebound-backup.lua')end
  if shadow then remove('/startup')end
  write('/startup.lua',launcher);print('Autostart enabled')
 end
else print('Autostart unchanged (--startup to opt in)')end
print('Installed SHATTERED EXPANSE v5.3. All saves preserved.')
print('PLAY  /tidebound/tidebound.lua')

print('SAVES /tidebound/v5-save.dat (+ .bak)')