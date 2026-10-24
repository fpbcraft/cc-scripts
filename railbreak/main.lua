-- RAILBREAK: KINETIC FRONTIER - Train-first Edition v2.0.4
-- Turn-based, 1-4 players, touch-operated monitor (3x3 to 5x5).
local argv={...}
-- Program-local imports: CC:Tweaked's require is relative to the running
-- script directory, not to the shell's current working directory.
-- The installer creates /railbreak/train and /railbreak/core. Anchor imports
-- there explicitly, avoiding double-prefixing /railbreak/railbreak/.
package.path='/railbreak/?.lua;/railbreak/?/init.lua;'..package.path
local UI=require('train.ui')
local State=require('train.state')
local Rules=require('train.rules')
if argv[1]=='--test-api' then
 -- Installer health check: exercise actual screen layouts without touching saves
 -- or requiring a peripheral. Import-only checks missed a crash in map rendering.
 for _,dim in ipairs({{80,54},{135,92}})do
  local fake={}
  function fake.getSize()return dim[1],dim[2]end
  function fake.setBackgroundColor(_)end
  function fake.setTextColor(_)end
  function fake.setCursorPos(_,_)end
  function fake.write(_)end
  local g=State.new({count=1,seed=42})
  local testApp=UI.new(fake,{game=g})
  local screens={'hub','map','station','modules','market','contracts','train',
   'wagons','upgrades','help','travel','results'}
  for _,screen in ipairs(screens)do
   testApp.scene=screen
   if screen=='map' then testApp.selected=2 end
   if screen=='travel' then g.pending={to=2,from=1,event='rocks'}end
   testApp:draw()
  end
  testApp:close()
 end
 return {UI=UI,State=State,Rules=Rules}
end
local monitor,monitorName
if peripheral then
 if argv[1] and argv[1]~='--test-api' then
  local chosen=peripheral.wrap and peripheral.wrap(argv[1])
  assert(chosen and chosen.getSize,'No monitor peripheral named '..tostring(argv[1]))
  monitor=chosen;monitorName=argv[1]
 elseif peripheral.getNames then
  local biggest=-1
  for _,name in ipairs(peripheral.getNames())do
   if peripheral.getType(name)=='monitor' then
    local m=peripheral.wrap(name);local w,h=m.getSize();local area=w*h
    if area>biggest then biggest=area;monitor=m;monitorName=name end
   end
  end
 end
 if not monitor and peripheral.find then monitor=peripheral.find('monitor')end
end
if not monitor then monitor=term.current()end
assert(monitor and monitor.getSize,'Attach an Advanced Monitor or run on an Advanced Computer')
local oldScale=monitor.getTextScale and monitor.getTextScale() or nil
-- CC:Tweaked's smallest supported text scale is 0.5. Set this *before*
-- reading the monitor dimensions / entering CC: Graphics mode.
if monitor.setTextScale then
 local applied,why=pcall(monitor.setTextScale,0.5)
 if not applied then error('Cannot set monitor text scale to 0.5: '..tostring(why),0)end
end
local app=UI.new(monitor)
local function run()
 app:draw()
 local timer=nil
 local function animate()
  if app.r.mode=='graphics' and (app.scene=='title' or app.scene=='hub' or app.scene=='travel') and os.startTimer then
   timer=os.startTimer(1.2)
  end
 end
 animate()
 while true do
  local event,a,b,c=os.pullEvent()
  if event=='monitor_touch' then
   -- CC Graphics graphics mode: zero-based pixel coordinates; mode 0: one-based cells.
   -- Do not assume pointer positions are always character cells.
   if monitorName and a~=monitorName then
    -- Touch on another monitor; ignore.
   else
    app:touch(b,c);animate()
   end
  elseif event=='mouse_click' and monitor==term.current()then
   app:touch(b,c);animate()
  elseif event=='monitor_resize' then app:resize();animate()
  elseif event=='char' and app.scene=='setup' and app.editing then
   local U=require('core.util')
   local name=app.names[app.editing]
   app.names[app.editing]=U.name(name..a);app:draw()
  elseif event=='key' and app.scene=='setup' and app.editing and keys and a==keys.backspace then
   app.names[app.editing]=app.names[app.editing]:sub(1,-2);app:draw()
  elseif event=='timer' and a==timer then
   timer=nil;app.frame=app.frame+1;app:draw();animate()
  end
 end
end
local success,why=xpcall(run,function(s)return tostring(s)..'\n'..(debug and debug.traceback and debug.traceback()or'')end)
app:close();if oldScale and monitor.setTextScale then pcall(monitor.setTextScale,oldScale)end
if not success then error(why,0)end
