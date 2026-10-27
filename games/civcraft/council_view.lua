local Council = dofile("/games/civcraft/council.lua")
local Rules = dofile("/games/civcraft/council_rules.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local View = {}
local descriptions = {
	trade = "Material exchanges cost 15 instead of 20 gold. Commerce agreements pay one additional gold per round.",
	embargo = "The named civilization cannot buy materials or make trade and commerce agreements. Existing commerce income is suspended, then resumes when the embargo expires.",
	peace = "Ends the war between these civilizations at this boundary and prevents either from attacking or declaring war on the other during the protection period.",
	censure = "The named civilization loses 20 public reputation while this resolution remains active. The penalty expires automatically.",
}
local function name(state, observer, id)
	if id == nil or id == false then
		return "ABSTAIN"
	end
	if not Contacts.knows(state, observer, id) then
		return "UNMET CIV " .. id
	end
	for _, player in ipairs(state.players) do
		if player.id == id then
			return player.name
		end
	end
	return "FORMER CIV " .. id
end
local function title(state, observer, item)
	local text = Council.names[item.kind]
	if item.target ~= nil then
		text = text .. ": " .. name(state, observer, item.target)
	end
	if item.other ~= nil then
		text = text .. " / " .. name(state, observer, item.other)
	end
	return text
end
function View.draw(ui, state, player, rect)
	local r = ui.r
	local public = state.observerID ~= nil and state.council or Council.public(state, player.id)
	public = public or { effects = {}, history = {} }
	local session = public.session
	local key = tostring(state.campaignID)
		.. ":"
		.. player.id
		.. ":"
		.. (session and session.id or 0)
	if not ui.councilModel or ui.councilModel.key ~= key then
		ui.councilModel = { key = key, tab = "STATUS", offset = 0 }
	end
	local model = ui.councilModel
	local function mode(tab)
		model.tab, model.offset, model.detail, model.draft, model.detailSession =
			tab, 0, nil, nil, nil
	end
	local function command(action, values)
		values.session = session.id
		ui:command(action, values)
	end
	r:text(rect.x + 3, rect.y + 4, "COUNCIL", 8, 1, rect.w - 46)
	r:button(rect.x + rect.w - 40, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local tabWidth = math.floor((rect.w - 8) / 3)
	for index, tab in ipairs({ "STATUS", "ELECTION", "AGENDA" }) do
		r:button(
			rect.x + 2 + (index - 1) * (tabWidth + 2),
			rect.y + 14,
			tabWidth,
			11,
			tab,
			function()
				mode(tab)
			end,
			{ selected = model.tab == tab }
		)
	end
	if
		model.draft
		and (not session or session.status ~= "voting" or state.round ~= session.opensRound)
	then
		model.draft, model.offset = nil, 0
	end
	local rows = {}
	local function text(value)
		for _, line in ipairs(Panels.wrap(r, value, rect.w - 18)) do
			rows[#rows + 1] = { text = line }
		end
	end
	local function button(label, run, selected)
		rows[#rows + 1] =
			{ buttons = { { label = label, run = run, style = { selected = selected } } } }
	end
	local active = session
		and session.status == "voting"
		and state.round < session.closesRound
		and Rules.member(session, player.id)
	if model.detail then
		local ballotSession = session
		if model.detailSession then
			for _, archived in ipairs(public.history or {}) do
				if archived.id == model.detailSession then
					ballotSession = archived
				end
			end
		end
		local item = ballotSession and ballotSession.agenda[model.detail] or nil
		if not item then
			model.detail = nil
			return
		end
		button("BACK", function()
			model.detail, model.detailSession, model.offset = nil, nil, 0
		end)
		text(title(state, player.id, item))
		text(descriptions[item.kind])
		text(
			"Strict majority of ALL allocated delegates required. Effects last for ten speed-scaled rounds."
		)
		if item.result then
			text(
				(item.result.passed and "PASSED" or "DID NOT PASS")
					.. " / YES "
					.. item.result.yes
					.. " / NO "
					.. item.result.no
			)
		elseif active then
			button("VOTE YES", function()
				command("councilVote", { resolution = item.id, support = true })
			end, item.ownVote and item.ownVote.support)
			button("VOTE NO", function()
				command("councilVote", { resolution = item.id, support = false })
			end, item.ownVote and item.ownVote.support == false)
		end
		for _, member in ipairs(ballotSession and ballotSession.members or {}) do
			local ballot = item.votes and item.votes[member.id]
			if ballot then
				text(name(state, player.id, member.id) .. (ballot.support and ": YES" or ": NO"))
				if ballot.reason then
					text(ballot.reason)
				end
			end
		end
	elseif model.draft then
		local draft = model.draft
		button("CANCEL PROPOSAL", function()
			model.draft, model.offset = nil, 0
		end)
		if not draft.kind then
			for _, kind in ipairs({ "embargo", "peace", "censure" }) do
				button(Council.names[kind], function()
					draft.kind, model.offset = kind, 0
				end)
			end
		elseif draft.target == nil or draft.kind == "peace" and draft.other == nil then
			text(
				draft.target == nil and "CHOOSE A CIVILIZATION"
					or "CHOOSE THE OTHER WAR PARTICIPANT"
			)
			for _, member in ipairs(session.members) do
				if member.alive ~= false and member.id ~= draft.target then
					button(name(state, player.id, member.id), function()
						if draft.target == nil then
							draft.target = member.id
						else
							draft.other = member.id
						end
						model.offset = 0
					end)
				end
			end
		else
			text(title(state, player.id, draft))
			text(descriptions[draft.kind])
			button("SUBMIT PROPOSAL", function()
				command(
					"councilPropose",
					{ kind = draft.kind, target = draft.target, other = draft.other }
				)
				model.draft, model.offset = nil, 0
			end)
		end
	elseif model.tab == "STATUS" then
		button("RECENT RESULTS", function()
			mode("RESULTS")
		end)
		button("COUNCIL HALL CODEX", function()
			ui:openCodex("buildings", "councilhall")
		end)
		if not public.foundedRound then
			text(
				"The Council forms once two civilizations have cities and one has researched Currency."
			)
		else
			text(
				"Leader: "
					.. (public.leader ~= nil and name(state, player.id, public.leader) or "VACANT")
			)
			text(
				session
						and session.status == "voting"
						and "Voting closes at round " .. session.closesRound
					or "Next session: round " .. (public.nextRound or state.round)
			)
		end
		text(
			"Each civilization receives two delegates. An independent village allied at 60 influence for three rounds grants one bonus delegate, capped at one."
		)
		text(
			"Leadership requires a strict majority. Diplomatic victory requires two-thirds of ALL delegates, another living civilization's support, Stock Logistics and a Council Hall."
		)
		text(
			public.victoryEnabled and "DIPLOMATIC VICTORY ENABLED" or "DIPLOMATIC VICTORY DISABLED"
		)
		for _, effect in ipairs(public.effects or {}) do
			text(title(state, player.id, effect) .. " / UNTIL ROUND " .. effect.endsRound)
		end
	elseif model.tab == "RESULTS" then
		local history = public.history or {}
		if #history == 0 then
			text("No completed Council sessions yet.")
		end
		for index = #history, 1, -1 do
			local result = history[index]
			text("SESSION " .. result.id .. " / ROUND " .. result.closedRound)
			text(
				"LEADER: "
					.. (
						result.result.leader ~= nil
							and name(state, player.id, result.result.leader)
						or "VACANT"
					)
			)
			for _, member in ipairs(result.members) do
				local ballot = result.election[member.id]
				text(
					name(state, player.id, member.id)
						.. ": "
						.. name(state, player.id, ballot and ballot.candidate)
						.. " ("
						.. member.delegates
						.. ")"
				)
				if ballot and ballot.reason then
					text(ballot.reason)
				end
			end
			for _, item in ipairs(result.agenda) do
				button("RESULT " .. result.id .. ": " .. Council.names[item.kind], function()
					model.detail, model.detailSession, model.offset = item.id, result.id, 0
				end)
				text(
					title(state, player.id, item) .. (item.result.passed and " PASSED" or " FAILED")
				)
				text(
					"YES "
						.. item.result.yes
						.. " / NO "
						.. item.result.no
						.. " / TOTAL "
						.. result.allocated
				)
			end
		end
	elseif not session then
		text("No Council session has opened yet. See Status for founding requirements.")
	elseif model.tab == "ELECTION" then
		if active then
			button("ABSTAIN", function()
				command("councilVote", { candidate = false })
			end, session.ownElection and session.ownElection.candidate == false)
			for _, member in ipairs(session.members) do
				if member.alive ~= false then
					button("VOTE " .. name(state, player.id, member.id), function()
						command("councilVote", { candidate = member.id })
					end, session.ownElection and session.ownElection.candidate == member.id)
				end
			end
		end
		text(
			session.status == "voting"
					and "Ballots are secret until round " .. session.closesRound .. ". You may change yours until then."
				or "Session closed. Open Status > Recent Results for public ballots."
		)
		text("Allocated delegates: " .. session.allocated)
		for _, member in ipairs(session.members) do
			text(
				name(state, player.id, member.id)
					.. ": "
					.. member.delegates
					.. " DELEGATES"
					.. (member.eligible and " / VICTORY ELIGIBLE" or "")
			)
		end
		for _, pledge in ipairs(session.pledges or {}) do
			text(
				name(state, player.id, pledge.from)
					.. " pledged to "
					.. name(state, player.id, pledge.to)
			)
		end
	else
		local proposed = false
		for _, item in ipairs(session.agenda) do
			if item.sponsor == player.id then
				proposed = true
			end
		end
		if active and state.round == session.opensRound and not proposed then
			button("PROPOSE RESOLUTION", function()
				model.draft, model.offset = {}, 0
			end)
		end
		for _, item in ipairs(session.agenda) do
			button(title(state, player.id, item), function()
				model.detail, model.offset = item.id, 0
			end)
			text(
				item.ownVote and (item.ownVote.support and "YOUR VOTE: YES" or "YOUR VOTE: NO")
					or "YOUR VOTE: NOT CAST"
			)
		end
		text(
			"One proposal per civilization, during the opening round only. Select a resolution for its terms and ballot."
		)
	end
	Panels.rows(
		r,
		{ x = rect.x + 3, y = rect.y + 28, w = rect.w - 6, h = rect.h - 31 },
		rows,
		model
	)
end
return View
