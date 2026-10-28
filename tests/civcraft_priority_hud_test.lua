local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
colors = colors
	or {
		black = 32768,
		white = 1,
		gray = 128,
		lightGray = 256,
		orange = 2,
		lightBlue = 8,
		yellow = 16,
		green = 8192,
		blue = 2048,
		lime = 32,
		red = 16384,
		brown = 4096,
	}

local HUD = dofile("/games/civcraft/hud.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Contacts = dofile("/games/civcraft/contacts.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local UI = dofile("/games/civcraft/ui.lua")

local originalEconomy = Systems.economy
Systems.economy = function()
	return { net = 1, science = 12, food = 2309, industry = 5407, strategic = {} }
end
local resourceText = {}
local resourceRenderer = {
	w = 320,
	buttons = {},
	textWidth = function(_, value)
		return #tostring(value) * 4
	end,
	text = function(_, _, _, value)
		resourceText[#resourceText + 1] = tostring(value)
	end,
	fill = function() end,
	withClip = function(_, _, draw)
		draw()
	end,
}
HUD.resources({ r = resourceRenderer }, { players = {} }, { gold = 50, techs = {} })
local resourceBar = table.concat(resourceText, " ")
assert(not resourceBar:find("2309", 1, true), "Aggregate food is absent from the global bar")
assert(not resourceBar:find("5407", 1, true), "Aggregate industry is absent from the global bar")
Systems.economy = originalEconomy

local function fixture()
	local world =
		{ width = 14, height = 10, tiles = {}, resources = {}, rails = {}, landmarks = {} }
	for y = 1, world.height do
		for x = 1, world.width do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local state = {
		version = 6,
		phase = "game",
		ruleset = "create",
		round = 2,
		nextId = 20,
		world = world,
		players = {
			{
				id = 1,
				name = "PLAYER ONE",
				civ = "forge",
				techs = {},
				gold = 50,
				contacts = { [2] = true, [4] = true },
			},
			{
				id = 2,
				name = "PLAYER TWO",
				civ = "merchant",
				techs = {},
				gold = 50,
				contacts = { [3] = true },
			},
			{
				id = 3,
				name = "SECRET THREE",
				civ = "iron",
				techs = {},
				gold = 98765,
				aiPlan = { primary = "SECRET PLAN" },
				contacts = {},
			},
			{ id = 4, name = "PLAYER FOUR", civ = "scholar", techs = {}, gold = 50, contacts = {} },
		},
		cities = {
			{ id = 10, owner = 1, x = 4, y = 4, population = 2, buildings = {} },
		},
		units = {},
		diplomacy = Diplomacy.new(),
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	state.players[1].contacts = { [2] = true, [4] = true }
	state.players[2].contacts = { [3] = true }
	return state
end

local function contactMetadata(state, id)
	for _, player in ipairs(state.players) do
		if player.id == id then
			return "CONTACT " .. player.name .. " / " .. Systems.civ(player.civ, state).name
		end
	end
end

local function contactRenderer(width)
	return {
		w = width,
		buttons = {},
		textWidth = function(_, value)
			return #tostring(value) * 4
		end,
		button = function(self, x, y, w, h, label, fn)
			self.buttons[#self.buttons + 1] = {
				x = x,
				y = y,
				w = w,
				h = h,
				label = label,
				fn = fn,
			}
		end,
		fill = function() end,
	}
end

local state = fixture()
local compact = { r = contactRenderer(200), panel = "context" }
local layout = HUD.contacts(compact, state, state.players[1], 10, 55)
assert(layout.count == 2 and layout.shown == 1 and layout.overflow == 1)
assert(compact.r.buttons[1].label == contactMetadata(state, 2))
assert(compact.r.buttons[2].label == "MORE KNOWN CIVILIZATIONS (1)")
compact.r.buttons[2].fn()
assert(compact.panel == "factions", "The overflow affordance opens all known contacts")
local observer = { r = contactRenderer(200), panel = "context" }
assert(HUD.contacts(observer, state, { name = "OBSERVER" }, 10, 55).count == 0)
assert(#observer.r.buttons == 0, "Observer views do not get another player's contacts")

local originalYieldValue = Icons.yieldValue
local activeRenderer
local localYields, topYields = {}, {}
Icons.yieldValue = function(renderer, kind, value, x, y, ...)
	if renderer == activeRenderer and (kind == "food" or kind == "wood") then
		if y <= 21 then
			topYields[kind] = value
		else
			localYields[kind] = value
		end
	end
	return originalYieldValue(renderer, kind, value, x, y, ...)
end

local function monitor(width, height, graphics)
	local result = {
		getSize = function(mode)
			if mode == 2 then
				return width * 6, height * 9
			end
			return width, height
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
	}
	if graphics then
		result.setGraphicsMode = function() end
		result.drawPixels = function() end
	else
		result.setCursorPos = function() end
		result.setBackgroundColor = function() end
		result.setTextColor = function() end
		result.write = function() end
	end
	return result
end

local function draw(ui, state, playerID)
	if os and os.queueEvent and os.pullEvent then
		os.queueEvent("priority_hud_test_yield")
		os.pullEvent("priority_hud_test_yield")
	end
	ui:draw(state, playerID, { screen = "game" })
end

local function button(ui, label)
	for _, candidate in ipairs(ui.r.buttons) do
		if candidate.label == label then
			return candidate
		end
	end
end

local function tap(ui, candidate)
	local x, y
	if ui.r.mode == "text" then
		x = math.floor((candidate.x + candidate.w / 2) / 2) + 1
		y = math.floor((candidate.y + candidate.h / 2) / 3) + 1
	else
		x = math.floor(ui.r.ox + (candidate.x + candidate.w / 2) * ui.r.sx)
		y = math.floor(ui.r.oy + (candidate.y + candidate.h / 2) * ui.r.sy)
	end
	return ui:tap(x, y)
end

local commands = 0
local wideState = fixture()
local wideUI = UI.new(monitor(200, 67, true), function()
	commands = commands + 1
end)
wideUI.selected = { x = 4, y = 4, kind = "city" }
activeRenderer = wideUI.r
local wideText = {}
local originalText = wideUI.r.text
wideUI.r.text = function(self, x, y, value, ...)
	wideText[#wideText + 1] = tostring(value)
	return originalText(self, x, y, value, ...)
end
local expected = Systems.yields(wideState.players[1], wideState.cities[1], wideState, Hex)
draw(wideUI, wideState, 1)
assert(topYields.food == nil and topYields.wood == nil, "The top strip omits aggregate city yields")
assert(localYields.food == expected.food, "The selected city still renders its food yield")
assert(localYields.wood == expected.industry, "The selected city still renders its industry yield")
assert(
	table.concat(wideText, " "):find(
		Systems.civ(wideState.players[2].civ, wideState).name .. " / " .. wideState.players[2].name,
		1,
		true
	),
	"Wide touch layouts display civilization and player names together"
)

local function checkGeometry(ui)
	for index, current in ipairs(ui.r.buttons) do
		assert(
			current.x >= 0
				and current.y >= 0
				and current.x + current.w <= ui.r.w
				and current.y + current.h <= ui.r.h,
			"HUD button is outside the viewport: " .. tostring(current.label)
		)
		for prior = 1, index - 1 do
			local other = ui.r.buttons[prior]
			local overlaps = current.x < other.x + other.w
				and other.x < current.x + current.w
				and current.y < other.y + other.h
				and other.y < current.y + current.h
			assert(
				not overlaps,
				"HUD buttons overlap: " .. tostring(current.label) .. " / " .. tostring(other.label)
			)
		end
	end
end

local function exerciseContacts(width, height, graphics, longHeader)
	local currentState = fixture()
	if longHeader then
		currentState.players[1].name = string.rep("LONG PLAYER HEADER ", 12)
	end
	local ui = UI.new(monitor(width, height, graphics), function()
		commands = commands + 1
	end)
	local headerCall
	if longHeader then
		local originalText = ui.r.text
		ui.r.text = function(self, x, y, value, color, scale, maxWidth)
			if y == 3 and tostring(value):find("LONG PLAYER HEADER", 1, true) then
				headerCall = { value = tostring(value), maxWidth = maxWidth }
			end
			return originalText(self, x, y, value, color, scale, maxWidth)
		end
	end
	draw(ui, currentState, 1)
	checkGeometry(ui)
	if longHeader and graphics and width >= 80 then
		local fullHeader = "R2 "
			.. currentState.players[1].name
			.. " / "
			.. Systems.ages[Systems.age(currentState.players[1])].name
		assert(headerCall, "A long active-player name is rendered in the wide header")
		assert(
			headerCall.maxWidth < ui.r:textWidth(fullHeader),
			"Long player and age text are clipped to reserve contact space"
		)
	end
	local overflowBadge
	for _, candidate in ipairs(ui.r.buttons) do
		if candidate.label and candidate.label:find("^MORE KNOWN CIVILIZATIONS") then
			overflowBadge = candidate
			break
		end
	end
	local knownBadge = button(ui, contactMetadata(currentState, 2))
		or overflowBadge
		or button(ui, "KNOWN CIVILIZATIONS")
	assert(
		knownBadge,
		"A compact layout keeps a known-contact or overflow button visible at " .. width
	)
	local visible = {}
	for _, candidate in ipairs(ui.r.buttons) do
		visible[#visible + 1] = candidate.label
	end
	local joined = table.concat(visible, " ")
	assert(
		joined:find(contactMetadata(currentState, 2), 1, true)
			or joined:find("MORE KNOWN CIVILIZATIONS", 1, true)
			or button(ui, "FACTIONS")
	)
	assert(not joined:find("SECRET THREE", 1, true) and not joined:find("SECRET PLAN", 1, true))
	local direct = button(ui, contactMetadata(currentState, 2))
	if direct then
		tap(ui, direct)
		assert(ui.panel == "conversation" and ui.conversationTarget == 2)
		assert(
			ui.playerID == 1 and commands == 0,
			"Opening a contact never dispatches as the other player"
		)
		ui.panel, ui.conversationTarget = "context", nil
		draw(ui, currentState, 1)
	end

	local factions = button(ui, "FACTIONS")
	assert(factions, "The compact toolbar keeps the known-civilization list reachable")
	tap(ui, factions)
	assert(ui.panel == "factions")
	local reached = {}
	for _ = 1, 48 do
		draw(ui, currentState, 1)
		for _, candidate in ipairs(ui.r.buttons) do
			if candidate.label:find("TALK PLAYER TWO", 1, true) then
				reached[2] = true
			elseif candidate.label:find("TALK PLAYER FOUR", 1, true) then
				reached[4] = true
			end
		end
		if reached[2] and reached[4] then
			break
		end
		local nextPage = button(ui, "NEXT")
		if not nextPage then
			break
		end
		tap(ui, nextPage)
	end
	assert(
		reached[2] and reached[4],
		"Every known civilization remains reachable on compact screens"
	)
	local talk = button(ui, "TALK PLAYER TWO") or button(ui, "TALK PLAYER FOUR")
	if talk then
		tap(ui, talk)
		assert(
			ui.panel == "conversation"
				and (ui.conversationTarget == 2 or ui.conversationTarget == 4)
		)
		assert(ui.playerID == 1 and commands == 0)
	end

	-- Hotseat/network views use only the active observer's own recorded contacts.
	draw(ui, currentState, 2)
	local secondPlayerLabels = {}
	for _, candidate in ipairs(ui.r.buttons) do
		secondPlayerLabels[#secondPlayerLabels + 1] = candidate.label
	end
	local secondPlayerText = table.concat(secondPlayerLabels, " ")
	assert(not secondPlayerText:find(contactMetadata(currentState, 4), 1, true))
	local thirdContact = button(ui, contactMetadata(currentState, 3))
	assert(thirdContact or button(ui, "FACTIONS"), "The active player's contacts stay reachable")
	if not thirdContact then
		local factions = button(ui, "FACTIONS")
		assert(factions, "Hotseat contacts remain available through Factions on narrow screens")
		tap(ui, factions)
		for _ = 1, 48 do
			draw(ui, currentState, 2)
			thirdContact = button(ui, "TALK SECRET THREE")
			if thirdContact then
				break
			end
			local nextPage = button(ui, "NEXT")
			if not nextPage then
				break
			end
			tap(ui, nextPage)
		end
	end
	assert(
		thirdContact,
		"The active player's known civilization can be contacted on a compact screen"
	)
	tap(ui, thirdContact)
	assert(ui.panel == "conversation" and ui.conversationTarget == 3 and ui.playerID == 2)
	assert(commands == 0, "Contact navigation remains local to the active player")

	-- A read-only observer has no civilization identity, so no contact strip is shown.
	draw(ui, currentState, 99)
	for _, candidate in ipairs(ui.r.buttons) do
		assert(not candidate.label:find("TALK ", 1, true))
	end
	ui:close()
end

exerciseContacts(51, 19, false, true)
exerciseContacts(57, 26, true)
exerciseContacts(80, 40, true, true)
exerciseContacts(100, 67, true)
wideUI:close()
Icons.yieldValue = originalYieldValue

print(
	"CIVCRAFT: global food/industry removed from the top strip; city yields and private per-player contact navigation pass."
)
