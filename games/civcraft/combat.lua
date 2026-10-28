-- Deterministic strength-difference combat with separate city and wall health.
local CombatStrength = dofile("/games/civcraft/combat_strength.lua")
local Events = dofile("/games/civcraft/events.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local UnitMovement = dofile("/games/civcraft/unit_movement.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local VisibilityEvents = dofile("/games/civcraft/visibility_events.lua")
local World = dofile("/games/civcraft/world.lua")
local Zone = dofile("/games/civcraft/zone_control.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local C = {}
local function at(list, x, y)
	for _, v in ipairs(list or {}) do
		if v.x == x and v.y == y then
			return v
		end
	end
end
local function remove(state, unit)
	Stacks.unlink(state, unit)
	for i = #state.units, 1, -1 do
		if state.units[i] == unit then
			table.remove(state.units, i)
			return
		end
	end
end
function C.unit(unit)
	unit.maxHP = 100
	unit.hp = math.max(0, math.min(100, unit.hp or 100))
	unit.xp = unit.xp or 0
	unit.level = unit.level or 1
end
function C.city(city)
	city.maxHP = 200
	city.hp = math.max(0, math.min(200, city.hp or 200))
	local buildings = city.buildings or {}
	local maximum = buildings.fortress and 200 or buildings.walls and 100 or 0
	if maximum > (city.maxWalls or 0) then
		city.wallHP = (city.wallHP or 0) + maximum - (city.maxWalls or 0)
	end
	city.maxWalls = maximum
	city.wallHP = math.max(0, math.min(maximum, city.wallHP or 0))
end
function C.migrate(state)
	for _, unit in ipairs(state.units or {}) do
		C.unit(unit)
	end
	for _, city in ipairs(state.cities or {}) do
		C.city(city)
	end
end
C.power = CombatStrength.unit
C.cityPower = CombatStrength.city
function C.damage(attack, defense)
	return math.max(8, math.min(80, math.floor(30 * math.exp((attack - defense) / 25) + 0.5)))
end
function C.experience(unit, amount)
	unit.xp = (unit.xp or 0) + amount
	unit.level = unit.level or 1
	while unit.level < 10 and unit.xp >= unit.level * 10 do
		unit.level = unit.level + 1
	end
end
function C.besieged(state, city, systems)
	local checked = 0
	for _, tile in ipairs(Hex.neighbours(city.x, city.y, state)) do
		local terrain = Hex.terrain(tile.x, tile.y, state)
		if terrain ~= "water" and terrain ~= "mountain" then
			checked = checked + 1
			local controlled = false
			for _, u in ipairs(state.units) do
				local stats = systems.units[u.kind] or {}
				if
					u.owner ~= city.owner
					and Diplomacy.canAttack(state, u.owner, city.owner)
					and (stats.strength or 0) > 0
					and (stats.range or 1) <= 1
					and not stats.naval
					and Hex.distance(u.x, u.y, tile.x, tile.y) <= 1
				then
					controlled = true
					break
				end
			end
			if not controlled then
				return false
			end
		end
	end
	return checked > 0
end
function C.restRecovery(state, unit, systems)
	local result = { base = 0, support = 0, total = 0, territory = "neutral" }
	if unit.actedThisRound then
		result.territory = "acted"
		return result
	end
	local registered = false
	for _, player in ipairs(state.players or {}) do
		registered = registered or player.id == unit.owner
	end
	if not registered then
		return result
	end
	local claim = World.territoryCity(state, Hex, unit.x, unit.y)
	local owner = claim and claim.owner
	if state.world and state.world.observedOwners then
		owner = state.world.observedOwners[World.key(unit.x, unit.y)]
	end
	local war = owner ~= nil and Diplomacy.war(state, unit.owner, owner)
	if owner == unit.owner then
		result.base, result.territory = 20, "owned"
	elseif war and war.active then
		result.base, result.territory = 5, "enemy"
	elseif owner ~= nil and Offers.treaty(state, unit.owner, owner, "openBorders") then
		result.base, result.territory = 15, "friendly"
	else
		result.base = 10
	end
	for _, other in ipairs(state.units or {}) do
		if
			other.id ~= unit.id
			and other.owner == unit.owner
			and (other.hp or 100) > 0
			and (systems.units[other.kind] or {}).healer
			and Hex.distance(unit.x, unit.y, other.x, other.y) <= 1
		then
			result.support = 10
			break
		end
	end
	result.total = result.base + result.support
	return result
end

function C.round(state, systems)
	C.migrate(state)
	if ContentRules.isRedesign(state) then
		local recovery = {}
		for _, unit in ipairs(state.units) do
			recovery[unit] = C.restRecovery(state, unit, systems).total
		end
		for _, unit in ipairs(state.units) do
			unit.hp = math.min(100, unit.hp + recovery[unit])
			unit.actedThisRound = false
		end
	else
		for _, u in ipairs(state.units) do
			if u.healing or not u.actedThisRound then
				local claim = World.territoryCity(state, Hex, u.x, u.y)
				if claim and claim.owner == u.owner then
					u.hp = math.min(100, u.hp + 20)
				end
			end
			if (systems.units[u.kind] or {}).healer then
				for _, ally in ipairs(state.units) do
					if ally.owner == u.owner and Hex.distance(u.x, u.y, ally.x, ally.y) <= 1 then
						ally.hp = math.min(100, (ally.hp or 100) + 10)
					end
				end
			end
			u.actedThisRound = false
		end
	end
	for _, city in ipairs(state.cities) do
		if not C.besieged(state, city, systems) then
			city.hp = math.min(200, city.hp + 15)
		end
		if (state.round or 1) - (city.lastAttackRound or -10) >= 3 then
			city.wallHP = math.min(city.maxWalls, city.wallHP + 15)
		end
	end
end
-- Pure forecast: normalize private records, never mutate the supplied state.
local function copy(record)
	local result = {}
	for k, v in pairs(record or {}) do
		result[k] = v
	end
	return result
end
function C.predict(state, unit, target, systems)
	if unit.attackedRound and unit.attackedRound == state.round then
		return nil, "Unit already attacked this round"
	end
	local attacker = copy(unit)
	C.unit(attacker)
	local stats = systems.units[unit.kind] or systems.units.warrior
	local city = at(state.cities, target.x, target.y)
	if city and city.owner == unit.owner then
		city = nil
	end
	local defender = Stacks.at(state.units, target.x, target.y)
	if not city and (not defender or defender.owner == unit.owner) then
		return nil, "No enemy target"
	end
	if not Diplomacy.canAttack(state, unit.owner, city and city.owner or defender.owner) then
		return nil, "Declare war before attacking this civilization"
	end
	local ranged = MovementBudget.attackRange(state, unit, stats, Hex) > 1
	if not ranged and not stats.naval and Hex.terrain(target.x, target.y, state) == "water" then
		return nil, "Land melee units cannot initiate attacks against units on water"
	end
	if
		not ranged
		and Stacks.settler(state.units, target.x, target.y)
		and (
			Stacks.partner(state, unit) or Stacks.partner(state, Stacks.byID(state, unit.id) or {})
		)
	then
		return nil, "Detach the escort before capturing another settler"
	end
	if not city and defender.kind == "settler" and not ranged then
		return {
			damage = 0,
			retaliation = 0,
			attackerHP = attacker.hp,
			defenderHP = defender.hp or 100,
			ranged = false,
			captured = false,
			capturedSettler = true,
			captureOnly = true,
			attackerDied = false,
			defenderDied = false,
		}
	end

	local offense = C.power(attacker, systems, false, state)
	local defense
	if city then
		city = copy(city)
		C.city(city)
		defense = C.cityPower(state, city, systems)
	else
		defender = copy(defender)
		C.unit(defender)
		defense = C.power(defender, systems, true, state)
	end
	if
		defender
		and ((systems.units[defender.kind] or {}).mounted or defender.kind == "horseman")
		and unit.kind == "spearman"
	then
		offense = offense + 10
	end
	local damage = C.damage(offense, defense)
	local wallDamage = 0
	if city and city.wallHP > 0 then
		local multiplier = stats.siege and 1 or ranged and 0.25 or 0.35
		local hit = math.max(1, math.floor(damage * multiplier))
		wallDamage = math.min(city.wallHP, hit)
		damage = math.max(0, hit - wallDamage)
	end
	local retaliation = ranged and 0 or C.damage(defense, C.power(attacker, systems, true, state))
	local attackerHP = math.max(0, attacker.hp - retaliation)
	local targetHP = math.max(
		city and (ranged or stats.hostile) and 1 or 0,
		(city and city.hp or defender.hp) - damage
	)
	local captured = city ~= nil and targetHP <= 0 and not ranged and attackerHP > 0
	if city and targetHP <= 0 then
		targetHP = captured and 100 or 1
	end
	if stats.explosive then
		attackerHP = 0
	end
	return {
		damage = damage,
		retaliation = retaliation,
		wallDamage = wallDamage,
		attackerHP = attackerHP,
		defenderHP = not city and targetHP or nil,
		cityHP = city and targetHP or nil,
		wallHP = city and (captured and 0 or city.wallHP - wallDamage) or nil,
		attackerDied = attackerHP <= 0,
		defenderDied = not city and targetHP <= 0 or false,
		captured = captured,
		capturedSettler = not ranged
				and attackerHP > 0
				and (captured or not city and targetHP <= 0)
				and Stacks.settler(state.units, target.x, target.y) ~= nil
			or false,
		ranged = ranged,
	}
end
function C.predictOrder(state, unit, order, systems)
	local attacker = copy(unit)
	attacker.standby = false
	attacker.healing = false
	if not order.ranged and order.path then
		local locked = Zone.locked(state, unit, systems)
		local zones = Zone.map(state, unit, systems, Hex)
		for index = 2, #order.path - 1 do
			if locked then
				return nil, "Approach crosses an enemy zone of control"
			end
			local point = order.path[index]
			locked = zones[point.x .. ":" .. point.y] == true
		end
	end
	if not order.ranged and order.path and #order.path > 1 then
		local approach = order.path[#order.path - 1]
		attacker.x, attacker.y = approach.x, approach.y
	end
	return C.predict(state, attacker, order, systems)
end

function C.attack(state, unit, target, systems)
	local startX, startY = unit.x, unit.y
	local companion, approachSpent = Stacks.partner(state, unit), 0
	local result, why
	if target.path then
		result, why = C.predictOrder(state, unit, target, systems)
	else
		result, why = C.predict(state, unit, target, systems)
	end
	if not result then
		return false, why
	end
	if target.path and not result.ranged and #target.path > 2 then
		local first = target.path[1]
		if unit.x == first.x and unit.y == first.y then
			local spent, completed, reason =
				UnitMovement.walk(state, unit, target.path, systems, #target.path - 1)
			approachSpent = spent
			if not completed then
				return spent > 0, reason, { interrupted = true, spent = spent }
			end
		end
	end
	if companion and not result.ranged then
		local cost = Hex.moveCost(
			target.x,
			target.y,
			state,
			companion,
			systems,
			companion.x,
			companion.y,
			companion.movesLeft
		)
		if not cost or cost > companion.movesLeft then
			return approachSpent > 0,
				"Escort cannot follow the attack",
				{ interrupted = true, spent = approachSpent }
		end
	end
	C.migrate(state)
	local stats = systems.units[unit.kind] or systems.units.warrior
	local city = at(state.cities, target.x, target.y)
	if city and city.owner == unit.owner then
		city = nil
	end
	local defender = Stacks.at(state.units, target.x, target.y)
	local event = {
		type = "combat",
		actor = VisibilityEvents.actor(unit),
		start = VisibilityEvents.frame(state, unit),
		target = VisibilityEvents.frame(state, city or defender),
		defender = VisibilityEvents.actor(city or defender),
		result = result,
	}
	local damage, retaliation, captured, ranged =
		result.damage, result.retaliation, result.captured, result.ranged
	if result.captureOnly then
		Stacks.capture(state, defender, unit.owner)
		unit.x, unit.y = target.x, target.y
	elseif city then
		city.lastAttackRound = state.round
		city.wallHP = result.wallHP
		city.hp = result.cityHP
		if stats.hostile then
			city.foodStore = math.max(0, (city.foodStore or 0) - 5)
			for _, p in ipairs(state.players) do
				if p.id == city.owner then
					p.gold = math.max(0, (p.gold or 0) - math.min(5, damage))
					p.raids = (p.raids or 0) + 1
				end
			end
		end
		unit.hp = result.attackerHP
		if captured then
			local previousOwner = city.owner
			city.owner = unit.owner
			city.hp = 100
			city.wallHP = 0
			city.population = math.max(1, city.population - 1)
			city.project = nil
			city.worked = nil
			if defender and defender.owner == previousOwner and defender.kind ~= "settler" then
				remove(state, defender)
			end
			state.territoryRevision = (state.territoryRevision or 0) + 1
			captured = true
			unit.x = city.x
			unit.y = city.y
		elseif city.hp <= 0 then
			city.hp = 1
		end
	else
		defender.hp = result.defenderHP
		C.experience(defender, 2)
		unit.hp = result.attackerHP
		if defender.hp <= 0 then
			if (systems.units[defender.kind] or {}).hostile and not stats.hostile then
				Villages.defended(state, unit.owner, defender.x, defender.y)
				Perception.protection(state, unit.owner, defender.x, defender.y, Hex)
			end
			remove(state, defender)
			C.experience(unit, 5)
			if not ranged and unit.hp > 0 then
				unit.x = target.x
				unit.y = target.y
			end
		end
	end
	if result.capturedSettler and not result.captureOnly and unit.hp > 0 then
		local settler = Stacks.settler(state.units, target.x, target.y)
		if settler and settler.owner ~= unit.owner then
			Stacks.capture(state, settler, unit.owner)
		end
	end
	if stats.explosive then
		unit.hp = 0
	end
	C.experience(unit, city and 4 or 3)
	unit.attackedRound = state.round
	unit.actedThisRound = true
	unit.healing = false
	unit.autoExplore = false
	if unit.hp <= 0 then
		remove(state, unit)
	end
	local following, notices
	if not result.ranged and unit.hp > 0 then
		following, notices = UnitMovement.followAttack(state, unit, companion, systems)
	end
	Events.emit(state, event)
	if following then
		Events.emit(state, following)
	end
	for _, notice in ipairs(notices or {}) do
		Events.emit(state, notice)
	end
	World.reveal(state, Hex, systems)
	if not result.ranged and unit.hp > 0 and (unit.x ~= startX or unit.y ~= startY) then
		Zone.enter(state, unit, systems, Hex)
	end
	return true,
		result.capturedSettler and "Settler captured"
			or captured and "City captured"
			or ("Dealt " .. damage .. " HP; received " .. retaliation .. " HP"),
		result
end
function C.strike(state, city, x, y, systems)
	C.migrate(state)
	if city.maxWalls <= 0 or city.wallHP <= 0 then
		return false, "City needs functioning walls for a ranged strike"
	end
	if city.struckRound and city.struckRound == state.round then
		return false, "City already attacked this round"
	end
	local enemy = Stacks.at(state.units, x, y)
	if not enemy or enemy.owner == city.owner or Hex.distance(city.x, city.y, x, y) > 2 then
		return false, "Select an enemy unit within two hexes"
	end
	if not Diplomacy.canAttack(state, city.owner, enemy.owner) then
		return false, "Declare war before attacking this civilization"
	end
	local owner
	for _, p in ipairs(state.players) do
		if p.id == city.owner then
			owner = p
		end
	end
	if owner and not (owner.visible or {})[World.key(x, y)] then
		return false, "Target is not visible"
	end
	local event = {
		type = "cityStrike",
		actor = VisibilityEvents.actor(city),
		start = VisibilityEvents.frame(state, city),
		target = VisibilityEvents.frame(state, enemy),
		defender = VisibilityEvents.actor(enemy),
	}
	local damage = C.damage(C.cityPower(state, city, systems), C.power(enemy, systems, true, state))
	enemy.hp = math.max(0, enemy.hp - damage)
	C.experience(enemy, 2)
	city.struckRound = state.round
	if enemy.hp <= 0 then
		if (systems.units[enemy.kind] or {}).hostile then
			Villages.defended(state, city.owner, enemy.x, enemy.y)
		end
		remove(state, enemy)
	end
	event.result =
		{ attackerHP = city.hp, defenderHP = enemy.hp, defenderDied = enemy.hp <= 0, ranged = true }
	Events.emit(state, event)
	World.reveal(state, Hex, systems)
	return true, "City strike dealt " .. damage .. " HP", event.result
end
return C
