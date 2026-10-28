local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local A = dofile("/games/civcraft/actions.lua")
local Content = dofile("/games/civcraft/content.lua")
local function fixture()
	local p = { id = 0, civ = "forge", techs = {}, gold = 100 }
	for id in pairs(Content.techs) do
		p.techs[id] = true
	end
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = "balance5",
		phase = "game",
		logs = {},
		round = 1,
		turn = 1,
		nextId = 20,
		players = { p, { id = 1, civ = "iron", techs = {}, gold = 100 } },
		cities = {
			{ id = 1, owner = 0, x = 4, y = 4, population = 7, buildings = {}, worked = {} },
		},
		units = {},
		world = { width = 12, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, p, state.cities[1]
end
local state, p, c = fixture()
assert(Sites.allowance(state, c).allowed == 3)
assert(A.apply(state, 0, { action = "placeSite", city = c.id, kind = "works", x = 5, y = 4 }, S))
assert(c.project.kind == "site" and state.nextSiteId == 2)
assert(
	not A.apply(state, 0, { action = "placeSite", city = c.id, kind = "works", x = 5, y = 4 }, S)
)
assert(state.nextSiteId == 2)
assert(Sites.advance(state, p, c, 10) == false)
assert(S.queue(p, c, "building", "library", state, H))
assert(c.siteProjects[1].progress == 10)
assert(A.apply(state, 0, { action = "resumeSite", city = c.id, projectId = 1 }, S))
assert(Sites.advance(state, p, c, 20))
assert(c.sites.works.id == 1 and not c.project)
assert(Sites.effects(state, c).industry == 1)
assert(S.canBuild(p, c, "workshop", state))
c.buildings.workshop = true
assert(Sites.effectiveBuilding(state, c, "workshop"))
local base = S.centerYields(p, c, state).industry
assert(
	A.apply(
		state,
		0,
		{ action = "redevelopSite", city = c.id, siteId = 1, kind = "knowledge", x = 5, y = 4 },
		S
	)
)
assert(
	not A.apply(
		state,
		0,
		{ action = "redevelopSite", city = c.id, siteId = 1, kind = "freight", x = 4, y = 5 },
		S
	)
)
assert(Sites.allowance(state, c).used == 1)
assert(Sites.advance(state, p, c, 45))
assert(not c.sites.works and c.sites.knowledge and not c.buildings.workshop)
assert(S.centerYields(p, c, state).industry < base)
Sites.validate(state)
assert(
	A.apply(
		state,
		0,
		{ action = "redevelopSite", city = c.id, siteId = 2, kind = "knowledge", x = 4, y = 5 },
		S
	)
)
assert(Sites.advance(state, p, c, 45))
assert(c.sites.knowledge.x == 4)
for _, pop in ipairs({ 1, 3, 4, 6, 7 }) do
	c.population = pop
	assert(Sites.allowance(state, c).allowed == (pop < 4 and 1 or pop < 7 and 2 or 3))
end
c.population = 1
assert(not S.canBuild(p, c, "workshop", state))
c.buildings.portal = true
assert(S.canBuild(p, c, "observatory", state))
for _, r in ipairs({ { 0 / 0, 4 }, { math.huge, 4 }, { 5.5, 4 }, { 5, -1 } }) do
	assert(not Sites.canPlace(state, p, c, "works", r[1], r[2]))
end
assert(Sites.effectiveBuilding(state, c, "portal"))
local before = c.sites.knowledge.id
local view = W.forPlayer(state, 0)
view.cities[1].sites.knowledge.id = 99
assert(c.sites.knowledge.id == before)
print(
	"PASS: specialty placement, retained progress, redevelopment, focus shrink, End bridge and copied projections"
)
local function clone(t)
	if type(t) ~= "table" then
		return t
	end
	local r = {}
	for k, v in pairs(t) do
		r[k] = clone(v)
	end
	return r
end
local function encode(t)
	if type(t) ~= "table" then
		return type(t) .. ":" .. tostring(t)
	end
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local out = { "{" }
	for _, k in ipairs(keys) do
		out[#out + 1] = encode(k) .. "=" .. encode(t[k])
	end
	return table.concat(out, "|") .. "}"
end
-- Rejections preserve every authoritative table and all counters/events.
state, p, c = fixture()
for _, req in ipairs({
	{ action = "placeSite", city = 999, kind = "works", x = 5, y = 4 },
	{ action = "placeSite", city = 1, kind = "works", x = 0 / 0, y = 4 },
	{ action = "placeSite", city = 1, kind = "works", x = math.huge, y = 4 },
	{ action = "redevelopSite", city = 1, siteId = 99, kind = "works", x = 5, y = 4 },
	{ action = "resumeSite", city = 1, projectId = 99 },
	{ action = "cancelSite", city = 1, projectId = 99 },
}) do
	local beforeState = encode(state)
	assert(not A.apply(state, 0, req, S))
	assert(encode(state) == beforeState)
end
-- New sites cannot be added after shrink, but reserved work completes and operates.
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
assert(Sites.advance(state, p, c, 30))
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "knowledge", x = 4, y = 5 }, S))
c.population = 1
assert(Sites.advance(state, p, c, 30))
assert(Sites.allowance(state, c).overage == 1)
assert(Sites.effects(state, c).industry == 1 and Sites.effects(state, c).science == 1)
assert(not Sites.canPlace(state, p, c, "freight", 3, 4))
assert(
	A.apply(
		state,
		0,
		{ action = "redevelopSite", city = 1, siteId = 1, kind = "freight", x = 5, y = 4 },
		S
	)
)
assert(Sites.allowance(state, c).used == 2)
assert(A.apply(state, 0, { action = "cancelSite", city = 1, projectId = 3 }, S))
assert(c.sites.works and Sites.allowance(state, c).used == 2)
-- Capture/invalidation/occupation never discard completed flags or queued progress.
c.buildings.workshop = true
c.projectProgress["building:assembly"] = 17
c.claimed["5:4"] = nil
assert(not Sites.effectiveBuilding(state, c, "workshop"))
c.claimed["5:4"] = true
assert(Sites.effectiveBuilding(state, c, "workshop"))
c.owner = 1
assert(not Sites.effectiveBuilding(state, c, "workshop"))
assert(c.sites.works and c.projectProgress["building:assembly"] == 17)
c.owner = 0
state.units = { { id = 88, owner = -1, kind = "zombie", x = 5, y = 4, movesLeft = 0 } }
assert(not Sites.effectiveBuilding(state, c, "workshop"))
state.units = {}
assert(Sites.effectiveBuilding(state, c, "workshop"))
-- Every base building has intentional role gating; End and basics stay usable.
for id, record in pairs(Content.buildings) do
	local testState, player, city = fixture()
	for need in pairs(Content.buildings) do
		city.buildings[need] = true
	end
	city.buildings[id] = nil
	if Sites.families[id] or id == "farm" or id == "mine" or id == "councilhall" then
		assert(not S.canBuild(player, city, id, testState), id)
	elseif not record.coastal then
		assert(S.canBuild(player, city, id, testState), id)
	end
