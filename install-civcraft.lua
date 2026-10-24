-- CIVCRAFT safe installer/updater
-- wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-civcraft.lua
local args={...}
local ref='main';local startup=false
for _,v in ipairs(args)do
 if v=='--startup' then startup=true
 elseif v=='--no-startup' then startup=false
 else ref=v end
end
assert(ref:match('^[%w%._/-]+$') and not ref:find('..',1,true),'Invalid ref')
assert(http and http.get,'Enable HTTP in CC:Tweaked settings')
local root='/civcraft'
local files={'game.lua','render.lua','ui.lua','hex.lua','icons.lua','systems.lua','README.md'}
local url='https://raw.githubusercontent.com/fpbcraft/cc-scripts/'..ref..'/civcraft/'
local nextDir=root..'/.install-next'
local backup=root..'/.install-backup'
local function remove(p)if fs.exists(p)then fs.delete(p)end end
local function write(p,s)
 local h,e=fs.open(p,'w');assert(h,e or ('Unable to write '..p));h.write(s);h.close()
end
if not fs.exists(root)then fs.makeDir(root)end
remove(nextDir);fs.makeDir(nextDir)
local ok,err=pcall(function()
 for _,file in ipairs(files)do
  local nonce=os.epoch and os.epoch('utc') or math.floor(os.clock()*1000)
  local response,e=http.get(url..file..'?civcraft_cb='..tostring(nonce),nil,true)
  assert(response,'Download failed: '..file..' '..tostring(e))
  local status=response.getResponseCode and response.getResponseCode() or 200
  local body=response.readAll();response.close()
  assert(status==200 and #body>30,'Invalid HTTP response for '..file)
  if file:sub(-4)=='.lua' then assert(load(body,'@'..file,'t'))end
  write(nextDir..'/'..file,body)
  print('Validated '..file)
 end
end)
if not ok then remove(nextDir);error('Old install preserved: '..tostring(err),0)end
remove(backup);fs.makeDir(backup)
local installed,archived={},{}
local success,reason=pcall(function()
 for _,file in ipairs(files)do
  local dest=root..'/'..file
  if fs.exists(dest)then fs.move(dest,backup..'/'..file);archived[#archived+1]=file end
  fs.move(nextDir..'/'..file,dest);installed[#installed+1]=file
 end
end)
if not success then
 for _,file in ipairs(installed)do remove(root..'/'..file)end
 for _,file in ipairs(archived)do fs.move(backup..'/'..file,root..'/'..file)end
 remove(nextDir);remove(backup);error('Update rolled back: '..tostring(reason),0)
end
remove(nextDir);remove(backup)
if startup then
 local launcher="shell.run('/civcraft/game.lua','host')\n"
 if fs.exists('/startup') or fs.exists('/startup.lua')then
  print('Existing startup preserved. Configure startup manually.')
 else write('/startup.lua',launcher);print('Host autostart enabled')end
end
print('CIVCRAFT installed; saved games were not modified.')
print('Local hotseat: /civcraft/game.lua local')
print('Host: /civcraft/game.lua host')
print('Join: /civcraft/game.lua join [host ID]')
