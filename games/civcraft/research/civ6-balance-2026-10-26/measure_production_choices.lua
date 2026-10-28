-- City production-choice trace on HEAD 97944b8bc85e011d00abbdf45bf9aecdb82050ae.
-- Captures copied project fields to preserve each historical snapshot.
-- Run /choices.lua 180 75123 forge none forge in an isolated profile.
-- Outputs /civcraft-production-trace.json; action-count metrics are not reliable.
-- Full-duration Prince-vs-Prince native baseline adapted from
-- tests/civcraft_ai_tournament.lua. This is a measurement fixture only:
-- Difficulty.order is restricted to Prince, the round limit is supplied as
-- 180, and no game files or rules are changed.
-- Reproduction copies games/civcraft and this file into an isolated
-- CraftOS-PC profile, then runs: shell.run("/full180.lua", "180", "75123",
-- "forge", "forge"). The fixture uses compact Pangaea with hostileMode off.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local function trace(label)
	if fs then
		local file = assert(fs.open("/civcraft-ai-tournament-progress.txt", "w"))
		file.write(label)
		file.close()
	end
end
trace("loading modules")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Council = dofile("/games/civcraft/council.lua")
local CouncilAI = dofile("/games/civcraft/council_ai.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local Movement = dofile("/games/civcraft/movement_budget.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Cooperative = dofile("/games/civcraft/cooperative.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Events = dofile("/games/civcraft/events.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local Hostiles = dofile("/games/civcraft/hostiles.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local work = {}
local function checkpoint()
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint = checkpoint, checkpoint
local function milliseconds()
	return os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
end
trace("modules loaded")
local arguments = { ... }
local seed = tonumber(arguments[2]) or 75123
local civilization = arguments[3] or "forge"
assert(Systems.civ(civilization).id == civilization, "Choose a known civilization")
local gcBetweenRounds = arguments[4] == "--gc"
local opponent = arguments[5] or civilization
assert(Systems.civ(opponent).id == opponent, "Choose a known opponent civilization")
local rounds = tonumber(arguments[1]) or 40
assert(rounds >= 1 and rounds <= 180, "Choose 1 to 180 tournament rounds")
local report = {
	researchHead = "97944b8bc85e011d00abbdf45bf9aecdb82050ae",
	fixture = "Prince mirror; Compact/Pangaea; hostiles off; one deterministic match",
	rounds = rounds,
	seed = seed,
	civilization = civilization,
	opponent = opponent,
	matches = {},
}
local apply = Actions.apply
local metrics
Actions.apply = function(state, actor, request, systems)
	local ok, reason = apply(state, actor, request, systems)
	if metrics then
		metrics.orders = metrics.orders + 1
		if not ok then
			metrics.rejections = metrics.rejections + 1
			metrics.reasons[reason] = (metrics.reasons[reason] or 0) + 1
			local unavailable = request.action == "queue"
				and request.kind == "wonder"
				and not dofile("/games/civcraft/landmarks.lua").available(state, request.id)
			local observedMove, actualMove = false, false
			if request.action == "move" then
				local unit
				for _, candidate in ipairs(state.units) do
					if candidate.id == request.unitID then
						unit = candidate
					end
				end
				for _, choice in
					ipairs(Hex.reachable(World.forPlayer(state, actor), unit, actor, systems))
				do
					observedMove = observedMove or choice.x == request.x and choice.y == request.y
				end
				for _, choice in ipairs(Hex.reachable(state, unit, actor, systems)) do
					actualMove = actualMove or choice.x == request.x and choice.y == request.y
				end
			end
			assert(
				unavailable or observedMove and not actualMove,
				"Unexpected AI rejection: " .. tostring(reason)
			)
			if unavailable then
				metrics.unavailableWonders = (metrics.unavailableWonders or 0) + 1
			else
				metrics.observationDenials = (metrics.observationDenials or 0) + 1
			end
		end
	end
	return ok, reason
end
for _, level in ipairs({ "prince" }) do
	for seat = 1, 1 do
		trace(level .. " seat " .. seat .. " generation")
		if gcBetweenRounds then
			collectgarbage("collect")
		end
		local world = World.generate(seed, "compact", 2, "pangaea")
		local state = {
			version = 6,
			phase = "game",
			ruleset = "create",
			round = 1,
			roundLimit = rounds,
			victoryRulesVersion = 2,
			world = world,
			players = {},
			cities = {},
			units = {},
			nextId = 10,
			diplomacy = Diplomacy.new(),
			hostileMode = "off",
		}
		for index = 1, 2 do
			local point = world.starts[index]
			state.players[index] = {
				id = index - 1,
				name = "AI " .. index,
				ai = true,
				aiDifficulty = index == seat and level or "prince",
				civ = index == seat and civilization or opponent,
				techs = {},
				gold = 20,
			}
			state.cities[index] = {
				id = index,
				owner = index - 1,
				capitalOf = index - 1,
				x = point.x,
				y = point.y,
				population = 2,
				buildings = {},
			}
			state.units[index] = {
				id = index + 2,
				owner = index - 1,
				x = point.x + 1,
				y = point.y,
				kind = "warrior",
				hp = 100,
				movesLeft = 2,
			}
		end
		trace(level .. " seat " .. seat .. " migration")
		Systems.migrate(state)
		Diplomacy.migrate(state)
		metrics = {
			level = level,
			seat = seat,
			orders = 0,
			rejections = 0,
			reasons = {},
			worstActor = 0,
			ageTurns = {},
			roundRates = {},
			productionSamples = {},
		}
		for round = 1, rounds do
			trace(level .. " seat " .. seat .. " round " .. round .. " boundary")
			if gcBetweenRounds then
				collectgarbage("collect")
			end
			state.round = round
			for _, player in ipairs(state.players) do
				player.ready = false
			end
			if round > 1 then
				Council.advance(state)
				Diplomacy.boundary(state)
				Events.prune(state)
				Combat.round(state, Systems)
				Systems.production(state, Hex)
				Villages.round(state, Systems, Combat)
				Hostiles.round(state, Systems)
				for _, unit in ipairs(state.units) do
					Movement.reset(
						state,
						unit,
						Systems.units[unit.kind],
						state.players[unit.owner + 1],
						Hex
					)
				end
			end
			World.reveal(state, Hex, Systems)
			Perception.promises(state, Hex, World, Systems.units)
			Victory.check(state, true)
			if metrics then
				for _, tracked in ipairs(state.players) do
					local age = Systems.age(tracked)
					local key = tostring(tracked.id)
					metrics.ageTurns[key] = metrics.ageTurns[key] or {}
					if not metrics.ageTurns[key][age] then
						metrics.ageTurns[key][age] = round
					end
				end
			end
			for _ = 1, #state.players + 1 do
				local acted = false
				for _, player in ipairs(state.players) do
					if state.phase == "game" then
						Systems.diplomaticResponses(state, player)
						CouncilAI.run(state, player, World.forPlayer(state, player.id))
						if Scheduler.canAct(state, player.id) then
							local start = milliseconds()
							trace(
								level
									.. " seat "
									.. seat
									.. " round "
									.. round
									.. " actor "
									.. player.id
							)
							Systems.aiTurn(state, player, Hex)
							metrics.worstActor =
								math.max(metrics.worstActor, milliseconds() - start)
							acted = true
							Victory.check(state, false)
						end
					end
				end
				if not acted then
					break
				end
			end
			for _, player in ipairs(state.players) do
				assert(
					state.phase ~= "game" or player.ready,
					"AI scheduler did not finish its round"
				)
			end

			for _, tracked in ipairs(state.players) do
				local sample = {
					round = round,
					player = tracked.id,
					gold = tracked.gold,
					units = {},
					cities = {},
				}
				sample.treasury = Systems.treasury(tracked, state)
				for _, unit in ipairs(state.units) do
					if unit.owner == tracked.id then
						sample.units[unit.kind] = (sample.units[unit.kind] or 0) + 1
					end
				end
				for _, city in ipairs(state.cities) do
					if city.owner == tracked.id then
						local legal, built = {}, 0
						for id in pairs(Systems.buildings) do
							if Systems.canBuild(tracked, city, id, state) then
								legal[#legal + 1] = id
							end
						end
						table.sort(legal)
						for _, yes in pairs(city.buildings or {}) do
							if yes then
								built = built + 1
							end
						end
						sample.cities[#sample.cities + 1] = {
							id = city.id,
							population = city.population,
							availableBuildings = legal,
							built = built,
							project = city.project and {
								kind = city.project.kind,
								id = city.project.id,
								progress = city.project.progress,
							},
							idle = city.productionIdle,
							yields = Systems.yields(tracked, city, state, Hex),
						}
					end
				end
				metrics.productionSamples[#metrics.productionSamples + 1] = sample
			end
			if state.phase == "over" then
				break
			end
			checkpoint()
		end
		local player = state.players[seat]
		metrics.score, metrics.cities, metrics.techs, metrics.round =
			Victory.score(state, player), 0, 0, state.round
		for _, city in ipairs(state.cities) do
			if city.owner == player.id then
				metrics.cities = metrics.cities + 1
			end
		end
		for _ in pairs(player.techs) do
			metrics.techs = metrics.techs + 1
		end
		metrics.winnerIDs = state.winnerIDs or {}
		metrics.victoryReason = state.victoryReason
		metrics.opponentScore = Victory.score(state, state.players[3 - seat])
		metrics.won, metrics.tied = false, #metrics.winnerIDs > 1
		for _, id in ipairs(metrics.winnerIDs) do
			metrics.won = metrics.won or id == player.id
		end
		assert(
			metrics.rejections
				== (metrics.unavailableWonders or 0) + (metrics.observationDenials or 0),
			"Unexpected rejected AI actions"
		)
		report.matches[#report.matches + 1] = metrics
		print(
			level
				.. " seat "
				.. seat
				.. ": score "
				.. metrics.score
				.. ", cities "
				.. metrics.cities
				.. ", techs "
				.. metrics.techs
				.. ", orders "
				.. metrics.orders
				.. ", rejected "
				.. metrics.rejections
				.. ", worst actor "
				.. metrics.worstActor
				.. "ms"
		)
	end
end
Actions.apply = apply
report.yields = work.yieldToken or 0
report.gcCycles, report.gcMaxMillis = work.gcCycles or 0, work.gcMaxMillis or 0
if fs and textutils then
	local file = assert(fs.open("/civcraft-production-trace.json", "w"))
	file.write(textutils.serializeJSON(report))
	file.close()
end
assert(#report.matches == 1)
print(
	"CIVCRAFT: full-duration same-seed Prince simulations completed; these are smoke measurements, not balance estimates."
)
return report
