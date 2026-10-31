local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Founding = dofile("/games/civcraft/founding.lua")
-- Host-authoritative gameplay orders shared by humans, remote players and AI.
-- Session orchestration (lobby, save, end turn) belongs to game.lua.
local Combat = dofile("/games/civcraft/combat.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Events = dofile("/games/civcraft/events.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Hostiles = dofile("/games/civcraft/hostiles.lua")
local Rails = dofile("/games/civcraft/railways.lua")
local UnitMovement = dofile("/games/civcraft/unit_movement.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local World = dofile("/games/civcraft/world.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Zone = dofile("/games/civcraft/zone_control.lua")
local TurnTasks = dofile("/games/civcraft/turn_tasks.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Queue = dofile("/games/civcraft/queued_routes.lua")
local Council = dofile("/games/civcraft/council.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local WorkQueue = dofile("/games/civcraft/queued_work.lua")
local A = {}

function A.validateIntent(state, request)
	if request.campaignID ~= nil and request.campaignID ~= state.campaignID then
		return false, "Campaign changed; refresh before ordering"
	end
	if request.round ~= nil and request.round ~= state.round then
		return false, "Round changed; refresh before ordering"
	end
	return true
end

local function apply(state, id, req, Systems)
	if type(req) ~= "table" then
		return false, "Invalid order"
	end
	local p
	for _, candidate in ipairs(state.players or {}) do
		if candidate.id == id then
			p = candidate
		end
	end
	if not p then
		return false, "You are not registered"
	end
	if state.phase ~= "game" then
		return false, "Game not running"
	end
	local current, reason = A.validateIntent(state, req)
	if not current then
		return false, reason
	end
	local eligible, waiting = Scheduler.canAct(state, id)
	if
		not eligible
		and req.action ~= "diplomaticReply"
		and req.action ~= "diplomaticCounter"
		and req.action ~= "councilVote"
		and req.action ~= "councilPropose"
	then
		return false, waiting
	end
	if req.action == "councilVote" then
		return Council.vote(state, id, req)
	end
	if req.action == "councilPropose" then
		return Council.propose(state, id, req)
	end
	local outcome
	local function at(list, x, y)
		for _, item in ipairs(list or {}) do
			if item.x == x and item.y == y then
				return item
			end
		end
	end
	local function cityAt(x, y)
		return at(state.cities, x, y)
	end
	local function unitAt(x, y)
		return Stacks.at(state.units, x, y, req.unitID)
	end
	local function terrain(x, y)
		return Hex.terrain(x, y, state)
	end
	local function log(message)
		state.logs = state.logs or {}
		table.insert(state.logs, 1, message)
		while #state.logs > 5 do
			table.remove(state.logs)
		end
	end
	if req.action == "diplomaticOffer" then
		local ok, why, offer = Offers.propose(state, id, req, Systems, Diplomacy)
		if ok then
			Events.notice(state, "order", nil, "Offered " .. Offers.label(offer.kind), id)
			Events.notice(
				state,
				"order",
				nil,
				(p.name or tostring(id)) .. " offered " .. Offers.label(offer.kind),
				offer.to
			)
		end
		return ok, why
	elseif req.action == "diplomaticReply" then
		local offer = Offers.find(state, req.offerID)
		local ok, why = Offers.respond(state, id, req, Systems, Diplomacy)
		if ok then
			Events.notice(state, "order", nil, why, id)
			Events.notice(state, "order", nil, (p.name or tostring(id)) .. ": " .. why, offer.from)
		end
		return ok, why
	elseif req.action == "diplomaticCounter" then
		local ok, why, offer = Offers.counter(state, id, req, Systems, Diplomacy)
		if ok then
			Events.notice(state, "order", nil, "Counteroffer sent", id)
			Events.notice(
				state,
				"order",
				nil,
				"Counteroffer received from " .. (p.name or tostring(id)),
				offer.to
			)
		end
		return ok, why
	elseif req.action == "diplomaticTalk" then
		if not state.diplomacy then
			return false, "Diplomacy is unavailable"
		end
		local ok, why = Diplomacy.talk(state, id, req.target, req.topic)
		if ok then
			for _, observer in ipairs(state.players) do
				if req.topic == "denounce" or observer.id == id or observer.id == req.target then
					Events.notice(
						state,
						"order",
						nil,
						(p.name or tostring(id)) .. ": " .. why,
						observer.id
					)
				end
			end
		end
		return ok, why
	elseif req.action == "cancelTreaty" then
		if not state.diplomacy then
			return false, "Diplomacy is unavailable"
		end
		local ok, why, other = Diplomacy.cancelTreaty(state, id, req.treatyID)
		if ok then
			Events.notice(state, "order", nil, why, id)
			Events.notice(state, "order", nil, why, other)
		end
		return ok, why
	elseif req.action == "declareWar" then
		local ok, why = Diplomacy.declare(state, id, req.target, req.kind)
		if ok then
			log((p.name or tostring(id)) .. ": " .. why)
			for _, observer in ipairs(state.players) do
				Events.notice(state, "order", nil, why, observer.id)
			end
		end
		return ok, why
	elseif req.action == "exchange" then
		local ok, why = Systems.exchange(state, p, req.resource)
		if ok then
			Events.notice(state, "order", nil, req.action, id)
		end
		return ok, why
	end
	if
		req.action == "placeSite"
		or req.action == "redevelopSite"
		or req.action == "resumeSite"
		or req.action == "cancelSite"
	then
		local city
		for _, candidate in ipairs(state.cities or {}) do
			if candidate.id == req.city then
				city = candidate
			end
		end
		if not city or city.owner ~= id then
			return false, "Select an owned city"
		end
		local ok, why = Sites.request(state, p, city, req)
		if ok then
			Events.notice(state, "order", city, why, id)
		end
		return ok, why
	end
	if
		req.action == "assign"
		or req.action == "workTile"
		or req.action == "build"
		or req.action == "recruit"
		or req.action == "researchTech"
		or req.action == "queue"
	then
		local ok, why, orderedCity
		if req.action == "researchTech" then
			ok, why = Systems.research(p, req.id)
		else
			local cx, cy = tonumber(req.cityX or req.x), tonumber(req.cityY or req.y)
			local c = cx and cy and cityAt(cx, cy)
			if not c or c.owner ~= id then
				return false, "Select an owned city"
			end
			orderedCity = c
			if req.action == "workTile" then
				ok, why = Systems.workTile(state, c, tonumber(req.x), tonumber(req.y))
			elseif req.action == "assign" then
				ok, why = Systems.assign(c, req.from, req.to, state)
			elseif req.action == "queue" then
				ok, why = Systems.queue(
					p,
					c,
					req.kind,
					req.id,
					state,
					Hex,
					tonumber(req.tileX),
					tonumber(req.tileY)
				)
			elseif req.action == "build" then
				ok, why = Systems.build(p, c, req.id, state, Hex)
			elseif req.action == "recruit" then
				ok, why = Systems.queue(p, c, "unit", req.id, state, Hex)
			end
		end
		if ok then
			local detail = req.action
			if req.action == "researchTech" then
				detail = "Research selected: " .. Systems.label("tech", req.id)
			elseif req.action == "queue" then
				local project = orderedCity.project
				detail = "Production selected: "
					.. (project and Systems.label(project.kind, project.id) or "No production")
			end
			Events.notice(state, "order", orderedCity, detail, id)
		end
		return ok, why
	end
	local x, y = tonumber(req.x), tonumber(req.y)
	if not x or not y or x % 1 ~= 0 or y % 1 ~= 0 or not Hex.inBounds(x, y, state) then
		return false, "Select a tile"
	end
	local c, u = cityAt(x, y), unitAt(x, y)
	if req.action == "research" or req.action == "warrior" or req.action == "settler" then
		return false, "Use research and city production projects"
	elseif
		req.action == "improve"
		or req.action == "queueWork"
		or req.action == "cancelWork"
		or req.action == "resumeWork"
		or req.action == "autoWork"
	then
		if not u or u.owner ~= id or u.kind ~= "builder" then
			return false, "Select an owned Builder"
		end
		if req.action == "improve" then
			local ok, why, result = Works.complete(state, p, u, req.kind, Systems)
			if ok then
				Events.notice(state, "order", u, why, id)
				World.reveal(state, Hex, Systems)
			end
			return ok, why, result
		elseif req.action == "cancelWork" then
			u.workQueue = nil
			return true, "Builder work cancelled"
		elseif req.action == "autoWork" then
			if req.value == true or req.value == "resume" then
				if not ContentRules.hasBuilders(state) then
					return false, "Builder auto work is unavailable in this campaign"
				end
				if (u.charges or 0) <= 0 then
					return false, "No Builder charges remain"
				end
				u.autoWork = true
				u.autoWorkPaused = nil
				if u.workQueue and u.workQueue.auto then
					u.workQueue.paused = nil
					WorkQueue.run(state, id, Systems, A.apply, u)
				else
					u.autoWorkScanStamp = nil
					WorkQueue.planAuto(state, id, Systems, A.apply)
				end
				return true, u.autoWorkPaused and "Auto work paused" or "Auto work enabled"
			end
			if req.value == "pause" then
				u.autoWork = true
				u.autoWorkPaused = "Paused by player"
				if u.workQueue and u.workQueue.auto then
					u.workQueue = nil
				end
				return true, "Auto work paused"
			end
			u.autoWork = false
			u.autoWorkPaused = nil
			if u.workQueue and u.workQueue.auto then
				u.workQueue = nil
			end
			return true, "Auto work stopped"
		elseif req.action == "resumeWork" then
			if not u.workQueue then
				return false, "No saved Builder work"
			end
			u.workQueue.paused = nil
			if u.workQueue.auto then
				u.autoWorkPaused = nil
			end
			u.skippedTurn = nil
			WorkQueue.run(state, id, Systems, A.apply, u)
			return true, "Builder work resumed"
		end
		local ok, why, result = WorkQueue.submit(
			state,
			p,
			u,
			req.kind,
			tonumber(req.tileX),
			tonumber(req.tileY),
			req.append == true,
			Systems,
			u.autoWorkPlanning == true
		)
		if ok then
			WorkQueue.run(state, id, Systems, A.apply, u)
		end
		return ok, why, result
	elseif req.action == "attachEscort" or req.action == "detachEscort" then
		if not u or u.owner ~= id then
			return false, "Select an owned unit"
		end
		local other = req.action == "attachEscort" and Stacks.byID(state, req.partnerID)
			or Stacks.partner(state, u)
		if req.action == "attachEscort" then
			local ok, reason = Stacks.link(state, u, other, Systems)
			if not ok then
				return false, reason
			end
		else
			Stacks.unlink(state, u)
		end
		for _, member in ipairs({ u, other }) do
			member.standby, member.healing, member.autoExplore, member.skippedTurn =
				false, false, false, nil
		end
		Events.notice(
			state,
			"order",
			nil,
			req.action == "attachEscort" and "Escort attached" or "Escort detached",
			id
		)
		return true
	elseif req.action == "skipTurn" then
		if not u or u.owner ~= id or req.unitID and req.unitID ~= u.id then
			return false, "Select an owned unit"
		end
		for _, member in ipairs({ u, Stacks.partner(state, u) }) do
			member.skippedTurn = TurnTasks.stamp(state, id)
			member.standby, member.healing, member.autoExplore = false, false, false
		end
		Events.notice(state, "order", u, "Skipped unit for this turn", id)
		return true
	elseif req.action == "standby" then
		if not u or u.owner ~= id then
			return false, "Select an owned unit"
		end
		for _, member in ipairs({ u, Stacks.partner(state, u) }) do
			member.skippedTurn = nil
			member.standby = req.value == true
			if not member.standby then
				member.healing = false
			end
			if member.standby then
				member.autoExplore = false
			end
		end
		Events.notice(state, "order", u, req.action, id)
		return true
	elseif req.action == "autoExplore" then
		if not u or u.owner ~= id then
			return false, "Select an owned scout"
		end
		if req.value == false then
			for _, member in ipairs({ u, Stacks.partner(state, u) }) do
				member.autoExplore, member.standby, member.healing, member.skippedTurn =
					false, false, false, nil
			end
			Events.notice(state, "order", u, req.action, id)
			return true
		end
		local ok, why = Systems.autoExplore(state, u, Hex)
		if ok then
			u.skippedTurn = nil
			Events.notice(state, "order", u, req.action, id)
		end
		return ok, why
	elseif req.action == "cancelRoute" then
		if not u or u.owner ~= id then
			return false, "Select an owned unit"
		end
		Queue.cancel(state, u)
		for _, member in ipairs({ u, Stacks.partner(state, u) }) do
			member.autoExplore, member.standby, member.healing, member.skippedTurn =
				false, false, false, nil
		end
		Events.notice(state, "order", u, "Movement route cancelled", id)
		return true
	elseif req.action == "queueMove" then
		local moving = Stacks.at(state.units, tonumber(req.sx), tonumber(req.sy), req.unitID)
		if not moving or moving.owner ~= id then
			return false, "Select an owned unit"
		end
		local ok, why = Queue.submit(state, moving, x, y, req.append == true, Systems)
		if ok then
			local _, leader = Queue.get(state, moving)
			Queue.run(state, id, Systems, A.apply, leader)
		end
		return ok, why
	elseif req.action == "move" then
		local sx, sy = tonumber(req.sx), tonumber(req.sy)
		local moving = sx and sy and unitAt(sx, sy)
		if
			not moving
			or moving.owner ~= id
			or (moving.movesLeft or (moving.moved and 0 or 1)) <= 0
		then
			return false, "Unit cannot move"
		end
		local legal
		for _, dest in ipairs(Hex.reachable(state, moving, id, Systems)) do
			if dest.x == x and dest.y == y then
				legal = dest
				break
			end
		end
		if not legal then
			return false, "Destination out of range or blocked"
		end
		if legal.attack then
			local prediction, reason = Combat.predictOrder(state, moving, legal, Systems)
			if not prediction then
				return false, reason
			end
		end
		local asleep, healing = moving.standby, moving.healing
		moving.standby = false
		moving.healing = false
		if legal.attack then
			local ok, why, result = Combat.attack(state, moving, legal, Systems)
			if not ok then
				moving.standby = asleep
				moving.healing = healing
				return false, why
			end
			log((p.name or tostring(id)) .. ": " .. why)
			if result and result.interrupted then
				outcome = why
			end
			local cost = result and result.interrupted and result.spent or legal.cost
			moving.movesLeft = legal.ranged and 0
				or math.max(0, (moving.movesLeft or Systems.units[moving.kind].move) - cost)
		else
			local spent, completed, reason = UnitMovement.walk(state, moving, legal.path, Systems)
			if spent == 0 and not completed then
				moving.standby, moving.healing = asleep, healing
				return false, reason
			end
			if not completed then
				outcome = reason
				log(reason)
			end
			moving.movesLeft =
				math.max(0, (moving.movesLeft or Systems.units[moving.kind].move) - spent)
			moving.actedThisRound = true
			moving.healing = false
			moving.autoExplore = false
		end
		moving.standby = false
		moving.healing = false
		moving.skippedTurn = nil
		if Zone.locked(state, moving, Systems) and Zone.civilian(moving, Systems) then
			moving.movesLeft = 0
		end
		moving.moved = moving.movesLeft <= 0
	elseif req.action == "disband" then
		if not u or u.owner ~= id or (req.unitID and req.unitID ~= u.id) then
			return false, "Select an owned unit"
		end
		Stacks.unlink(state, u)
		for i = #state.units, 1, -1 do
			if state.units[i] == u then
				table.remove(state.units, i)
				break
			end
		end
		Events.notice(state, "disband", u)
	elseif req.action == "buildRail" then
		local moving = unitAt(tonumber(req.sx), tonumber(req.sy))
		local asleep = moving and moving.standby
		if moving then
			moving.standby = false
		end
		local ok, why = Rails.build(state, p, moving, x, y, Systems)
		if not ok then
			if moving then
				moving.standby = asleep
			end
			return false, why
		end
		moving.healing = false
		moving.skippedTurn = nil
		Events.notice(state, "rail", { x = x, y = y, owner = id }, "rail")
	elseif req.action == "envoy" then
		local ok, why = Villages.envoy(state, p, c)
		if not ok then
			return false, why
		end
	elseif req.action == "heal" then
		if not u or u.owner ~= id then
			return false, "Select an owned unit"
		end
		for _, member in ipairs({ u, Stacks.partner(state, u) }) do
			member.skippedTurn, member.standby, member.autoExplore = nil, true, false
		end
		u.healing = true
		u.movesLeft = 0
		u.moved = true
	elseif req.action == "cityStrike" then
		if not c or c.owner ~= id then
			return false, "Select an owned city"
		end
		local tx, ty = tonumber(req.tx), tonumber(req.ty)
		if not tx or not ty or tx % 1 ~= 0 or ty % 1 ~= 0 or not Hex.inBounds(tx, ty, state) then
			return false, "Select a target tile"
		end
		local ok, why = Combat.strike(state, c, tx, ty, Systems)
		if not ok then
			return false, why
		end
		log(why)
	elseif req.action == "found" then
		if not u or u.owner ~= id or u.kind ~= "settler" then
			return false, "Choose a settler"
		end
		if (u.movesLeft or (u.moved and 0 or Systems.units.settler.move)) <= 0 then
			return false, "Settler needs movement remaining"
		end
		local legal, why = Founding.canFound(state, id, x, y, Systems, u)
		if not legal then
			return false, why
		end
		Stacks.unlink(state, u)
		for i, v in ipairs(state.units) do
			if v == u then
				table.remove(state.units, i)
				break
			end
		end
		table.insert(state.cities, {
			id = state.nextId,
			x = x,
			y = y,
			owner = id,
			level = 1,
			population = 2,
			foodStore = 0,
			jobs = { food = 1, wood = 1, science = 0 },
			buildings = {},
		})
		local plot = World.key(x, y)
		if state.world.improvements and state.world.improvements[plot] then
			state.world.improvements[plot] = nil
			state.improvementRevision = (state.improvementRevision or 0) + 1
		end
		local founded = state.cities[#state.cities]
		if ContentRules.startsWithSettler(state) and not p.capitalFounded then
			founded.capitalOf = p.id
			p.capitalFounded = true
			Council.afterFounding(state)
		end
		if ContentRules.startsWithSettler(state) then
			Combat.city(founded)
		end
		Systems.nameCity(state, founded)
		state.nextId = state.nextId + 1
		World.ensureTerritories(state, Hex, false)
		log(p.name .. " founded " .. founded.name)
		Events.notice(state, "found", founded)
		Perception.settlement(state, founded, Hex)
	else
		return false, "Unknown action"
	end
	if req.action == "heal" or req.action == "envoy" then
		Events.notice(state, "order", nil, req.action, id)
	end
	Hostiles.clear(state, Systems)
	World.reveal(state, Hex, Systems)
	return true, outcome
end
local replacesRoute = {
	improve = true,
	move = true,
	skipTurn = true,
	standby = true,
	heal = true,
	autoExplore = true,
	buildRail = true,
	envoy = true,
	found = true,
	disband = true,
	attachEscort = true,
	detachEscort = true,
}
function A.apply(state, id, request, systems)
	local unit = type(request) == "table" and Stacks.byID(state, request.unitID)
	if not unit and type(request) == "table" and replacesRoute[request.action] then
		unit = Stacks.at(
			state.units,
			tonumber(request.sx or request.x),
			tonumber(request.sy or request.y)
		)
	end
	if not unit and type(request) == "table" and request.action == "queueMove" then
		unit = Stacks.at(state.units, tonumber(request.sx), tonumber(request.sy), request.unitID)
	end
	local ok, why, result = apply(state, id, request, systems)
	if ok and unit and request.action == "queueMove" then
		unit.workQueue = nil
		unit.autoWork, unit.autoWorkPaused = false, nil
	end
	if ok and unit and request.action == "queueWork" and not unit.autoWorkPlanning then
		unit.autoWork, unit.autoWorkPaused = false, nil
		if unit.workQueue then
			unit.workQueue.auto = false
		end
	end
	if ok and unit and replacesRoute[request.action] and not unit.executingQueue then
		Queue.cancel(state, unit)
		if not unit.executingWork and request.action ~= "skipTurn" then
			unit.workQueue = nil
			unit.autoWork, unit.autoWorkPaused = false, nil
			local partner = Stacks.partner(state, unit)
			if partner then
				partner.workQueue = nil
			end
		end
	end
	return ok, why, result
end
return A
