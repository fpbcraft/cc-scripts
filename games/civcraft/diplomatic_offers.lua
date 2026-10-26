local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Events = dofile("/games/civcraft/events.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Offers = {}
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local labels = {
	openBorders = "OPEN BORDERS",
	defensivePact = "DEFENSIVE PACT",
	jointWar = "JOINT WAR",
	defenseCall = "CALL TO ARMS",
	commerce = "COMMERCE",
	councilSupport = "COUNCIL VOTE PLEDGE",
	peace = "PEACE",
	alliance = "ALLIANCE",
	trade = "TRADE",
	withdrawal = "WITHDRAWAL",
}
function Offers.label(kind)
	return labels[kind] or tostring(kind):upper()
end
local kinds = {
	peace = true,
	openBorders = true,
	commerce = true,
	councilSupport = true,
	alliance = true,
	defensivePact = true,
	jointWar = true,
	trade = true,
	withdrawal = true,
}
local function player(state, id)
	for _, participant in ipairs(state.players) do
		if participant.id == id then
			return participant
		end
	end
end
local function samePair(record, a, b)
	return record.a == a and record.b == b or record.a == b and record.b == a
end
local function integer(value, default, maximum)
	value = value == nil and default or value
	return type(value) == "number"
			and value == value
			and value >= 0
			and value <= maximum
			and value % 1 == 0
			and value
		or nil
end

function Offers.ensure(state)
	local data = state.diplomacy
	for _, field in ipairs({ "offers", "treaties", "pairCounters", "armistices", "promises" }) do
		data[field] = data[field] or {}
	end
	return data
end

function Offers.treaty(state, a, b, kind)
	for _, treaty in ipairs(state.diplomacy and state.diplomacy.treaties or {}) do
		if
			samePair(treaty, a, b)
			and treaty.kind == kind
			and treaty.status == "active"
			and treaty.startsRound <= state.round
			and treaty.endsRound > state.round
		then
			return treaty
		end
	end
end

function Offers.withdrawing(state, id)
	for _, promise in ipairs(state.diplomacy and state.diplomacy.promises or {}) do
		if promise.by == id and promise.status == "active" then
			return true
		end
	end
	return false
end

local function create(state, sender, recipient, kind, terms, deadline)
	local data = Offers.ensure(state)
	local pair = tostring(sender) .. ">" .. tostring(recipient)
	data.pairCounters[pair] = (data.pairCounters[pair] or 0) + 1
	local offer = {
		id = pair .. ":" .. data.pairCounters[pair],
		from = sender,
		to = recipient,
		kind = kind,
		terms = terms,
		createdRound = state.round,
		expiresRound = deadline or state.round + 3,
		status = "pending",
	}
	data.offers[#data.offers + 1] = offer
	if kind == "defenseCall" then
		Events.notice(
			state,
			"order",
			nil,
			"Call to Arms: "
				.. player(state, sender).name
				.. " requests defense against "
				.. player(state, terms.enemy).name
				.. "; your choice is required",
			recipient
		)
	end
	return offer
end

function Offers.propose(state, sender, request, systems, diplomacy)
	if state.phase ~= "game" then
		return false, "Game not running"
	end
	if not state.diplomacy then
		return false, "Diplomacy is unavailable"
	end
	local recipient, kind = request.target, request.kind
	if not Contacts.knows(state, sender, recipient) then
		return false, "Discover this civilization before making offers"
	end
	if
		not player(state, sender)
		or not player(state, recipient)
		or sender == recipient
		or not kinds[kind]
	then
		return false, "Choose a civilization and a supported offer"
	end
	if
		(kind == "trade" or kind == "commerce") and CouncilRules.embargoed(state, sender, recipient)
	then
		return false, "Council embargo prevents this trade agreement"
	end
	local data = Offers.ensure(state)
	local pending = 0
	for _, offer in ipairs(data.offers) do
		if offer.from == sender and offer.status == "pending" then
			pending = pending + 1
			if offer.to == recipient and offer.kind == kind then
				return false, "This offer is already pending"
			end
		end
	end
	if pending >= 8 then
		return false, "Resolve existing offers first"
	end
	local input = type(request.terms) == "table" and request.terms or {}
	local duration = kind == "withdrawal" and 2
		or integer(input.duration, kind == "peace" and 5 or 10, 30)
	if not duration or kind ~= "withdrawal" and duration < 3 then
		return false, "Agreement duration must be 3 to 30 rounds"
	end
	local terms = { duration = duration }
	local war = diplomacy.war(state, sender, recipient)
	if kind == "peace" then
		if not war then
			return false, "There is no war to settle"
		end
		if war.endsRound then
			return false, "Peace is already scheduled"
		end
	elseif kind ~= "trade" and war then
		return false, "Settle the war before making this agreement"
	end
	if Offers.treaty(state, sender, recipient, kind) then
		return false, "This agreement is already active"
	end
	if kind == "councilSupport" then
		local ok, why = CouncilRules.canPledge(state, recipient, sender, input.session)
		if not ok then
			return false, why
		end
		terms.session = input.session
	elseif kind == "jointWar" then
		terms.enemy = input.enemy
		if
			not player(state, terms.enemy)
			or not Contacts.knows(state, sender, terms.enemy)
			or not Contacts.knows(state, recipient, terms.enemy)
			or terms.enemy == recipient
			or terms.enemy == sender
			or not diplomacy.war(state, sender, terms.enemy)
		then
			return false, "Joint war must name an opponent you already fight or have announced"
		end
	elseif kind == "withdrawal" then
		terms.by = input.by == recipient and recipient or sender
		terms.duration = 2
	elseif kind == "trade" then
		terms.gold = integer(input.gold, 0, 1000)
		terms.requestGold = integer(input.requestGold, 0, 1000)
		terms.giveAmount = integer(input.giveAmount, 0, 99)
		terms.askAmount = integer(input.askAmount, 0, 99)
		terms.giveResource = type(input.giveResource) == "string" and input.giveResource or nil
		terms.askResource = type(input.askResource) == "string" and input.askResource or nil
		if
			not terms.gold
			or not terms.requestGold
			or not terms.giveAmount
			or not terms.askAmount
		then
			return false, "Trade amounts must be nonnegative whole numbers within the offer limits"
		end
		if terms.giveAmount + terms.askAmount + terms.gold + terms.requestGold == 0 then
			return false, "Offer an exchange or a gift"
		end
		if
			terms.giveAmount > 0 and not (systems.resources or {})[terms.giveResource]
			or terms.askAmount > 0 and not (systems.resources or {})[terms.askResource]
		then
			return false, "Choose a known strategic material"
		end
		if terms.giveAmount == 0 then
			terms.giveResource = nil
		end
		if terms.askAmount == 0 then
			terms.askResource = nil
		end
	end
	local offer = create(state, sender, recipient, kind, terms)
	return true, "Offer sent; it expires in three rounds", offer
end

function Offers.find(state, id)
	for _, offer in ipairs(state.diplomacy and state.diplomacy.offers or {}) do
		if offer.id == id then
			return offer
		end
	end
end

local function affordable(sender, recipient, terms)
	return (sender.gold or 0) >= terms.gold
		and (recipient.gold or 0) >= terms.requestGold
		and (terms.giveAmount == 0 or ((sender.stockpile or {})[terms.giveResource] or 0) >= terms.giveAmount)
		and (
			terms.askAmount == 0
			or ((recipient.stockpile or {})[terms.askResource] or 0) >= terms.askAmount
		)
end

local function refusal(state, offer, reason)
	if offer.kind == "defenseCall" then
		Memory.add(state, offer.from, offer.to, "defenseRefused", -25, 20, 30, reason)
		state.diplomacy.reputation[offer.to] = (state.diplomacy.reputation[offer.to] or 0) - 10
	end
end

function Offers.respond(state, actor, request, systems, diplomacy)
	if state.phase ~= "game" then
		return false, "Game not running"
	end
	local offer = Offers.find(state, request.offerID)
	if not offer or offer.to ~= actor then
		return false, "That offer is not addressed to you"
	end
	if offer.status ~= "pending" or offer.expiresRound <= state.round then
		return false, "Offer is no longer pending"
	end
	if request.response ~= "accept" and request.response ~= "reject" then
		return false, "Choose Accept or Reject"
	end
	if offer.kind == "defenseCall" or offer.kind == "jointWar" then
		local origin = diplomacy.war(state, offer.from, offer.terms.enemy)
		if not origin or origin.endsRound or diplomacy.war(state, offer.from, actor) then
			offer.status, offer.reason =
				"withdrawn", "The original war has ended or peace is scheduled"
			return true, offer.reason
		end
	end
	if request.response == "reject" then
		offer.status, offer.responseRound = "rejected", state.round
		offer.reason = tostring(request.reason or "Terms declined"):sub(1, 160)
		refusal(state, offer, "Declined a defensive call: " .. offer.reason)
		return true, "Offer rejected"
	end
	local sender, recipient, terms = player(state, offer.from), player(state, actor), offer.terms
	if
		(offer.kind == "trade" or offer.kind == "commerce")
		and CouncilRules.embargoed(state, offer.from, actor)
	then
		return false, "Council embargo now prevents this agreement"
	end
	if not sender or not recipient then
		return false, "A signatory is no longer available"
	end
	if offer.kind == "trade" then
		if not affordable(sender, recipient, terms) then
			return false, "The exchange is no longer affordable"
		end
	elseif offer.kind == "peace" then
		if not diplomacy.war(state, sender.id, actor) then
			return false, "The war has already ended"
		end
		if diplomacy.war(state, sender.id, actor).endsRound then
			return false, "Peace is already scheduled"
		end
	elseif offer.kind == "defenseCall" or offer.kind == "jointWar" then
		if not diplomacy.war(state, offer.from, terms.enemy) then
			return false, "The requested war has already ended"
		end
	elseif diplomacy.war(state, sender.id, actor) then
		return false, "War changed the terms; negotiate peace first"
	elseif Offers.treaty(state, sender.id, actor, offer.kind) then
		return false, "This agreement is already active"
	end
	if offer.kind == "councilSupport" then
		local ok, reason = CouncilRules.pledge(state, actor, offer.from, terms.session)
		if not ok then
			return false, reason
		end
	end
	local data = Offers.ensure(state)
	if offer.kind == "trade" then
		sender.gold, recipient.gold =
			(sender.gold or 0) - terms.gold + terms.requestGold,
			(recipient.gold or 0) + terms.gold - terms.requestGold
		sender.stockpile, recipient.stockpile = sender.stockpile or {}, recipient.stockpile or {}
		for _, transfer in ipairs({
			{ sender, recipient, terms.giveResource, terms.giveAmount },
			{ recipient, sender, terms.askResource, terms.askAmount },
		}) do
			if transfer[4] > 0 then
				transfer[1].stockpile[transfer[3]] = (transfer[1].stockpile[transfer[3]] or 0)
					- transfer[4]
				transfer[2].stockpile[transfer[3]] = (transfer[2].stockpile[transfer[3]] or 0)
					+ transfer[4]
			end
		end
	elseif offer.kind == "peace" then
		diplomacy.war(state, sender.id, actor).endsRound = state.round + 1
		data.armistices[#data.armistices + 1] = {
			id = offer.id,
			status = "pending",
			a = sender.id,
			b = actor,
			startsRound = state.round + 1,
			endsRound = state.round + 1 + terms.duration,
		}
	elseif offer.kind == "defenseCall" or offer.kind == "jointWar" then
		local ok, reason =
			diplomacy.join(state, actor, terms.enemy, { defender = sender.id, offerID = offer.id })
		if not ok then
			return false, reason
		end
		data.treaties[#data.treaties + 1] = {
			id = offer.id,
			a = sender.id,
			b = actor,
			kind = "jointWar",
			startsRound = state.round + 1,
			endsRound = state.round + 1 + terms.duration,
			status = "active",
			terms = { enemy = terms.enemy },
		}
	elseif offer.kind == "councilSupport" then
		-- The session owns the pledge; voting remains a separate explicit action.
	elseif offer.kind == "withdrawal" then
		data.promises[#data.promises + 1] = {
			id = offer.id,
			by = terms.by,
			to = terms.by == sender.id and actor or sender.id,
			kind = "withdrawal",
			deadline = state.round + 2,
			status = "active",
		}
	else
		data.treaties[#data.treaties + 1] = {
			id = offer.id,
			a = sender.id,
			b = actor,
			kind = offer.kind,
			startsRound = state.round,
			endsRound = state.round + terms.duration,
			status = "active",
		}
	end
	offer.status, offer.responseRound = "accepted", state.round
	offer.reason = tostring(request.reason or "Terms accepted"):sub(1, 160)
	local reward = 8
	if offer.kind == "trade" then
		reward = math.min(
			4,
			math.floor(
				(terms.gold + terms.requestGold + 20 * (terms.giveAmount + terms.askAmount)) / 20
			)
		)
	end
	Memory.add(
		state,
		sender.id,
		actor,
		"agreementAccepted",
		reward,
		0,
		15,
		"Accepted " .. Offers.label(offer.kind):lower() .. " terms"
	)
	Memory.add(
		state,
		actor,
		sender.id,
		"agreementAccepted",
		reward,
		0,
		15,
		"Reached a " .. Offers.label(offer.kind):lower() .. " agreement"
	)
	return true,
		offer.kind == "peace" and "Peace starts next round; armistice terms recorded"
			or (offer.kind == "jointWar" or offer.kind == "defenseCall") and "War entry scheduled for next round"
			or "Agreement accepted"
end

function Offers.counter(state, actor, request, systems, diplomacy)
	local original = Offers.find(state, request.offerID)
	if
		not original
		or original.to ~= actor
		or original.status ~= "pending"
		or original.expiresRound <= state.round
	then
		return false, "Only the recipient of a pending offer may counter it"
	end
	if original.kind ~= "trade" then
		return false, "Only material and gold trades support counteroffers"
	end
	local ok, reason, nextOffer = Offers.propose(
		state,
		actor,
		{ target = original.from, kind = original.kind, terms = request.terms },
		systems,
		diplomacy
	)
	if ok then
		original.status, original.responseRound = "countered", state.round
		nextOffer.parentID = original.id
	end
	return ok, reason, nextOffer
end

function Offers.callAllies(state, war)
	local data = Offers.ensure(state)
	for _, treaty in ipairs(data.treaties) do
		if
			treaty.kind == "defensivePact"
			and treaty.status == "active"
			and treaty.startsRound <= state.round
			and treaty.endsRound > state.round
			and (treaty.a == war.b or treaty.b == war.b)
		then
			local ally = treaty.a == war.b and treaty.b or treaty.a
			local already = false
			for _, existing in ipairs(data.wars) do
				already = already or samePair(existing, ally, war.a)
			end
			if ally ~= war.a and not already then
				local duplicate = false
				for _, offer in ipairs(data.offers) do
					duplicate = duplicate
						or offer.kind == "defenseCall"
							and offer.from == war.b
							and offer.to == ally
							and offer.terms.enemy == war.a
							and offer.createdRound == state.round
				end
				if not duplicate then
					create(state, war.b, ally, "defenseCall", {
						enemy = war.a,
						defender = war.b,
						warKind = war.kind,
						treatyID = treaty.id,
						duration = 10,
					}, state.round + 2)
				end
			end
		end
	end
end

function Offers.advance(state)
	local data = Offers.ensure(state)
	Memory.advance(state)
	for _, armistice in ipairs(data.armistices) do
		if armistice.status ~= "broken" then
			armistice.status = armistice.endsRound <= state.round and "expired"
				or armistice.startsRound <= state.round and "active"
				or "pending"
		end
	end
	for _, offer in ipairs(data.offers) do
		if offer.status == "pending" and offer.kind == "councilSupport" then
			local available, why =
				CouncilRules.canPledge(state, offer.to, offer.from, offer.terms.session)
			if not available then
				offer.status, offer.reason = "withdrawn", why
			end
		end
		if
			offer.status == "pending" and (offer.kind == "defenseCall" or offer.kind == "jointWar")
		then
			local ongoing, hostileSignatories = false, false
			for _, war in ipairs(data.wars) do
				ongoing = ongoing
					or samePair(war, offer.from, offer.terms.enemy) and not war.endsRound
				hostileSignatories = hostileSignatories or samePair(war, offer.from, offer.to)
			end
			if not ongoing or hostileSignatories then
				offer.status, offer.reason =
					"withdrawn", "The original war has ended or peace is scheduled"
				Events.notice(
					state,
					"order",
					nil,
					"War invitation withdrawn because its terms changed",
					offer.from
				)
				Events.notice(
					state,
					"order",
					nil,
					"War invitation withdrawn because its terms changed",
					offer.to
				)
			end
		end
		if offer.status == "pending" and offer.expiresRound <= state.round then
			offer.status = "expired"
			offer.reason = "No response before the round deadline"
			refusal(state, offer, "A defensive call expired without a response")
			Events.notice(
				state,
				"order",
				nil,
				Offers.label(offer.kind) .. " offer expired",
				offer.from
			)
			Events.notice(
				state,
				"order",
				nil,
				Offers.label(offer.kind) .. " offer expired",
				offer.to
			)
		end
	end
	for _, treaty in ipairs(data.treaties) do
		if treaty.status == "active" and treaty.endsRound <= state.round then
			treaty.status = "expired"
			Events.notice(
				state,
				"order",
				nil,
				Offers.label(treaty.kind) .. " agreement expired",
				treaty.a
			)
			Events.notice(
				state,
				"order",
				nil,
				Offers.label(treaty.kind) .. " agreement expired",
				treaty.b
			)
		end
	end
	while #data.offers > 96 do
		local removed = false
		for index, offer in ipairs(data.offers) do
			if offer.status ~= "pending" then
				table.remove(data.offers, index)
				removed = true
				break
			end
		end
		if not removed then
			break
		end
	end
end

return Offers
