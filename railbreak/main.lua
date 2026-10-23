-- RAILBREAK: KINETIC FRONTIER / CC:Tweaked 5x5 Advanced Monitor
-- Usage: /railbreak/main.lua [monitor_name]
local argv={...}
package.path='/?.lua;/?/init.lua;'..package.path
local App=require('railbreak.ui.app')
local S=require('railbreak.game.state')
local K=require('railbreak.game.kinetics')
local A=require('railbreak.game.commands')
local function locate(requested)
 if not peripheral then return nil,nil end
 if requested then
  local m=peripheral.wrap(requested)
  if not m or peripheral.getType(requested)~='monitor' then error('Unknown monitor '..requested,0)end
  return m,requested
 end
 local chosen,name,area=nil,nil,0
 for _,n in ipairs(peripheral.getNames()) do
  if peripheral.getType(n)=='monitor' then
   local mon=peripheral.wrap(n)
   if not mon.isColor or mon.isColor() then
    local ok,w,h=pcall(mon.getSize)
    if ok and w*h>area then chosen,name,area=mon,n,w*h end
   end
  end
 end
 return chosen,name
end
local function run()
 local mon,name=locate(argv[1]);assert(mon,'Attach a color Advanced Monitor.',0)
 local originalScale=mon.getTextScale and mon.getTextScale() or 1
 if mon.setTextScale then mon.setTextScale(.5) end
 local game=App.new(mon)
 local ok,err=xpcall(function()
  game:draw()
  local timer=nil
  local function animate()
   if game.animation>0 and not timer then timer=os.startTimer(.10)end
  end
  while true do
   local ev,a,b,c=os.pullEvent()
   if ev=='monitor_touch' and a==name then
    game:touch(b,c);game:draw();animate()
   elseif ev=='monitor_resize' and a==name then
    game.r:resize();game:draw()
   elseif ev=='char' and game.scene=='setup' then
    local U=require('railbreak.core.util')
    game.names[game.editing]=U.name(game.names[game.editing]..a)
    game:draw()
   elseif ev=='key' and game.scene=='setup' and keys and a==keys.backspace then
    game.names[game.editing]=game.names[game.editing]:sub(1,-2);game:draw()
   elseif ev=='timer' and a==timer then
    timer=nil;game.animation=game.animation-1
    -- Cosmetic-only animation: simulation time is unaffected by timers.
    if game.animation>0 then game:draw();animate()end
   end
  end
 end,function(message) return tostring(message)..'\n'..(debug and debug.traceback and debug.traceback() or '')end)
 game.r:close()
 if mon.setTextScale then pcall(mon.setTextScale,originalScale)end
 if not ok then error(err,0)end
end
if argv[1]=='--test-api' then return {App=App,State=S,Kinetics=K,Commands=A} end
run()
