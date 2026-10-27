local ContentRules = dofile("/games/civcraft/content_rules.lua")
-- Host-authoritative elections; ballots remain private until the closing boundary.
local Rules = dofile("/games/civcraft/council_rules.lua")
local Campaign = dofile("/games/civcraft/campaign_rules.lua")
local Events = dofile("/games/civcraft/events.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local Council = {}
local kinds = { trade = true, embargo = true, peace = true, censure = true }
local names = {
	trade = "TRADE FACILITATION",
	embargo = "TRADE EMBARGO",
	peace = "PEACE INITIATIVE",
	censure = "DIPLOMATIC CENSURE",
}
Council.names = names
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
function Council.ensure(state)
	if not state.council then
		state.council = { version = 1, effects = {}, loyalty = {}, history = {}, nextSession = 1 }
	end
	assert(state.council.version == 1, "Unsupported Council version")
	state.council.effects, state.council.loyalty, state.council.history =
		state.council.effects or {}, state.council.loyalty or {}, state.council.history or {}
	state.council.nextSession = state.council.nextSession or 1
	return state.council
end
local function announce(state, text)
	for _, player in ipairs(state.players) do
		Events.notice(state, "order", nil, text, player.id)
	end
end
local function war(state, a, b)
	for _, record in ipairs(state.diplomacy and state.diplomacy.wars or {}) do
		if record.a == a and record.b == b or record.a == b and record.b == a then
			return record
		end
	end
end
local function loyalty(state, council)
	local existing = {}
	for _, city in ipairs(state.cities or {}) do
		if Villages.independent(city) then
			existing[city.id] = true
			local ally = Villages.ally(city)
			if ally ~= nil and ((city.influence or {})[ally] or 0) < 60 then
				ally = nil
			end
			local support = council.loyalty[city.id]
			if not support or support.owner ~= (ally or false) then
				council.loyalty[city.id] = { owner = ally or false, since = state.round }
			end
		end
	end
	for id in pairs(council.loyalty) do
		if not existing[id] then
			council.loyalty[id] = nil
		end
	end
end
local function members(state, council)
	local result = {}
	for _, player in ipairs(state.players) do
		if Rules.alive(state, player.id) then
			local bonus = false
			for _, city in ipairs(state.cities) do
				local support = council.loyalty[city.id]
				if
					support
					and support.owner == player.id
					and state.round - support.since >= 3
					and ((city.influence or {})[player.id] or 0) >= 60
				then
					bonus = true
				end
			end
			result[#result + 1] = {
				id = player.id,
				delegates = bonus and 3 or 2,
				eligible = not ContentRules.isRedesign(state) and Rules.eligible(state, player.id),
			}
		end
	end
	return result
end
local function opening(state, council)
	local roster = members(state, council)
	if #roster < 2 then
		return
	end
	local commercial = false
	for _, player in ipairs(state.players) do
		commercial = commercial or (player.techs or {}).currency == true
	end
	if not commercial then
		return
	end
	council.foundedRound = council.foundedRound or state.round
	local id = council.nextSession
	council.nextSession = id + 1
	local allocated = 0
	for _, member in ipairs(roster) do
		allocated = allocated + member.delegates
	end
	council.session = {
		id = id,
		opensRound = state.round,
		closesRound = state.round + Campaign.cost(3, state),
		status = "voting",
		members = roster,
		allocated = allocated,
		election = {},
		agenda = { { id = 1, kind = "trade", votes = {} } },
		pledges = {},
	}
	council.nextRound = state.round + Campaign.cost(10, state)
	announce(state, "Council session " .. id .. " opened: leadership and world resolutions")
end
local function applyResolution(state, council, resolution)
	local effect = {
		kind = resolution.kind,
		target = resolution.target,
		other = resolution.other,
		startsRound = state.round,
		endsRound = state.round + Campaign.cost(10, state),
	}
	if effect.kind == "peace" then
		local conflict = war(state, effect.target, effect.other)
		if not conflict then
			return false
		end
		conflict.endsRound, conflict.forcedPeace = state.round, true
	end
	for index = #council.effects, 1, -1 do
		local old = council.effects[index]
		if
			old.kind == effect.kind
			and old.target == effect.target
			and old.other == effect.other
		then
			table.remove(council.effects, index)
		end
	end
	council.effects[#council.effects + 1] = effect
	return true
end
local function tally(state, council, session)
	session.status, session.closedRound = "closed", state.round
	local counts, supporters = {}, {}
	for _, member in ipairs(session.members) do
		local ballot = session.election[member.id]
		if ballot and Rules.member(session, ballot.candidate) and Rules.alive(state, member.id) then
			local candidate = ballot.candidate
			counts[candidate] = (counts[candidate] or 0) + member.delegates
			if candidate ~= member.id then
				supporters[candidate] = true
			end
		end
	end
	local leader, votes
	for _, member in ipairs(session.members) do
		local count = counts[member.id] or 0
		if count > session.allocated / 2 and Rules.alive(state, member.id) then
			leader, votes = member.id, count
		end
	end
	council.leader = leader
	session.result = { leader = leader, leadership = counts }
	if
		leader ~= nil
		and votes * 3 >= session.allocated * 2
		and supporters[leader]
		and Rules.eligible(state, leader)
		and Campaign.enabled(state, "diplomatic")
	then
		council.victory = { id = leader, round = state.round, session = session.id }
	end
	for _, resolution in ipairs(session.agenda) do
		local yes, no = 0, 0
		for _, member in ipairs(session.members) do
			if Rules.alive(state, member.id) then
				local ballot = resolution.votes[member.id]
				if ballot then
					if ballot.support then
						yes = yes + member.delegates
					else
						no = no + member.delegates
					end
				end
			end
		end
		resolution.result = { yes = yes, no = no, passed = yes > session.allocated / 2 }
		if resolution.result.passed then
			resolution.result.applied = applyResolution(state, council, resolution)
		end
		announce(
			state,
			"Council "
				.. names[resolution.kind]
				.. (resolution.result.passed and " passed" or " did not pass")
		)
	end
	for _, pledge in ipairs(session.pledges) do
		if Rules.alive(state, pledge.from) and Rules.alive(state, pledge.to) then
			local ballot = session.election[pledge.from]
			local honored = ballot and ballot.candidate == pledge.to
			Memory.add(
				state,
				pledge.to,
				pledge.from,
				honored and "councilPledgeHonored" or "councilPledgeBroken",
				honored and 10 or -25,
				honored and 0 or 15,
				30,
				honored and "Honored a Council voting pledge" or "Broke a Council voting pledge"
			)
		end
	end
	local archived = copy(session)
	archived.pledges = nil
	council.history[#council.history + 1] = archived
	while #council.history > 3 do
		table.remove(council.history, 1)
	end
	announce(
		state,
		leader ~= nil and "Council leadership election concluded"
			or "Council leadership remains vacant: no majority"
	)
end
function Council.advance(state)
	if state.phase ~= "game" then
		return
	end
	local council = Council.ensure(state)
	if council.lastRound == state.round then
		return
	end
	council.lastRound = state.round
	loyalty(state, council)
	for index = #council.effects, 1, -1 do
		if council.effects[index].endsRound <= state.round then
			table.remove(council.effects, index)
		end
	end
	local session = council.session
	if session and session.status == "voting" and state.round >= session.closesRound then
		tally(state, council, session)
	end
	if (not session or session.status == "closed") and state.round >= (council.nextRound or 1) then
		opening(state, council)
	end
end
local function voting(state, actor, sessionID)
	local session = state.council and state.council.session
	if
		state.phase ~= "game"
		or not session
		or session.status ~= "voting"
		or session.id ~= sessionID
		or state.round >= session.closesRound
		or not Rules.member(session, actor)
		or not Rules.alive(state, actor)
	then
		return nil, "Select the current Council session as a living member"
	end
	return session
end
function Council.vote(state, actor, request, reason)
	local session, why = voting(state, actor, request.session)
	if not session then
		return false, why
	end
	if request.resolution == nil then
		if request.candidate ~= false and not Rules.member(session, request.candidate) then
			return false, "Choose a Council member or abstain"
		end
		if request.candidate ~= false and not Rules.alive(state, request.candidate) then
			return false, "Candidate is no longer a living member"
		end
		session.election[actor] = { candidate = request.candidate, reason = reason }
	else
		if type(request.support) ~= "boolean" then
			return false, "Vote yes or no on this resolution"
		end
		local resolution = session.agenda[request.resolution]
		if not resolution or resolution.id ~= request.resolution then
			return false, "Unknown Council resolution"
		end
		resolution.votes[actor] = { support = request.support, reason = reason }
	end
	return true
end
function Council.propose(state, actor, request)
	local session, why = voting(state, actor, request.session)
	if not session then
		return false, why
	end
	if state.round ~= session.opensRound then
		return false, "Proposals are accepted only in the opening round"
	end
	if not kinds[request.kind] then
		return false, "Choose a Council resolution"
	end
	local target = request.kind ~= "trade" and request.target or nil
	local other = request.kind == "peace" and request.other or nil
	if type(target) == "number" and type(other) == "number" and other < target then
		target, other = other, target
	end
	for _, resolution in ipairs(session.agenda) do
		if resolution.sponsor == actor then
			return false, "One proposal per civilization per session"
		end
		if
			resolution.kind == request.kind
			and resolution.target == target
			and resolution.other == other
		then
			return false, "That proposal is already on the agenda"
		end
	end
	if request.kind ~= "trade" then
		if not Rules.member(session, target) or not Rules.alive(state, target) then
			return false, "Choose a Council member"
		end
		if
			request.kind == "peace"
			and (
				other == target
				or not Rules.member(session, other)
				or not Rules.alive(state, other)
				or not war(state, target, other)
			)
		then
			return false, "Choose two civilizations in an announced or active war"
		end
	end
	session.agenda[#session.agenda + 1] = {
		id = #session.agenda + 1,
		kind = request.kind,
		target = request.kind ~= "trade" and target or nil,
		other = request.kind == "peace" and other or nil,
		sponsor = actor,
		votes = {},
	}
	announce(state, "A Council " .. names[request.kind] .. " proposal joined the agenda")
	return true
end
function Council.public(state, observer)
	local council = state.council
	if not council then
		return {
			version = 1,
			effects = {},
			history = {},
			victoryEnabled = Campaign.enabled(state, "diplomatic"),
		}
	end
	local result = {
		version = 1,
		foundedRound = council.foundedRound,
		nextRound = council.nextRound,
		victoryEnabled = Campaign.enabled(state, "diplomatic"),
		leader = council.leader,
		effects = copy(council.effects),
		history = copy(council.history),
		victory = copy(council.victory),
	}
	local session = council.session
	if session then
		local public = {
			id = session.id,
			opensRound = session.opensRound,
			closesRound = session.closesRound,
			status = session.status,
			members = copy(session.members),
			allocated = session.allocated,
			agenda = {},
			result = copy(session.result),
			ownElection = copy(session.election[observer]),
			pledges = {},
		}
		for _, member in ipairs(public.members) do
			member.alive = Rules.alive(state, member.id)
		end
		if session.status == "closed" then
			public.election = copy(session.election)
		end
		for _, resolution in ipairs(session.agenda) do
			local item = {
				id = resolution.id,
				kind = resolution.kind,
				target = resolution.target,
				other = resolution.other,
				sponsor = resolution.sponsor,
				result = copy(resolution.result),
				ownVote = copy(resolution.votes[observer]),
			}
			if session.status == "closed" then
				item.votes = copy(resolution.votes)
			end
			public.agenda[#public.agenda + 1] = item
		end
		for _, pledge in ipairs(session.pledges) do
			if pledge.from == observer or pledge.to == observer then
				public.pledges[#public.pledges + 1] = copy(pledge)
			end
		end
		result.session = public
	end
	return result
end
return Council
