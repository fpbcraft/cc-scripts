local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Memory = dofile("/games/civcraft/diplomatic_memory.lua")
local Offers = dofile("/games/civcraft/diplomatic_offers.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Surface = dofile("/games/civcraft/basalt_surface.lua")
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
	local t = offer.terms or { duration = offer.endsRound - offer.startsRound }
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

local function wrap(value, width)
	local lines, line = {}, ""
	for word in tostring(value):gmatch("%S+") do
		if #line + #word + 1 > width and line ~= "" then
			lines[#lines + 1], line = line, ""
		end
		while #word > width do
			if line ~= "" then
				lines[#lines + 1], line = line, ""
			end
			lines[#lines + 1], word = word:sub(1, width), word:sub(width + 1)
		end
		line = line == "" and word or line .. " " .. word
	end
	lines[#lines + 1] = line
	return lines
end

function Conversation.close(ui)
	if ui.conversationSurface then
		ui.conversationSurface:close()
	end
	ui.conversationSurface, ui.conversationModel = nil, nil
end

function Conversation.back(ui)
	local s = ui.conversationSurface
	if s and s.modal and s.modal.visible then
		s.modal:close()
	else
		Conversation.close(ui)
		ui.panel = "factions"
	end
	return true
end

local function build(ui, rect, targetID)
	local s = Surface.new(ui.r, rect)
	ui.conversationSurface = s
	local c, root, width, height = s.colors, s.root, s.columns, s.rows
	local model = { targetID = targetID, rect = rect, surface = s }
	ui.conversationModel = model
	local function label(parent, value, x, y, w, color)
		return parent:addLabel({
			x = x,
			y = y,
			width = w,
			height = 1,
			text = value,
			foreground = color or c.white,
			background = false,
		})
	end
	local function paragraph(parent, value, x, y, w, color)
		local lines = wrap(value, w)
		for index, line in ipairs(lines) do
			label(parent, line, x, y + index - 1, w, color)
		end
		return #lines
	end
	local function button(parent, title, x, y, w, run)
		local element = parent:addButton({
			x = x,
			y = y,
			width = w,
			height = 1,
			text = title,
			background = c.gray,
			foreground = c.white,
		})
		element:onClick(function()
			run()
		end)
		element:onKey(function(_, key)
			if key == s.keys.enter then
				run()
			end
		end)
		s:register(element, title:upper())
		return element
	end
	local function command(action, request)
		ui:command(action, request)
	end
	local dialog = root:addDialog()
	s.modal = dialog
	local function detail(title, message, actions)
		dialog:close()
		-- Remove obsolete modal controls as well as their widgets.
		for index = #s.controls, 1, -1 do
			if s.controls[index].dialog then
				table.remove(s.controls, index)
			end
		end
		local first = #s.controls + 1
		dialog.visible = true
		local w, h = math.min(width - 2, 64), math.min(height - 2, 18)
		local box = dialog:addFrame({
			x = math.floor((width - w) / 2) + 1,
			y = math.floor((height - h) / 2) + 1,
			width = w,
			height = h,
			background = c.gray,
			foreground = c.white,
		})
		label(box, title, 2, 1, w - 3, c.yellow)
		local body = box:addFrame({
			x = 2,
			y = 3,
			width = w - 3,
			height = h - 5,
			background = false,
			scrollable = true,
		})
		paragraph(body, message, 1, 1, w - 5)
		local choices = {}
		for _, action in ipairs(actions or {}) do
			choices[#choices + 1] = action
		end
		choices[#choices + 1] = {
			"BACK",
			function()
				dialog:close()
			end,
		}
		local slot = math.floor((w - 2) / #choices)
		for index, action in ipairs(choices) do
			button(box, action[1], 2 + (index - 1) * slot, h - 1, slot - 1, action[2])
		end
		for index = first, #s.controls do
			s.controls[index].dialog = true
		end
		root:setFocused(body)
	end
	local function offer(kind, values)
		command("diplomaticOffer", { target = targetID, kind = kind, terms = values })
		dialog:close()
	end
	local function proposal(kind, values)
		detail(Offers.label(kind), terms(ui.state, { kind = kind, terms = values }), {
			{
				"SEND OFFER",
				function()
					offer(kind, values)
				end,
			},
		})
	end
	local function menu(title, options)
		detail(title, "Select an option to review its effects.")
		local children = dialog:getChildren()
		local box = children[#children]
		local list = box:addList({
			x = 2,
			y = 3,
			width = box.width - 4,
			height = box.height - 7,
			background = c.black,
			foreground = c.white,
			emptyText = "No available options",
		})
		for index, option in ipairs(options) do
			list:addItem(option[1])
			s:register(list, option[1]:upper(), function()
				local row = index - list.offset
				return {
					x = 0,
					y = row - 1,
					w = list.width - 1,
					h = 1,
					hidden = row < 1 or row > list.height,
				}
			end)
			s.controls[#s.controls].dialog = true
		end
		s:register(list, title:upper() .. " OPTIONS")
		s.controls[#s.controls].dialog = true
		button(box, "VIEW", 2, box.height - 3, 12, function()
			local choice = options[list:getSelectedIndex() or 1]
			if choice then
				choice[2]()
			end
		end)
		s.controls[#s.controls].dialog = true
		root:setFocused(list)
	end
	model.heading = label(root, "", 2, 1, width - 12, c.yellow)
	button(root, "CLOSE", width - 9, 1, 8, function()
		Conversation.back(ui)
	end)
	model.status = label(root, "", 2, 2, width - 3, c.lightGray)
	local tabs = root:addTabControl({
		x = 2,
		y = 4,
		width = width - 3,
		height = height - 5,
		background = c.black,
		foreground = c.lightGray,
		headerBackground = c.gray,
		activeBackground = c.blue,
		activeForeground = c.white,
	})
	model.tabs = tabs
	local frames, offset = {}, 0
	for _, title in ipairs({ "Talk", "Deals", "Agreements", "Messages" }) do
		local caption = width < 45
				and ({ Talk = "Talk", Deals = "Deal", Agreements = "Pacts", Messages = "Mail" })[title]
			or title
		frames[#frames + 1] = tabs:addTab(caption)
		s:register(tabs, title:upper(), { x = offset, y = 0, w = #caption + 2, h = 1 })
		offset = offset + #caption + 2
	end
	model.notice = label(root, "", 2, height, width - 3, c.yellow)
	local talk = frames[1]
	model.greeting = talk:addLabel({
		x = 2,
		y = 1,
		width = tabs.width - 4,
		height = math.max(1, math.min(4, talk.height - 5)),
		wrap = true,
		background = false,
		foreground = c.white,
		text = "",
	})
	local half = math.floor((tabs.width - 5) / 2)
	local y = math.max(3, talk.height - 2)
	model.actions = {}
	model.actions[#model.actions + 1] = button(talk, "GREET", 2, y, half, function()
		command("diplomaticTalk", { target = targetID, topic = "greeting" })
	end)
	model.actions[#model.actions + 1] = button(talk, "DISCUSS", half + 3, y, half, function()
		local choices = {}
		for _, choice in ipairs({
			{
				"WARN",
				"warning",
				"Warn this civilization about its conduct. This has a limited, temporary effect.",
			},
			{
				"APOLOGIZE",
				"apologize",
				"Offer an apology. Its limited, temporary effect cannot erase serious grievances.",
			},
			{
				"DENOUNCE",
				"denounce",
				"Publicly denounce this civilization. It loses 10 reputation and relations deteriorate.",
			},
		}) do
			choices[#choices + 1] = {
				choice[1],
				function()
					detail(choice[1], choice[3], {
						{
							choice[1],
							function()
								command("diplomaticTalk", { target = targetID, topic = choice[2] })
								dialog:close()
							end,
						},
					})
				end,
			}
		end
		menu("DISCUSS", choices)
	end)
	model.actions[#model.actions + 1] = button(talk, "REQUESTS", 2, y + 2, half, function()
		local options = {}
		if not Diplomacy.war(ui.state, ui.playerID, targetID) then
			options = {
				{
					"PROMISE TO WITHDRAW",
					function()
						proposal("withdrawal", { by = ui.playerID })
					end,
				},
				{
					"REQUEST WITHDRAWAL",
					function()
						proposal("withdrawal", { by = targetID })
					end,
				},
			}
			for _, war in ipairs(ui.state.diplomacy.wars or {}) do
				local enemy = war.a == ui.playerID and war.b or war.b == ui.playerID and war.a
				if enemy and enemy ~= targetID and Contacts.knows(ui.state, ui.playerID, enemy) then
					options[#options + 1] = {
						"JOIN VS " .. name(ui.state, enemy),
						function()
							proposal("jointWar", { enemy = enemy, duration = 10 })
						end,
					}
				end
			end
		end
		menu("REQUESTS", options)
	end)
	button(talk, "RELATIONSHIP", half + 3, y + 2, half, function()
		local d = ui.state.diplomacy
		local their = d.relations[Memory.key(targetID, ui.playerID)] or {}
		local own = d.relations[Memory.key(ui.playerID, targetID)] or {}
		local lines = {
			"Their trust: "
				.. (their.trust or 0)
				.. ". Grievances: "
				.. (their.grievances or 0)
				.. ". Your trust: "
				.. (own.trust or 0)
				.. ". Your grievances: "
				.. (own.grievances or 0)
				.. ". Observed military pressure: "
				.. (own.pressure or 0)
				.. ".",
		}
		for _, memory in ipairs(their.memories or {}) do
			lines[#lines + 1] = "Round " .. memory.round .. ": " .. memory.explanation .. "."
		end
		detail("RELATIONSHIP", table.concat(lines, " "))
	end)
	local dealPage, inputs = frames[2], {}
	local deal = dealPage:addFrame({
		x = 1,
		y = 1,
		width = tabs.width,
		height = dealPage.height - 2,
		background = false,
		scrollable = true,
	})
	ui.trade = ui.trade or { gold = 10, requestGold = 0, giveAmount = 0, askAmount = 0 }
	local resources = { "NONE" }
	local observer = model.observer
	for _, player in ipairs(ui.state.players) do
		if player.id == ui.playerID then
			observer = player
		end
	end
	for _, resource in ipairs(Systems.resourceOrder) do
		local tech = Systems.resources[resource].tech
		if not tech or observer.techs[tech] then
			resources[#resources + 1] = resource
		end
	end
	for side, column in ipairs({
		{ "YOU GIVE", "gold", "giveResource", "giveAmount" },
		{ "THEY GIVE", "requestGold", "askResource", "askAmount" },
	}) do
		local x = side == 1 and 2 or half + 3
		label(deal, column[1] .. " / GOLD", x, 1, half, c.yellow)
		for _, field in ipairs({ { column[2], "GOLD", 2 }, { column[4], "QUANTITY", 6 } }) do
			if field[1] ~= column[2] then
				label(deal, field[2], x, field[3] - 1, half)
			end
			local input = deal:addInput({
				x = x,
				y = field[3],
				width = half,
				height = 1,
				text = tostring(ui.trade[field[1]] or 0),
				pattern = "%d",
				maxLength = 4,
				background = c.gray,
				foreground = c.white,
			})
			input:onChange(function(element)
				ui.trade[field[1]] = tonumber(element.text) or 0
			end)
			inputs[#inputs + 1] = s:register(input, column[1] .. " " .. field[2])
			input.tradeField = field[1]
		end
		label(deal, "MATERIAL", x, 3, half)
		local combo = deal:addDropdown({
			x = x,
			y = 4,
			width = half,
			text = "NONE",
			dropHeight = 3,
			background = c.gray,
			foreground = c.white,
		})
		for _, resource in ipairs(resources) do
			combo:addItem(resource)
		end
		combo:select(1, false)
		combo.tradeChoices = resources
		combo:onSelect(function(_, index)
			local value = resources[index]
			ui.trade[column[3]] = value ~= "NONE" and value or nil
			if not ui.trade[column[3]] then
				ui.trade[column[4]] = 0
			end
			model.restoreTrade = true
		end)
		inputs[#inputs + 1] = s:register(combo, column[1] .. " MATERIAL")
		combo.tradeField = column[3]
		combo.tradeResource = true
	end
	-- The compact canvas has eleven content rows; review stays below the fields.
	local review = button(dealPage, "REVIEW TRADE", 2, dealPage.height, tabs.width - 4, function()
		local draft = {}
		for key, value in pairs(ui.trade) do
			draft[key] = value
		end
		local function send()
			if model.counterID then
				command("diplomaticCounter", { offerID = model.counterID, terms = draft })
				model.counterID = nil
				dialog:close()
			else
				offer("trade", draft)
			end
		end
		detail(
			"REVIEW TRADE",
			terms(ui.state, { kind = "trade", from = ui.playerID, to = targetID, terms = draft }),
			{ { "SEND TRADE", send } }
		)
	end)
	model.actions[#model.actions + 1] = review
	for _, input in ipairs(inputs) do
		model.actions[#model.actions + 1] = input
	end
	local function listPage(frame, title, empty)
		label(frame, title, 2, 1, tabs.width - 4, c.yellow)
		local list = frame:addList({
			x = 2,
			y = 3,
			width = tabs.width - 4,
			height = math.max(1, frame.height - 4),
			background = c.black,
			foreground = c.white,
			emptyText = empty,
			selectionBackground = c.blue,
		})
		s:register(list, title)
		return list
	end
	local agreements, messages = frames[3], frames[4]
	model.agreements = listPage(agreements, "ACTIVE AGREEMENTS", "No agreements in force")
	model.messages = listPage(messages, "PRIVATE MESSAGES", "No exchanges yet")
	button(agreements, "DETAILS", 2, agreements.height, half, function()
		local entry = model.agreementItems[model.agreements:getSelectedIndex() or 1]
		if not entry then
			return
		end
		local actions = {}
		if entry.treaty then
			actions[1] = {
				"END TREATY",
				function()
					detail(
						"END " .. Offers.label(entry.treaty.kind),
						"Ending an agreement early harms trust. Ending an alliance or defensive pact also costs 10 reputation.",
						{
							{
								"CONFIRM",
								function()
									command("cancelTreaty", { treatyID = entry.treaty.id })
									dialog:close()
								end,
							},
						}
					)
				end,
			}
		end
		detail(entry.title, entry.description, actions)
	end)
	model.actions[#model.actions + 1] = button(
		agreements,
		"PROPOSE",
		half + 3,
		agreements.height,
		half,
		function()
			local choices = {}
			local war = Diplomacy.war(ui.state, ui.playerID, targetID)
			for _, kind in
				ipairs(
					war and { "peace" }
						or { "openBorders", "commerce", "alliance", "defensivePact" }
				)
			do
				choices[#choices + 1] = {
					Offers.label(kind),
					function()
						proposal(kind, { duration = kind == "peace" and 5 or 10 })
					end,
				}
			end
			menu("PROPOSE AGREEMENT", choices)
		end
	)
	button(messages, "VIEW MESSAGE", 2, messages.height, tabs.width - 4, function()
		local entry = model.messageItems[model.messages:getSelectedIndex() or 1]
		if not entry then
			return
		end
		local actions = {}
		if entry.to == ui.playerID and entry.status == "pending" then
			for _, reply in ipairs({ "accept", "reject" }) do
				actions[#actions + 1] = {
					reply:upper(),
					function()
						command("diplomaticReply", { offerID = entry.id, response = reply })
						dialog:close()
					end,
				}
			end
			if entry.kind == "trade" then
				actions[#actions + 1] = {
					"COUNTER",
					function()
						local t = entry.terms
						ui.trade = {
							gold = t.requestGold,
							requestGold = t.gold,
							giveResource = t.askResource,
							giveAmount = t.askAmount,
							askResource = t.giveResource,
							askAmount = t.giveAmount,
						}
						model.restoreTrade = true
						model.counterID = entry.id
						dialog:close()
						tabs:setActiveTab(2)
					end,
				}
			end
		end
		detail(
			Offers.label(entry.kind) .. " / " .. entry.status,
			terms(ui.state, entry)
				.. " Expires at start of round "
				.. entry.expiresRound
				.. ". "
				.. (entry.reason or ""),
			actions
		)
	end)
	model.inputs = inputs
	return model
end

local function refreshList(list, entries, old)
	local signature = {}
	for _, entry in ipairs(entries) do
		signature[#signature + 1] = entry.title
	end
	local key = table.concat(signature, "\n")
	if key ~= old then
		local selected, offset = list:getSelectedIndex(), list.offset
		list:clear()
		for _, entry in ipairs(entries) do
			list:addItem(entry.title)
		end
		if selected and #entries > 0 then
			list:selectItem(math.min(selected, #entries), false)
		end
		list:setOffset(offset)
	end
	return key
end

function Conversation.draw(ui, state, observer, rect)
	local cellW, cellH = ui.r.mode == "text" and 2 or 4, ui.r.mode == "text" and 3 or 6
	local w, h = math.min(rect.w, 80 * cellW), math.min(rect.h, 20 * cellH)
	rect = {
		x = rect.x + math.floor((rect.w - w) / 2),
		y = rect.y + math.floor((rect.h - h) / 2),
		w = w,
		h = h,
	}
	if not Contacts.knows(state, observer.id, ui.conversationTarget) then
		Conversation.close(ui)
		ui.panel = "factions"
		return
	end
	local target
	for _, player in ipairs(state.players) do
		if player.id == ui.conversationTarget then
			target = player
		end
	end
	if not target or not state.diplomacy then
		Conversation.close(ui)
		ui.panel = "factions"
		return
	end
	local model = ui.conversationModel
	if
		model
		and (
			model.targetID ~= target.id
			or model.rect.w ~= rect.w
			or model.rect.h ~= rect.h
			or model.rect.x ~= rect.x
			or model.rect.y ~= rect.y
			or model.surface.renderer ~= ui.r
		)
	then
		Conversation.close(ui)
		model = nil
	end
	model = model or build(ui, rect, target.id)
	local d, mood = state.diplomacy, Diplomacy.state(state, observer.id, target.id)
	model.heading.text = "WITH " .. target.name
	local pending = 0
	local messages, agreements = {}, {}
	for index = #(d.offers or {}), 1, -1 do
		local entry = d.offers[index]
		if
			entry.from == observer.id and entry.to == target.id
			or entry.to == observer.id and entry.from == target.id
		then
			messages[#messages + 1] = entry
			if
				messages[#messages].status == "pending"
				and messages[#messages].to == observer.id
			then
				pending = pending + 1
			end
		end
	end
	local messageRows = {}
	for _, entry in ipairs(messages) do
		messageRows[#messageRows + 1] = {
			title = (entry.from == observer.id and "SENT " or "RECEIVED ") .. Offers.label(
				entry.kind
			) .. " / " .. entry.status,
		}
	end
	for _, entry in ipairs(d.treaties or {}) do
		if
			entry.status == "active"
			and (
				entry.a == observer.id and entry.b == target.id
				or entry.b == observer.id and entry.a == target.id
			)
		then
			agreements[#agreements + 1] = {
				title = Offers.label(entry.kind) .. " / UNTIL R" .. (entry.endsRound - 1),
				treaty = entry,
				description = terms(state, entry),
			}
		end
	end
	for _, entry in ipairs(d.promises or {}) do
		if
			entry.by == observer.id and entry.to == target.id
			or entry.to == observer.id and entry.by == target.id
		then
			agreements[#agreements + 1] = {
				title = "WITHDRAWAL / " .. entry.status .. " / BY R" .. entry.deadline,
				description = name(state, entry.by)
					.. " promised to withdraw by end of round "
					.. entry.deadline
					.. ". Status: "
					.. entry.status,
			}
		end
	end
	for _, entry in ipairs(d.armistices or {}) do
		if
			entry.endsRound > state.round
			and (
				entry.a == observer.id and entry.b == target.id
				or entry.b == observer.id and entry.a == target.id
			)
		then
			agreements[#agreements + 1] = {
				title = "ARMISTICE / UNTIL R" .. (entry.endsRound - 1),
				description = "Peace is protected through round "
					.. (entry.endsRound - 1)
					.. ". Surprise war breaks this promise and carries greater penalties.",
			}
		end
	end
	model.messageItems, model.agreementItems = messages, agreements
	model.messageKey = refreshList(model.messages, messageRows, model.messageKey)
	model.agreementKey = refreshList(model.agreements, agreements, model.agreementKey)
	model.status.text = mood
		.. " | "
		.. pending
		.. " PENDING MESSAGE"
		.. (pending == 1 and "" or "S")
	local relation = d.relations[Memory.key(target.id, observer.id)] or {}
	model.greeting.text = target.ai
			and (mood == "WAR" and "We are at war. Bring a peace proposal if you want to end this conflict." or (relation.trust or 0) < -30 and "Past actions have damaged our trust. Pleasant words cannot erase them." or greetings[Personalities.forCivilization(
				target.civ
			).archetype])
		or "Send a private offer. The other player chooses how to respond."
	if model.surface.rows < 15 then
		model.greeting.text = mood == "WAR" and "Do you bring terms for peace?"
			or "What brings you to our people?"
	end
	for _, element in ipairs(model.actions) do
		element.disabled = not Scheduler.canAct(state, observer.id)
	end
	if model.restoreTrade then
		for _, input in ipairs(model.inputs) do
			if input.tradeResource then
				for index, resource in ipairs(input.tradeChoices) do
					if resource == (ui.trade[input.tradeField] or "NONE") then
						input:select(index, false)
					end
				end
			else
				input.text = tostring(ui.trade[input.tradeField] or 0)
			end
		end
		model.restoreTrade = nil
	end
	model.notice.text = ui.notice or ""
	model.surface:draw()
end

return Conversation
