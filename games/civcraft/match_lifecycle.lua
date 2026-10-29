-- Authoritative match setup and round boundaries shared by CraftOS and research.
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Hostiles = dofile("/games/civcraft/hostiles.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local Council = dofile("/games/civcraft/council.lua")
local Events = dofile("/games/civcraft/events.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local DiplomaticPerception = dofile("/games/civcraft/diplomatic_perception.lua")
local Reports = dofile("/games/civcraft/reports.lua")
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Lifecycle = {}

local function player(state, id)
	for _, participant in ipairs(state.players) do
		if participant.id == id then
			return participant
		end
	end
end

function Lifecycle.newLobby(campaignID, contentRules)
	return {
		campaignID = campaignID,
		version = 6,
		ruleset = "create",
		contentRules = contentRules ~= "baseline" and contentRules or nil,
		roundLimit = CampaignRules.rounds({ contentRules = contentRules }),
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

local function addUnit(state, owner, x, y, kind)
	local u = {
		id = state.nextId,
		owner = owner,
		x = x,
		y = y,
		kind = kind,
		moved = false,
		movesLeft = Systems.units[kind].move,
	}
	state.nextId = state.nextId + 1
	table.insert(state.units, u)
	return u
end

function Lifecycle.initialize(state)
	state.world = World.generate(state.mapSeed, state.mapSize, #state.players, state.mapType, state)
	state.name = "EMPIRE " .. state.world.seed
	for i, p in ipairs(state.players) do
		local pos = state.world.starts[i]
		local x, y = pos.x, pos.y
		p.techs = p.techs or {}
		p.civ = p.civ or Systems.civs[i].id
		if ContentRules.startsWithSettler(state) then
			local settler = addUnit(state, p.id, x, y, "settler")
			settler.initialSettler = true
			p.settlersTrained = 0
			p.capitalFounded = false
			local gx, gy = x, y
			for _, point in ipairs(Hex.neighbours(x, y, state)) do
				if
					Hex.passable(
						point.x,
						point.y,
						state,
						{ owner = p.id, kind = "warrior" },
						Systems
					)
				then
					gx, gy = point.x, point.y
					break
				end
			end
			addUnit(state, p.id, gx, gy, "warrior")
		else
			table.insert(state.cities, {
				id = state.nextId,
				x = x,
				y = y,
				owner = p.id,
				capitalOf = p.id,
				level = 1,
				population = 2,
				foodStore = 0,
				jobs = { food = 1, wood = 1, science = 0 },
				buildings = {},
			})
			state.nextId = state.nextId + 1
			addUnit(state, p.id, x + ((x < state.world.width / 2) and 1 or -1), y, "warrior")
		end
		p.food = 12
		p.wood = 12
		p.science = 0
		p.tech = 0
		p.ready = false
		p.techs = p.techs or {}
		p.civ = p.civ or Systems.civs[i].id
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

function Lifecycle.advance(state, progress)
	local function stage(label)
		if progress then
			progress(label)
		end
	end
	state.round = state.round + 1
	for _, p in ipairs(state.players) do
		p.ready = false
	end
	stage("COUNCIL AND DIPLOMACY")
	Council.advance(state)
	Diplomacy.boundary(state)
	Events.prune(state)
	stage("COMBAT AND RECOVERY")
	Combat.round(state, Systems)
	stage("ECONOMY AND PRODUCTION")
	Systems.production(state, Hex)
	stage("VILLAGES AND HOSTILES")
	Villages.round(state, Systems, Combat)
	Hostiles.round(state, Systems)
	for _, u in ipairs(state.units) do
		local owner = player(state, u.owner)
		local base = Systems.units[u.kind] or Systems.units.warrior
		MovementBudget.reset(state, u, base, owner, Hex)
	end
	stage("VISIBILITY AND DIPLOMACY")
	World.reveal(state, Hex, Systems)
	DiplomaticPerception.promises(state, Hex, World, Systems.units)
	stage("AUTOMATIC EXPLORATION")
	for _, unit in ipairs(state.units) do
		if unit.autoExplore and not unit.standby and Scheduler.canAct(state, unit.owner) then
			unit.autoExploreRound = state.round
			Systems.autoExplore(state, unit, Hex)
		end
	end
	stage("TURN REPORTS")
	for _, p in ipairs(state.players) do
		p.age = Systems.age(p)
		p.endStage = 0
		for _, city in ipairs(state.cities) do
			if city.owner == p.id then
				for i, id in ipairs({ "eyes", "equipment", "dragon" }) do
					if city.buildings[id] then
						p.endStage = math.max(p.endStage, i)
					end
				end
			end
		end
		p.turnReport = Reports.build(state, p, p.turnBaseline)
		p.reportRound = state.round
	end
end

function Lifecycle.finish(state, id)
	local eligible, why = Scheduler.canAct(state, id)
	if not eligible then
		return false, why
	end
	local participant = player(state, id)
	if not participant.ready then
		participant.turnBaseline = Reports.capture(state, participant)
	end
	Scheduler.finish(state, id)
	Events.notice(state, "order", nil, "end", id)
	table.insert(state.logs, 1, participant.name .. " is ready")
	while #state.logs > 5 do
		table.remove(state.logs)
	end
	return true
end

return Lifecycle
