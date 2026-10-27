-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/games/shattered/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/shattered" then
	-- selene: allow(undefined_variable) -- Selene misidentifies chunk-level varargs.
	return bootstrap().run("/games/shattered", "shattered.lua", _ENV, ...)
end
-- SHATTERED EXPANSE v5.6. Run: /games/shattered/shattered.lua
local argv = { ... }
if #argv == 0 and type(arg) == "table" and arg[1] then
	argv[1] = arg[1]
end
_G.EXPANSE_V5_ROOT = _G.EXPANSE_V5_ROOT or "/games/shattered/expanse-v5"
local UI = dofile(_G.EXPANSE_V5_ROOT .. "/ui.lua")
local Display = dofile("/games/shattered/display.lua")
if argv[1] == "--self-test" then
	local M = dofile(_G.EXPANSE_V5_ROOT .. "/sim.lua")
	local g = M.new({ humans = { true, false, false, false }, seed = 73 })
	assert(M.validState(g) and #g.systems == 30 and #g.factions == 4)
	assert(M.endTurn(g, 1))
	assert(M.advanceAI(g) > 0)
	print("SHATTERED V5 SELF-TEST OK")
	return
end
local monitor, name
if peripheral then
	if argv[1] then
		name = argv[1]
		monitor = peripheral.wrap(name)
	else
		monitor = peripheral.find("monitor")
		if monitor and peripheral.getName then
			name = peripheral.getName(monitor)
		end
	end
end
local viewport = dofile("/games/shattered/terminal_view.lua")
local mode
monitor, mode = Display.select(monitor, term.current(), viewport, 80, 54)
local computerMode = Display.isComputer(mode)
local app = UI.new(monitor)
assert(
	app.r.w >= 38 and app.r.h >= 19,
	"Display too small; expand the terminal or connect a monitor."
)
local ok, err = xpcall(function()
	app:loop(name, computerMode and monitor or nil)
end, function(e)
	return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if app.r.kind == "gfx" then
	pcall(monitor.setGraphicsMode, 0)
end
Display.close(monitor, mode)
if not ok then
	error(err, 0)
end
