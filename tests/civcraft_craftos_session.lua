--[[
	Manual full-session test for a dedicated CraftOS computer. Save slot 1 is
	overwritten. Rendering and input handling are real. The UI is instrumented to enqueue and
	acknowledge mouse events at actual button coordinates.
]]
local includeAI, includeSettings, includeResearch, includeCampaign = false, false, false, false
local includeWar = false
local includeHost = false
local includeConversation = false
for _, argument in ipairs({ ... }) do
	if argument == "--ai" then
		includeAI = true
	end
	if argument == "--settings" then
		includeSettings = true
	end
	if argument == "--research" then
		includeResearch = true
	end
	if argument == "--campaign" then
		includeCampaign = true
	end
	if argument == "--war" then
		includeWar = true
	end
	if argument == "--host-ai" then
		includeHost, includeAI = true, true
	end
	if argument == "--conversation" then
		includeConversation, includeAI = true, true
	end
end
assert(
	not (includeHost and includeWar),
	"The host AI scenario has one human; use hotseat for defender reactions"
)
local native = dofile
local stage = 0
local settingsExpectedSpeed, settingsExpectedDisplay
local responseSaved = false
local renderer
local queued = false
local function tap(view, label)
	for _, button in ipairs(view.r.buttons) do
		if button.label == label then
			local x, y = button.x + button.w / 2, button.y + button.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			local px, py = math.floor(x), math.floor(y)
			local vx, vy = view.r:touch(px, py)
			local hits = {}
			for _, candidate in ipairs(view.r.buttons) do
				if
					vx
					and vx >= candidate.x
					and vx < candidate.x + candidate.w
					and vy >= candidate.y
					and vy < candidate.y + candidate.h
				then
					hits[#hits + 1] = tostring(candidate.label)
				end
			end
			local trace = assert(fs.open("/session-input.log", "a"))
			local available = {}
			for _, candidate in ipairs(view.r.buttons) do
				available[#available + 1] = candidate.label
			end
			trace.writeLine(textutils.serialize({
				stage = stage,
				techSelected = view.techModel and view.techModel.selected,
				techOffset = view.techModel and view.techModel.offset,
				techPageMax = view.techModel and view.techModel.pageMax,
				available = available,
				label = label,
				mode = view.r.mode,
				width = view.r.w,
				height = view.r.h,
				x = px,
				y = py,
				vx = vx,
				vy = vy,
				hits = hits,
			}))
			trace.close()
			queued = true
			os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
			os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
			os.queueEvent("civcraft_test_input_complete")
			return true
		end
	end
	return false
end

local function completeDecisions(view)
	if view.panel == "context" then
		local label = view:turnAction()
		if tap(view, label) then
			return label == "END TURN"
		end
	elseif view.panel == "inspector" then
		if view.selected.kind == "unit" then
			if not tap(view, "SKIP TURN") then
				tap(view, "NEXT")
			end
		else
			local resolved = false
			for _, city in ipairs(view.state.cities) do
				if city.x == view.selected.x and city.y == view.selected.y then
					resolved = city.productionIdle or city.project
				end
			end
			if resolved then
				tap(view, "CLOSE")
			elseif not tap(view, "NO PRODUCTION") then
				tap(view, "NEXT")
			end
		end
	elseif view.panel == "tech" then
		local researching = false
		for _, player in ipairs(view.state.players) do
			if player.id == view.playerID then
				researching = player.researchTarget
			end
		end
		if researching then
			tap(view, "CLOSE")
		elseif view.techModel and view.techModel.detail then
			if not tap(view, "RESEARCH") then
				tap(view, "NEXT")
			end
		elseif
			not tap(view, "RESEARCH")
			and not tap(view, "DETAILS")
			and not tap(view, "DETAILS / CODEX")
		then
			tap(view, "WHEAT FARMING")
		end
	end
	return false
end

dofile = function(path)
	local module = native(path)
	if path == "/games/civcraft/world.lua" and (includeConversation or includeWar) then
		local generate = module.generate
		module.generate = function(...)
			local world = generate(...)
			-- A contact scenario: nearby capitals are actually seen by normal revelation.
			-- No contact flags or diplomacy validation are bypassed.
			local positions =
				{ { x = 4, y = 6 }, { x = 6, y = 6 }, { x = 5, y = 8 }, { x = 7, y = 8 } }
			for index = 1, #world.starts do
				world.starts[index] = positions[index]
			end
			for y = 4, 10 do
				for x = 3, 9 do
					world.tiles[module.key(x, y)] = "plains"
				end
			end
			return world
		end
	end
	if path ~= "/games/civcraft/ui.lua" then
		return module
	end
	local construct = module.new
	module.new = function(display, dispatch)
		local view = construct(display, dispatch)
		local pull = view.r.pullEvent
		view.r.pullEvent = function(canvas)
			local event = table.pack(pull(canvas))
			if event[1] == "civcraft_test_input_complete" then
				queued = false
				os.queueEvent("term_resize")
			end
			return (table.unpack or unpack)(event, 1, event.n)
		end
		local draw = view.draw
		local aiConfigured = false
		local settingsStep = 0
		local researchStep = 0
		local campaignStep = 0
		local warStep, responseStep = 0, 0
		local conversationStep = 0
		view.draw = function(self, state, observer, options)
			draw(self, state, observer, options)
			renderer = self.r.mode
			if queued then
				return
			end
			if
				includeSettings
				and stage == 0
				and options.screen == "title"
				and settingsStep < 5
			then
				local label
				if settingsStep == 0 then
					settingsExpectedDisplay = self.animationPreferences.display
					label = "SETTINGS"
				elseif settingsStep == 1 then
					settingsExpectedSpeed = ({ normal = "fast", fast = "off", off = "normal" })[self.animationPreferences.speed]
					label = "ANIMATIONS " .. self.animationPreferences.speed:upper()
				elseif settingsStep == 2 then
					label = "DISPLAY " .. self.animationPreferences.display:upper()
				elseif settingsStep == 3 then
					label = "DISPLAY " .. self.animationPreferences.display:upper()
				else
					label = "CLOSE"
				end
				if tap(self, label) then
					settingsStep = settingsStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeAI and not aiConfigured and stage == 1 and state.phase == "lobby" then
				if includeHost then
					if tap(self, "+ AI") then
						aiConfigured = true
					else
						tap(self, "NEXT")
					end
				else
					self:command("addPlayer")
					self:command("toggleAI", { player = 3 })
					aiConfigured = true
					os.queueEvent("term_resize")
				end
				return
			end
			if includeCampaign and stage == 1 and state.phase == "lobby" and campaignStep < 5 then
				local labels =
					{ "CAMPAIGN OPTIONS", "LENGTH STANDARD", "LENGTH EPIC", "SCORE ON", "CLOSE" }
				if tap(self, labels[campaignStep + 1]) then
					campaignStep = campaignStep + 1
				else
					tap(self, campaignStep == 0 and "PREV" or "NEXT")
				end
				return
			end
			if self.panel == "recap" and not options.handoff then
				tap(self, "SKIP")
				return
			end
			if
				state.phase == "game"
				and not options.paused
				and not options.handoff
				and self.panel == "report"
			then
				tap(self, "CLOSE")
				return
			end
			if includeResearch and stage == 2 and not options.handoff and researchStep < 8 then
				local labels = {
					"TECH TREE",
					"agriculture",
					"DETAILS",
					"CODEX WHEAT FARM",
					"CLOSE",
					"TECH TREE",
					"RESEARCH",
					"CLOSE",
				}
				local label = labels[researchStep + 1]
				if tap(self, label) or label == "DETAILS" and tap(self, "DETAILS / CODEX") then
					researchStep = researchStep + 1
				else
					tap(self, label == "RESEARCH" and "PREV" or "NEXT")
				end
				return
			end
			if
				includeConversation
				and stage == 2
				and not options.handoff
				and conversationStep < 14
			then
				local labels = {
					"FACTIONS",
					includeHost and "TALK AI 2" or "TALK PLAYER 3",
					"GREET",
					"AGREEMENTS",
					"PROPOSE",
					"COMMERCE",
					"VIEW",
					"SEND OFFER",
					"DEALS",
					"REVIEW TRADE",
					"SEND TRADE",
					"TALK",
					"CLOSE",
					"CLOSE",
				}
				if tap(self, labels[conversationStep + 1]) then
					conversationStep = conversationStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeWar and stage == 5 and not options.handoff and warStep < 3 then
				local labels = { "FACTIONS", "SURPRISE WAR: " .. state.players[1].name, "CLOSE" }
				if tap(self, labels[warStep + 1]) then
					warStep = warStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeWar and stage == 7 and state.round == 1 then
				local label = options.handoff and "READY TO PLAY"
					or responseStep == 1 and "PAUSE"
					or options.paused and responseStep == 2 and "SAVE"
					or options.paused and responseStep == 3 and "RESUME"
					or self.endConfirm and "END ANYWAY"
					or "END TURN"
				if options.paused and responseStep == 3 then
					local saved = native("/games/civcraft/saves.lua").load(1)
					assert(
						saved.round == 1
							and saved.players[1].ready
							and saved.scheduler.reactions[saved.players[1].id],
						"Mid-response save retains the Ready defender's window"
					)
					responseSaved = true
				end
				if not options.handoff then
					assert(
						state.players[1].ready and state.scheduler.reactions[state.players[1].id],
						"Ended defender must receive an unspent-action response before the round closes"
					)
				end
				if label == "END TURN" then
					if completeDecisions(self) then
						responseStep = responseStep + 1
					end
				elseif tap(self, label) then
					responseStep = responseStep + 1
				end
				return
			end
			if
				(stage == 2 or stage == 5)
				and state.phase == "game"
				and not options.handoff
				and not options.paused
			then
				if completeDecisions(self) then
					stage = stage + 2
				end
				return
			end
			local label
			if stage == 0 and options.screen == "title" then
				label = "NEW CAMPAIGN"
			elseif stage == 1 and state.phase == "lobby" then
				label = "START GAME"
			elseif stage == 2 and state.phase == "game" and not options.handoff then
				label = "END TURN"
			elseif stage == 3 and self.endConfirm then
				label = "END ANYWAY"
			elseif includeHost and stage == 4 and state.round == 2 then
				label = "PAUSE"
			elseif includeHost and stage == 5 and options.paused then
				label = "SAVE"
			elseif includeHost and stage == 6 and options.paused then
				label = "EXIT"
			elseif stage == 4 and options.handoff then
				label = "READY TO PLAY"
			elseif stage == 5 and not options.handoff then
				label = "END TURN"
			elseif stage == 6 and self.endConfirm then
				label = "END ANYWAY"
			elseif stage == 7 and options.handoff and state.round == 2 then
				label = "READY TO PLAY"
			elseif stage == 8 and not options.handoff and state.round == 2 then
				if self.panel == "report" then
					tap(self, "CLOSE")
					return
				end
				label = "PAUSE"
			elseif stage == 9 and options.paused then
				label = "SAVE"
			elseif stage == 10 and options.paused then
				label = "EXIT"
			end
			if label and tap(self, label) then
				stage = stage + 1
			elseif label then
				tap(self, "NEXT")
			end
		end
		return view
	end
	return module
end
local completed = false
local timeout = os.startTimer(45)
local success, reason = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))(
			includeHost and "host" or "local",
			"--new",
			"--debug"
		)
		completed = true
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == timeout then
				error("Native game session timed out at stage " .. stage)
			end
		end
	end)
