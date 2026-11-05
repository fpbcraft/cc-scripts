-- Pure owner-scoped machinery forecast from a copied post-extraction snapshot.
local Choices = dofile("/games/civcraft/machine_choices.lua")
local Content = dofile("/games/civcraft/content.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Reservations = dofile("/games/civcraft/resource_reservations.lua")
local M = {}

local function copy(source)
	local result = {}
	for key, value in pairs(source or {}) do
		if type(value) == "table" then
			result[key] = copy(value)
		else
			result[key] = value
		end
	end
	return result
end

local function byOperation(a, b)
	if a.priority ~= b.priority then
		return a.priority < b.priority
	end
	if a.cityID ~= b.cityID then
		return a.cityID < b.cityID
	end
	return a.buildingID < b.buildingID
end

local function playerRecord(state, player)
	local id = type(player) == "table" and player.id or player
	for _, candidate in ipairs(state.players or {}) do
		if candidate.id == id then
			return candidate
		end
	end
end

local function operation(owner, city, id, choice, recipe)
	local inputs, outputs = {}, {}
	if id == "mixer" and recipe == "brass" then
		inputs, outputs = { copper = 1, zinc = 1 }, { brass = 2 }
	end
	return {
		owner = owner,
		cityID = city.id,
		buildingID = id,
		priority = choice.priority,
		inputs = inputs,
		outputs = outputs,
		impact = Choices.machines[id].impact,
	}
end

local function gate(state, city, player, id, choice)
	if choice.enabled == false then
		return "disabled"
	end
	if (city.buildings or {})[id] ~= true or not Sites.effectiveBuilding(state, city, id) then
		return "inactive_family"
	end
	local building = Content.buildings[id] or {}
	if building.tech and not (player.techs or {})[building.tech] then
		return "inactive_family"
	end
	if id == "mixer" and choice.recipe == "no_recipe" then
		return "no_recipe"
	end
	if id == "mixer" and choice.recipe == "brass" and not (player.techs or {}).brassworking then
		return "inactive_family"
	end
	return nil
end

local function plausible(stock, owner, op)
	local result = Reservations.plan(stock, owner, { op })
	return result and result.operations[1].active or false
end

local function fuelPlan(stock, owner, cities, candidates, steamPriorities)
	local fuels = {}
	for _, city in ipairs(cities) do
		if candidates[city.id] then
			fuels[#fuels + 1] = {
				owner = owner,
				cityID = city.id,
				buildingID = "steamplant",
				priority = steamPriorities[city.id],
				inputs = { coal = 1 },
				outputs = {},
			}
		end
	end
	return Reservations.plan(stock, owner, fuels)
end

-- Inputs are state, owner id/record, and copied stock after extraction.
-- The result is detached and contains only the requested owner's operations.
function M.plan(state, owner, postExtractionStock)
	if type(state) ~= "table" then
		return nil, "Invalid machinery state"
	end
	local player = playerRecord(state, owner)
	if not player then
		return nil, "Unknown machinery owner"
	end
	local ownerID = player.id
	local stock, why = Stock.migrate(postExtractionStock)
	if not stock then
		return nil, why
	end
	local cities, operations, records = {}, {}, {}
	for _, city in ipairs(state.cities or {}) do
		if city.owner == ownerID then
			cities[#cities + 1] = city
			for id, choice in pairs(city.machines or {}) do
				if not Choices.machines[id] or type(choice) ~= "table" then
					return nil, "Invalid owner machine choice"
				end
				if
					type(choice.priority) ~= "number"
					or choice.priority % 1 ~= 0
					or choice.priority < 1
					or choice.priority > 4
					or not (Choices.recipes[id] or {})[choice.recipe]
					or (choice.enabled ~= true and choice.enabled ~= false)
				then
					return nil, "Invalid owner machine choice"
				end
			end
			for id, spec in pairs(Choices.machines) do
				if (city.buildings or {})[id] == true then
					local choice = city.machines and city.machines[id]
					if type(choice) ~= "table" then
						choice = { recipe = spec.recipe, priority = spec.priority, enabled = true }
					end
					local record = { cityID = city.id, buildingID = id, choice = copy(choice) }
					records[#records + 1] = record
					local reason = gate(state, city, player, id, choice)
					if spec.generator then
						record.generatorReason = reason
						record.active = reason == nil
						record.impact, record.capacity = 0, spec.capacity
						record.effects = record.active
								and copy((Content.buildings[id] or {}).effects)
							or {}
					else
						record.reason = reason
						if not reason then
							local op = operation(ownerID, city, id, choice, choice.recipe)
							record.operation = op
							operations[#operations + 1] = op
						end
					end
				end
			end
		end
	end
	table.sort(cities, function(a, b)
		return a.id < b.id
	end)
	table.sort(operations, byOperation)
	local baseCapacity, totalCapacity = {}, {}
	for _, city in ipairs(cities) do
		local capacity = 0
		for id, spec in pairs(Choices.machines) do
			if spec.generator and id ~= "steamplant" and (city.buildings or {})[id] == true then
				local choice = city.machines and city.machines[id] or spec
				if choice.enabled ~= false and Sites.effectiveBuilding(state, city, id) then
					capacity = capacity + spec.capacity
				end
			end
		end
		baseCapacity[city.id], totalCapacity[city.id] = capacity, capacity
	end
	local candidates, steamReasons, steamPriorities = {}, {}, {}
	for _, record in ipairs(records) do
		if record.buildingID == "steamplant" then
			steamPriorities[record.cityID] = record.choice.priority
			if record.generatorReason then
				record.reason = record.generatorReason
			elseif baseCapacity[record.cityID] == nil then
				record.reason = "inactive_family"
			else
				local demand = false
				for _, op in ipairs(operations) do
					if
						op.cityID == record.cityID
						and op.impact > 0
						and plausible(stock, ownerID, op)
					then
						demand = true
					end
				end
				if demand then
					candidates[record.cityID] = true
				else
					record.reason = "no_demand"
					steamReasons[record.cityID] = "no_demand"
				end
			end
		end
	end
	local fuelForecast, finalSession, activeFuel
	for _ = 1, #cities + 1 do
		fuelForecast = assert(fuelPlan(stock, ownerID, cities, candidates, steamPriorities))
		activeFuel = {}
		for _, op in ipairs(fuelForecast.operations) do
			if op.active then
				activeFuel[op.cityID] = true
				totalCapacity[op.cityID] = baseCapacity[op.cityID] + 8
			end
		end
		local session = assert(Reservations.begin(fuelForecast.stock, ownerID))
		local used, active = {}, {}
		for _, city in ipairs(cities) do
			used[city.id], active[city.id] = 0, 0
		end
		for _, op in ipairs(operations) do
			local room = totalCapacity[op.cityID] - used[op.cityID]
			local result
			if op.impact > room then
				local check = assert(Reservations.plan(fuelForecast.stock, ownerID, { op }))
				result = assert(
					Reservations.skip(session, op, check.operations[1].reason or "no_capacity")
				)
			else
				result = assert(Reservations.reserve(session, op))
				if result.active then
					used[op.cityID] = used[op.cityID] + op.impact
					active[op.cityID] = active[op.cityID] + op.impact
				end
			end
		end
		finalSession = Reservations.result(session)
		local changed = false
		for _, city in ipairs(cities) do
			if candidates[city.id] and (active[city.id] or 0) <= baseCapacity[city.id] then
				steamReasons[city.id] = activeFuel[city.id] and "no_demand" or "missing_fuel"
				candidates[city.id] = nil
				changed = true
			end
		end
		if not changed then
			break
		end
		for _, city in ipairs(cities) do
			totalCapacity[city.id] = baseCapacity[city.id]
		end
	end
	local statusById = {}
	for _, result in ipairs(finalSession.operations) do
		statusById[result.cityID .. ":" .. result.buildingID] = result
	end
	for _, record in ipairs(records) do
		if record.operation then
			local status = statusById[record.cityID .. ":" .. record.buildingID]
			record.active, record.reason = status.active, status.reason
			record.impact = record.operation.impact
			record.effects = status.active
					and (record.buildingID == "mixer" and record.choice.recipe == "brass" and {} or copy(
						(Content.buildings[record.buildingID] or {}).effects
					))
				or {}
		elseif record.buildingID == "steamplant" and not record.reason then
			local active = activeFuel[record.cityID] == true and candidates[record.cityID] == true
			record.active = active
			record.reason = active and nil or steamReasons[record.cityID] or "missing_fuel"
			record.impact, record.effects =
				0, active and copy((Content.buildings.steamplant or {}).effects) or {}
			if not active then
				record.effects = {}
			end
		elseif record.buildingID == "steamplant" then
			record.active, record.impact, record.effects = false, 0, {}
			record.reason = record.reason or steamReasons[record.cityID] or "missing_fuel"
		end
	end
	local cityResults = {}
	for _, city in ipairs(cities) do
		cityResults[city.id] = { capacity = totalCapacity[city.id], used = 0 }
	end
	for _, record in ipairs(records) do
		if record.active and record.impact then
			cityResults[record.cityID].used = cityResults[record.cityID].used + record.impact
		end
	end
	local reservationInputs, reservationOutputs, reservationOperations = {}, {}, {}
	for _, resource in ipairs(Stock.order) do
		reservationInputs[resource] = fuelForecast.inputs[resource] + finalSession.inputs[resource]
		reservationOutputs[resource] = fuelForecast.outputs[resource]
			+ finalSession.outputs[resource]
	end
	for _, item in ipairs(fuelForecast.operations) do
		reservationOperations[#reservationOperations + 1] = copy(item)
	end
	for _, item in ipairs(finalSession.operations) do
		reservationOperations[#reservationOperations + 1] = copy(item)
	end
	local materialReservations = {
		owner = ownerID,
		snapshot = copy(stock),
		stock = copy(finalSession.stock),
		inputs = reservationInputs,
		outputs = reservationOutputs,
		caps = copy(finalSession.caps),
		operations = reservationOperations,
	}
	return {
		owner = ownerID,
		stock = copy(finalSession.stock),
		capacity = copy(cityResults),
		machines = copy(records),
		reservations = materialReservations,
	}
end

return M
