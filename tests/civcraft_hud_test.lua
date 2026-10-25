local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Colors = dofile("/games/civcraft/faction_colors.lua")
local HUD = dofile("/games/civcraft/hud.lua")
local Factions = dofile("/games/civcraft/faction_view.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local world = { width = 12, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} }
for y = 1, 10 do
	for x = 1, 12 do
		world.tiles[World.key(x, y)] = "plains"
	end
end
local state = {
	version = 6,
	phase = "game",
	round = 1,
	world = world,
	players = {
		{
			id = 1,
			name = "ONE",
			civ = "forge",
			techs = {},
			gold = 50,
			science = 987654,
			food = 876543,
			wood = 765432,
		},
		{ id = 2, name = "TWO" },
		{ id = 3, name = "THREE" },
		{ id = 4, name = "FOUR" },
	},
	cities = { { id = 5, owner = 1, x = 3, y = 5, population = 2, buildings = {} } },
	units = {},
}
Systems.migrate(state)
local player = state.players[1]
player.stockpile.iron, player.stockpile.copper = 123, 234
local lines = {}
local renderer = {
	w = 1000,
	buttons = {},
	scrollbars = {},
	h = 500,
	fill = function() end,
	outline = function() end,
	line = function() end,
	withClip = function(_, _, draw)
		draw()
	end,
	textWidth = function(_, text)
		return #tostring(text) * 4
	end,
	text = function(_, _, _, text)
		lines[#lines + 1] = tostring(text)
	end,
}
local ui = { r = renderer, state = state }
-- Inspect actual text produced by the HUD, including resources that are clipped on small terminals.
HUD.resources(ui, state, player)
local bar = table.concat(lines, " ")
assert(
	not bar:find("987", 1, true) and not bar:find("876", 1, true) and not bar:find("765", 1, true),
	"Food/science/industry totals never enter the top bar"
)
assert(
	not bar:find("123", 1, true) and not bar:find("234", 1, true),
	"Locked material stocks stay hidden"
)
assert(not bar:find("+0", 1, true))
player.techs.bronze = true
lines = {}
HUD.resources(ui, state, player)
bar = table.concat(lines, " ")
assert(bar:find("123", 1, true) and not bar:find("234", 1, true) and not bar:find("+0", 1, true))
world.resources["3:5"] = "iron"
lines = {}
HUD.resources(ui, state, player)
assert(table.concat(lines, " "):find("123+1", 1, true), "Positive material rates remain visible")
renderer.button = function() end
lines = {}
HUD.ledger(ui, { x = 0, y = 0, w = 1000, h = 500 }, player)
local ledger = table.concat(lines, " ")
assert(not ledger:find("+0", 1, true) and not ledger:find("234", 1, true))
assert(not ledger:find("987654", 1, true), "The ledger also presents science as a rate")
player.visible = { [World.key(3, 5)] = true }
state.units = {
	{ owner = 2, kind = "scout", x = 3, y = 5 },
	{ owner = 2, kind = "scout", x = 10, y = 9 },
}
player.contacts = { [2] = true }
state.players[2].gold = 123456
state.players[2].aiPlan = { primaryGoal = "SECRET CAMPAIGN" }
lines = {}
Factions.draw(ui, state, player, { x = 0, y = 0, w = 1000, h = 1000 })
local factions = table.concat(lines, " ")
assert(factions:find("CURRENTLY VISIBLE: 0 CITIES, 1 UNITS", 1, true))
assert(
	not factions:find("123456", 1, true) and not factions:find("SECRET CAMPAIGN", 1, true),
	"Faction details never reveal hidden economy or AI plans"
)
local seen = {}
for index, color in ipairs(Colors.players) do
	assert(color ~= 11 and color ~= 21 and not seen[color])
	seen[color] = true
	assert(Colors.owner(state, index) == color)
end
local painted = {}
local canvas = {
	fill = function(_, _, _, _, _, color)
		painted[color] = true
	end,
}
Icons.draw(canvas, "scout", 0, 0, 9, Colors.players[3])
assert(painted[Colors.players[3]], "Bitmap units honor their faction color")
-- Lobby selection exposes actual bonus text on both narrow and wide layouts.
state.phase = "lobby"
for _, size in ipairs({ { 57, 38 }, { 120, 90 } }) do
	local monitor = {
		getSize = function()
			return size[1], size[2]
		end,
		setCursorPos = function() end,
		setBackgroundColor = function() end,
		setTextColor = function() end,
		write = function() end,
	}
	local view = UI.new(monitor, function() end)
	local text = view.r.text
	local captured = {}
	view.r.text = function(self, x, y, value, ...)
		captured[#captured + 1] = tostring(value)
		return text(self, x, y, value, ...)
	end
	for offset = 0, 25 do
		view.lobbyOffset = offset
		view:draw(state, 1, { screen = "game", localMode = true })
	end
	assert(
		table.concat(captured, " "):find("Belt workshops", 1, true),
		"The civilization bonus is visible during selection"
	)
	view:close()
end
print(
	"CIVCRAFT: rate-only science/food/industry, unlocked material stocks, nonzero rates, distinct faction colors and lobby bonuses passed."
)
