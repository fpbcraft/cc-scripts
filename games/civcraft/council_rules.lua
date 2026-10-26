-- Pure resolution queries shared by diplomacy, markets and the economy.
local Rules = {}
function Rules.effect(state, kind, target)
	for _, effect in ipairs(state.council and state.council.effects or {}) do
		if
			effect.kind == kind
			and effect.startsRound <= state.round
			and effect.endsRound > state.round
			and (target == nil or effect.target == target)
		then
			return effect
		end
	end
end
function Rules.embargoed(state, a, b)
	return Rules.effect(state, "embargo", a) ~= nil
		or b ~= nil and Rules.effect(state, "embargo", b) ~= nil
end
function Rules.peaceProtected(state, a, b)
	for _, effect in ipairs(state.council and state.council.effects or {}) do
		if
			effect.kind == "peace"
			and effect.startsRound <= state.round
			and effect.endsRound > state.round
			and (
				effect.target == a and effect.other == b
				or effect.target == b and effect.other == a
			)
		then
			return true
		end
	end
	return false
end
function Rules.exchangeCost(state)
	return Rules.effect(state, "trade") and 15 or 20
end
function Rules.commerceBonus(state)
	return Rules.effect(state, "trade") and 1 or 0
end
function Rules.reputation(state, id)
	return Rules.effect(state, "censure", id) and -20 or 0
end
function Rules.member(session, id)
	for _, member in ipairs(session and session.members or {}) do
		if member.id == id then
			return member
		end
	end
end
function Rules.alive(state, id)
	for _, city in ipairs(state.cities or {}) do
		if city.owner == id then
			return true
		end
	end
	return false
end
function Rules.eligible(state, id)
	local known = false
	for _, player in ipairs(state.players or {}) do
		if player.id == id then
			known = (player.techs or {}).commerce == true
		end
	end
	if not known then
		return false
	end
	for _, city in ipairs(state.cities or {}) do
		if city.owner == id and (city.buildings or {}).councilhall then
			return true
		end
	end
	return false
end
function Rules.canPledge(state, from, to, sessionID)
	local session = state.council and state.council.session
	if
		state.phase ~= "game"
		or not session
		or session.id ~= sessionID
		or session.status ~= "voting"
		or state.round >= session.closesRound
		or from == to
		or not Rules.member(session, from)
		or not Rules.member(session, to)
		or not Rules.alive(state, from)
		or not Rules.alive(state, to)
	then
		return false, "Council ballot is no longer available"
	end
	for _, pledge in ipairs(session.pledges or {}) do
		if pledge.from == from then
			return false, "This civilization already pledged its ballot"
		end
	end
	return true
end
function Rules.pledge(state, from, to, sessionID)
	local ok, reason = Rules.canPledge(state, from, to, sessionID)
	if not ok then
		return false, reason
	end
	local session = state.council.session
	for _, pledge in ipairs(session.pledges) do
		if pledge.from == from then
			return false, "This civilization already pledged its ballot"
		end
	end
	session.pledges[#session.pledges + 1] = { from = from, to = to }
	return true
end
return Rules
