local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Hex = dofile("games/civcraft/hex.lua")
local Systems = dofile("games/civcraft/systems.lua")
local UI = dofile("games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local World = dofile("games/civcraft/world.lua")

for _, graphics in ipairs({ false, true }) do
	local world =
		{ width = 18, height = 12, tiles = {}, resources = {}, landmarks = {}, rails = {} }
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local state = {
		version = 6,
		phase = "game",
		ruleset = "create",
		round = 1,
		nextId = 10,
		world = world,
		players = { { id = 1, name = "ONE", techs = {} }, { id = 2, name = "TWO", techs = {} } },
		cities = {},
		units = { { id = 3, owner = 1, kind = "scout", x = 3, y = 6, movesLeft = 4 } },
		spawners = { { id = 4, x = 6, y = 6, kind = "spawner", cleared = false } },
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	state.units[1].x = 16
	World.reveal(state, Hex, Systems)
	world.rails["6:6"] = true
	world.landmarks["6:6"] = { kind = "beacon", natural = false }
	state.spawners[1].cleared = true
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 600, 603
			end
			return 100, 67
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
	else
		monitor.setCursorPos = function() end
		monitor.setBackgroundColor = function() end
		monitor.setTextColor = function() end
		monitor.write = function() end
	end
	local ui = UI.new(monitor, function() end)
	ui:draw(state, 1, { screen = "game" })
	ui.selected = { x = 6, y = 6, kind = "tile" }
	ui.panel = "context"
	local original = ui.r.text
	local lines = {}
	ui.r.text = function(self, x, y, text, ...)
		lines[#lines + 1] = tostring(text)
		return original(self, x, y, text, ...)
	end
	local function inspect()
		lines = {}
		for offset = 0, 25 do
			ui.inspectorOffset = offset
			ui:draw(state, 1, { screen = "game" })
		end
		return table.concat(lines, " ")
	end
	local hidden = inspect()
	assert(not hidden:find("BEACON", 1, true) and not hidden:find("RAILWAY", 1, true))
	assert(
		not hidden:find("CLEARED SPAWNER", 1, true) and hidden:find("HOSTILE", 1, true),
		"Local inspector must retain last-observed camp status"
	)
	state.units[1].x = 3
	World.reveal(state, Hex, Systems)
	local revealed = inspect()
	assert(
		revealed:find("BEACON", 1, true)
			and revealed:find("RAILWAY", 1, true)
			and revealed:find("CLEARED SPAWNER", 1, true),
		"Re-scouting must update infrastructure knowledge"
	)
	ui:close()
end
print(
	"CIVCRAFT: text/graphics local inspection keeps hidden rails, wonders and camp changes private until re-scouted."
)
