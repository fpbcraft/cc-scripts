local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
local CityRoles = dofile("/games/civcraft/ai_city_roles.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Materials = dofile("/games/civcraft/ai_materials.lua")
local Content = dofile("/games/civcraft/content.lua")
local function fixture(profile)
	local p = {
		id = 0,
		civ = "verdant",
		gold = 100,
		techs = {
			writing = true,
			engineering = true,
			currency = true,
			crafting = true,
		},
		aiPlan = { primary = "expedition" },
	}
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = profile or "balance5",
		phase = "game",
		round = 1,
		turn = 1,
		nextId = 100,
		players = { p },
		units = {},
		cities = {
			{
				id = 1,
				owner = 0,
				x = 4,
				y = 4,
				population = 3,
				buildings = { craftinghall = true, library = true, market = true, housing = true },
				worked = {},
			},
			{
				id = 2,
				owner = 0,
				x = 12,
				y = 4,
				population = 3,
				buildings = { craftinghall = true, library = true, market = true, housing = true },
				worked = {},
			},
		},
		world = { width = 16, height = 9, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 9 do
		for x = 1, 16 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	state.world.tiles["5:4"] = "hills"
	state.world.tiles["13:4"] = "mountain"
	for i = 1, 4 do
		state.units[#state.units + 1] =
			{ id = 20 + i, owner = 0, kind = "warrior", x = 4, y = 4, movesLeft = 0 }
	end
	for i = 1, 2 do
		state.units[#state.units + 1] =
			{ id = 30 + i, owner = 0, kind = "builder", x = 4, y = 4, movesLeft = 0, charges = 3 }
	end
	state.units[#state.units + 1] =
		{ id = 40, owner = 0, kind = "scout", x = 4, y = 4, movesLeft = 0 }
	state.cities[1].worked = { ["5:4"] = true, ["4:3"] = true, ["3:4"] = true }
	state.cities[2].worked = { ["12:3"] = true, ["11:4"] = true, ["12:5"] = true }
	for _, city in ipairs(state.cities) do
		for k in pairs(city.worked) do
			state.world.resources[k] = "grain"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, p
end
local function snapshot(state, p)
	local view = AI.knowledge(state, p)
	local known
	for _, candidate in ipairs(view.players) do
		if candidate.id == p.id then
			known = candidate
		end
	end
	return view, known
end
local state, p = fixture()
local view, known = snapshot(state, p)
local roles = CityRoles.choose(view, known, S)
assert(
	roles[1] == "industry" and roles[2] == "science",
	"Observed hills and mountains give cities different roles"
)
p.aiPlan.citySpecializations = roles
view, known = snapshot(state, p)
local choices1 = Production.ranked(view, known, view.cities[1], S, false)
local choices2 = Production.ranked(view, known, view.cities[2], S, false)
assert(choices1[1].siteKind == "works", "Industry city invests in its legal Works site")
assert(choices2[1].siteKind == "knowledge", "Science city invests in its legal Knowledge site")
local request = choices1[1].request
assert(request.action == "placeSite" and Actions.apply(state, 0, request, S))
local id = state.cities[1].project.id
assert(Sites.advance(state, p, state.cities[1], 8) == false)
assert(AI.choose(state, p, state.cities[1], S))
assert(
	state.cities[1].project.id == id and state.cities[1].siteProjects[id].progress == 8,
	"Valid investment is preserved"
)
assert(S.queue(p, state.cities[1], "building", "pens", state, H) == false)
-- Paused work resumes its exact record instead of reserving another site.
assert(S.queue(p, state.cities[1], "none", nil, state, H))
view, known = snapshot(state, p)
local resumed = Production.ranked(view, known, view.cities[1], S, false)
assert(resumed[1].request.action == "resumeSite" and resumed[1].id == id)
assert(Actions.apply(state, 0, resumed[1].request, S))
assert(state.nextSiteId == 2)
assert(Sites.advance(state, p, state.cities[1], 30))
view, known = snapshot(state, p)
local developed = Production.ranked(view, known, view.cities[1], S, false)
for _, choice in ipairs(developed) do
	assert(
		not choice.request or choice.request.action ~= "redevelopSite",
		"Active investments do not churn for adjacency"
	)
end
-- Completed families survive loss of population and are restored through legal relocation.
local city = state.cities[1]
city.population = 1
local old = city.sites.works
city.claimed[W.key(old.x, old.y)] = nil
view, known = snapshot(state, p)
local recovery = Production.ranked(view, known, view.cities[1], S, false)
local relocate
for _, choice in ipairs(recovery) do
	if choice.request and choice.request.action == "redevelopSite" then
		relocate = choice.request
		break
	end
end
assert(relocate and relocate.kind == "works" and relocate.siteId == old.id)
assert(Actions.apply(state, 0, relocate, S))
assert(Sites.allowance(state, city).used == 1)
-- The revised End bridge must not value an impossible Knowledge prerequisite.
local deps = {}
Values.dependencies(S.buildings, "dragon", {}, 400, deps, view)
assert(
	deps.portal and deps.observatory and not deps.academy,
	"V5 End dependency plan follows the shared bridge"
)
local legacy = {}
Values.dependencies(S.buildings, "dragon", {}, 400, legacy, { contentRules = "balance4" })
assert(
	legacy.portal and legacy.observatory and not legacy.academy,
	"Historical IDs use the current End bridge"
)
-- Host changes outside observed geography cannot alter legal AI investments.
state, p = fixture()
view, known = snapshot(state, p)
local before = Production.ranked(view, known, view.cities[2], S, false)
state.world.resources["16:9"] = "diamond"
state.world.tiles["16:9"] = "mountain"
local afterView, afterPlayer = snapshot(state, p)
local after = Production.ranked(afterView, afterPlayer, afterView.cities[2], S, false)
assert(
	before[1].id == after[1].id and before[1].score == after[1].score,
	"Unseen changes cannot steer site valuation"
)
-- If a target is invalidated after planning, shared action rejection keeps all investment untouched.
local stale = before[1].request
state.world.improvements = { [W.key(stale.x, stale.y)] = { kind = "farm" } }
assert(not Actions.apply(state, 0, stale, S))
assert(state.nextSiteId == 1 and not state.cities[2].project)
local original, oldPlayer = fixture("balance4")
local oldView, oldKnown = snapshot(original, oldPlayer)
local currentSites = false
for _, choice in ipairs(Production.ranked(oldView, oldKnown, oldView.cities[1], S, false)) do
	currentSites = currentSites or choice.kind == "site"
end
assert(original.contentRules == "balance5" and currentSites, "Migrated AI plans current sites")
-- Immediate survival investments remain alternatives to filling focus slots.
state, p = fixture()
state.cities[1].worked = {}
view, known = snapshot(state, p)
local hungry = Production.ranked(view, known, view.cities[1], S, false)
assert(
	hungry[1].kind == "project" and hungry[1].id == "tend",
	"Starving city can prefer food work to a site"
)
state, p = fixture()
p.aiPlan.emergency = "defendCapital"
p.techs.masonry = true
state.units = {}
view, known = snapshot(state, p)
local defense = Production.ranked(view, known, view.cities[1], S, false)
assert(defense[1].kind ~= "site", "Immediate defense can outrank specialization")
-- Visible threats exclude exposed site construction without reading hidden enemies.
state, p = fixture()
state.units[#state.units + 1] =
	{ id = 99, owner = -1, kind = "zombie", x = 5, y = 4, movesLeft = 0 }
W.reveal(state, H, S)
view, known = snapshot(state, p)
local threatened = Production.ranked(view, known, view.cities[1], S, false)
for _, choice in ipairs(threatened) do
	if choice.request and choice.request.action == "placeSite" then
		assert(
			H.distance(choice.tileX, choice.tileY, 5, 4) > 2,
			"No site investment beside a visible hostile"
		)
	end
end
-- Known hostile city strike range is also part of investment safety.
state, p = fixture()
state.cities[#state.cities + 1] =
	{ id = 3, owner = -1, x = 6, y = 4, population = 2, buildings = { walls = true }, worked = {} }
W.reveal(state, H, S)
view, known = snapshot(state, p)
local exposed = Production.ranked(view, known, view.cities[1], S, false)
for _, choice in ipairs(exposed) do
	if choice.request and choice.request.action == "placeSite" then
		assert(
			H.distance(choice.tileX, choice.tileY, 6, 4) > 2,
			"No site investment under an observed hostile city"
		)
	end
end
-- Reserved production remains part of a city's role even when focus is full.
state, p = fixture()
assert(
	Actions.apply(
		state,
		0,
		{ action = "placeSite", city = 2, kind = "knowledge", x = 12, y = 3 },
		S
	)
)
assert(S.queue(p, state.cities[2], "none", nil, state, H))
view, known = snapshot(state, p)
assert(
	CityRoles.choose(view, known, S)[2] == "science",
	"Retained Knowledge investment preserves its city role"
)
-- Retained machinery without effective Works must not trigger material purchases.
state, p = fixture()
p.techs.brassworking, p.techs.heatedmixing, p.techs.deepmining = true, true, true
state.cities[1].buildings.mixer = true
view, known = snapshot(state, p)
assert(not Sites.effectiveBuilding(view, view.cities[1], "mixer"))
local orders, targets = Materials.orders(view, known, S)
assert(
	#orders == 0 and not targets.copper and not targets.zinc,
	"Inactive mixer creates no brass material demand"
)
assert(Actions.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
assert(Sites.advance(state, p, state.cities[1], 30))
view, known = snapshot(state, p)
orders, targets = Materials.orders(view, known, S)
assert(
	#orders == 2 and targets.copper == 1 and targets.zinc == 1,
	"Effective mixer keeps normal material demand"
)
state.contentRules = "balance4"
view, known = snapshot(state, p)
orders, targets = Materials.orders(view, known, S)
assert(
	#orders == 2 and targets.copper == 1 and targets.zinc == 1,
	"Legacy mixer retains material demand"
)
-- Native save/load preserves deterministic ranked requests and retained progress.
if fs and textutils then
	state, p = fixture()
	view, known = snapshot(state, p)
	local requestBefore = Production.ranked(view, known, view.cities[1], S, false)[1].request
	assert(Actions.apply(state, 0, requestBefore, S))
	Sites.advance(state, p, state.cities[1], 8)
	local Saves = dofile("/games/civcraft/saves.lua")
	local path = Saves.path(1)
	assert(Saves.writeFile(path, state))
	local loaded = S.migrate(assert(Saves.load(1)))
	local savedPlayer = loaded.players[1]
	local savedView, savedKnown = snapshot(loaded, savedPlayer)
	local savedChoice = Production.ranked(savedView, savedKnown, savedView.cities[1], S, false)[1]
	assert(
		savedChoice.request.action == "resumeSite" and savedChoice.id == loaded.cities[1].project.id
	)
	assert(loaded.cities[1].siteProjects[savedChoice.id].progress == 8)
	fs.delete(path)
end
print(
	"PASS: observed specialty roles, legal production/resume/relocation, End bridge, rejection, legacy and native save behavior"
)
