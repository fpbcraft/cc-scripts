-- Plan from detached observer knowledge; execute through the shared action rules.
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Campaigns = dofile("/games/civcraft/ai_campaigns.lua")
local CityRoles = dofile("/games/civcraft/ai_city_roles.lua")
local Infrastructure = dofile("/games/civcraft/ai_infrastructure.lua")
local Materials = dofile("/games/civcraft/ai_materials.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
local Research = dofile("/games/civcraft/ai_research.lua")
local Settlement = dofile("/games/civcraft/ai_settlement.lua")
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local Workers = dofile("/games/civcraft/ai_workers.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local A = {}

function A.knowledge(state, player)
	return Presentation.capture(state, player.id)
end
function A.beginTurn(state, player, systems)
	local view = A.knowledge(state, player)
	local plan = Strategy.review(view, player, state.world and state.world.seed)
	if systems and plan.specializationRound ~= plan.lastReviewRound then
		plan.citySpecializations = CityRoles.choose(view, player, systems)
		plan.specializationRound = plan.lastReviewRound
	end
	local treasury = systems and systems.treasury(player, view)
	if treasury and treasury.net < 0 and (player.gold or 0) < -treasury.net * 3 then
		plan.emergency, plan.mood = "avoidBankruptcy", "recovering"
		plan.priorities = { "avoidBankruptcy", plan.primary }
	end
	if systems then
		local roles = Campaigns.update(view, player, systems)
		for _, unit in ipairs(state.units) do
			if unit.owner == player.id and roles[unit.id] then
				unit.aiRole = roles[unit.id]
				unit.aiRole.groupID = plan.campaign and plan.campaign.groupID
			end
		end
	end
	return plan, view
end
function A.military(state, player, unit, systems)
	local failed, acted = {}, false
	for _ = 1, 8 do
		if (unit.movesLeft or 0) <= 0 then
			break
		end
		local view = A.knowledge(state, player)
		local present = false
		for _, known in ipairs(view.units) do
			if known.id == unit.id then
				present = true
			end
		end
		if not present then
			break
		end
		local selected, key
		for _, choice in ipairs(Tactics.ranked(view, player, unit, systems)) do
			local request = choice.request
			key = request.action .. ":" .. request.x .. ":" .. request.y
			if not failed[key] then
				selected = choice
				break
			end
		end
		if not selected then
			break
		end
		local ok = Actions.apply(state, player.id, selected.request, systems)
		if ok then
			acted = true
			if selected.request.action ~= "move" then
				break
			end
		else
			failed[key] = true
			local count = 0
			for _ in pairs(failed) do
				count = count + 1
			end
			if count >= 3 then
				break
			end
		end
	end
	return acted
end
function A.strike(state, player, city, systems)
	local view = A.knowledge(state, player)
	local known
	for _, current in ipairs(view.cities) do
		if current.id == city.id then
			known = current
		end
	end
	local request = known and Tactics.cityStrike(view, player, known, systems)
	return request and Actions.apply(state, player.id, request, systems) or false
end
function A.research(player, systems, view)
	view = view or { observerID = player.id, players = { player }, cities = {}, units = {} }
	local choices = Research.ranked(view, player, systems)
	return choices[1] and choices[1].id
end
local function cityIn(view, id)
	for _, city in ipairs(view.cities) do
		if city.id == id then
			return city
		end
	end
end
function A.staff(state, player, city, systems)
	local view = A.knowledge(state, player)
	local known = cityIn(view, city.id)
	for _, request in ipairs(Workers.orders(view, player, known, systems)) do
		if not Actions.apply(state, player.id, request, systems) then
			break
		end
	end
end
function A.materials(state, player, systems)
	local requests, targets = Materials.orders(A.knowledge(state, player), player, systems)
	if player.aiPlan then
		player.aiPlan.materialTargets = targets
	end
	for _, request in ipairs(requests) do
		if not Actions.apply(state, player.id, request, systems) then
			break
		end
	end
end
function A.choose(state, player, city, systems)
	local view = A.knowledge(state, player)
	local known = cityIn(view, city.id)
	local canExpand = Settlement.available(view, player, known, systems)
	local choices, context = Production.ranked(view, player, known, systems, canExpand)
	local currentEligible = false
	for _, choice in ipairs(choices) do
		if
			known.project
			and known.project.kind == choice.kind
			and known.project.id == choice.id
		then
			currentEligible = true
		end
	end
	if currentEligible and context.surplus >= 0 and not context.emergency then
		return true -- Complete ordinary investments before considering a replacement.
	end
	for index = 1, math.min(4, #choices) do
		local choice = choices[index]
		if
			not known.project
			or known.project.kind ~= choice.kind
			or known.project.id ~= choice.id
		then
			local ok = Actions.apply(state, player.id, {
				action = "queue",
				cityX = city.x,
				cityY = city.y,
				kind = choice.kind,
				id = choice.id,
				tileX = choice.tileX,
				tileY = choice.tileY,
			}, systems)
			if ok then
				return true
			end
		else
			return true
		end
	end
	if not currentEligible and not known.productionIdle then
		return Actions.apply(
			state,
			player.id,
			{ action = "queue", cityX = city.x, cityY = city.y, kind = "none" },
			systems
		)
	end
	return false
end
function A.settle(state, player, unit, systems)
	for _ = 1, 16 do
		if (unit.movesLeft or 0) <= 0 then
			break
		end
		local view = A.knowledge(state, player)
		local request, target = Settlement.order(view, player, unit, systems)
		unit.aiSettlement = target
		if not request then
			break
		end
		local ok = Actions.apply(state, player.id, request, systems)
		if not ok then
			break
		end
		if request.action == "found" then
			return true
		end
	end
	return false
end
function A.engineer(state, player, unit, systems)
	if unit.standby and player.techs.railways then
		Actions.apply(
			state,
			player.id,
			{ action = "standby", x = unit.x, y = unit.y, value = false },
			systems
		)
	end
	local acted = false
	for _ = 1, 16 do
		if (unit.movesLeft or 0) <= 0 then
			return acted
		end
		local view = A.knowledge(state, player)
		local request, plan = Infrastructure.order(view, player, unit, systems)
		unit.aiRail = plan
		if not request then
			break
		end
		if not Actions.apply(state, player.id, request, systems) then
			break
		end
		acted = true
		if request.action == "buildRail" then
			return true
		end
	end
	if not unit.standby then
		Actions.apply(
			state,
			player.id,
			{ action = "standby", x = unit.x, y = unit.y, value = true },
			systems
		)
	end
	return acted
end
function A.diplomacy(state, p, systems)
	local view = A.knowledge(state, p)
	if state.diplomacy and (p.aiPlan or {}).primary == "conquest" then
		local army = 0
		for _, unit in ipairs(view.units) do
			if unit.owner == p.id and ((systems.units[unit.kind] or {}).strength or 0) > 0 then
				army = army + 1
			end
		end
		if army >= 3 then
			for _, city in ipairs(view.cities) do
				if
					city.owner ~= p.id
					and not city.village
					and not Diplomacy.war(view, p.id, city.owner)
					and (p.visible or {})[city.x .. ":" .. city.y]
				then
					Actions.apply(
						state,
						p.id,
						{ action = "declareWar", target = city.owner, kind = "normal" },
						systems
					)
					break
				end
			end
		end
	end
	if (p.gold or 0) > 100 then
		for _, city in ipairs(view.cities) do
			if Villages.independent(city) and Villages.discovered(p, city) then
				Actions.apply(state, p.id, { action = "envoy", x = city.x, y = city.y }, systems)
			end
		end
	end
end
return A
