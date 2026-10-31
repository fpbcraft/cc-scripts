local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Content = dofile("/games/civcraft/content.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Reservations = dofile("/games/civcraft/resource_reservations.lua")
local E = {}
function E.effects(city, state, systems)
	local result = { food = 0, industry = 0, science = 0, gold = 0 }
	for id, built in pairs(city.buildings or {}) do
		if
			built
			and Sites.effectiveBuilding(state, city, id)
			and not (ContentRules.hasBuilders(state) and (id == "farm" or id == "mine"))
		then
			for k, v in pairs((Content.buildings[id] or {}).effects or {}) do
				result[k] = (result[k] or 0) + v
			end
		end
	end
	if state then
		local specialty = Sites.effects(state, city)
		for _, field in ipairs({ "food", "industry", "science", "gold" }) do
			result[field] = result[field] + specialty[field]
		end
		for k, v in pairs(Landmarks.effects(state, city, systems)) do
			result[k] = result[k] + v
		end
		local p
		for _, player in ipairs(state.players) do
			if player.id == city.owner then
				p = player
			end
		end
		if p then
			local network = Rails.network(state, p)
			if network[city.id] then
				result.industry = result.industry + 2
				result.gold = result.gold + 2
			end
			-- Village alliance benefits go to the empire's oldest remaining city once.
			local first
			for _, c in ipairs(state.cities) do
				if c.owner == p.id and (not first or c.id < first.id) then
					first = c
				end
			end
			if first == city then
				for k, v in pairs(Villages.effects(state, p)) do
					result[k] = result[k] + v
				end
			end
		end
	end
	return result
end
function E.stocks(p)
	p.stockpile = p.stockpile or {}
	for id in pairs(Content.resources) do
		p.stockpile[id] = p.stockpile[id] or 0
	end
end
function E.plan(p, state, owned)
	local initial = assert(Stock.migrate(p.stockpile or {}))
	local stock, overflow = assert(Stock.copy(initial)), {}
	local rates = {}
	for id in pairs(Content.resources) do
		rates[id] = 0
	end
	for key, id in pairs(state.world and state.world.resources or {}) do
		local record = Content.resources[id]
		if
			record
			and owned[key] == p.id
			and (state.ruleset ~= "create" or not record.tech or p.techs[record.tech])
		then
			rates[id] = rates[id] + 1
		end
	end
	for _, id in ipairs(Stock.order) do
		local inflow = assert(Stock.planInflow(stock, id, rates[id] or 0))
		stock = assert(Stock.applyInflow(stock, inflow))
		overflow[id] = inflow.overflow
	end
	-- This adapter retains the pre-activation mixer choice. #103 supplies selected
	-- operations and local SU/fuel gates through this same reservation engine.
	local operations = {}
	for _, city in ipairs(state.cities or {}) do
		if
			city.owner == p.id
			and Sites.effectiveBuilding(state, city, "mixer")
			and p.techs.brassworking
		then
			operations[#operations + 1] = {
				owner = p.id,
				cityID = city.id,
				buildingID = "mixer",
				priority = 3,
				inputs = { copper = 1, zinc = 1 },
				outputs = { brass = 2 },
			}
		end
	end
	local reservations = assert(Reservations.plan(stock, p.id, operations))
	stock = reservations.stock
	for _, id in ipairs(Stock.order) do
		rates[id] = stock[id] - initial[id]
	end
	return { stock = stock, rates = rates, overflow = overflow, reservations = reservations }
end
function E.rates(p, state, owned)
	return E.plan(p, state, owned).rates
end
function E.exchange(state, p, resource)
	local gold = p.gold == nil and 0 or p.gold
	if type(gold) ~= "number" or gold ~= gold or gold < 0 or gold == math.huge then
		return false, "Invalid treasury"
	end
	if CouncilRules.embargoed(state, p.id) then
		return false, "Council embargo prevents material exchange"
	end
	local price = CouncilRules.exchangeCost(state)
	local record = Content.resources[resource]
	if
		not record
		or resource == "horses"
		or resource == "saltpeter"
		or not p.techs.currency
		or record.tech and not p.techs[record.tech]
	then
		return false, "Research trading and the material technology first"
	end
	local market = false
	for _, c in ipairs(state.cities) do
		if c.owner == p.id and (c.buildings or {}).market then
			market = true
		end
	end
	if not market then
		for _, c in ipairs(state.cities) do
			if
				Villages.independent(c)
				and Villages.discovered(p, c)
				and ((c.influence or {})[p.id] or 0) >= 20
			then
				market = true
			end
		end
	end
	if not market or (p.gold or 0) < price then
		return false, "Need a trading hall or friendly village, and " .. price .. " gold"
	end
	local stock, reason = Stock.migrate(p.stockpile or {})
	if not stock then
		return false, reason
	end
	local plan
	plan, reason = Stock.planOutput(stock, resource, 1)
	if not plan then
		return false, "Material is at its stock cap"
	end
	local result = assert(Stock.applyInflow(stock, plan))
	p.gold, p.stockpile = p.gold - price, result
	return true, "Traded " .. price .. " gold for 1 " .. resource
end
return E
