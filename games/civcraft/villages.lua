-- Independent villager city-states: defense, envoys and contested alliances.
local Events = dofile("/games/civcraft/events.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local V = {}
V.types = {
	farmer = { name = "FARMER VILLAGE", food = 2 },
	librarian = { name = "LIBRARIAN VILLAGE", science = 2 },
	toolsmith = { name = "TOOLSMITH VILLAGE", industry = 2 },
}
function V.generate(state)
	local wanted = math.max(2, math.floor(state.world.width * state.world.height / 200))
	for y = 3, state.world.height - 2 do
		for x = 3, state.world.width - 2 do
			if wanted <= 0 then
				return
			end
			local safe = true
			for _, start in ipairs(state.world.starts or {}) do
				if Hex.distance(x, y, start.x, start.y) < 5 then
					safe = false
					break
				end
			end
			for _, s in ipairs(state.cities) do
				if Hex.distance(x, y, s.x, s.y) < 5 then
					safe = false
				end
			end
			for _, s in ipairs(state.spawners or {}) do
				if Hex.distance(x, y, s.x, s.y) < 3 then
					safe = false
				end
			end
			local k = x .. ":" .. y
			local t = Hex.terrain(x, y, state)
			if
				safe
				and t ~= "water"
				and t ~= "mountain"
				and not (state.world.landmarks or {})[k]
			then
				local id = state.nextId
				state.nextId = id + 1
				local kind = ({ "farmer", "librarian", "toolsmith" })[(id % 3) + 1]
				local owner = -1000 - id
				state.cities[#state.cities + 1] = {
					id = id,
					owner = owner,
					x = x,
					y = y,
					name = ({ "OAKHAM", "BELLBROOK", "MOSSY", "COPPERWELL", "BIRCHREST" })[id % 5 + 1],
					village = true,
					villageOwner = owner,
					villageKind = kind,
					influence = {},
					population = 2,
					jobs = { food = 1, wood = 1, science = 0 },
					buildings = { walls = true },
					foodStore = 20,
				}
				state.units[#state.units + 1] = {
					id = state.nextId,
					owner = owner,
					x = x,
					y = y,
					kind = "spearman",
					hp = 100,
					moved = true,
					movesLeft = 0,
					villageGuard = id,
				}
				state.nextId = state.nextId + 1
				wanted = wanted - 1
			end
		end
	end
end
function V.independent(city)
	return city.village and city.owner == city.villageOwner
end
function V.ally(city)
	if city.publicAlly ~= nil then
		return city.publicAlly ~= false and city.publicAlly or nil
	end
	if not V.independent(city) then
		return nil
	end
	local best, score
	for id, value in pairs(city.influence or {}) do
		if value >= 40 and (not score or value > score or value == score and id < best) then
			best, score = id, value
		end
	end
	return best
end
function V.discovered(p, city)
	return (p.explored or {})[city.x .. ":" .. city.y] or (p.visible or {})[city.x .. ":" .. city.y]
end
function V.envoy(state, p, city)
	if not city or not V.independent(city) or not V.discovered(p, city) then
		return false, "Discover an independent village first"
	end
	if (p.gold or 0) < 25 then
		return false, "Envoy costs 25 gold"
	end
	city.envoyRounds = city.envoyRounds or {}
	if (state.round or 1) - (city.envoyRounds[p.id] or -10) < 5 then
		return false, "Wait five rounds between envoys"
	end
	city.influence = city.influence or {}
	city.influence[p.id] = (city.influence[p.id] or 0) + 10
	city.envoyRounds[p.id] = state.round
	p.gold = p.gold - 25
	return true, "Envoy welcomed: +10 influence"
end
function V.defended(state, pid, x, y)
	local player = false
	for _, p in ipairs(state.players) do
		if p.id == pid then
			player = true
		end
	end
	if not player then
		return
	end
	for _, city in ipairs(state.cities) do
		if V.independent(city) and Hex.distance(city.x, city.y, x, y) <= 3 then
			city.influence = city.influence or {}
			city.influence[pid] = (city.influence[pid] or 0) + 10
		end
	end
end
function V.effects(state, p)
	local result = { food = 0, industry = 0, science = 0, gold = 0 }
	for _, city in ipairs(state.cities or {}) do
		if V.ally(city) == p.id then
			for k, v in pairs(V.types[city.villageKind] or {}) do
				if type(v) == "number" then
					result[k] = result[k] + v
				end
			end
		end
	end
	return result
end
function V.round(state, systems, combat)
	if state.villageRound == state.round then
		return
	end
	state.villageRound = state.round
	for _, city in ipairs(state.cities) do
		if V.independent(city) then
			local guard
			for _, u in ipairs(state.units) do
				if u.villageGuard == city.id and u.owner == city.owner then
					guard = u
					break
				end
			end
			if guard then
				guard.movesLeft = 2
				guard.moved = false
				for _, target in ipairs(Hex.reachable(state, guard, guard.owner, systems)) do
					local hostile = false
					for _, enemy in ipairs(state.units) do
						if
							enemy.x == target.x
							and enemy.y == target.y
							and (systems.units[enemy.kind] or {}).hostile
						then
							hostile = true
						end
					end
					if
						hostile
						and target.attack
						and Hex.distance(target.x, target.y, city.x, city.y) <= 2
					then
						combat.attack(state, guard, target, systems)
						break
					end
				end
				guard.movesLeft = 0
				guard.moved = true
			elseif state.round % 10 == 0 then
				local free = true
				for _, u in ipairs(state.units) do
					if u.x == city.x and u.y == city.y then
						free = false
					end
				end
				if free then
					state.units[#state.units + 1] = {
						id = state.nextId,
						owner = city.owner,
						x = city.x,
						y = city.y,
						kind = "spearman",
						villageGuard = city.id,
						movesLeft = 0,
						moved = true,
					}
					Events.notice(state, "spawn", state.units[#state.units])
					state.nextId = state.nextId + 1
				end
			end
		end
	end
end
return V
