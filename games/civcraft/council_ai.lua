-- Vote utilities consume a private observer projection, never rival ballots or stockpiles.
local Council = dofile("/games/civcraft/council.lua")
local Rules = dofile("/games/civcraft/council_rules.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Profiles = dofile("/games/civcraft/ai_personalities.lua")
local AI = {}
local function war(view, a, b)
	for _, conflict in ipairs(view.diplomacy and view.diplomacy.wars or {}) do
		if conflict.a == a and conflict.b == b or conflict.a == b and conflict.b == a then
			return true
		end
	end
	return false
end
local function relation(view, a, b)
	return (view.diplomacy and view.diplomacy.relations or {})[Memory.key(a, b)] or {}
end
function AI.election(view, player)
	assert(view.observerID == player.id, "Council AI needs its own observations")
	local session = view.council and view.council.session
	if not session then
		return false, "No election is open"
	end
	for _, pledge in ipairs(session.pledges or {}) do
		local promised = Rules.member(session, pledge.to)
		if
			pledge.from == player.id
			and promised
			and promised.alive ~= false
			and not war(view, player.id, pledge.to)
		then
			return pledge.to, "Honoring our Council voting pledge"
		end
	end
	local profile = Profiles.forCivilization(player.civ)
	local best, score, reason = false, -math.huge, "Abstaining: no suitable living candidate"
	for _, member in ipairs(session.members) do
		if
			member.alive ~= false
			and (member.id == player.id or Contacts.knows(view, player.id, member.id))
		then
			local value, explanation
			if member.id == player.id then
				value = 30 + profile.ambition * 0.25 + (member.eligible and 25 or 0)
				explanation = "Protecting our own leadership prospects"
			else
				local attitude = relation(view, player.id, member.id)
				value = (attitude.trust or 0) * 0.7
					- (attitude.grievances or 0) * 0.5
					+ (Offers.treaty(view, player.id, member.id, "alliance") and 35 or 0)
					+ (Offers.treaty(view, player.id, member.id, "commerce") and 15 or 0)
					+ ((view.diplomacy.reputation or {})[member.id] or 0) * 0.1
					+ 10
				if member.eligible then
					value = value - 35 - profile.ambition * 0.2
				end
				if war(view, player.id, member.id) then
					value = value - 1000
				end
				explanation = member.eligible
						and "A trusted long-term partner outweighs the risk of their diplomatic victory"
					or "Our observed relations and cooperation favor this partner"
			end
			if value > score then
				best, score, reason = member.id, value, explanation
			end
		end
	end
	return best, reason
end
function AI.resolution(view, player, resolution)
	local target, other = resolution.target, resolution.other
	local profile = Profiles.forCivilization(player.civ)
	local attitude = relation(view, player.id, target)
	local allied = target ~= nil and Offers.treaty(view, player.id, target, "alliance")
	if resolution.kind == "trade" then
		local support = not Rules.embargoed(view, player.id)
		return support,
			support and "Lower exchange costs and commerce income benefit our economy"
				or "Our embargo prevents us from using these benefits"
	elseif resolution.kind == "peace" then
		if (target == player.id or other == player.id) and profile.aggression >= 70 then
			return false, "We prefer to keep fighting rather than accept a binding Council peace"
		end
		return true, "A temporary peace protects stability and trade"
	elseif resolution.kind == "embargo" then
		if target == player.id or allied then
			return false, "This embargo would harm us or an ally"
		end
		if war(view, player.id, target) then
			return true, "An embargo constrains an opponent we already fight"
		end
		return (attitude.grievances or 0) > 30,
			"Our recorded grievances determine whether economic sanctions are justified"
	end
	if target == player.id or allied then
		return false, "We oppose censuring ourselves or an ally"
	end
	local support = (attitude.grievances or 0) > 15
		or (attitude.trust or 0) < -25
		or ((view.diplomacy.reputation or {})[target] or 0) < -20
	return support,
		support and "Observed conduct warrants a temporary diplomatic penalty"
			or "We have no observed reason for this penalty"
end
function AI.run(state, player, view)
	local session = view.council and view.council.session
	if
		not session
		or session.status ~= "voting"
		or view.round >= session.closesRound
		or not Rules.member(session, player.id)
	then
		return
	end
	local candidate, reason = AI.election(view, player)
	Council.vote(state, player.id, { session = session.id, candidate = candidate }, reason)
	for _, resolution in ipairs(session.agenda) do
		local support, why = AI.resolution(view, player, resolution)
		Council.vote(
			state,
			player.id,
			{ session = session.id, resolution = resolution.id, support = support },
			why
		)
	end
	if state.round ~= session.opensRound then
		return
	end
	for _, resolution in ipairs(session.agenda) do
		if resolution.sponsor == player.id then
			return
		end
	end
	for _, conflict in ipairs(view.diplomacy.wars or {}) do
		local enemy = conflict.a == player.id and conflict.b
			or conflict.b == player.id and conflict.a
		if enemy ~= nil and Rules.member(session, enemy) then
			local profile = Profiles.forCivilization(player.civ)
			Council.propose(state, player.id, {
				session = session.id,
				kind = profile.aggression >= 70 and "embargo" or "peace",
				target = enemy,
				other = profile.aggression < 70 and player.id or nil,
			})
			return
		end
	end
end
return AI
