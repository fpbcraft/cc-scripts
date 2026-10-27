-- Behavior-preservation checks for the lifecycle extraction.
--
-- The reference functions below are deliberately kept as a small, readable
-- transcription of the corresponding functions in HEAD's game.lua.  They
-- omit only presentation, save, trace and victory side effects; those are
-- UI/runtime concerns and are not part of the extracted lifecycle helpers.
-- This test compares the helper output with the reference on fresh seeded
-- states, rather than asserting a handful of expected fields.

local nativeDofile = dofile
dofile = function(path)
	return nativeDofile(path:gsub("^/games/civcraft/", "games/civcraft/"))
end

local Hex = dofile("games/civcraft/hex.lua")
local Systems = dofile("games/civcraft/systems.lua")
local World = dofile("games/civcraft/world.lua")
local Diplomacy = dofile("games/civcraft/diplomacy.lua")
local Scheduler = dofile("games/civcraft/turn_scheduler.lua")
local Hostiles = dofile("games/civcraft/hostiles.lua")
local Villages = dofile("games/civcraft/villages.lua")
local Council = dofile("games/civcraft/council.lua")
local Events = dofile("games/civcraft/events.lua")
local Combat = dofile("games/civcraft/combat.lua")
local MovementBudget = dofile("games/civcraft/movement_budget.lua")
local DiplomaticPerception = dofile("games/civcraft/diplomatic_perception.lua")
local Reports = dofile("games/civcraft/reports.lua")
local Presentation = dofile("games/civcraft/presentation.lua")
local CouncilAI = dofile("games/civcraft/council_ai.lua")
local QueuedRoutes = dofile("games/civcraft/queued_routes.lua")
local Actions = dofile("games/civcraft/actions.lua")

local Lifecycle = dofile("games/civcraft/match_lifecycle.lua")
local Actors = dofile("games/civcraft/actor_lifecycle.lua")

local function copy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do
		result[copy(key, seen)] = copy(child, seen)
	end
	return result
end

local function equal(left, right, path, seen)
	path = path or "state"
	assert(type(left) == type(right), path .. ": type mismatch")
	if type(left) ~= "table" then
		assert(left == right, path .. ": " .. tostring(left) .. " ~= " .. tostring(right))
		return
	end
	seen = seen or {}
	if seen[left] then
		assert(seen[left] == right, path .. ": reference mismatch")
		return
	end
	seen[left] = right
	for key, value in pairs(left) do
		assert(right[key] ~= nil, path .. ": missing " .. tostring(key))
		equal(value, right[key], path .. "." .. tostring(key), seen)
	end
	for key in pairs(right) do
		assert(left[key] ~= nil, path .. ": unexpected " .. tostring(key))
	end
end

local function lobby(campaignID)
	-- Equivalent to HEAD's newGame(), with a fixed campaign id so the two
	-- executions can be compared without depending on timestamp generation.
	return {
		campaignID = campaignID,
		version = 6,
		ruleset = "create",
		roundLimit = 180,
		gameSpeed = "standard",
		victoryRulesVersion = 2,
		diplomacy = Diplomacy.new(),
		scheduler = Scheduler.new(),
		hostileMode = "standard",
		phase = "lobby",
		round = 1,
		turn = 1,
		players = {},
		cities = {},
		units = {},
		nextId = 1,
		logs = { "Welcome to CIVCRAFT" },
		winner = nil,
		mapSize = "standard",
		mapType = "continents",
		mapSeed = 12345,
		name = "NEW EMPIRE",
	}
end

local function fixture(campaignID, seed, count, newLobby)
	local state = (newLobby or lobby)(campaignID)
	state.mapSeed = seed
	for id = 1, count do
		state.players[id] = {
			id = id,
			name = "PLAYER " .. id,
			ai = false,
			ready = false,
		}
	end
	return state
end

local function addUnit(state, owner, x, y, kind)
	local unit = {
		id = state.nextId,
		owner = owner,
		x = x,
		y = y,
		kind = kind,
		moved = false,
		movesLeft = Systems.units[kind].move,
	}
	state.nextId = state.nextId + 1
	table.insert(state.units, unit)
	return unit
end

