-- Persisted player choices for the intermediate, pre-activation machinery step.
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local M = {
	schema = 1,
	machines = {
		waterwheel = { priority = 4, recipe = "generator" },
		windmill = { priority = 4, recipe = "generator" },
		press = { priority = 1, recipe = "industry" },
		crusher = { priority = 1, recipe = "industry" },
		beltlogistics = { priority = 1, recipe = "industry" },
		assembly = { priority = 1, recipe = "industry" },
		crafter = { priority = 1, recipe = "industry" },
		deepmine = { priority = 2, recipe = "industry" },
		deployer = { priority = 2, recipe = "industry" },
		burner = { priority = 2, recipe = "industry" },
		mixer = { priority = 3, recipe = "no_recipe" },
		steamplant = { priority = 4, recipe = "generator" },
	},
	recipes = {
		mixer = { no_recipe = true, brass = true, industry = true },
		waterwheel = { generator = true },
		windmill = { generator = true },
		press = { industry = true },
		crusher = { industry = true },
		beltlogistics = { industry = true },
		assembly = { industry = true },
		crafter = { industry = true },
		deepmine = { industry = true },
		deployer = { industry = true },
		burner = { industry = true },
		steamplant = { generator = true },
	},
}
local function copy(record)
	return { recipe = record.recipe, priority = record.priority, enabled = record.enabled }
end
local function hasRetainedSite(city, id)
	local kind = Sites.families[id]
	return kind ~= nil and (city.sites or {})[kind] ~= nil
end
function M.create(city, building)
	local spec = M.machines[building]
	if not spec or (city.buildings or {})[building] ~= true then
		return
	end
	city.machines = city.machines or {}
	if not city.machines[building] then
		city.machines[building] = { recipe = spec.recipe, priority = spec.priority, enabled = true }
	end
end
-- Called only at migration/construction boundaries, never by forecasts.
function M.ensureCity(state, city)
	for id, built in pairs(city.buildings or {}) do
		if
			built == true
			and M.machines[id]
			and (Sites.effectiveBuilding(state, city, id) or hasRetainedSite(city, id))
		then
			M.create(city, id)
		end
	end
end
function M.migrate(state)
	assert(
		state.machinerySchema == nil or state.machinerySchema == M.schema,
		"Unsupported machinery schema"
	)
	local seenRecords, seenMaps = {}, {}
	for _, city in ipairs(state.cities or {}) do
		assert(city.machines == nil or type(city.machines) == "table", "Invalid machine choices")
		city.machines = city.machines or {}
		assert(not seenMaps[city.machines], "Shared city machine choices")
		seenMaps[city.machines] = true
		city.machineStatus = nil
		for id, record in pairs(city.machines) do
			local spec = M.machines[id]
			assert(
				spec and (city.buildings or {})[id] == true,
				"Machine choice has no completed building"
			)
			assert(
				Sites.effectiveBuilding(state, city, id) or hasRetainedSite(city, id),
				"Machine choice has no effective building or retained site"
			)
			local ownerExists = false
			for _, player in ipairs(state.players or {}) do
				if player.id == city.owner then
					ownerExists = true
					break
				end
			end
			assert(ownerExists, "Machine choice has no valid city owner")
			assert(type(record) == "table", "Invalid machine choice")
			assert(not seenRecords[record], "Shared machine choice record")
			seenRecords[record] = true
			assert(
				record.cityID == nil and record.owner == nil,
				"Machine choice has foreign ownership"
			)
			assert(M.recipes[id][record.recipe] == true, "Unknown machine recipe")
			assert(
				type(record.priority) == "number"
					and record.priority % 1 == 0
					and record.priority >= 1
					and record.priority <= 4,
				"Invalid machine priority"
			)
			assert(
				record.enabled == true or record.enabled == false,
				"Invalid machine enabled state"
			)
		end
		M.ensureCity(state, city)
	end
	state.machinerySchema = M.schema
	return state
end
function M.apply(state, owner, request)
	if type(request) ~= "table" then
		return false, "Invalid machine order"
	end
	if
		request.action ~= "selectMachineRecipe"
		and request.action ~= "setMachinePriority"
		and request.action ~= "setMachineEnabled"
	then
		return false, "Unknown machine action"
	end
	local city
	for _, candidate in ipairs(state.cities or {}) do
		if candidate.id == request.city then
			city = candidate
			break
		end
	end
	if not city or city.owner ~= owner then
		return false, "Select an owned city"
	end
	local id = request.building
	local spec = M.machines[id]
	local player
	for _, candidate in ipairs(state.players or {}) do
		if candidate.id == owner then
			player = candidate
			break
		end
	end
	if
		not spec
		or not player
		or not (city.buildings or {})[id]
		or not Sites.effectiveBuilding(state, city, id)
	then
		return false, "Select a completed effective machine"
	end
	local record = city.machines and city.machines[id]
	if not record then
		return false, "Machine choices are unavailable"
	end
	if request.action == "selectMachineRecipe" then
		if not (M.recipes[id] or {})[request.recipe] then
			return false, "Unknown machine recipe"
		end
		if request.recipe == "brass" and not (player.techs or {}).brassworking then
			return false, "Research Brassworking"
		end
		record.recipe = request.recipe
	elseif request.action == "setMachinePriority" then
		if
			type(request.priority) ~= "number"
			or request.priority % 1 ~= 0
			or request.priority < 1
			or request.priority > 4
		then
			return false, "Invalid machine priority"
		end
		record.priority = request.priority
	elseif request.action == "setMachineEnabled" then
		if type(request.enabled) ~= "boolean" then
			return false, "Invalid enabled state"
		end
		record.enabled = request.enabled
	end
	return true, "Machine choice updated"
end
return M
