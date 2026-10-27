-- Reports contain only the receiving empire's possessions and economy.
local Content = dofile("/games/civcraft/content.lua")
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local R = {}
local function sortedKeys(records)
	local keys = {}
	for key in pairs(records) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then
			return a < b
		end
		return type(a) < type(b)
	end)
	return keys
end
function R.capture(state, p)
	local s = {
		food = p.food or 0,
		wood = p.wood or 0,
		science = p.science or 0,
		gold = p.gold or 0,
		cities = {},
		units = {},
		techs = {},
		wonders = {},
		influence = {},
		raids = p.raids or 0,
		mobClears = p.mobClears or 0,
		age = p.age or 1,
		industryTurns = p.industryTurns or 0,
		industryTarget = CampaignRules.cost(10, state),
		endStage = p.endStage or 0,
	}
	for id, value in pairs(p.techs or {}) do
		if value then
			s.techs[id] = true
		end
	end
	for _, c in ipairs(state.cities or {}) do
		if c.owner == p.id then
			local b = {}
			for id, value in pairs(c.buildings or {}) do
				if value then
					b[id] = true
				end
			end
			s.cities[c.x .. "," .. c.y] =
				{ name = c.name, population = c.population or 2, buildings = b }
		end
	end
	for _, u in ipairs(state.units or {}) do
		if u.owner == p.id then
			s.units[tostring(u.id or (u.kind .. ":" .. u.x .. "," .. u.y))] =
				{ kind = u.kind, hp = u.hp }
		end
	end
	for key, landmark in pairs(state.world and state.world.landmarks or {}) do
		if not landmark.natural then
			local x, y = key:match("^(%d+):(%d+)$")
			local city = World.territoryCity(state, Hex, tonumber(x), tonumber(y))
			if city and city.owner == p.id then
				s.wonders[landmark.kind] = true
			end
		end
	end
	for _, city in ipairs(state.cities or {}) do
		if city.village then
			s.influence[city.id] = (city.influence or {})[p.id] or 0
		end
	end
	return s
end
function R.build(state, p, before)
	local now = R.capture(state, p)
	local lines = {}
	if not before then
		return {
			"Your empire is ready. Inspect cities to assign citizens and choose production.",
			"Select a unit, then use MOVE / ATTACK to issue an order.",
		}
	end
	for _, field in ipairs({ "food", "wood", "science", "gold" }) do
		local delta = now[field] - (before[field] or 0)
		lines[#lines + 1] = (field == "wood" and "INDUSTRY" or field:upper())
			.. " "
			.. (delta >= 0 and "+" or "")
			.. delta
			.. " (TOTAL "
			.. now[field]
			.. ")"
	end
	local ids = {}
	for id in pairs(now.techs) do
		if not before.techs[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		lines[#lines + 1] = "Research completed: " .. ((Content.techs[id] or {}).name or id)
	end
	local coords = {}
	for key in pairs(now.cities) do
		coords[#coords + 1] = key
	end
	table.sort(coords)
	for _, key in ipairs(coords) do
		local city, old = now.cities[key], before.cities[key]
		if not old then
			lines[#lines + 1] = (city.name or "City") .. " gained at " .. key
		else
			if city.population ~= old.population then
				lines[#lines + 1] = (city.name or ("City " .. key))
					.. " population "
					.. old.population
					.. " -> "
					.. city.population
			end
			local built = {}
			for id in pairs(city.buildings) do
				if not old.buildings[id] then
					built[#built + 1] = id
				end
			end
			table.sort(built)
			for _, id in ipairs(built) do
				lines[#lines + 1] = (city.name or ("City " .. key))
					.. " completed "
					.. ((Content.buildings[id] or {}).name or id)
			end
		end
	end
	for _, key in ipairs(sortedKeys(before.cities)) do
		if not now.cities[key] then
			lines[#lines + 1] = "City lost at " .. key
		end
	end
	for _, id in ipairs(sortedKeys(now.units)) do
		local u = now.units[id]
		local old = before.units[id]
		if not old then
			lines[#lines + 1] = "Unit recruited: " .. ((Content.units[u.kind] or {}).name or u.kind)
		elseif old.hp and u.hp and u.hp < old.hp then
			lines[#lines + 1] = ((Content.units[u.kind] or {}).name or u.kind)
				.. " damaged: "
				.. u.hp
				.. " HP"
		end
	end
	for _, id in ipairs(sortedKeys(before.units)) do
		local u = before.units[id]
		if not now.units[id] then
			lines[#lines + 1] = "Unit lost: " .. ((Content.units[u.kind] or {}).name or u.kind)
		end
	end
	for _, id in ipairs(sortedKeys(now.wonders)) do
		if not (before.wonders or {})[id] then
			lines[#lines + 1] = "Wonder gained: " .. Content.wonders[id].name
		end
	end
	for _, id in ipairs(sortedKeys(now.influence)) do
		local value = now.influence[id]
		if value ~= ((before.influence or {})[id] or 0) then
			lines[#lines + 1] = "Village influence: " .. value
		end
	end
	if now.raids > (before.raids or 0) then
		lines[#lines + 1] = "Hostile raids: " .. (now.raids - (before.raids or 0))
	end
	if now.mobClears > (before.mobClears or 0) then
		lines[#lines + 1] = "Spawner cleared; 25 gold reward"
	end
	if now.age > (before.age or 1) then
		lines[#lines + 1] = "New Age: " .. Content.ages[now.age].name
	end
	if now.industryTurns > 0 then
		lines[#lines + 1] = "Industrial victory: "
			.. now.industryTurns
			.. "/"
			.. now.industryTarget
			.. " rounds"
	end
	if now.endStage > (before.endStage or 0) then
		lines[#lines + 1] = "End expedition: " .. now.endStage .. "/3 projects"
	end
	return lines
end
return R