end
-- Actual production resolution constructs the site, not a unit/building fallback.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
c.siteProjects[1].progress = 29
c.project.progress = 29
S.production(state, H)
assert(c.sites.works and not c.project and #state.units == 0)
-- Bonuses use the owner's last observations and revelation technologies.
state, p, c = fixture()
state.world.resources["5:4"] = "diamond"
p.techs.deepmining = nil
assert(Sites.bonus(state, p, "knowledge", 5, 4) == 0)
p.techs.deepmining = true
assert(Sites.bonus(state, p, "knowledge", 5, 4) == 1)
W.reveal(state, H, S)
p.visible["5:4"] = nil
state.world.resources["5:4"] = nil
assert(Sites.bonus(state, p, "knowledge", 5, 4) == 1)
local projected = W.forPlayer(state, 0)
assert(Sites.bonus(projected, projected.players[1], "knowledge", 5, 4) == 1)
-- Public site memory survives loss of vision without exposing new construction.
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 4, y = 5 }, S))
assert(Sites.advance(state, p, c, 30))
W.reveal(state, H, S)
p.visible["4:5"] = nil
c.sites.works.kind = "freight"
c.sites.freight = c.sites.works
c.sites.works = nil
projected = W.forPlayer(state, 0)
assert(projected.world.specialtySites["4:5"].kind == "works")
-- Malformed save identities/reservations fail rather than silently duplicating yield.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
assert(Sites.advance(state, p, c, 30))
assert(
	A.apply(
		state,
		0,
		{ action = "redevelopSite", city = 1, siteId = 1, kind = "knowledge", x = 5, y = 4 },
		S
	)
)
Sites.validate(state)
for _, corrupt in ipairs({
	function(x)
		x.specialtySchema = 99
	end,
	function(x)
		x.specialtySchema = nil
	end,
	function(x)
		x.nextSiteId = 1
	end,
	function(x)
		x.cities[1].siteProjects[2].sourceSiteId = 99
	end,
	function(x)
		x.cities[1].siteProjects[2].progress = math.huge
	end,
	function(x)
		x.cities[1].siteProjects[2].id = 1
	end,
	function(x)
		x.cities[1].project.progress = 99
	end,
	function(x)
		local r = clone(x.cities[1].siteProjects[2])
		r.id = 3
		x.cities[1].siteProjects[3] = r
		x.nextSiteId = 4
	end,
}) do
	local bad = clone(state)
	corrupt(bad)
	assert(not pcall(Sites.validate, bad))
