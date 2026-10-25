local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local AI = {}
local function strength(view, owner, systems)
	local total = 0
	for _, unit in ipairs(view.units) do
		if unit.owner == owner then
			total = total
				+ ((systems.units[unit.kind] or {}).strength or 0) * (unit.hp or 100) / 100
		end
	end
	return total
end
local function material(view, player, resource, systems)
	local stock = ((player.stockpile or {})[resource] or 0)
	local value = stock < 2 and 25 or stock > 5 and 12 or 20
	for key, kind in pairs(view.world and view.world.resources or {}) do
		if kind == resource then
			local x, y = key:match("^(%d+):(%d+)$")
			local claim = World.territoryCity(view, Hex, tonumber(x), tonumber(y))
			local technology = (systems.resources[resource] or {}).tech
			if
				claim
				and claim.owner == player.id
				and (not technology or player.techs[technology])
			then
				return value * 0.8
			end
		end
	end
	return value
end

function AI.evaluate(view, player, offer, systems)
	assert(view.observerID == player.id, "Diplomatic AI requires its own observations")
	local relation = (view.diplomacy.relations or {})[Memory.key(player.id, offer.from)] or {}
	local profile = Personalities.forCivilization(player.civ)
	local trust, grievances = relation.trust or 0, relation.grievances or 0
	local terms, utility = offer.terms, 0
	if offer.kind == "trade" then
		if
			(player.gold or 0) < terms.requestGold
			or terms.askAmount > 0
				and ((player.stockpile or {})[terms.askResource] or 0) < terms.askAmount
		then
			return "reject", "The requested payment exceeds our available supplies"
		end
		utility = terms.gold
			- terms.requestGold
			+ terms.giveAmount * material(view, player, terms.giveResource, systems)
			- terms.askAmount * material(view, player, terms.askResource, systems)
			+ trust * 0.05
			+ profile.diplomacy * 0.02
		local treasury = systems.treasury(player, view)
		if
			treasury.net < 0
			and (player.gold or 0) + terms.gold - terms.requestGold < -treasury.net * 3
		then
			utility = utility - 30
		end
		return utility >= -2 and "accept" or "reject",
			utility >= -2 and "The exchange serves our economy"
				or "The exchange asks more than it offers"
	elseif offer.kind == "peace" then
		local war = Diplomacy.war(view, player.id, offer.from)
		local ours, theirs = strength(view, player.id, systems), strength(view, offer.from, systems)
		local cities = 0
		for _, city in ipairs(view.cities) do
			if city.owner == player.id then
				cities = cities + 1
			end
		end
		local lost = war and war.ownInitialCities and war.ownInitialCities - cities or 0
		utility = 20
			+ math.min(20, war and (view.round - war.declaredRound) * 2 or 0)
			+ (theirs - ours) * 2
			+ trust * 0.1
			- profile.aggression * 0.3
			+ lost * 15
		return utility >= 0 and "accept" or "reject",
			utility >= 0 and "An armistice is worth more than continuing this war"
				or "We see a stronger position in continuing the war"
	elseif offer.kind == "defenseCall" or offer.kind == "jointWar" then
		if
			Offers.treaty(view, player.id, terms.enemy, "alliance")
			or Offers.treaty(view, player.id, terms.enemy, "defensivePact")
		then
			return "reject", "That intervention conflicts with an existing alliance"
		end
		local ours = math.max(1, strength(view, player.id, systems))
		local theirs = strength(view, terms.enemy, systems)
		utility = trust * 0.5
			+ profile.loyalty * 0.6
			+ profile.diplomacy * 0.2
			- theirs / ours * 20
			- (offer.kind == "jointWar" and 20 or 0)
		return utility >= 20 and "accept" or "reject",
			utility >= 20 and "Our commitments and position justify intervention"
				or "Our present commitments and military position do not justify intervention"
	elseif offer.kind == "withdrawal" then
		if terms.by ~= player.id then
			return "accept",
				"We acknowledge your promise and will judge the withdrawal we can observe"
		end
		utility = trust * 0.2 + profile.loyalty * 0.5 - profile.aggression * 0.2
	else
		utility = trust * 0.4
			- grievances * 0.5
			+ profile.diplomacy * 0.3
			+ profile.loyalty * 0.1
			- profile.aggression * 0.15
			+ (offer.kind == "commerce" and 15 or 0)
	end
	return utility >= 10 and "accept" or "reject",
		utility >= 10 and "These terms fit our relations and interests"
			or "Our relations and interests do not support these terms"
end

local function homeDistance(view, player, x, y)
	local distance = math.huge
	for _, city in ipairs(view.cities) do
		if city.owner == player.id then
			distance = math.min(distance, Hex.distance(x, y, city.x, city.y))
		end
	end
	return distance
end

function AI.allows(view, player, unit, request)
	if request.action ~= "move" or not Offers.withdrawing(view, player.id) then
		return true
	end
	local destination = World.territoryCity(view, Hex, request.x, request.y)
	for _, promise in ipairs(view.diplomacy and view.diplomacy.promises or {}) do
		if
			promise.by == player.id
			and promise.status == "active"
			and destination
			and destination.owner == promise.to
		then
			local current = World.territoryCity(view, Hex, unit.x, unit.y)
			if not current or current.owner ~= promise.to then
				return false
			end
			local distance = homeDistance(view, player, unit.x, unit.y)
			if distance == math.huge then
				return Hex.distance(request.x, request.y, current.x, current.y)
					> Hex.distance(unit.x, unit.y, current.x, current.y)
			end
			return homeDistance(view, player, request.x, request.y) < distance
		end
	end
	return true
end

function AI.pullbackOrder(view, player, unit, systems)
	local current = World.territoryCity(view, Hex, unit.x, unit.y)
	if not current then
		return
	end
	local withdrawing = false
	for _, promise in ipairs(view.diplomacy and view.diplomacy.promises or {}) do
		withdrawing = withdrawing
			or promise.by == player.id
				and promise.status == "active"
				and current.owner == promise.to
	end
	if not withdrawing then
		return
	end
	local best, score = nil, -math.huge
	for _, move in ipairs(Hex.reachable(view, unit, player.id, systems)) do
		local request = { action = "move", sx = unit.x, sy = unit.y, x = move.x, y = move.y }
		if not move.attack and AI.allows(view, player, unit, request) then
			local destination = World.territoryCity(view, Hex, move.x, move.y)
			local value = (not destination or destination.owner ~= current.owner) and 100 or 0
			local distance = homeDistance(view, player, move.x, move.y)
			value = value
				+ (distance == math.huge and Hex.distance(move.x, move.y, current.x, current.y) or -distance) * 3
				- move.cost * 0.1
			if value > score then
				best, score = request, value
			end
		end
	end
	return best
end

return AI
