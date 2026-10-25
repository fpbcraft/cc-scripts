local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Conversation = {}
local greetings = {
	guardian = "Our villages value dependable neighbors. Show us that your word can be trusted.",
	conqueror = "Iron and resolve keep a civilization standing. Bring us terms worth considering.",
	scholar = "There is much to discover. Let our arrangements leave room for learning.",
	expansionist = "The world is wide, but our settlements still need room to grow.",
	industrialist = "Our workshops are busy. A practical agreement can help both civilizations prosper.",
	merchant = "Every good exchange leaves both sides better prepared for tomorrow.",
}
local function name(state, id)
	for _, player in ipairs(state.players) do
		if player.id == id then
			return player.name
		end
	end
	return "UNKNOWN"
end
local function terms(state, offer)
	local t = offer.terms
	if offer.kind == "trade" then
		local give, ask = { t.gold .. " GOLD" }, { t.requestGold .. " GOLD" }
		if t.giveAmount > 0 then
			give[#give + 1] = t.giveAmount .. " " .. t.giveResource:upper()
		end
		if t.askAmount > 0 then
			ask[#ask + 1] = t.askAmount .. " " .. t.askResource:upper()
		end
		return name(state, offer.from)
			.. " GIVES "
			.. table.concat(give, ", ")
			.. "; "
			.. name(state, offer.to)
			.. " GIVES "
			.. table.concat(ask, ", ")
	elseif offer.kind == "defenseCall" or offer.kind == "jointWar" then
		return "JOIN AGAINST "
			.. name(state, t.enemy)
			.. " NEXT ROUND, FOR A "
			.. t.duration
			.. "-ROUND JOINT-WAR COMMITMENT. Separate peace before expiry harms the ally's trust. "
			.. (
				offer.kind == "defenseCall"
					and "Refusing or ignoring this call costs 25 trust and 10 reputation. Conflicting alliances must be ended explicitly."
				or "Acceptance schedules your intervention; it does not refresh actions."
			)
	elseif offer.kind == "peace" then
		return "Peace begins next round, followed by a " .. t.duration .. "-round armistice."
	elseif offer.kind == "withdrawal" then
		return name(state, t.by)
			.. " promises to withdraw troops within two following rounds, by the end of round "
			.. ((offer.responseRound or state.round) + 2)
			.. "."
	end
	return t.duration
		.. " ROUNDS. "
		.. (
			offer.kind == "commerce" and "Both civilizations earn +2 gold per round."
			or offer.kind == "defensivePact" and "An attack produces a Call to Arms; joining is always an explicit choice."
			or offer.kind == "alliance" and "Cooperation improves relations; this agreement does not force war entry."
			or "Crossing each other's territory no longer causes an unpermitted-border grievance."
		)
end

function Conversation.draw(ui, state, observer, rect)
	local target
	for _, player in ipairs(state.players) do
		if player.id == ui.conversationTarget then
			target = player
		end
	end
	if not target or not state.diplomacy then
		ui.panel = "factions"
		return
	end
	local r, rows = ui.r, {}
	r:text(rect.x + 4, rect.y + 4, "WITH " .. target.name, 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "factions"
	end)
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, rect.w - 20)) do
			rows[#rows + 1] = { text = line, color = color }
		end
	end
	local function button(label, run)
		rows[#rows + 1] = { buttons = { { label = label, run = run } } }
	end
	local relation = state.diplomacy.relations[Memory.key(target.id, observer.id)]
		or { trust = 0, grievances = 0 }
	local mood = Diplomacy.state(state, observer.id, target.id)
	text(mood .. " / THEIR TRUST " .. relation.trust .. " / GRIEVANCES " .. relation.grievances, 8)
	local ownOpinion = state.diplomacy.relations[Memory.key(observer.id, target.id)] or {}
	text(
		"YOUR TRUST " .. (ownOpinion.trust or 0) .. " / GRIEVANCES " .. (ownOpinion.grievances or 0)
	)
	text("OBSERVED MILITARY PRESSURE: " .. (ownOpinion.pressure or 0))
	text(
		target.ai
				and (mood == "WAR" and "We are at war. If you seek an end to it, bring an explicit peace proposal." or relation.trust < -30 and "Past actions have damaged our trust. A pleasant greeting will not erase them." or greetings[Personalities.forCivilization(
					target.civ
				).archetype])
			or "This channel carries offers to the other human player. They choose how to respond."
	)
	for index = math.max(1, #(relation.memories or {}) - 4), #(relation.memories or {}) do
		local memory = relation.memories[index]
		text("R" .. memory.round .. ": " .. memory.explanation)
	end
	local incoming = {}
	for index = #(state.diplomacy.offers or {}), 1, -1 do
		local offer = state.diplomacy.offers[index]
		if
			offer.from == target.id and offer.to == observer.id
			or offer.from == observer.id and offer.to == target.id
		then
			incoming[#incoming + 1] = offer
		end
	end
	for _, offer in ipairs(incoming) do
		text(
			Offers.label(offer.kind)
				.. " / "
				.. offer.status:upper()
				.. " / EXPIRES AT START R"
				.. offer.expiresRound,
			9
		)
		text(terms(state, offer))
		if offer.reason then
			text("REASON: " .. offer.reason)
		end
		if offer.to == observer.id and offer.status == "pending" then
			rows[#rows + 1] = {
				buttons = {
					{
						label = "ACCEPT",
						run = function()
							ui:command(
								"diplomaticReply",
								{ offerID = offer.id, response = "accept" }
							)
						end,
					},
					{
						label = "REJECT",
						run = function()
							ui:command(
								"diplomaticReply",
								{ offerID = offer.id, response = "reject" }
							)
						end,
					},
				},
			}
			if offer.kind == "trade" then
				button("COUNTER: +10 GOLD", function()
					local t = offer.terms
					ui:command("diplomaticCounter", {
						offerID = offer.id,
						terms = {
							gold = t.requestGold,
							requestGold = math.min(1000, t.gold + 10),
							giveResource = t.askResource,
							giveAmount = t.askAmount,
							askResource = t.giveResource,
							askAmount = t.giveAmount,
						},
					})
				end)
			end
		end
	end
	for _, promise in ipairs(state.diplomacy.promises or {}) do
		if
			promise.by == target.id and promise.to == observer.id
			or promise.by == observer.id and promise.to == target.id
		then
			text(
				"WITHDRAWAL / "
					.. name(state, promise.by)
					.. " / "
					.. promise.status:upper()
					.. " / BY END R"
					.. promise.deadline
			)
		end
	end
	for _, armistice in ipairs(state.diplomacy.armistices or {}) do
		if
			(
				armistice.a == target.id and armistice.b == observer.id
				or armistice.b == target.id and armistice.a == observer.id
			) and armistice.endsRound > state.round
		then
			text("ARMISTICE THROUGH ROUND " .. (armistice.endsRound - 1))
		end
	end
	for _, treaty in ipairs(state.diplomacy.treaties or {}) do
		if
			(
				treaty.a == target.id and treaty.b == observer.id
				or treaty.b == target.id and treaty.a == observer.id
			) and treaty.status == "active"
		then
			text(
				Offers.label(treaty.kind)
					.. (treaty.terms and treaty.terms.enemy and " AGAINST " .. name(
						state,
						treaty.terms.enemy
					) or "")
					.. " / EXPIRES AT START R"
					.. treaty.endsRound
			)
			text(
				"Ending an agreement early harms trust. Ending an alliance or defensive pact also costs 10 reputation."
			)
			button("END " .. Offers.label(treaty.kind), function()
				ui:command("cancelTreaty", { treatyID = treaty.id })
			end)
		end
	end
	if Scheduler.canAct(state, observer.id) then
		for _, choice in ipairs({
			{ "GREET", "greeting" },
			{ "WARN", "warning" },
			{ "APOLOGIZE", "apologize" },
			{ "DENOUNCE", "denounce" },
		}) do
			button(choice[1], function()
				ui:command("diplomaticTalk", { target = target.id, topic = choice[2] })
			end)
		end
		text(
			"Greetings and apologies have limited, temporary effects. Denouncing is public and costs the target 10 reputation."
		)
		local function offer(kind, values)
			ui:command("diplomaticOffer", { target = target.id, kind = kind, terms = values })
		end
		local war = Diplomacy.war(state, observer.id, target.id)
		if war then
			if not war.endsRound then
				button("PROPOSE PEACE", function()
					offer("peace", { duration = 5 })
				end)
			end
		else
			for _, kind in ipairs({ "openBorders", "commerce", "alliance", "defensivePact" }) do
				text(terms(state, { kind = kind, terms = { duration = 10 } }))
				button("OFFER " .. Offers.label(kind), function()
					offer(kind, { duration = 10 })
				end)
			end
			button("PROMISE TO WITHDRAW", function()
				offer("withdrawal", { by = observer.id })
			end)
			button("REQUEST WITHDRAWAL", function()
				offer("withdrawal", { by = target.id })
			end)
		end
		for _, conflict in ipairs(not war and state.diplomacy.wars or {}) do
			local enemy = conflict.a == observer.id and conflict.b
				or conflict.b == observer.id and conflict.a
			if enemy and enemy ~= target.id then
				button("ASK TO JOIN VS " .. name(state, enemy), function()
					offer("jointWar", { enemy = enemy })
				end)
			end
		end
		ui.trade = ui.trade or { gold = 10, requestGold = 0, giveAmount = 0, askAmount = 0 }
		local trade = ui.trade
		text("TRADE EDITOR / YOUR GOLD " .. (observer.gold or 0), 8)
		for _, entry in ipairs({
			{ "gold", "OFFER GOLD", 10, 1000 },
			{ "requestGold", "REQUEST GOLD", 10, 1000 },
			{ "giveAmount", "OFFER MATERIAL", 1, 99 },
			{ "askAmount", "REQUEST MATERIAL", 1, 99 },
		}) do
			rows[#rows + 1] = {
				adjust = {
					label = entry[2] .. " " .. trade[entry[1]],
					minus = function()
						trade[entry[1]] = math.max(0, trade[entry[1]] - entry[3])
					end,
					plus = function()
						trade[entry[1]] = math.min(entry[4], trade[entry[1]] + entry[3])
					end,
				},
			}
		end
		for _, field in ipairs({ "giveResource", "askResource" }) do
			button(
				(field == "giveResource" and "GIVE " or "ASK ") .. (trade[field] or "NONE"):upper(),
				function()
					local choices, current = { "none" }, 1
					for _, resource in ipairs(Systems.resourceOrder) do
						local technology = Systems.resources[resource].tech
						if not technology or observer.techs[technology] then
							choices[#choices + 1] = resource
						end
					end
					for index, resource in ipairs(choices) do
						if resource == trade[field] then
							current = index
						end
					end
					local selected = choices[current % #choices + 1]
					trade[field] = selected ~= "none" and selected or nil
					trade[field == "giveResource" and "giveAmount" or "askAmount"] = selected
								~= "none"
							and 1
						or 0
				end
			)
		end
		button("SEND TRADE", function()
			offer("trade", {
				gold = trade.gold,
				requestGold = trade.requestGold,
				giveResource = trade.giveResource,
				giveAmount = trade.giveAmount,
				askResource = trade.askResource,
				askAmount = trade.askAmount,
			})
		end)
	end
	if ui.notice and ui.notice ~= "" then
		text(ui.notice, 9)
	end
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 21 },
		rows,
		ui,
		"conversationOffset"
	)
end

return Conversation
