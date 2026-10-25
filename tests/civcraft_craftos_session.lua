--[[
	Manual full-session test for a dedicated CraftOS computer. Save slot 1 is
	overwritten. Rendering and input handling are real. The UI is instrumented to enqueue and
	acknowledge mouse events at actual button coordinates.
]]
local includeAI = ... == "--ai"
local native = dofile
local stage = 0
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
			trace.writeLine(textutils.serialize({
				stage = stage,
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
		view.draw = function(self, state, observer, options)
			draw(self, state, observer, options)
			renderer = self.r.mode
			if queued then
				return
			end
			if includeAI and not aiConfigured and stage == 1 and state.phase == "lobby" then
				self:command("addPlayer")
				self:command("toggleAI", { player = 3 })
				aiConfigured = true
				os.queueEvent("term_resize")
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
if includeAI then
	assert(
		state.players[3].ai and state.players[3].aiPlan and state.players[3].aiPlan.version == 1,
		"Native game session must execute and persist the third player's economic AI"
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
}))
output.close()
print(
	"CIVCRAFT native session: real mouse queue, full host loop, two hotseat turns, reports, pause, save and exit passed."
)
