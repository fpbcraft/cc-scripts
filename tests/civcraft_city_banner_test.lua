local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Banner = dofile("/games/civcraft/city_banner.lua")
local S = dofile("/games/civcraft/systems.lua")
local W = dofile("/games/civcraft/world.lua")
local state = {
	version = 6,
	ruleset = "create",
	contentRules = "balance4",
	phase = "game",
	round = 1,
	nextId = 3,
	players = { { id = 0, name = "OAK", civ = "verdant", techs = {}, gold = 100 } },
	units = {},
	cities = {
		{
			id = 1,
			owner = 0,
			capitalOf = 0,
			name = "MUSHROOMHAM",
			x = 4,
			y = 4,
			population = 2,
			buildings = {},
			jobs = { food = 2, wood = 0, science = 0 },
		},
	},
	world = { width = 12, height = 8, tiles = {}, resources = {}, landmarks = {}, rails = {} },
}
for y = 1, 8 do
	for x = 1, 12 do
		state.world.tiles[W.key(x, y)] = "plains"
	end
end
S.migrate(state)
local p, c = state.players[1], state.cities[1]
c.worked = nil
c.project = { kind = "unit", id = "scout", progress = 3 }
local model = Banner.model(state, p, c, S)
assert(model.population == 2 and model.capital and model.strength and model.private)
assert(model.production:match("^P%d+T$") and model.growth)
assert(
	c.worked == nil,
	"Banner forecasts cannot initialize workers or change the authoritative city"
)
c.project = nil
assert(Banner.model(state, p, c, S).production == "IDLE")
c.productionIdle = true
assert(Banner.model(state, p, c, S).production == "PAUSE")
c.population = 1
c.project = { kind = "unit", id = "settler", progress = 0 }
assert(Banner.model(state, p, c, S).production == "WAIT")
state.contentRules = "p1"
p.contentRules = "p1"
assert(
	Banner.model(state, p, c, S).production == "WAIT",
	"Historical profile labels cannot bypass current Settler population requirements"
)
state.contentRules = "balance4"
p.contentRules = "balance4"
c.population = 2
local rival = {
	id = 5,
	owner = 1,
	name = "FOREIGN",
	population = 7,
	hp = 150,
	maxHP = 200,
	wallHP = 50,
	maxWalls = 100,
	publicDefense = 42,
	project = { kind = "unit", id = "settler", progress = 20 },
	foodStore = 999,
	capitalOf = 1,
}
local public = Banner.model(state, p, rival, S)
assert(
	public.population == 7
		and public.strength == 42
		and not public.private
		and not public.production
		and not public.growth
)
rival.remembered = true
assert(Banner.model(state, p, rival, S).remembered)
for _, mode in ipairs({ "text", "graphics" }) do
	local r = { mode = mode, texts = {}, rectangles = {} }
	function r:textWidth(value)
		return #tostring(value) * (self.mode == "text" and 2 or 4)
	end
	function r:fill(x, y, w, h)
		self.rectangles[#self.rectangles + 1] = { x = x, y = y, w = w, h = h }
	end
	function r:outline() end
	function r:text(x, y, value, _, _, width)
		self.texts[#self.texts + 1] = { x = x, y = y, text = value, width = width }
	end
	for _, width in ipairs({ 28, 38, 80, 140 }) do
		local rect = { x = 0, y = 0, w = width, h = 80 }
		local box = Banner.layout(r, model, { x = width / 2, y = 35 }, rect, {})
		assert(box.x >= 0 and box.y >= 0 and box.x + box.w <= width and box.y + box.h <= 80)
		Banner.draw(r, model, box, 8)
		local pop = false
		for _, text in ipairs(r.texts) do
			if text.text == "2" then
				pop = true
			end
		end
		assert(pop, "Population remains present even when the name must truncate")
	end
	local rect = { x = 0, y = 0, w = 140, h = 100 }
	local first = Banner.layout(r, model, { x = 60, y = 40 }, rect, {})
	local second = Banner.layout(r, public, { x = 65, y = 40 }, rect, { first })
	assert(
		first.y + first.h <= second.y or second.y + second.h <= first.y,
		"Nearby banners must separate when there is space"
	)
end
print(
	"PASS: city population, public defenses, private read-only forecasts and responsive banner layout"
)
