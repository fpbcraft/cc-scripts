local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Diplomacy = {}
local function registered(state, id)
	for _, player in ipairs(state.players or {}) do
		if player.id == id then
			return true
		end
	end
	return false
end

function Diplomacy.new()
	return { version = 1, wars = {}, reputation = {}, relations = {} }
end

function Diplomacy.migrate(state)
	if state.phase ~= "game" and state.phase ~= "over" then
		return
	end
	if not state.diplomacy then
		state.diplomacy = Diplomacy.new()
		state.diplomacy.importedLegacy = true
		-- Older campaigns allowed every civilization to attack every other one.
		-- Import that existing hostility without changing positions or budgets.
		for index, a in ipairs(state.players) do
			for other = index + 1, #state.players do
				state.diplomacy.wars[#state.diplomacy.wars + 1] = {
					a = a.id,
					b = state.players[other].id,
					active = true,
					kind = "legacy",
					declaredRound = state.round,
					activatesRound = state.round,
				}
			end
		end
	end
	assert(state.diplomacy.version == 1, "Unsupported diplomacy version")
	if not state.scheduler then
		Scheduler.rebuild(
			state,
			state.diplomacy.wars,
			(state.players[state.activeIndex or 1] or {}).id
		)
	end
	assert(state.scheduler.version == 1, "Unsupported turn scheduler version")
end

function Diplomacy.war(state, a, b)
	for _, war in ipairs(state.diplomacy and state.diplomacy.wars or {}) do
		if war.a == a and war.b == b or war.a == b and war.b == a then
			return war
		end
	end
end

function Diplomacy.canAttack(state, a, b)
	if a == b or a == nil or b == nil then
		return false
	end
	if not registered(state, a) or not registered(state, b) then
		return true
	end
	-- Saves from before formal diplomacy retain their existing combat rules.
	if not state.diplomacy then
		return true
	end
	local war = Diplomacy.war(state, a, b)
	return war ~= nil and war.active == true
end

function Diplomacy.declare(state, attacker, defender, kind)
	if state.phase ~= "game" then
		return false, "Game not running"
	end
	if
		not registered(state, attacker)
		or not registered(state, defender)
		or attacker == defender
	then
		return false, "Select another civilization"
	end
	local allowed, reason = Scheduler.canAct(state, attacker)
	if not allowed then
		return false, reason
	end
	if kind ~= "normal" and kind ~= "surprise" then
		return false, "Choose normal or surprise war"
	end
	if not state.diplomacy then
		return false, "Legacy campaign already permits hostile actions"
	end
	if Diplomacy.war(state, attacker, defender) then
		return false, "War already active or announced"
	end
	local war = {
		a = attacker,
		b = defender,
		kind = kind,
		declaredRound = state.round,
		active = kind == "surprise",
		activatesRound = kind == "normal" and state.round + 1 or state.round,
	}
	state.diplomacy.wars[#state.diplomacy.wars + 1] = war
	if kind == "surprise" then
		local diplomacy = state.diplomacy
		diplomacy.reputation[attacker] = (diplomacy.reputation[attacker] or 0) - 50
		for _, observer in ipairs(state.players) do
			if observer.id ~= attacker then
				local key = tostring(observer.id) .. ":" .. tostring(attacker)
				local relation = diplomacy.relations[key] or { trust = 0, grievances = 0 }
				relation.trust = relation.trust - (observer.id == defender and 75 or 25)
				relation.grievances = relation.grievances + (observer.id == defender and 80 or 20)
				diplomacy.relations[key] = relation
			end
		end
		Scheduler.rebuild(state, diplomacy.wars, attacker, defender)
	end
	for _, player in ipairs(state.players) do
		if player.id == attacker or player.id == defender then
			player.strategySignal = "newWar"
		end
	end
	return true,
		kind == "surprise" and "Surprise War started immediately" or "War announced for next round"
end

function Diplomacy.boundary(state)
	if not state.diplomacy then
		return
	end
	for index = #state.diplomacy.wars, 1, -1 do
		local war = state.diplomacy.wars[index]
		if war.endsRound and war.endsRound <= state.round then
			table.remove(state.diplomacy.wars, index)
		elseif war.activatesRound <= state.round then
			if not war.active then
				for _, player in ipairs(state.players) do
					if player.id == war.a or player.id == war.b then
						player.strategySignal = "newWar"
					end
				end
			end
			war.active = true
		end
	end
	Scheduler.beginRound(state, state.diplomacy.wars)
end

function Diplomacy.public(state)
	if not state.diplomacy then
		return nil
	end
	local result = Diplomacy.new()
	result.importedLegacy = state.diplomacy.importedLegacy
	for _, war in ipairs(state.diplomacy.wars) do
		local copy = {}
		for key, value in pairs(war) do
			copy[key] = value
		end
		result.wars[#result.wars + 1] = copy
	end
	for id, value in pairs(state.diplomacy.reputation) do
		result.reputation[id] = value
	end
	return result
end

return Diplomacy
