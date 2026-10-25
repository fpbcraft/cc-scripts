-- The director accepts an observer projection, never unrestricted host state.
local Hex = dofile("/games/civcraft/hex.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Strategy = { version = 1, reviewInterval = 10 }
local preferences = {
	guardian = { industrial = 75, expedition = 50, conquest = 25, diplomatic = 65, score = 30 },
	conqueror = { industrial = 50, expedition = 35, conquest = 90, diplomatic = 25, score = 30 },
	scholar = { industrial = 50, expedition = 95, conquest = 20, diplomatic = 55, score = 30 },
	expansionist = { industrial = 75, expedition = 40, conquest = 65, diplomatic = 45, score = 40 },
	industrialist = {
		industrial = 100,
		expedition = 45,
		conquest = 40,
		diplomatic = 50,
		score = 30,
	},
	merchant = { industrial = 75, expedition = 45, conquest = 20, diplomatic = 100, score = 35 },
}
local goals = { "conquest", "industrial", "expedition", "diplomatic", "score" }

local function ownCities(view, player)
	local result = {}
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			result[#result + 1] = city
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	return result
end

local function treasury(player)
	local gold = player.gold or 0
	return gold < 0 and "bankrupt" or gold < 20 and "low" or "stable"
end

local function decisiveTech(player)
	local result = {}
	for _, id in ipairs({ "railways", "logistics", "astronomy", "enlightenment", "netherite" }) do
		if (player.techs or {})[id] then
			result[#result + 1] = id
		end
	end
	return table.concat(result, ":")
end

local function tie(seed, goal)
	local value = math.floor(tonumber(seed) or 1) % 65521
	for i = 1, #goal do
		value = (value * 131 + goal:byte(i)) % 65521
	end
	return value / 65521
end

local function scores(view, player, personality, cities, seed)
	local result = {}
	for _, goal in ipairs(goals) do
		result[goal] = preferences[personality.archetype][goal] + tie(seed, goal)
	end
	-- Council victory becomes eligible when its implementation publishes rules.
	if not (view.council and view.council.victoryEnabled) then
		result.diplomatic = -math.huge
	end
	if view.victories then
		for _, goal in ipairs(goals) do
			if view.victories[goal] == false then
				result[goal] = -math.huge
			end
		end
	end
	for _, city in ipairs(cities) do
		local built = city.buildings or {}
		result.industrial = result.industrial
			+ (built.bank and 15 or 0)
			+ (built.station and 5 or 0)
		result.expedition = result.expedition
			+ (built.observatory and 20 or 0)
			+ (built.eyes and 30 or 0)
		result.conquest = result.conquest
			+ (city.capitalOf and city.capitalOf ~= player.id and 30 or 0)
	end
	if (view.roundLimit or 180) - (view.round or 1) < 15 then
		result.score = result.score + 120
	end
	return result
end

local function emergency(view, player, cities)
	if treasury(player) == "bankrupt" then
		return "avoidBankruptcy"
	end
	for _, city in ipairs(cities) do
		if city.capitalOf == player.id then
			for _, unit in ipairs(view.units or {}) do
				if
					unit.owner ~= player.id
					and not unit.villageGuard
					and unit.kind ~= "settler"
					and Hex.distance(city.x, city.y, unit.x, unit.y) <= 3
				then
					return "defendCapital"
				end
			end
		end
	end
	return nil
end

function Strategy.signal(player, reason)
	-- War/treaty systems can request a deliberate review without rewriting a goal.
	player.strategySignal = reason
end

function Strategy.review(view, player, seed)
	assert(view.observerID == player.id, "Strategy requires its own observer projection")
	local personality = Personalities.forCivilization(player.civ)
	local cities = ownCities(view, player)
	local plan = player.aiPlan
	assert(not plan or plan.version == Strategy.version, "Unsupported AI strategy version")
	local round = view.round or 1
	local reason = not plan and "initial" or player.strategySignal
	local rivals = {}
	for _, rival in ipairs(view.players or {}) do
		if rival.id ~= player.id and (rival.industryTurns or 0) >= 7 then
			rivals[#rivals + 1] = tostring(rival.id)
		end
	end
	table.sort(rivals)
	local rivalVictory = table.concat(rivals, ":")
	if plan then
		local present = {}
		for _, city in ipairs(cities) do
			present[city.id] = true
		end
		for _, id in ipairs(plan.cityIDs) do
			if not present[id] then
				reason = "cityLoss"
			end
		end
		if treasury(player) ~= plan.treasury then
			reason = reason or "treasuryShock"
		end
		if decisiveTech(player) ~= plan.decisiveTech then
			reason = reason or "decisiveTechnology"
		end
		if round - plan.lastReviewRound >= Strategy.reviewInterval then
			reason = reason or "periodic"
		end
	end
	if plan and rivalVictory ~= "" and rivalVictory ~= plan.rivalVictory then
		reason = reason or "rivalVictory"
	end
	if not plan then
		plan = { version = Strategy.version, revision = 0, cityIDs = {}, citySpecializations = {} }
		player.aiPlan = plan
	end
	if reason then
		local utility = scores(view, player, personality, cities, seed)
		local best = goals[1]
		for _, goal in ipairs(goals) do
			if utility[goal] > utility[best] then
				best = goal
			end
		end
		local incumbent = plan.primary and utility[plan.primary]
		if not incumbent or incumbent == -math.huge or utility[best] > incumbent * 1.25 + 15 then
			if plan.primary ~= best then
				plan.primary, plan.revisionRound = best, round
				plan.revision = plan.revision + 1
			end
		end
		plan.lastReviewRound, plan.reviewReason = round, reason
		plan.treasury, plan.decisiveTech = treasury(player), decisiveTech(player)
		player.strategySignal = nil
	end
	plan.personality = personality.archetype
	plan.rivalVictory = rivalVictory
	plan.emergency = emergency(view, player, cities) or (#rivals > 0 and "contestVictory" or nil)
	plan.mood = plan.emergency and "defensive" or "developing"
	plan.priorities = plan.emergency and { plan.emergency, plan.primary }
		or { plan.primary, "developEconomy" }
	plan.objectives = { plan.primary, "secureResources", "connectCities" }
	local present = {}
	plan.cityIDs = {}
	for _, city in ipairs(cities) do
		present[city.id] = true
		plan.cityIDs[#plan.cityIDs + 1] = city.id
	end
	for id in pairs(plan.citySpecializations) do
		if not present[id] then
			plan.citySpecializations[id] = nil
		end
	end
	for i, city in ipairs(cities) do
		if not plan.citySpecializations[city.id] then
			plan.citySpecializations[city.id] = plan.primary == "expedition" and "science"
				or plan.primary == "conquest" and (i == 1 and "military" or "industry")
				or (i == 1 and "industry" or "commerce")
		end
	end
	return plan
end

return Strategy
