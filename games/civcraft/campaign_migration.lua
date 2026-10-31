-- Validate and migrate a detached save candidate before gameplay can use it.
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
local Projects = dofile("/games/civcraft/civilian_projects.lua")
local Migration = {}
local function copy(value, active, copies)
	if type(value) ~= "table" then
		assert(
			type(value) == "nil"
				or type(value) == "string"
				or type(value) == "number"
				or type(value) == "boolean",
			"Non-save value"
		)
		assert(
			type(value) ~= "number" or value == value and math.abs(value) < math.huge,
			"Nonfinite save value"
		)
		return value
	end
	assert(not active[value], "Cyclic save")
	if copies[value] then
		return copies[value]
	end
	local result = {}
	copies[value], active[value] = result, true
	for key, item in pairs(value) do
		assert(type(key) == "string" or type(key) == "number", "Invalid save key")
		result[key] = copy(item, active, copies)
	end
	active[value] = nil
	return result
end
local function integer(value)
	return type(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value % 1 == 0
end
local function collection(state, field)
	state[field] = state[field] or {}
	assert(type(state[field]) == "table", "Invalid " .. field)
	for key, value in pairs(state[field]) do
		assert(
			integer(key) and key >= 1 and key <= #state[field] and type(value) == "table",
			"Invalid " .. field .. " entry"
		)
	end
end
function Migration.load(saved)
	local ok, candidate = pcall(function()
		assert(type(saved) == "table", "Invalid saved campaign")
		local state = copy(saved, {}, {})
		assert(
			state.version == nil
				or integer(state.version) and state.version >= 0 and state.version <= 6,
			"Unsupported save version"
		)
		assert(
			state.resourceSchema == nil or state.resourceSchema == 1,
			"Unsupported resource schema"
		)
		assert(
			state.phase == "lobby" or state.phase == "game" or state.phase == "over",
			"Invalid campaign phase"
		)
		assert(ContentRules.migrateId(state.contentRules))
		for _, field in ipairs({ "players", "cities", "units" }) do
			collection(state, field)
		end
		assert(state.phase == "lobby" or #state.players > 0, "Campaign has no players")
		local players, entities = {}, {}
		for _, p in ipairs(state.players) do
			assert(integer(p.id) and not players[p.id], "Invalid player ID")
			players[p.id] = true
			local plan = p.aiPlan
			if
				plan
				and (
					type(plan) ~= "table"
					or plan.version ~= Strategy.version
					or state.contentRules ~= ContentRules.current
					or not ({ conquest = true, expedition = true, score = true })[plan.primary]
				)
			then
				p.aiPlan = nil
			end
		end
		for _, field in ipairs({ "cities", "units" }) do
			for _, item in ipairs(state[field]) do
				assert(
					integer(item.id) and item.id > 0 and not entities[item.id],
					"Invalid entity ID"
				)
				entities[item.id] = true
				assert(
					integer(item.owner) and integer(item.x) and integer(item.y),
					"Invalid entity position/owner"
				)
				if field == "units" then
					assert(Systems.units[item.kind], "Unsupported saved unit")
				else
					assert(
						integer(item.population) and item.population > 0,
						"Missing or invalid saved population"
					)
					assert(
						item.buildings == nil or type(item.buildings) == "table",
						"Invalid saved buildings"
					)
					if item.project then
						local project = item.project
						assert(type(project) == "table", "Invalid saved project")
						local catalogs = {
							unit = Systems.units,
							building = Systems.buildings,
							wonder = Systems.wonders,
							project = Projects.definitions,
						}
						if project.kind ~= "site" then
							local record = (catalogs[project.kind] or {})[project.id]
							assert(
								record and ContentRules.available(record),
								"Unsupported saved project"
							)
						end
					end
					for building, built in pairs(item.buildings or {}) do
						assert(
							Systems.buildings[building] and type(built) == "boolean",
							"Unsupported saved building"
						)
					end
				end
			end
		end
		World.migrate(state)
		if state.phase ~= "lobby" then
			assert(type(state.world) == "table", "Missing campaign world")
			assert(
				integer(state.world.width)
					and state.world.width > 0
					and integer(state.world.height)
					and state.world.height > 0,
				"Invalid world dimensions"
			)
			assert(type(state.world.tiles) == "table", "Invalid world tiles")
			for _, field in ipairs({ "cities", "units" }) do
				for _, item in ipairs(state[field]) do
					assert(Hex.inBounds(item.x, item.y, state), "Saved entity outside world")
				end
			end
		end
		Systems.migrate(state)
		Diplomacy.migrate(state)
		return state
	end)
	if not ok then
		return nil,
			"Cannot repair this campaign: "
				.. tostring(candidate)
				.. ". Delete/reset this save to continue."
	end
	return candidate
end
return Migration
