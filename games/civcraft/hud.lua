local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local CouncilRules = dofile("/games/civcraft/council_rules.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local FactionColors = dofile("/games/civcraft/faction_colors.lua")
local H = {}
local function compact(value)
	value = math.floor(value or 0)
	if math.abs(value) >= 1000 then
		return (value < 0 and "-" or "") .. math.floor(math.abs(value) / 1000) .. "K"
	end
	return tostring(value)
end
local function rate(value)
	value = value or 0
	return (value > 0 and "+" or "") .. compact(value)
end
local function stock(value, change)
	return compact(value) .. ((change or 0) ~= 0 and rate(change) or "")
end
local function unlocked(player, kind)
	local technology = (Systems.resources[kind] or {}).tech
	return not technology or (player.techs or {})[technology] == true
end
function H.resources(ui, state, player)
	local r = ui.r
	local economy = Systems.economy(player, state)
	ui.economy = economy
	local x = 4
	r:withClip({ x = 4, y = 14, w = r.w - 8, h = 7 }, function()
		for _, entry in ipairs({
			{ "gold", stock(player.gold or 20, economy.net) },
			{ "science", rate(economy.science) },
		}) do
			local width = Icons.yieldValue(r, entry[1], entry[2], x, 15)
			x = x + width + 3
		end
		for _, kind in ipairs(Systems.resourceOrder) do
			if unlocked(player, kind) then
				Icons.resource(r, kind, x, 15)
				local value = stock((player.stockpile or {})[kind], economy.strategic[kind])
				r:text(x + 6, 15, value, 7)
				x = x + 7 + r:textWidth(value) + 3
			end
		end
	end)
	r.buttons[#r.buttons + 1] = {
		x = 4,
		y = 14,
		w = r.w - 8,
		h = 7,
		label = "RESOURCE LEDGER",
		fn = function()
			ui.panel = "resources"
			ui.resourceOffset = 0
		end,
	}
end

local function contactLabel(state, player)
	local civ = Systems.civ(player.civ, state)
	local name = civ and civ.name or player.name or ("CIV " .. tostring(player.id))
	local label = name:upper():gsub("%s+", ""):sub(1, 3)
	return label, name
end

local function openFactions(ui)
	ui.panel, ui.factionOffset = "factions", 0
end

local function openConversation(ui, player)
	-- Match the existing FACTIONS > TALK transition.
	ui.conversationTarget, ui.conversationOffset, ui.panel = player.id, 0, "conversation"
end

local function knownContacts(state, observer)
	local contacts = {}
	if observer and observer.id ~= nil then
		for index, player in ipairs(state.players or {}) do
			if player.id ~= observer.id and Contacts.knows(state, observer.id, player.id) then
				local label, name = contactLabel(state, player)
				contacts[#contacts + 1] = {
					player = player,
					label = label,
					name = name,
					color = FactionColors.players[index] or 32,
				}
			end
		end
	end
	return contacts
end

function H.contactCount(state, observer)
	if not observer or observer.id == nil then
		return 0
	end
	local count = 0
	for _, player in ipairs(state.players or {}) do
		if player.id ~= observer.id and Contacts.knows(state, observer.id, player.id) then
			count = count + 1
		end
	end
	return count
end

function H.contacts(ui, state, observer, left, right)
	local r = ui.r
	local contacts = knownContacts(state, observer)
	if #contacts == 0 then
		return { count = 0, shown = 0 }
	end

	local minimumWidth, buttonHeight, gap = 26, 12, 2
	left, right = math.floor(left or 1), math.floor(right or r.w)
	local available = math.max(0, right - left + 1)
	local fullWidth = #contacts * minimumWidth + (#contacts - 1) * gap
	local shown = #contacts
	local overflow = false
	local overflowWidth
	if fullWidth > available then
		overflow = true
		local overflowLabel = "+" .. #contacts
		overflowWidth = math.max(16, r:textWidth(overflowLabel) + 6)
		shown = math.min(
			#contacts,
			math.max(0, math.floor((available - overflowWidth) / (minimumWidth + gap)))
		)
		if available < overflowWidth and available >= 10 then
			local width = math.min(available, 14)
			r:button(left, 1, width, buttonHeight, "C", function()
				openFactions(ui)
			end)
			r.buttons[#r.buttons].label = "KNOWN CIVILIZATIONS"
			return { count = #contacts, shown = 0, overflow = #contacts }
		end
	end
	local reserved = overflow and (overflowWidth + (shown > 0 and gap or 0)) or 0
	local extra =
		math.max(0, available - reserved - shown * minimumWidth - math.max(0, shown - 1) * gap)
	local x = left
	for index = 1, shown do
		local contact = contacts[index]
		local combined = contact.name .. " / " .. contact.player.name
		local combinedWidth = r:textWidth(combined) + 8
		local civWidth = r:textWidth(contact.name) + 8
		local cap = minimumWidth + math.floor(extra / (shown - index + 1))
		local label, width = contact.label, minimumWidth
		if combinedWidth <= cap then
			label, width = combined, combinedWidth
		elseif civWidth <= cap then
			label, width = contact.name, civWidth
		end
		r:button(
			x,
			1,
			width,
			buttonHeight,
			label,
			function()
				openConversation(ui, contact.player)
			end,
			{ selected = ui.panel == "conversation" and ui.conversationTarget == contact.player.id }
		)
		r:fill(x + 2, 3, 2, 8, contact.color)
		r.buttons[#r.buttons].label = "CONTACT " .. contact.player.name .. " / " .. contact.name
		extra = math.max(0, extra - (width - minimumWidth))
		x = x + width + gap
	end
	if overflow then
		local hidden = #contacts - shown
		local label = "+" .. hidden
		local width = math.max(16, r:textWidth(label) + 6)
		if x + width - 1 <= right then
			r:button(x, 1, width, buttonHeight, label, function()
				openFactions(ui)
			end)
			r.buttons[#r.buttons].label = "MORE KNOWN CIVILIZATIONS (" .. hidden .. ")"
		end
	end
	return { count = #contacts, shown = shown, overflow = #contacts - shown }
end

function H.ledger(ui, rect, player)
	local r = ui.r
	local e = Systems.economy(player, ui.state)
	r:fill(rect.x, rect.y, rect.w, rect.h, 1)
	r:outline(rect.x, rect.y, rect.w, rect.h, 8)
	r:text(rect.x + 4, rect.y + 4, "EMPIRE RESOURCES", 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local rows = {}
	local victories = {}
	for _, victory in ipairs(CampaignRules.victories) do
		if CampaignRules.enabled(ui.state, victory) then
			victories[#victories + 1] = victory:upper()
		end
	end
	for _, line in
		ipairs(Panels.wrap(r, "VICTORIES: " .. table.concat(victories, ", "), rect.w - 20))
	do
		rows[#rows + 1] = { text = line }
	end
	rows[#rows + 1] = { text = "LENGTH: " .. (ui.state.gameSpeed or "standard"):upper() }
	for _, entry in ipairs({
		{
			"GOLD",
			compact(player.gold or 20) .. (e.net ~= 0 and " (" .. rate(e.net) .. "/TURN)" or ""),
		},
		{ "SCIENCE", rate(e.science) .. "/TURN" },
		{ "FOOD", rate(e.food) .. "/TURN" },
		{ "INDUSTRY", rate(e.industry) .. "/TURN" },
		{ "GOLD INCOME", rate(e.income) .. "/TURN" },
		{ "UNIT UPKEEP", rate(-e.upkeep) .. "/TURN" },
	}) do
		for _, line in ipairs(Panels.wrap(r, entry[1] .. " " .. entry[2], rect.w - 20)) do
			rows[#rows + 1] = { text = line }
		end
	end
	for _, kind in ipairs(Systems.resourceOrder) do
		if unlocked(player, kind) then
			local change = e.strategic[kind] or 0
			rows[#rows + 1] = {
				text = kind:upper()
					.. " "
					.. ((player.stockpile or {})[kind] or 0)
					.. (change ~= 0 and " (" .. rate(change) .. "/TURN)" or ""),
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "TRADE "
							.. CouncilRules.exchangeCost(ui.state)
							.. " GOLD FOR 1 "
							.. kind:upper(),
						run = function()
							ui:command("exchange", { resource = kind })
						end,
					},
				},
			}
		end
	end
	rows[#rows + 1] = { text = "AGE: " .. Systems.ages[Systems.age(player)].name }
	local victory = dofile("/games/civcraft/victory.lua").status(ui.state, player)
	if ContentRules.isRedesign(ui.state) and CampaignRules.enabled(ui.state, "conquest") then
		local capitals = 0
		for _, city in ipairs(ui.state.cities) do
			if city.owner == player.id and city.capitalOf ~= nil then
				capitals = capitals + 1
			end
		end
		rows[#rows + 1] =
			{ text = "CONQUEST: " .. capitals .. "/" .. #ui.state.players .. " CAPITALS" }
	end
	if not ContentRules.isRedesign(ui.state) then
		rows[#rows + 1] = {
			text = "INDUSTRIAL: "
				.. victory.industryTurns
				.. "/"
				.. victory.industryTarget
				.. " ROUNDS; "
				.. victory.connected
				.. " LINKED CITIES",
		}
	end
	rows[#rows + 1] = { text = "END EXPEDITION: " .. (player.endStage or 0) .. "/3 PROJECTS" }
	rows[#rows + 1] =
		{ text = "SCORE " .. victory.score .. " / DEADLINE ROUND " .. (ui.state.roundLimit or 90) }
	for _, rival in ipairs(ui.state.players) do
		if rival.id ~= player.id then
			rows[#rows + 1] = {
				text = rival.name
					.. ": AGE "
					.. (rival.age or Systems.age(rival))
					.. (not ContentRules.isRedesign(ui.state) and (", INDUSTRY " .. (rival.industryTurns or 0) .. "/" .. victory.industryTarget) or "")
					.. ", END "
					.. (rival.endStage or 0)
					.. "/3",
			}
		end
	end
	rows[#rows + 1] = { text = "Gold pays unit upkeep each round." }
	rows[#rows + 1] = { text = "Unpaid units are disbanded." }
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 21 },
		rows,
		ui,
		"resourceOffset"
	)
end
return H
