-- TIDEBOUND: The Shattered Expanse v5.1. Run: /tidebound/tidebound.lua
local argv={...};if #argv==0 and type(arg)=='table' and arg[1]then argv[1]=arg[1]end
_G.EXPANSE_V5_ROOT=_G.EXPANSE_V5_ROOT or '/tidebound/expanse-v5'
local UI=dofile(_G.EXPANSE_V5_ROOT..'/ui.lua')
if argv[1]=='--self-test' then
 local M=dofile(_G.EXPANSE_V5_ROOT..'/sim.lua');local g=M.new({humans={true,false,false,false},seed=73})
 assert(M.validState(g) and #g.systems==30 and #g.factions==4)
 assert(M.endTurn(g,1));assert(M.advanceAI(g)>0);print('TIDEBOUND V5 SELF-TEST OK');return
end
local monitor,name
if peripheral then
 if argv[1]then name=argv[1];monitor=peripheral.wrap(name)
 else monitor=peripheral.find('monitor');if monitor and peripheral.getName then name=peripheral.getName(monitor)end end
end
local computerMode=not monitor
local computerView=nil
if computerMode then
 local native=term.current()
 local w,h=native.getSize()
 if w>=51 and h>=29 then
  -- Use actual terminal geometry; the UI now recomputes layout on resize.
  monitor=native
 else
  -- Only very small screens need a minimal scrollable workspace.
  computerView=dofile('/tidebound/terminal_view.lua').new(native,math.max(51,w),math.max(29,h))
  monitor=computerView
 end
end
local app=UI.new(monitor)
assert(app.r.w>=68 and app.r.h>=44,'Requires a 3x3 or larger Advanced Monitor (5x5 recommended).')
local ok,err=xpcall(function()app:loop(name,computerMode and (computerView or monitor) or nil)end,function(e)return tostring(e)..'\n'..(debug and debug.traceback and debug.traceback()or'')end)
if app.r.kind=='gfx' then pcall(monitor.setGraphicsMode,0)end
if computerView then computerView.close()end
if not ok then error(err,0)end