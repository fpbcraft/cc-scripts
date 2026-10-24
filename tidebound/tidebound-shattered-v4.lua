-- Legacy entrypoint: Shattered Expanse v4.0, with its unchanged /expanse modules.
local argv={...};if #argv==0 and type(arg)=='table' and arg[1]then argv[1]=arg[1]end
_G.EXPANSE_ROOT=_G.EXPANSE_ROOT or '/tidebound/expanse'
local UI=dofile(_G.EXPANSE_ROOT..'/ui.lua')
local monitor,name
if peripheral then
 if argv[1] then name=argv[1];monitor=peripheral.wrap(name)
 else monitor=peripheral.find('monitor');if monitor and peripheral.getName then name=peripheral.getName(monitor)end end
end
assert(monitor,'Connect an Advanced Monitor.')
local app=UI.new(monitor)
local ok,err=xpcall(function()app:loop(name)end,tostring)
if app.r.kind=='gfx' then pcall(monitor.setGraphicsMode,0)end
if not ok then error(err,0)end