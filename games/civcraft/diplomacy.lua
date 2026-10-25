local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Perception = dofile("/games/civcraft/diplomatic_perception.lua")
local Diplomacy = {}
local function cityCount(state, id)
	local count = 0
	for _, city in ipairs(state.cities or {}) do
		if city.owner == id then
			count = count + 1
		end
	end
	return count
end
local function registered(state, id)
	for _, player in ipairs(state.players or {}) do
		if player.id == id then
			return true
		end
	end
	return false
end

function Diplomacy.new()
	return {
		version = 1,
		wars = {},
		reputation = {},
		relations = {},
		offers = {},
		treaties = {},
		pairCounters = {},
		armistices = {},
		promises = {},
	}
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
	Offers.ensure(state)
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
	if kind == "normal" then
		if
			Offers.treaty(state, attacker, defender, "alliance")
			or Offers.treaty(state, attacker, defender, "defensivePact")
		then
			return false, "End the alliance or defensive pact before announcing war"
		end
		for _, armistice in ipairs(state.diplomacy.armistices or {}) do
			if
				(
					armistice.a == attacker and armistice.b == defender
					or armistice.a == defender and armistice.b == attacker
				) and armistice.endsRound > state.round
			then
				return false, "The armistice still protects this civilization"
			end
		end
	end
	local war = {
		a = attacker,
		b = defender,
		kind = kind,
		declaredRound = state.round,
		active = kind == "surprise",
		activatesRound = kind == "normal" and state.round + 1 or state.round,
		initialCities = {
			[attacker] = cityCount(state, attacker),
			[defender] = cityCount(state, defender),
		},
	}
	state.diplomacy.wars[#state.diplomacy.wars + 1] = war
	if kind == "surprise" then
		local diplomacy = state.diplomacy
		diplomacy.reputation[attacker] = (diplomacy.reputation[attacker] or 0) - 50
		for _, observer in ipairs(state.players) do
			if observer.id ~= attacker then
				local profile = Personalities.forCivilization(observer.civ)
				local penalty =
					math.floor(25 * (0.5 + profile.loyalty / 200 + profile.diplomacy / 200))
				Memory.add(
					state,
					observer.id,
					attacker,
					"surpriseWar",
					observer.id == defender and -75 or -penalty,
					observer.id == defender and 80 or 20,
					nil,
					"Declared a Surprise War"
				)
			end
		end
		for _, treaty in ipairs(diplomacy.treaties or {}) do
			if
				treaty.status == "active"
				and (
					treaty.a == attacker and treaty.b == defender
					or treaty.a == defender and treaty.b == attacker
				)
			then
				treaty.status = "broken"
				Memory.add(
					state,
					defender,
					attacker,
					"treatyBetrayal",
					-40,
					40,
					nil,
					"Broke an active agreement by declaring war"
				)
			end
		end
		for _, armistice in ipairs(diplomacy.armistices or {}) do
			if
				(
					armistice.a == attacker and armistice.b == defender
					or armistice.a == defender and armistice.b == attacker
				) and armistice.endsRound > state.round
			then
				armistice.endsRound = state.round
				armistice.status = "broken"
				Memory.add(
					state,
					defender,
					attacker,
					"armisticeBetrayal",
					-50,
					50,
					nil,
					"Broke an armistice with Surprise War"
				)
			end
		end
		Offers.callAllies(state, war)
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
	Offers.advance(state)
	local ending = {}
	for _, war in ipairs(state.diplomacy.wars) do
		if war.endsRound and war.endsRound <= state.round then
			ending[Memory.key(war.a, war.b)], ending[Memory.key(war.b, war.a)] = true, true
		end
	end
	for index = #state.diplomacy.wars, 1, -1 do
		local war = state.diplomacy.wars[index]
		if not war.active and war.supporting then
			local origin = Diplomacy.war(state, war.supporting.defender, war.b)
			if not origin or origin.endsRound and origin.endsRound <= state.round then
				for _, treaty in ipairs(state.diplomacy.treaties) do
					if treaty.id == war.supporting.offerID then
						treaty.status = "cancelled"
					end
				end
				local offer = Offers.find(state, war.supporting.offerID)
				if offer then
					offer.status, offer.reason =
						"cancelled", "The original war ended before intervention began"
				end
				table.remove(state.diplomacy.wars, index)
			end
		end
	end
	for index = #state.diplomacy.wars, 1, -1 do
		local war = state.diplomacy.wars[index]
		if war.endsRound and war.endsRound <= state.round then
			for _, treaty in ipairs(state.diplomacy.treaties) do
				local enemy = treaty.terms and treaty.terms.enemy
				local withdrawing = enemy == war.a and war.b or enemy == war.b and war.a
				if
					treaty.kind == "jointWar"
					and treaty.status == "active"
					and withdrawing
					and (treaty.a == withdrawing or treaty.b == withdrawing)
					and treaty.endsRound > state.round
				then
					local partner = treaty.a == withdrawing and treaty.b or treaty.a
					if ending[Memory.key(partner, enemy)] then
						treaty.status = "completed"
					else
						treaty.status = "broken"
						Memory.add(
							state,
							partner,
							withdrawing,
							"jointWarBroken",
							-20,
							15,
							30,
							"Made a separate peace before a joint-war commitment expired"
						)
					end
				end
			end
			Memory.add(state, war.a, war.b, "previousWar", -10, 10, 30, "Previously fought a war")
			Memory.add(state, war.b, war.a, "previousWar", -10, 10, 30, "Previously fought a war")
			table.remove(state.diplomacy.wars, index)
		elseif war.activatesRound <= state.round then
			if not war.active then
				for _, treaty in ipairs(state.diplomacy.treaties) do
					if
						treaty.status == "active"
						and (
							treaty.a == war.a and treaty.b == war.b
							or treaty.a == war.b and treaty.b == war.a
						)
					then
						treaty.status, treaty.endsRound = "broken", state.round
						Memory.add(
							state,
							war.b,
							war.a,
							"agreementEndedByWar",
							-10,
							10,
							30,
							"Ended a standing agreement by starting a war"
						)
					end
				end
				Offers.callAllies(state, war)
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

function Diplomacy.join(state, ally, enemy, supporting)
	if not registered(state, ally) or not registered(state, enemy) or ally == enemy then
		return false, "Invalid war participants"
	end
	if Diplomacy.war(state, ally, enemy) then
		return true
	end
	if
		Offers.treaty(state, ally, enemy, "alliance")
		or Offers.treaty(state, ally, enemy, "defensivePact")
	then
		return false, "End the conflicting alliance before accepting this intervention"
	end
	state.diplomacy.wars[#state.diplomacy.wars + 1] = {
		a = ally,
		b = enemy,
		kind = "intervention",
		declaredRound = state.round,
		activatesRound = state.round + 1,
		active = false,
		supporting = supporting,
		initialCities = { [ally] = cityCount(state, ally), [enemy] = cityCount(state, enemy) },
	}
	return true
end

function Diplomacy.talk(state, actor, target, topic)
	local topics = {
		greeting = { 2, 0, 5, "Exchanged a friendly greeting" },
		apologize = { 5, -5, 10, "Apologized for strained relations; lasting breaches remain" },
		warning = { -3, 0, 5, "Warned about tension along the border" },
		denounce = { -15, 15, 20, "Publicly denounced this civilization" },
	}
	local choice = topics[topic]
	if
		not choice
		or actor == target
		or not registered(state, actor)
		or not registered(state, target)
	then
		return false, "Choose a civilization and a conversation topic"
	end
	local relation = Memory.relation(state, target, actor)
	relation.lastTalk = relation.lastTalk or {}
	if (relation.lastTalk[topic] or -100) + choice[3] > state.round then
		return false, "Give this conversation time to have an effect"
	end
	relation.lastTalk[topic] = state.round
	Memory.add(state, target, actor, topic, choice[1], choice[2], choice[3], choice[4])
	if topic == "denounce" then
		state.diplomacy.reputation[target] = (state.diplomacy.reputation[target] or 0) - 10
	end
	return true, choice[4]
end

function Diplomacy.cancelTreaty(state, actor, id)
	for _, treaty in ipairs(state.diplomacy.treaties or {}) do
		if
			treaty.id == id
			and (treaty.a == actor or treaty.b == actor)
			and treaty.status == "active"
		then
			local other = treaty.a == actor and treaty.b or treaty.a
			treaty.status, treaty.endsRound = "broken", state.round
			local pact = treaty.kind == "alliance" or treaty.kind == "defensivePact"
			Memory.add(
				state,
				other,
				actor,
				"agreementBroken",
				pact and -25 or -15,
				pact and 20 or 10,
				30,
				"Ended a " .. Offers.label(treaty.kind):lower() .. " agreement before its expiry"
			)
			if pact then
				state.diplomacy.reputation[actor] = (state.diplomacy.reputation[actor] or 0) - 10
			end
			for _, participant in ipairs(state.players) do
				if participant.id == actor or participant.id == other then
					participant.strategySignal = "brokenAlliance"
				end
			end
			return true, "Agreement ended; its trust consequences are recorded", other
		end
	end
	return false, "Select one of your active agreements"
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

function Diplomacy.public(state, observer, hex, units)
	if not state.diplomacy then
		return nil
	end
	local result = Diplomacy.new()
	result.importedLegacy = state.diplomacy.importedLegacy
	for _, war in ipairs(state.diplomacy.wars) do
		local copy = {}
		for _, key in ipairs({
			"a",
			"b",
			"active",
			"kind",
			"declaredRound",
			"activatesRound",
			"endsRound",
		}) do
			copy[key] = war[key]
		end
		copy.ownInitialCities = war.initialCities and war.initialCities[observer]
		result.wars[#result.wars + 1] = copy
	end
	for id, value in pairs(state.diplomacy.reputation) do
		result.reputation[id] = value
	end
	if observer ~= nil then
		for key, relation in pairs(state.diplomacy.relations) do
			local a, b = key:match("^(-?%d+):(-?%d+)$")
			if tonumber(a) == observer or tonumber(b) == observer then
				result.relations[key] = copy(relation)
			end
		end
		if hex and units then
			for _, subject in ipairs(state.players) do
				if subject.id ~= observer then
					local key = Memory.key(observer, subject.id)
					result.relations[key] = result.relations[key]
						or { trust = 0, grievances = 0, memories = {} }
					result.relations[key].pressure =
						Perception.pressure(state, observer, subject.id, hex, units)
				end
			end
		end
		for _, offer in ipairs(state.diplomacy.offers or {}) do
			if offer.from == observer or offer.to == observer then
				result.offers[#result.offers + 1] = copy(offer)
			end
		end
		for _, field in ipairs({ "treaties", "armistices", "promises" }) do
			for _, record in ipairs(state.diplomacy[field] or {}) do
				if
					record.a == observer
					or record.b == observer
					or record.by == observer
					or record.to == observer
				then
					result[field][#result[field] + 1] = copy(record)
				end
			end
		end
	end
	return result
end

function Diplomacy.state(state, a, b)
	local war = Diplomacy.war(state, a, b)
	if war then
		return war.active and "WAR" or "TENSION"
	end
	for _, armistice in ipairs(state.diplomacy and state.diplomacy.armistices or {}) do
		if
			(armistice.a == a and armistice.b == b or armistice.a == b and armistice.b == a)
			and armistice.startsRound <= state.round
			and armistice.endsRound > state.round
		then
			return "ARMISTICE"
		end
	end
	local relation = state.diplomacy and state.diplomacy.relations[Memory.key(a, b)]
	local other = state.diplomacy and state.diplomacy.relations[Memory.key(b, a)]
	for _, opinion in pairs({ relation, other }) do
		if opinion.trust < -20 or opinion.grievances >= 20 or (opinion.pressure or 0) > 0 then
			return "TENSION"
		end
	end
	return "PEACE"
end

return Diplomacy
