-- TIDEBOUND: THE SHATTERED EXPANSE v4.0
-- Four empire, resource-driven 4X with 1-4 human players, local AI and narrative events.
local args={...}
if #args==0 and type(arg)=='table' and arg[1] then args[1]=arg[1] end
-- Settable by CLI regression tests; normal CC:Tweaked install uses /tidebound/expanse.
_G.EXPANSE_ROOT=_G.EXPANSE_ROOT or '/tidebound/expanse'
local UI=dofile(_G.EXPANSE_ROOT..'/ui.lua')
local function start()
 local monitor,monitorName
 if peripheral then
  if args[1] then monitorName=args[1];monitor=peripheral.wrap(monitorName)
  else monitor=peripheral.find('monitor');if monitor and peripheral.getName then monitorName=peripheral.getName(monitor)end end
 end
 if not monitor then error('Connect an Advanced Monitor. Try tidebound <monitor name>.',0)end
 local game=UI.new(monitor)
 if game.r.w<68 or game.r.h<44 then error('Display too small: use a 3x3 or preferably 5x5 Advanced Monitor at 0.5 scale.',0)end
 local ok,err=xpcall(function()game:loop(monitorName)end,function(reason)
  return tostring(reason)..'\n'..(debug and debug.traceback and debug.traceback() or '')
 end)
 if game.r.kind=='gfx' then pcall(monitor.setGraphicsMode,0)end
 if not ok then error(err,0)end
end
if args[1]=='--self-test' then
 local sim=dofile(_G.EXPANSE_ROOT..'/sim.lua');local g=sim.new({humans={true,false,false,false}})
 assert(#g.systems==40 and #g.factions==4);assert(sim.endTurn(g,1));assert(sim.advanceAI(g)>=3)
 print('SHATTERED EXPANSE BASIC TEST OK');return
end
start()