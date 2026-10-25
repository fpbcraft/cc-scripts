--[[
	Manual full-session test for a dedicated CraftOS computer. Save slot 1 is
	overwritten. Rendering and input handling are real. The UI is instrumented to enqueue and
	acknowledge mouse events at actual button coordinates.
]]
local includeAI, includeSettings, includeResearch, includeCampaign = false, false, false, false
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
end
local native = dofile
local stage = 0
local settingsExpectedSpeed, settingsExpectedDisplay
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

dofile = function(path)
	local module = native(path)
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
				self:command("addPlayer")
				self:command("toggleAI", { player = 3 })
				aiConfigured = true
				os.queueEvent("term_resize")
				return
			end
			if includeCampaign and stage == 1 and state.phase == "lobby" and campaignStep < 5 then
				local labels =
					{ "CAMPAIGN OPTIONS", "LENGTH STANDARD", "LENGTH EPIC", "SCORE ON", "CLOSE" }
				if tap(self, labels[campaignStep + 1]) then
					campaignStep = campaignStep + 1
				else
					tap(self, "NEXT")
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
			local label
			if stage == 0 and options.screen == "title" then
				label = "NEW CAMPAIGN"
			elseif stage == 1 and state.phase == "lobby" then
				label = "START GAME"
			elseif stage == 2 and state.phase == "game" and not options.handoff then
				label = "END TURN"
			elseif stage == 3 and self.endConfirm then
				label = "END ANYWAY"
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
local timeout = os.startTimer(20)
local success, reason = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))("local", "--new", "--debug")
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
assert(completed and stage == 11, "Session did not traverse both players and return to round two")
local state = native("/games/civcraft/saves.lua").load(1)
assert(state and state.round == 2 and state.activeIndex == 1 and state.campaignID)
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
	assert(
		state.players[3].ai and state.players[3].aiPlan and state.players[3].aiPlan.version == 1,
		"Native game session must execute and persist the third player's economic AI"
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
	aiPlanReload = includeAI,
	settingsReload = includeSettings,
	researchFlow = includeResearch,
	campaignOptions = includeCampaign,
}))
output.close()
print(
	"CIVCRAFT native session: real mouse queue, full host loop, two hotseat turns, reports, pause, save and exit passed."
)
