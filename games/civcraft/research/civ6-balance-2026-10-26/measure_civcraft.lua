-- Reproducible CivCraft balance measurements.
--
-- Run inside an isolated CraftOS-PC profile after copying the current
-- games/civcraft directory to /games/civcraft:
--   shell.run("/measure_civcraft.lua")
--
-- The script writes JSON using ComputerCraft's native textutils.serializeJSON:
--   /civcraft_content.json       exact runtime Content tables
--   /civcraft_measurements.json  counts, speed examples, and seeded starts
-- The host can copy those files out of computer/0 after os.shutdown().

local HEAD = "c5d7e4dfb7538b1f164d36fcb08946f250179c6e"
local RUNTIME = "CraftOS-PC 2.8.3 / ComputerCraft 1.112.0"
assert(textutils.serializeJSON, "ComputerCraft textutils.serializeJSON is required")

local function writeJSON(path, value)
	local handle = assert(fs.open(path, "w"))
	handle.write(textutils.serializeJSON(value))
	handle.close()
end

local Content = dofile("/games/civcraft/content.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Combat = dofile("/games/civcraft/combat.lua")

-- Preserve the complete runtime data, including fields that a hand-written
-- parser could miss (e.g. prerequisites, abilities, upkeep, and descriptions).
writeJSON("/civcraft_content.json", {
	metadata = {
		repository_head = HEAD,
		runtime = RUNTIME,
		generated_by = "games/civcraft/research/civ6-balance-2026-10-26/measure_civcraft.lua",
	},
	ages = Content.ages,
	civs = Content.civs,
	techs = Content.techs,
	techOrder = Content.techOrder,
	units = Content.units,
	buildings = Content.buildings,
	wonders = Content.wonders,
	resources = Content.resources,
})

local ageCounts, ageCosts, techTotal = {}, {}, 0
for _, id in ipairs(Content.techOrder) do
	local tech = Content.techs[id]
	ageCounts[tech.age] = (ageCounts[tech.age] or 0) + 1
	ageCosts[tech.age] = (ageCosts[tech.age] or 0) + tech.cost
	techTotal = techTotal + tech.cost
end
local unitCount, hostileCount = 0, 0
for _, unit in pairs(Content.units) do
	if unit.hostile then
		hostileCount = hostileCount + 1
	else
		unitCount = unitCount + 1
	end
end
local buildingCount = 0
for _ in pairs(Content.buildings) do
	buildingCount = buildingCount + 1
end

local function costs()
	local function bySpeed(value)
		return {
			quick = Rules.cost(value, { gameSpeed = "quick" }),
			standard = Rules.cost(value, { gameSpeed = "standard" }),
			epic = Rules.cost(value, { gameSpeed = "epic" }),
		}
	end
	return {
		agriculture = bySpeed(24),
		farm = bySpeed(15),
		pop2GrowthThreshold = bySpeed(36),
	}
end

local function scenario(civ, cityCount)
	local world = World.generate(12345, "standard", cityCount, "continents")
	local state = {
		version = 6,
		ruleset = "create",
		gameSpeed = "standard",
		phase = "game",
		round = 1,
		mapSize = "standard",
		world = world,
		players = {},
		cities = {},
		units = {},
		nextId = 1,
	}
	for index = 1, cityCount do
		local player = {
			id = index,
			name = "P" .. index,
			civ = civ,
			techs = {},
			stockpile = {},
			gold = 20,
		}
		state.players[index] = player
		local start = world.starts[index]
		state.cities[index] = {
			id = index,
			owner = index,
			capitalOf = index,
			x = start.x,
			y = start.y,
			population = 2,
			foodStore = 0,
			buildings = {},
		}
	end
	Systems.migrate(state)
	local result = { civ = civ, cities = cityCount, round = state.round, players = {} }
	for index, player in ipairs(state.players) do
		local city = state.cities[index]
		local yields = Systems.yields(player, city, state, Hex)
		local growth = Systems.growth(player, city, state)
		result.players[index] = {
			yields = yields,
			center = Systems.centerYields(player, city, state),
			foodSurplus = growth.surplus,
			growthTurns = growth.turns,
			agricultureTurns = math.ceil(Systems.techCost("agriculture", player) / yields.science),
			farmTurns = math.ceil(
				Systems.projectCost("building", "farm", player) / yields.industry
			),
			farmPrerequisite = "agriculture",
			farmAvailableAtStart = false,
		}
	end
	return result
end

local stone = { kind = "warrior", owner = 1, x = 1, y = 1, hp = 100, level = 1 }
local sword = { kind = "swordsman", owner = 1, x = 1, y = 1, hp = 100, level = 1 }
local combatState = {
	world = { width = 3, height = 3, tiles = { ["1:1"] = "plains" }, geography = {} },
	players = { { id = 1, civ = "verdant" } },
}
local stonePower = Combat.power(stone, Systems, false, combatState)
local stoneDefense = Combat.power(stone, Systems, true, combatState)
local swordPower = Combat.power(sword, Systems, false, combatState)
local swordDefense = Combat.power(sword, Systems, true, combatState)

writeJSON("/civcraft_measurements.json", {
	metadata = {
		repository_head = HEAD,
		runtime = RUNTIME,
		generated_by = "games/civcraft/research/civ6-balance-2026-10-26/measure_civcraft.lua",
		benchmark_snapshot = "games/civcraft/AI-BENCHMARK.csv is an existing 60-match snapshot measured 2026-10-26 with Lupa; it was not rerun by this harness.",
	},
	contentCounts = {
		technologyCount = #Content.techOrder,
		technologyCountsByAge = ageCounts,
		technologyCostsByAge = ageCosts,
		technologyCostTotal = techTotal,
		recruitableUnitCount = unitCount,
		hostileUnitCount = hostileCount,
		buildingCount = buildingCount,
	},
	speeds = Rules.presets,
	scaledCosts = costs(),
	starts = {
		seed12345StandardContinents = {
			-- cityCount creates that many isolated players, each with one city;
			-- these are multi-player start samples, not one empire's city count.
			verdantOnePlayer = scenario("verdant", 1),
			forgeOnePlayer = scenario("forge", 1),
			scholarOnePlayer = scenario("scholar", 1),
			verdantThreePlayer = scenario("verdant", 3),
			scholarThreePlayer = scenario("scholar", 3),
		},
	},
	earlyAffordableProjectsAtFiveIndustry = {
		scout = { baseCost = 5, turns = 1, prerequisite = "none" },
		warrior = { baseCost = 13, turns = 3, prerequisite = "none" },
		settler = {
			baseCost = 12,
			turns = 3,
			prerequisite = "none",
			note = "next settler adds +5 after each completed settler",
		},
		farm = {
			baseCost = 15,
			turns = 3,
			prerequisite = "agriculture",
			note = "not available in the no-tech start",
		},
	},
	combat = {
		formula = "power = 10 + base_strength * 5 + 2 * (level - 1) - floor((100 - hp) / 10); damage = clamp(floor(30 * exp((attack - defense) / 25) + 0.5), 8, 80)",
		stoneGuardAttack = stonePower,
		stoneGuardDefense = stoneDefense,
		ironSwordsmanAttack = swordPower,
		ironSwordsmanDefense = swordDefense,
		stoneGuardVsStoneGuard = Combat.damage(stonePower, stoneDefense),
		ironSwordsmanVsStoneGuard = Combat.damage(swordPower, stoneDefense),
		stoneGuardVsIronSwordsman = Combat.damage(stonePower, swordDefense),
	},
	pacingCode = {
		productionOverflow = "systems.lua:801-825 adds full industry, completes when progress >= cost, then clears the project; excess is discarded.",
		researchOverflow = "systems.lua:853-863 adds full science to the selected target, completes it when progress >= cost, then clears the target; excess is not transferred.",
		progressSwitching = "systems.lua:420-430 retains progress per project when switching; this preserves investment but still delays the selected alternative.",
	},
})
