-- Deterministic strength-difference combat with separate city and wall health.
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local C = {}
local function at(list, x, y)
	for _, v in ipairs(list or {}) do
		if v.x == x and v.y == y then
			return v
		end
	end
end
local function remove(state, unit)
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
function C.power(unit, systems, defending, state)
	C.unit(unit)
	local stats = systems.units[unit.kind] or systems.units.warrior
	local base = (defending and stats.defense or stats.strength) or 0
	local result = 10 + base * 5 + (unit.level - 1) * 2 - math.floor((100 - unit.hp) / 10)
	if defending then
		for _, p in ipairs(state and state.players or {}) do
			if
				p.id == unit.owner
				and p.civ == "highland"
				and Hex.terrain(unit.x, unit.y, state) == "hills"
			then
				result = result + 3
			end
		end
		local terrain = Hex.terrain(unit.x, unit.y, state)
		if terrain == "hills" or terrain == "forest" then
			result = result + 3
		end
		if unit.standby or unit.healing then
			result = result + 3
		end
	end
	return math.max(1, result)
end
function C.cityPower(state, city, systems)
	C.city(city)
	local strongest = 20
	for _, u in ipairs(state.units) do
		if u.owner == city.owner then
			strongest = math.max(strongest, C.power(u, systems, true, state))
		end
	end
	local bonus = 0
	for _, p in ipairs(state.players or {}) do
		if p.id == city.owner and p.civ == "sentinel" then
			bonus = 3
		end
	end
	return math.max(
		1,
		bonus
			+ 10
			+ math.floor(strongest / 2)
			+ city.population * 2
			+ (city.maxWalls > 0 and 8 or 0)
			- math.floor((200 - city.hp) / 20)
	)
end
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
function C.round(state, systems)
	C.migrate(state)
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
	local defender = at(state.units, target.x, target.y)
	if not city and (not defender or defender.owner == unit.owner) then
		return nil, "No enemy target"
	end
	local ranged = (stats.range or 1) > 1
	local offense = C.power(attacker, systems, false, state)
	local defense
	if city then
		city = copy(city)
		C.city(city)
		local units = {}
		for _, u in ipairs(state.units) do
			units[#units + 1] = copy(u)
		end
		defense = C.cityPower(
			{ units = units, players = state.players, world = state.world },
			city,
			systems
		)
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
		ranged = ranged,
	}
end
function C.attack(state, unit, target, systems)
	local result, why = C.predict(state, unit, target, systems)
	if not result then
		return false, why
	end
	C.migrate(state)
	local stats = systems.units[unit.kind] or systems.units.warrior
	local city = at(state.cities, target.x, target.y)
	if city and city.owner == unit.owner then
		city = nil
	end
	local defender = at(state.units, target.x, target.y)
	local damage, retaliation, captured, ranged =
		result.damage, result.retaliation, result.captured, result.ranged
	if city then
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
			if defender and defender.owner == previousOwner then
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
			end
			remove(state, defender)
			C.experience(unit, 5)
			if not ranged and unit.hp > 0 then
				unit.x = target.x
				unit.y = target.y
			end
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
	return true,
		captured and "City captured"
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
	local enemy = at(state.units, x, y)
	if not enemy or enemy.owner == city.owner or Hex.distance(city.x, city.y, x, y) > 2 then
		return false, "Select an enemy unit within two hexes"
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
	return true, "City strike dealt " .. damage .. " HP"
end
return C
