local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)

local Actions = dofile("/games/civcraft/actions.lua")
local Content = dofile("/games/civcraft/content.lua")
local Economy = dofile("/games/civcraft/economy.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Queue = dofile("/games/civcraft/queued_routes.lua")
local Railways = dofile("/games/civcraft/railways.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")

local function fixture()
	local technologies = {}
	for id in pairs(Content.techs) do
		technologies[id] = true
	end
	local player = {
		id = 1,
		name = "CYLINDER",
		civ = "iron",
		techs = technologies,
		gold = 100,
	}
	local observer = { id = 2, name = "OBSERVER", civ = "verdant", techs = {}, gold = 100 }
	local state = {
		version = 6,
		phase = "game",
		name = "WRAPPED LIFECYCLE",
		campaignID = "wrapped-lifecycle-test",
		ruleset = "create",
		contentRules = "balance5",
		gameSpeed = "normal",
		round = 1,
		turn = 1,
		nextId = 100,
		players = { player, observer },
		cities = {
			{
				id = 10,
				owner = player.id,
				x = 1,
				y = 4,
				population = 7,
				buildings = { station = true },
				worked = {},
			},
			{
				id = 20,
				owner = player.id,
				x = 6,
				y = 4,
				population = 7,
				buildings = { station = true },
				worked = {},
			},
		},
		units = {},
		world = {
			width = 8,
			height = 10,
			wrapX = true,
			seed = 241,
			tiles = {},
			resources = {},
			landmarks = {},
			rails = {},
		},
	}
	for y = 1, state.world.height do
		for x = 1, state.world.width do
			state.world.tiles[World.key(x, y)] = "plains"
			player.explored = player.explored or {}
			player.explored[World.key(x, y)] = true
		end
	end
	local builders = {
		{ id = 101, x = 2, y = 4 },
		{ id = 102, x = 1, y = 4 },
		{ id = 103, x = 8, y = 4 },
		{ id = 104, x = 7, y = 4 },
	}
	for _, placement in ipairs(builders) do
		state.units[#state.units + 1] = {
			id = placement.id,
			owner = player.id,
			kind = "engineer",
			x = placement.x,
			y = placement.y,
			movesLeft = 3,
		}
	end
	state.units[#state.units + 1] = {
		id = 200,
		owner = player.id,
		kind = "scout",
		x = 2,
		y = 6,
		movesLeft = 1,
	}
	World.migrate(state)
	Systems.migrate(state)
	player.stockpile.iron = 100
	World.reveal(state, Hex, Systems)
	return state, player, observer
end

local state, player, observer = fixture()
local first, second = state.cities[1], state.cities[2]
assert(Hex.distance(first.x, first.y, state.world.width, 4, state) == 1)
assert(World.territoryCity(state, Hex, state.world.width, 4) == first)
assert(World.territoryCity(state, Hex, 7, 4) == second)

-- Site placement crosses the saved-coordinate seam, then production completes it.
for _, request in ipairs({
	{ action = "placeSite", city = first.id, kind = "freight", x = 8, y = 4 },
	{ action = "placeSite", city = second.id, kind = "freight", x = 7, y = 4 },
}) do
	assert(Actions.apply(state, player.id, request, Systems))
end
assert(first.siteProjects[1].x == 8 and first.project.x == 8)
assert(second.siteProjects[2].x == 7 and second.project.x == 7)

observer.explored = { ["1:4"] = true, ["7:4"] = true, ["8:4"] = true }
observer.visible = { ["1:4"] = true, ["7:4"] = true, ["8:4"] = true }
local pendingView = World.forPlayer(state, observer.id)
for _, city in ipairs(pendingView.cities) do
	if city.id == first.id then
		assert(city.sites == nil and city.siteProjects == nil, "Pending specialty details leaked")
	end
end
assert(
	not pendingView.world.specialtySites["8:4"],
	"A reserved site leaked before production completion"
)
for _, event in ipairs((pendingView.eventStream or {}).entries or {}) do
	assert(event.type ~= "order", "Owner-only specialty selection leaked to the observer")
end

for turn = 1, 100 do
	Systems.production(state, Hex)
	if first.sites and first.sites.freight and second.sites and second.sites.freight then
		break
	end
end
assert(first.sites.freight and first.sites.freight.x == 8, "Seam freight site did not complete")
assert(second.sites.freight and second.sites.freight.x == 7, "Second freight site did not complete")
assert(first.project == nil and second.project == nil)
assert(Sites.effects(state, first).gold == 1 and Sites.effects(state, second).gold == 1)
local siteEvent
for _, event in ipairs((World.forPlayer(state, observer.id).eventStream or {}).entries or {}) do
	if event.type == "site" and event.target.x == 8 then
		siteEvent = event
	end
end
assert(
	siteEvent and siteEvent.target.x == 8,
	"Visible completion event lost its canonical seam coordinate"
)

-- Build the real rail segments through the wrapped Actions path. The five
-- connected tiles join both active stations through the horizontal seam.
for _, build in ipairs({
	{ unit = 101, sourceX = 2, x = 1 },
	{ unit = 102, sourceX = 1, x = 8 },
	{ unit = 103, sourceX = 8, x = 7 },
	{ unit = 104, sourceX = 7, x = 6 },
}) do
	local ok, why = Actions.apply(state, player.id, {
		action = "buildRail",
		unitID = build.unit,
		sx = build.sourceX,
		sy = 4,
		x = build.x,
		y = 4,
	}, Systems)
	assert(
		ok,
		"Build rail at x=" .. build.x .. " from x=" .. build.sourceX .. ": " .. tostring(why)
	)
	assert(
		state.world.rails[World.key(build.x, 4)],
		"Builder did not create the requested canonical rail"
	)
end
local network = Railways.network(state, player)
assert(
	network[first.id] and network[second.id],
	"Rails failed to connect both station cities across the seam"
)
assert(network[first.id].size == 2 and network[second.id].size == 2)
assert(Sites.effects(state, first).gold == 2 and Sites.effects(state, second).gold == 2)
assert(Economy.effects(first, state, Systems).gold == 4)
assert(Economy.effects(second, state, Systems).gold == 4)

local ownerView = World.forPlayer(state, player.id)
local ownerCity
for _, city in ipairs(ownerView.cities) do
	if city.id == first.id then
		ownerCity = city
	end
end
assert(ownerCity and ownerCity.sites.freight.x == 8)
assert(ownerCity.focus.used == 1 and ownerCity.familyAvailability.freight.available)
observer.explored = { ["1:4"] = true, ["7:4"] = true, ["8:4"] = true }
observer.visible = { ["1:4"] = true, ["7:4"] = true, ["8:4"] = true }
local publicView = World.forPlayer(state, observer.id)
local publicSite = publicView.world.specialtySites["8:4"]
assert(
	publicSite
		and publicSite.kind == "freight"
		and publicSite.x == 8
		and publicSite.owner == player.id
)
local publicCity
for _, city in ipairs(publicView.cities) do
	if city.id == first.id then
		publicCity = city
	end
end
assert(
	publicCity
		and publicCity.sites == nil
		and publicCity.focus == nil
		and publicCity.siteProjects == nil,
	"The observer's city projection includes owner-only specialty details: "
		.. tostring(publicCity and publicCity.owner)
		.. ", sites="
		.. tostring(publicCity and publicCity.sites)
		.. ", focus="
		.. tostring(publicCity and publicCity.focus)
		.. ", projects="
		.. tostring(publicCity and publicCity.siteProjects)
)
assert(publicSite.progress == nil and publicSite.bonus == nil and publicSite.project == nil)

-- Redevelopment reserves the existing seam site, runs through production, and
-- replaces both its family output and the now-inactive station building.
local freightId = first.sites.freight.id
assert(Actions.apply(state, player.id, {
	action = "redevelopSite",
	city = first.id,
	siteId = freightId,
	kind = "works",
	x = 8,
	y = 4,
}, Systems))
assert(
	first.project.kind == "site" and first.siteProjects[first.project.id].sourceSiteId == freightId
)
assert(Sites.effects(state, first).gold == 2, "Redevelopment changed output before completion")
local projectID = first.project.id
Systems.migrate(state)
assert(first.siteProjects[projectID].sourceSiteId == freightId)
assert(first.siteProjects[projectID].progress == first.project.progress)
for turn = 1, 100 do
	Systems.production(state, Hex)
	if first.sites.works and not first.project then
		break
	end
end
assert(first.sites.works and first.sites.works.x == 8, "Seam redevelopment did not complete")
assert(first.sites.freight == nil and first.buildings.station == nil)
assert(Sites.effects(state, first).industry == 1 and Sites.effects(state, first).gold == 0)
assert(
	not Railways.network(state, player)[first.id] and not Railways.network(state, player)[second.id]
)
assert(
	Sites.effects(state, second).gold == 2,
	"The remaining freight site lost its rail-tile bonus"
)
assert(Economy.effects(first, state, Systems).gold == 0)
assert(Economy.effects(second, state, Systems).gold == 2)

-- Queue a wrapped route, persist it through the normal migration boundary, and
-- execute the actual next steps across x=1 -> x=8 using canonical path points.
local scout = state.units[#state.units]
assert(scout.id == 200 and scout.x == 2 and scout.y == 6)
local queued, why = Actions.apply(state, player.id, {
	action = "queueMove",
	unitID = scout.id,
	sx = scout.x,
	sy = scout.y,
	x = 7,
	y = 6,
}, Systems)
assert(queued, why)
assert(scout.x == 1 and scout.moveQueue, "Queued seam route did not consume its first legal step")
assert(scout.moveQueue.goals[1].x == 7 and scout.moveQueue.path[1].x == 2)
Systems.migrate(state)
local cursor = scout.moveQueue.next
assert(scout.moveQueue and scout.moveQueue.path[cursor].x == 8)
scout.movesLeft, scout.moved = 1, false
Queue.run(state, player.id, Systems, Actions.apply, scout)
assert(scout.x == 8 and scout.moveQueue, "Persisted route did not cross the seam canonically")
assert(scout.moveQueue.path[scout.moveQueue.next].x == 7)
scout.movesLeft, scout.moved = 1, false
Queue.run(state, player.id, Systems, Actions.apply, scout)
assert(scout.x == 7 and scout.moveQueue == nil, "Persisted route did not reach its canonical goal")

-- A missing topology flag keeps old saves bounded, and action/path aliases are
-- rejected even when the same coordinate would be a legal wrapped display copy.
local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[clone(key)] = clone(item)
	end
	return result
end
local legacy = clone(state)
legacy.world.wrapX = nil
World.migrate(legacy)
Systems.migrate(legacy)
assert(legacy.world.wrapX == false)
assert(Hex.canonical(0, 4, legacy) == nil and not Hex.inBounds(9, 4, legacy))
assert(Hex.distance(1, 4, 8, 4, legacy) > 1)
assert(
	not Queue.preview(
		World.forPlayer(legacy, player.id),
		legacy.units[#legacy.units],
		9,
		6,
		false,
		Systems
	)
)
print(
	"CIVCRAFT: wrapped site production/redevelopment, privacy, rail network, and route lifecycle passed."
)
