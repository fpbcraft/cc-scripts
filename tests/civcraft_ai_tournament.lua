-- Generated-data simulation; native output is intended for an isolated test profile.
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
local rounds = tonumber(arguments[1]) or 40
assert(rounds >= 1 and rounds <= 180, "Choose 1 to 180 tournament rounds")
local report = { rounds = rounds, seed = seed, civilization = civilization, matches = {} }
local apply = Actions.apply
local metrics
Actions.apply = function(state, actor, request, systems)
	local ok, reason = apply(state, actor, request, systems)
	if metrics then
		metrics.orders = metrics.orders + 1
		if not ok then
			metrics.rejections = metrics.rejections + 1
			metrics.reasons[reason] = (metrics.reasons[reason] or 0) + 1
		end
	end
	return ok, reason
end
for _, level in ipairs(Difficulty.order) do
	for seat = 1, 2 do
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
				civ = civilization,
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
		metrics =
			{ level = level, seat = seat, orders = 0, rejections = 0, reasons = {}, worstActor = 0 }
		for round = 1, rounds do
			trace(level .. " seat " .. seat .. " round " .. round .. " boundary")
			if gcBetweenRounds then
				collectgarbage("collect")
			end
			state.round = round
			for _, player in ipairs(state.players) do
				player.ready = false
			end
			Council.advance(state)
			Diplomacy.boundary(state)
			World.reveal(state, Hex, Systems)
			for _ = 1, #state.players do
				for _, player in ipairs(state.players) do
					CouncilAI.run(state, player, World.forPlayer(state, player.id))
					local start = milliseconds()
					trace(level .. " seat " .. seat .. " round " .. round .. " actor " .. player.id)
					Systems.aiTurn(state, player, Hex)
					metrics.worstActor = math.max(metrics.worstActor, milliseconds() - start)
				end
			end
			trace(level .. " seat " .. seat .. " round " .. round .. " production")
			Systems.production(state, Hex)
			Victory.check(state, true)
			for _, unit in ipairs(state.units) do
				Movement.reset(
					{ round = round + 1, world = world },
					unit,
					Systems.units[unit.kind],
					state.players[unit.owner + 1],
					Hex
				)
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
	local file = assert(fs.open("/civcraft-ai-tournament.txt", "w"))
	file.write(textutils.serialize(report))
	file.close()
end
assert(#report.matches == 10)
print(
	"CIVCRAFT: ten same-seed, swapped-seat difficulty simulations completed; these are smoke measurements, not balance estimates."
)
return report