end)
dofile = native
if term.setGraphicsMode then
	pcall(term.setGraphicsMode, 0)
end
assert(success, reason)
assert(
	completed and stage == (includeHost and 7 or 11),
	"Session did not complete its turns and return to round two"
)
local state
if includeHost then
	local file = assert(fs.open("/games/civcraft/data/save.dat", "r"))
	state = textutils.unserialize(file.readAll())
	file.close()
else
	state = native("/games/civcraft/saves.lua").load(1)
end
assert(
	state
		and state.round == 2
		and (includeHost or state.activeIndex == (includeWar and 2 or 1))
		and state.campaignID
)
if includeWar then
	assert(responseSaved, "The native response scenario must save during the response window")
	assert(
		#state.diplomacy.wars == 1 and state.diplomacy.wars[1].active,
		"Native Surprise War must survive response, round rotation and save reload"
	)
	assert(
		state.scheduler.groups[1].active == state.players[2].id,
		"The defending group's starting player rotates at the global boundary"
	)
end
if includeCampaign then
	assert(
		state.gameSpeed == "quick" and state.roundLimit == 120 and state.victories.score == false,
		"Native lobby options must survive round processing and save reload"
	)
	assert(state.players[1].gameSpeed == "quick", "The campaign pace must reach gameplay costs")