-- Original initMap() body through World.reveal().  The original then calls
-- pumpActors(), logs and saves; those side effects are intentionally omitted.
local function referenceInitialize(state)
	state.world = World.generate(state.mapSeed, state.mapSize, #state.players, state.mapType)
	local width = state.world.width
	state.name = "EMPIRE " .. state.world.seed
	for i, participant in ipairs(state.players) do
		local pos = state.world.starts[i]
		local x, y = pos.x, pos.y
		table.insert(state.cities, {
			id = state.nextId,
			x = x,
			y = y,
			owner = participant.id,
			capitalOf = participant.id,
			level = 1,
			population = 2,
			foodStore = 0,
			jobs = { food = 1, wood = 1, science = 0 },
			buildings = {},
		})
		state.nextId = state.nextId + 1
		addUnit(state, participant.id, x + ((x < width / 2) and 1 or -1), y, "warrior")
		participant.food = 12
		participant.wood = 12
		participant.science = 0
		participant.tech = 0
		participant.ready = false
		participant.techs = participant.techs or {}
		participant.civ = participant.civ or Systems.civs[i].id
	end
	state.phase = "game"
	state.round = 1
	state.turn = 1
	Hostiles.generate(state)
	Villages.generate(state)
	Systems.migrate(state)
	Council.advance(state)
	Diplomacy.boundary(state)
	World.reveal(state, Hex, Systems)
	return state
end

local function findPlayer(state, id)
	for _, participant in ipairs(state.players) do
		if participant.id == id then
			return participant
		end
	end
end

-- Original nextTurn() body through report construction.  winner(), pumpActors,
-- logging and saving are deliberately outside this conformance boundary.
local function referenceAdvance(state)
	state.round = state.round + 1
	for _, participant in ipairs(state.players) do
		participant.ready = false
	end
	Council.advance(state)
	Diplomacy.boundary(state)
	Events.prune(state)
	Combat.round(state, Systems)
	Systems.production(state, Hex)
	Villages.round(state, Systems, Combat)
	Hostiles.round(state, Systems)
	for _, unit in ipairs(state.units) do
		local owner = findPlayer(state, unit.owner)
		local base = Systems.units[unit.kind] or Systems.units.warrior
		MovementBudget.reset(state, unit, base, owner, Hex)
	end
	World.reveal(state, Hex, Systems)
	DiplomaticPerception.promises(state, Hex, World, Systems.units)
	for _, unit in ipairs(state.units) do
		if unit.autoExplore and not unit.standby and Scheduler.canAct(state, unit.owner) then
			unit.autoExploreRound = state.round
			Systems.autoExplore(state, unit, Hex)
		end
	end
	for _, participant in ipairs(state.players) do
		participant.age = Systems.age(participant)
		participant.endStage = 0
		for _, city in ipairs(state.cities) do
			if city.owner == participant.id then
				for index, id in ipairs({ "eyes", "equipment", "dragon" }) do
					if city.buildings[id] then
						participant.endStage = math.max(participant.endStage, index)
					end
				end
			end
		end
		participant.turnReport = Reports.build(state, participant, participant.turnBaseline)
		participant.reportRound = state.round
	end
	return state
end

-- Original pumpActors() body with turnProgress/trace/presentation callbacks
-- made inert.  This is included so the extracted actor loop is checked even
-- though this test does not open a terminal UI or write a save file.
local function referencePump(state, callbacks)
	callbacks = callbacks or {}
	if state.phase ~= "game" then
		return
	end
	for _ = 1, #state.players do
		local ranAI = false
		for _, participant in ipairs(state.players) do
			if participant.ai then
				Systems.diplomaticResponses(state, participant)
				if
					state.council
					and state.council.session
					and state.council.session.status == "voting"
				then
					CouncilAI.run(state, participant, Presentation.capture(state, participant.id))
				end
			end
			if Scheduler.canAct(state, participant.id) then
				for _, unit in ipairs(state.units) do
					if
						unit.owner == participant.id and state.scheduler.reactions[participant.id]
					then
						MovementBudget.response(
							state,
							unit,
							Systems.units[unit.kind] or Systems.units.warrior,
							participant,
							Hex
						)
					end
					if
						unit.owner == participant.id
						and unit.autoExplore
						and not unit.standby
						and unit.autoExploreRound ~= state.round
					then
						unit.autoExploreRound = state.round
						Systems.autoExplore(state, unit, Hex)
					end
				end
				QueuedRoutes.run(state, participant.id, Systems, Actions.apply)
				if participant.ai then
					if not participant.ready then
						participant.turnBaseline = Reports.capture(state, participant)
					end
					if callbacks.before then
						callbacks.before(state, participant)
					end
					Systems.aiTurn(state, participant, Hex)
					if callbacks.after then
						callbacks.after(state, participant)
					end
					ranAI = true
				end
			end
		end
		if not ranAI then
			break
		end
	end
end

local function runFixture(count, seed)
	local campaignID = string.format("lifecycle-%d-%d", count, seed)
	local extracted = fixture(campaignID, seed, count, Lifecycle.newLobby)
	local reference = fixture(campaignID, seed, count, lobby)
	equal(extracted, reference, "lobby[" .. count .. "," .. seed .. "]")
	Lifecycle.initialize(extracted)
	referenceInitialize(reference)
	equal(extracted, reference, "initialize[" .. count .. "," .. seed .. "]")

	-- A second boundary catches stateful changes to production, movement,
	-- fog-of-war, reports, hostiles and diplomacy that initialization cannot.
	local extractedRound = copy(extracted)
	local referenceRound = copy(reference)
	Lifecycle.advance(extractedRound)
	referenceAdvance(referenceRound)
	equal(extractedRound, referenceRound, "advance[" .. count .. "," .. seed .. "]")

	-- Mark one participant as AI to exercise the extracted actor path.  The
	-- initialized scheduler may have no allowance yet; that is itself part of
	-- the original boundary behavior and is compared below.
	extractedRound.players[1].ai = true
	referenceRound.players[1].ai = true
	local extractedCalls, referenceCalls = {}, {}
	Actors.pump(extractedRound, {
		before = function(_, participant)
			table.insert(extractedCalls, "before:" .. participant.id)
		end,
		after = function(_, participant)
			table.insert(extractedCalls, "after:" .. participant.id)
		end,
	})
	referencePump(referenceRound, {
		before = function(_, participant)
			table.insert(referenceCalls, "before:" .. participant.id)
		end,
		after = function(_, participant)
			table.insert(referenceCalls, "after:" .. participant.id)
		end,
	})
	equal(extractedRound, referenceRound, "pump[" .. count .. "," .. seed .. "]")
	equal(extractedCalls, referenceCalls, "pump callbacks[" .. count .. "," .. seed .. "]")
end

for _, count in ipairs({ 2, 3, 4 }) do
	for _, seed in ipairs({ 12345, 24680 }) do
		runFixture(count, seed)
	end
end

print(
	"CIVCRAFT: extracted lobby, initialization, round boundary and actor pump match the frozen HEAD lifecycle reference for six seeded 2-4-player fixtures."
)
print(
	"CIVCRAFT: conformance excludes UI presentation, save/trace I/O and victory side effects; those remain runtime integration concerns."
)
