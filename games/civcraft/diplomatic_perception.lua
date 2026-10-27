local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Perception = {}
local function visible(player, x, y)
	return (player.visible or {})[x .. ":" .. y] == true
end

function Perception.pressure(state, observer, subject, hex, units)
	local viewer
	for _, player in ipairs(state.players) do
		if player.id == observer then
			viewer = player
		end
	end
	if not viewer then
		return 0
	end
	local pressure = 0
	for _, unit in ipairs(state.units) do
		local strength = (units[unit.kind] or {}).strength or 0
		if unit.owner == subject and strength > 0 and visible(viewer, unit.x, unit.y) then
			for _, city in ipairs(state.cities) do
				if city.owner == observer and hex.distance(unit.x, unit.y, city.x, city.y) <= 3 then
					pressure = pressure + strength
					break
				end
			end
		end
	end
	return pressure
end

function Perception.move(state, unit, hex, world, diplomacy)
	if not state.diplomacy then
		return
	end
	local claim = world.territoryCity(state, hex, unit.x, unit.y)
	if
		not claim
		or claim.owner == unit.owner
		or diplomacy.canAttack(state, unit.owner, claim.owner)
		or Offers.treaty(state, unit.owner, claim.owner, "openBorders")
	then
		return
	end
	for _, owner in ipairs(state.players) do
		if owner.id == claim.owner and visible(owner, unit.x, unit.y) then
			Memory.add(
				state,
				owner.id,
				unit.owner,
				"borderCrossing",
				-3,
				3,
				12,
				"Observed troops crossing our territory without open borders"
			)
		end
	end
end

function Perception.settlement(state, city, hex)
	if not state.diplomacy then
		return
	end
	for _, observer in ipairs(state.players) do
		if observer.id ~= city.owner and visible(observer, city.x, city.y) then
			for _, neighbor in ipairs(state.cities) do
				if
					neighbor.owner == observer.id
					and hex.distance(city.x, city.y, neighbor.x, neighbor.y) <= 5
				then
					Memory.add(
						state,
						observer.id,
						city.owner,
						"settlementCompetition",
						-5,
						5,
						20,
						"Founded an observed settlement near our cities"
					)
					break
				end
			end
		end
	end
end

function Perception.protection(state, actor, x, y, hex)
	if not state.diplomacy then
		return
	end
	for _, observer in ipairs(state.players) do
		if observer.id ~= actor and visible(observer, x, y) then
			for _, city in ipairs(state.cities) do
				if city.owner == observer.id and hex.distance(x, y, city.x, city.y) <= 4 then
					Memory.add(
						state,
						observer.id,
						actor,
						"mobProtection",
						5,
						0,
						15,
						"Defeated an observed hostile mob near our settlement"
					)
					break
				end
			end
		end
	end
end

function Perception.promises(state, hex, world, units)
	if not state.diplomacy then
		return
	end
	for _, promise in ipairs(state.diplomacy.promises or {}) do
		if promise.status == "active" and promise.deadline < state.round then
			local observer
			for _, player in ipairs(state.players) do
				if player.id == promise.to then
					observer = player
				end
			end
			local broken = false
			if observer then
				for _, unit in ipairs(state.units) do
					if
						unit.owner == promise.by
						and ((units[unit.kind] or {}).strength or 0) > 0
						and visible(observer, unit.x, unit.y)
					then
						local claim = world.territoryCity(state, hex, unit.x, unit.y)
						broken = broken or claim and claim.owner == promise.to or false
					end
				end
			end
			promise.status = broken and "broken" or "fulfilled"
			Memory.add(
				state,
				promise.to,
				promise.by,
				broken and "withdrawalBroken" or "withdrawalHonored",
				broken and -25 or 8,
				broken and 20 or 0,
				broken and 40 or 20,
				broken and "Observed troops remaining after a withdrawal deadline"
					or "No observed troops remained after the promised withdrawal"
			)
		end
	end
end

return Perception