end
-- Earlier campaigns never acquire the new gates or semantics from incidental data.
for _, profile in ipairs({ "baseline", "p1", "balance1", "balance2", "balance3", "balance4" }) do
	local old, player, city = fixture()
	old.contentRules = profile
	S.migrate(old)
	assert(not Sites.enabled(old) and S.canBuild(player, city, "workshop", old))
	assert(not A.apply(old, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
end
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/specialty-validation"
	assert(Saves.writeFile(Saves.path(1), state))
	local restored = S.migrate(assert(Saves.load(1)))
	assert(encode(restored.cities[1].sites) == encode(c.sites))
	assert(restored.cities[1].siteProjects[2].progress == 0)
	assert(Sites.advance(restored, restored.players[1], restored.cities[1], 45))
	assert(restored.cities[1].sites.knowledge.id == 2 and not restored.cities[1].sites.works)
end
print(
	"PASS: rejection atomicity, all building roles, real production, fog bonuses, capture/invalidation, schema rejection, old profiles and native save/reload"
)
-- Shared forecasts include paid redevelopment and native event metadata survives projection.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
c.siteProjects[1].progress = 29
c.project.progress = 29
S.production(state, H)
local streams = state.eventJournal.streams[0].entries
local completion
for _, event in ipairs(streams) do
	if event.type == "site" then
		completion = event
	end
end
assert(completion and completion.specialty.cityId == 1 and completion.specialty.siteId == 1)
assert(completion.specialty.kind == "works" and completion.specialty.sourceSiteId == nil)
assert(
	A.apply(
		state,
		0,
		{ action = "redevelopSite", city = 1, siteId = 1, kind = "knowledge", x = 5, y = 4 },
		S
	)
)
assert(S.projectCost("site", 2, p, c) == 45)
local Banner = dofile("/games/civcraft/city_banner.lua")
local model = Banner.model(state, p, c, S)
local yields = S.yields(p, c, state, H, nil, true)
assert(model.production == "P" .. math.ceil(45 / math.max(1, yields.industry)) .. "T")
local own = W.forPlayer(state, 0).cities[1]
assert(own.focus.used == 1 and own.siteProjectStatus[2].cost == 45)
assert(own.familyAvailability.works.available and not own.familyAvailability.knowledge.available)
own.siteProjectStatus[2].cost = 999
assert(Sites.owned(state, p, c).siteProjectStatus[2].cost == 45)
c.siteProjects[2].progress = 44
c.project.progress = 44
S.production(state, H)
for _, event in ipairs(state.eventJournal.streams[0].entries) do
	if event.type == "site" then
		completion = event
	end
end
assert(completion.specialty.siteId == 2 and completion.specialty.sourceSiteId == 1)
-- Known road bonuses agree in host forecasts, copied snapshots and remembered fog.
state, p, c = fixture()
state.world.roads = { ["5:4"] = true }
W.reveal(state, H, S)
local function roadParity(expected)
	local projectedState = W.forPlayer(state, 0)
	assert(Sites.bonus(state, p, "freight", 5, 4) == expected)
	assert(Sites.bonus(projectedState, projectedState.players[1], "freight", 5, 4) == expected)
end
roadParity(1)
p.visible["5:4"] = nil
state.world.roads["5:4"] = nil
roadParity(1)
W.reveal(state, H, S)
roadParity(0)
print(
	"PASS: projected completion identities, paid redevelopment forecasts, owned status and observed-road parity"
)
-- Opponent site projections include only visible occupation, never private research/queues.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
assert(Sites.advance(state, p, c, 30))
local rival = state.players[2]
rival.visible = { ["5:4"] = true }
rival.explored = { ["5:4"] = true }
p.techs.engineering = nil
local public = W.forPlayer(state, 1).world.specialtySites["5:4"]
assert(public.kind == "works" and not public.inactive and not public.reason and not public.tech)
state.units = { { id = 88, owner = -1, kind = "zombie", x = 5, y = 4, movesLeft = 0 } }
public = W.forPlayer(state, 1).world.specialtySites["5:4"]
assert(public.inactive and public.siteProjectStatus == nil)
-- Site and Builder/wonder requests share hex exclusivity; rails may coexist by design.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
local Improvements = dofile("/games/civcraft/tile_improvements.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
assert(not Improvements.canPlace(state, p, "farm", 5, 4, S))
local wonder = next(S.wonders)
assert(not Landmarks.canPlace(state, c, wonder, 5, 4, S))
assert(A.apply(state, 0, { action = "cancelSite", city = 1, projectId = 1 }, S))
c.project = { kind = "wonder", id = wonder, x = 5, y = 4, progress = 0 }
assert(not Sites.canPlace(state, p, c, "works", 5, 4))
print(
	"PASS: opponent public occupation stays private-safe and shared tile reservations reject conflicting development"
)

-- Redevelopment must disclose the current investment, not a stale paused copy.
state, p, c = fixture()
assert(A.apply(state, 0, { action = "placeSite", city = 1, kind = "works", x = 5, y = 4 }, S))
assert(Sites.advance(state, p, c, 30))
c.projectProgress = { ["building:press"] = 4 }
c.project = { kind = "building", id = "press", progress = 17 }
local request = { action = "redevelopSite", city = 1, siteId = 1, kind = "knowledge", x = 5, y = 4 }
local losses = assert(Sites.preview(state, p, c, request)).lostProgress
assert(#losses == 1 and losses[1].id == "press" and losses[1].progress == 17)
assert(c.project.progress == 17 and c.projectProgress["building:press"] == 4)
assert(A.apply(state, 0, request, S))
assert(c.projectProgress["building:press"] == 17)
assert(Sites.advance(state, p, c, 45))
assert(c.projectProgress["building:press"] == nil)
print("PASS: redevelopment discloses active family progress exactly once without mutating previews")