end
if includeResearch then
	assert(
		state.players[1].researchTarget == "agriculture" or state.players[1].techs.agriculture,
		"Native graph, details and Codex flow must preserve the selected research order"
	)
end
if includeAI then
	local ai = state.players[includeHost and 2 or 3]
	assert(
		ai.ai and ai.aiPlan and ai.aiPlan.version == 1,
		"Native game session must execute and persist the third player's economic AI"
	)
end
if includeConversation then
	local acceptedTrade, commerce = false, false
	for _, offer in ipairs(state.diplomacy.offers) do
		acceptedTrade = acceptedTrade or offer.kind == "trade" and offer.status == "accepted"
	end
	for _, treaty in ipairs(state.diplomacy.treaties) do
		commerce = commerce or treaty.kind == "commerce" and treaty.status == "active"
	end
	assert(
		acceptedTrade and commerce,
		"Native conversations must execute their actual trade and commerce terms"
	)
end
if includeSettings then
	local preferences = native("/games/civcraft/animation_preferences.lua").load()
	assert(
		preferences.display == settingsExpectedDisplay
			and preferences.speed == settingsExpectedSpeed,
		"Native settings must persist across renderer recreation"
	)
end

for _, participant in ipairs(state.players) do
	if not participant.ai then
		assert(
			participant.researchTarget or next(participant.techs),
			"Human turn workflow assigns research"
		)
		local skipped = false
		for _, unit in ipairs(state.units) do
			if unit.owner == participant.id and unit.skippedTurn then
				skipped = true
			end
		end
		assert(skipped, "Human turn workflow saves the actual Skip Turn order")
		for _, city in ipairs(state.cities) do
			if city.owner == participant.id then
				assert(city.project or city.productionIdle, "Human cities resolve production")
			end
		end
	end
end
local Events = native("/games/civcraft/events.lua")
assert(Events.forPlayer(state, state.players[1].id).lastSeq > 0)
assert(Events.forPlayer(state, state.players[2].id).lastSeq > 0)
local output = assert(fs.open("/civcraft-native-session.txt", "w"))
output.write(textutils.serialize({
	host = _G._HOST,
	renderer = renderer,
	stages = stage,
	round = state.round,
	saveReload = true,
	turnTasks = true,
	aiPlanReload = includeAI,
	settingsReload = includeSettings,
	researchFlow = includeResearch,
	campaignOptions = includeCampaign,
	warResponse = includeWar,
	responseSaved = responseSaved,
	hostModeAI = includeHost,
	conversationFlow = includeConversation,
}))
output.close()
print(
	"CIVCRAFT native session: real mouse queue, full host loop, two hotseat turns, reports, pause, save and exit passed."
)
