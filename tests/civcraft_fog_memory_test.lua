local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local H = dofile("/games/civcraft/hex.lua")
local S = dofile("/games/civcraft/systems.lua")
local W = dofile("/games/civcraft/world.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local Snapshots = dofile("/games/civcraft/snapshots.lua")
local UI = dofile("/games/civcraft/ui.lua")
local function fixture()
	local state = {
		phase = "game",
		round = 1,
		ruleset = "create",
		campaignID = "fog-memory",
		players = {
			{ id = 1, name = "ONE", civ = "iron", techs = {} },
			{ id = 2, name = "TWO", civ = "forge", techs = {} },
			{ id = 3, name = "THREE", civ = "wild", techs = {} },
		},
		units = {
			{ id = 1, owner = 1, kind = "scout", x = 3, y = 6, movesLeft = 4 },
			{ id = 2, owner = 2, kind = "warrior", x = 6, y = 6, movesLeft = 2 },
		},
		cities = {
			{
				id = 4,
				owner = 2,
				name = "ASH CITY",
				x = 6,
				y = 6,
				population = 2,
				hp = 77,
				buildings = { walls = true },
				project = { SECRET = true },
			},
		},
		world = {
			width = 18,
			height = 12,
			tiles = {},
			geography = {},
			resources = {},
			rails = {},
			landmarks = {},
		},
	}
	for y = 1, 12 do
		for x = 1, 18 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	state.world.tiles["6:6"] = "forest"
	state.world.geography["6:6"] = { biome = "forest", elevation = "flat", feature = "woods" }
	state.world.resources["6:6"] = "copper"
	S.migrate(state)
	W.reveal(state, H, S)
	return state
end
local state = fixture()
assert(W.observedCity(state, state.players[1], 6, 6).name == "ASH CITY")
state.units[1].x = 16
W.reveal(state, H, S)
local original = Presentation.capture(state, 1)
local city = W.observedCity(original, original.players[1], 6, 6)
assert(city.remembered and city.name == "ASH CITY" and city.lastSeenRound == 1 and not city.project)
assert(W.observedOwner(original, original.players[1], 6, 6) == 2)
state.round = 3
state.cities[1].name, state.cities[1].owner, state.cities[1].hp = "HIDDEN NAME", 3, 1
state.cities[1].buildings.fortress = true
state.world.geography["6:6"].biome = "desert"
state.world.tiles["6:6"], state.world.resources["6:6"] = "mountain", "diamond"
state.cities[#state.cities + 1] = {
	id = 5,
	owner = 3,
	name = "HIDDEN CITY",
	x = 5,
	y = 7,
	population = 2,
	hp = 200,
	buildings = {},
}
state.units[2].x = 4
W.reveal(state, H, S)
local updated = Presentation.capture(state, 1)
city = W.observedCity(updated, updated.players[1], 6, 6)
assert(
	city.name == "ASH CITY" and city.owner == 2 and city.hp == 77 and not city.buildings.fortress
)
assert(updated.world.tiles["6:6"] == "forest" and updated.world.geography["6:6"].biome == "forest")
assert(updated.world.resources["6:6"] == "copper" and updated.world.observedOwners["6:6"] == 2)
assert(not W.observedCity(updated, updated.players[1], 5, 7))
assert(
	#updated.units == 1 and #updated.cities == 0,
	"Remembered scenery cannot become current combat/AI entities"
)
local sender, receiver = Snapshots.sender("fog-host"), Snapshots.receiver()
local remote = assert(receiver:accept(sender(1, W.forPlayer(state, 1)), 1))
assert(W.observedCity(remote, remote.players[1], 6, 6).name == "ASH CITY")
assert(remote.world.resources["6:6"] == "copper" and remote.world.observedOwners["6:6"] == 2)

for _, graphics in ipairs({ false, true }) do
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 600, 603
			end
			return 100, 67
		end,
		setCursorPos = function() end,
		setTextColor = function() end,
		setBackgroundColor = function() end,
		write = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
		monitor.getPaletteColor = function()
			return 0, 0, 0
		end
		monitor.setPaletteColor = function() end
	end
	local ui = UI.new(monitor, function()
		error("Fog inspection cannot issue orders")
	end)
	ui.animationPreferences.speed = "off"
	ui:draw(updated, 1, {})
	ui.panX, ui.panY, ui.zoomLevel = 60, 40, 20
	ui.selected = { empty = true, x = 0, y = 0 }
	ui:draw(updated, 1, {})
	local map = ui.mapViewport
	local function mapPixels()
		if not graphics then
			return
		end
		local rows = {}
		for y = math.floor(map.y) + 1, math.floor(map.y + map.h) do
			rows[#rows + 1] = table
				.concat(ui.r.frameRows[y])
				:sub(math.floor(map.x) + 1, math.floor(map.x + map.w))
		end
		return table.concat(rows)
	end
	local before = mapPixels()
	local seen, originalText = {}, ui.r.text
	ui.r.text = function(self, x, y, text, ...)
		seen[#seen + 1] = tostring(text)
		return originalText(self, x, y, text, ...)
	end
	ui:draw(updated, 1, {})
	assert(table.concat(seen, " "):find("ASH CITY", 1, true))
	assert(not table.concat(seen, " "):find("HIDDEN", 1, true))
	if graphics then
		local target
		for _, hex in ipairs(ui.hexTargets) do
			if hex.tx == 6 and hex.ty == 6 then
				target = hex
			end
		end
		assert(target)
		for y = math.floor(target.y + 7), math.floor(target.y + 12) do
			for x = math.floor(target.x + 7), math.floor(target.x + 12) do
				local color = ui.r.frameRows[y + 1][x + 1]:byte()
				assert(
					color == 0 or color >= 36 and color <= 42,
					"Remembered city sprites and terrain are greyscale"
				)
			end
		end
	end
	if state.cities[1].id == 4 then
		table.remove(state.cities, 1)
	end
	W.reveal(state, H, S)
	updated = Presentation.capture(state, 1)
	ui:draw(updated, 1, {})
	assert(
		not graphics or mapPixels() == before,
		"Unseen city destruction leaves the frozen map unchanged"
	)
	ui:focus("city", city)
	ui.panel = "inspector"
	seen = {}
	ui:draw(updated, 1, {})
	assert(table.concat(seen, " "):find("LAST SEEN", 1, true))
	ui:close()
end
state.units[1].x = 3
W.reveal(state, H, S)
updated = Presentation.capture(state, 1)
assert(
	not W.observedCity(updated, updated.players[1], 6, 6),
	"Re-scouting removes a destroyed city"
)
assert(W.observedCity(updated, updated.players[1], 5, 7).name == "HIDDEN CITY")
assert(updated.world.resources["6:6"] == "diamond" and updated.world.tiles["6:6"] == "mountain")
assert(updated.world.geography["6:6"].biome == "desert")
print(
	"CIVCRAFT: frozen cities, terrain/deposits/borders, grey remembered sprites, private snapshots and re-scouting passed."
)

state = fixture()
state.units = {}
state.cities[1].owner = 1
W.reveal(state, H, S)
state.cities[1].owner = 2
W.reveal(state, H, S)
local defeated = W.forPlayer(state, 1)
city = W.observedCity(defeated, defeated.players[1], 6, 6)
assert(
	city and city.remembered and city.owner == 2 and not defeated.players[1].visible["6:6"],
	"Losing a sight source retains the final observed capture rather than stale ownership"
)
local Fog = dofile("/games/civcraft/fog_view.lua")
local draws = {}
local first = {
	palette = {},
	fill = function()
		draws[#draws + 1] = 1
	end,
}
local second = {
	palette = {},
	fill = function()
		draws[#draws + 1] = 2
	end,
}
local ui = { r = first }
Fog.forUI(ui):fill(0, 0, 1, 1, 0)
ui.r = second
Fog.forUI(ui):fill(0, 0, 1, 1, 0)
assert(
	draws[1] == 1 and draws[2] == 2,
	"Display preference changes replace the remembered-map renderer"
)
print("CIVCRAFT: last-look capture memory and recreated display tinting passed.")
