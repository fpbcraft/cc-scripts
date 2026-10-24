-- FPBCRAFT TIDEBOUND / installer & updater v4.0
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-tidebound.lua
-- Optional: branch/ref (default main), --startup to auto-launch on a dedicated computer.
local args={...};local ref,autostart='main',false
for _,a in ipairs(args)do
 if a=='--startup' then autostart=true
 elseif a=='--no-startup' then autostart=false
 else ref=a end
end
assert(ref:match('^[%w._/-]+$') and not ref:find('..',1,true),'Invalid Git ref')
assert(http and http.get,'Enable CC:Tweaked HTTP in server configuration')
local root='/tidebound'
local staging=root..'/.install-next'
local backup=root..'/.install-previous'
local origin='https://raw.githubusercontent.com/fpbcraft/cc-scripts/'..ref..'/tidebound/'
local files={
 'tidebound.lua',
 'tidebound-stellar-frontier.lua',
 'tidebound-kingdoms.lua',
 'tidebound-classic.lua',
 'expanse/content.lua',
 'expanse/events.lua',
 'expanse/sim.lua',
 'expanse/render.lua',
 'expanse/ui.lua',
}
local function drop(path)if fs.exists(path) then fs.delete(path)end end
local function write(path,value)
 local dir=fs.getDir(path);if dir~='' and not fs.exists(dir)then fs.makeDir(dir)end
 local h,err=fs.open(path,'w');assert(h,'Cannot write '..path..': '..tostring(err))
 h.write(value);h.close()
end
local function read(path)
 local h=fs.open(path,'r');if not h then return nil end
 local out=h.readAll();h.close();return out
end
local function download(name)
 local h,err=http.get(origin..name,nil,true)
 assert(h,'Download failed for '..name..': '..tostring(err))
 local code=h.getResponseCode and h.getResponseCode() or 200
 local text=h.readAll();h.close()
 assert(code==200 and text and #text>80,'HTTP '..tostring(code)..' for '..name)
 local chunk,reason=load(text,'@'..name,'t')
 assert(chunk,'Syntax error in '..name..': '..tostring(reason))
 return text
end
print('TIDEBOUND: SHATTERED EXPANSE / INSTALLER')
print('Source: fpbcraft/cc-scripts @ '..ref)
if not fs.exists(root)then fs.makeDir(root)end
-- Only touch code files; leave all save files outside these directories intact.
drop(staging);fs.makeDir(staging)
local fetched,fetchError=pcall(function()
 for _,name in ipairs(files)do
  write(fs.combine(staging,name),download(name));print('Fetched '..name)
 end
end)
if not fetched then drop(staging);error('Install aborted, old game unchanged: '..tostring(fetchError),0)end
-- Roll back every code file if any activation operation fails.
drop(backup);fs.makeDir(backup)
local changed,activated={},{}
local ok,reason=pcall(function()
 for _,name in ipairs(files)do
  local old=fs.combine(root,name);local oldBackup=fs.combine(backup,name)
  if fs.exists(old)then
   local dir=fs.getDir(oldBackup);if not fs.exists(dir)then fs.makeDir(dir)end
   fs.move(old,oldBackup);changed[#changed+1]=name
  end
  local targetDir=fs.getDir(old);if not fs.exists(targetDir)then fs.makeDir(targetDir)end
  fs.move(fs.combine(staging,name),old);activated[#activated+1]=name
 end
end)
if not ok then
 for _,name in ipairs(activated)do drop(fs.combine(root,name))end
 for _,name in ipairs(changed)do
  local oldBackup=fs.combine(backup,name);local dest=fs.combine(root,name)
  if fs.exists(oldBackup)then fs.move(oldBackup,dest)end
 end
 drop(staging);drop(backup)
 error('Activation rolled back: '..tostring(reason),0)
end
drop(staging);drop(backup)
if autostart then
 local launcher="shell.run('/tidebound/tidebound.lua')\n"
 local existing=fs.exists('/startup.lua') and read('/startup.lua') or nil
 local shadow=fs.exists('/startup') and read('/startup') or nil
 if shadow and shadow~=launcher then
  print('Startup unchanged: unrelated /startup exists.')
 elseif existing and existing~=launcher and fs.exists('/startup.tidebound-backup.lua') then
  print('Startup unchanged: previous startup backup already exists.')
 else
  if existing and existing~=launcher then fs.copy('/startup.lua','/startup.tidebound-backup.lua')end
  if shadow then drop('/startup')end
  write('/startup.lua',launcher)
  print('Autostart enabled. Existing startup preserved when replaced.')
 end
else print('Autostart unchanged (add --startup on a dedicated computer).')end
print('Installed v4.0. All saves preserved.')
print('Play: /tidebound/tidebound.lua')
print('Legacy v3: /tidebound/tidebound-stellar-frontier.lua')
print('New save: /tidebound/expanse-save.dat')