-- Bounded real-mainloop UI and queue observation. This is not a 40-round opening study.
local nativeDofile = dofile
local fixedSeed = 319497
local recordPath = "/opening-observation.jsonl"
local started = os.epoch("utc")
local stage = "boot"
local samples = { draws = 0, maximumDrawMillis = 0, commands = {}, inputs = {} }
local viewportBefore
local function record(kind, fields)
	fields = fields or {}
	fields.kind, fields.stage, fields.sinceStartMillis = kind, stage, os.epoch("utc") - started
	local file = assert(fs.open(recordPath, "a"))
	file.writeLine(textutils.serializeJSON(fields))
	file.close()
end
local function input(view, label)
	for _, button in ipairs(view.r.buttons or {}) do
		if button.label == label then
			local x, y = button.x + button.w / 2, button.y + button.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
			os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
			record("mouse_button", { label = label, x = x, y = y, backend = view.r.mode })
			return true
		end
	end
	return false
end

dofile = function(path)
	local module = nativeDofile(path)
	if path == "/games/civcraft/match_lifecycle.lua" then
		local newLobby = module.newLobby
		module.newLobby = function(...)
			local lobby = newLobby(...)
			lobby.contentRules, lobby.mapSeed, lobby.mapSize, lobby.mapType = "balance5", fixedSeed, "compact", "continents"
			return lobby
		end
	elseif path == "/games/civcraft/ui.lua" then
		local construct = module.new
		module.new = function(display, dispatch)
			local view = construct(display, function(action, params)
				local before = os.epoch("utc")
				local ok, result = dispatch(action, params)
				local elapsed = os.epoch("utc") - before
				samples.commands[#samples.commands + 1] = elapsed
				record("ui_command_dispatch", {
					action = action,
					elapsedMillis = elapsed,
					measurement = "dispatch through return; local host queue is synchronous",
				})
				return ok, result
			end)
			local draw = view.draw
			view.draw = function(self, state, observer, options)
				local before = os.epoch("utc")
				local result = draw(self, state, observer, options)
				local elapsed = os.epoch("utc") - before
				samples.draws = samples.draws + 1
				samples.maximumDrawMillis = math.max(samples.maximumDrawMillis, elapsed)
				record("frame_draw", { elapsedMillis = elapsed, panel = self.panel, screen = options.screen, backend = self.r.mode })
				if state and not samples.metadata then
					samples.metadata = true
					record("campaign_metadata", {
						sourceRevision = _G.__openingSourceRevision or "record in harness output",
						profile = state.contentRules or "baseline",
						mapSeed = state.mapSeed,
						mapSize = state.mapSize,
						mapType = state.mapType,
						playerCount = #state.players,
						runtime = _G._HOST,
						lua = _VERSION,
						width = self.r.w,
						height = self.r.h,
					})
				end
				if (stage == "title" or stage == "new-campaign-menu") and options.screen == "title" then
					if self.titleMenu == "main" and input(self, "NEW CAMPAIGN") then
						stage = "new-campaign-menu"
					elseif self.titleMenu == "new" and input(self, "CREATE CAMPAIGN") then
						stage = "lobby"
					end
				elseif (stage == "lobby" or stage == "lobby-ai-added") and state.phase == "lobby" then
					local aiCount = 0
					for _, player in ipairs(state.players) do
						if player.ai then
							aiCount = aiCount + 1
						end
					end
					if aiCount == 0 and input(self, "+ AI") then
						stage = "lobby-ai-added"
					elseif aiCount > 0 and input(self, "START GAME") then
						stage = "map-opening"
					end
				elseif stage == "map-opening" and state.phase == "game" then
					stage = "ui-sample"
					record("opening_state", {
						round = state.round,
						cities = #state.cities,
						units = #state.units,
						profile = state.contentRules,
					})
					if self.mapViewport then
						local beforeX, beforeY, beforeZoom = self.panX, self.panY, self.zoomLevel
					local x, y = self.r.w / 2, self.r.h / 2
					local sx, sy = x / 2 + 1, y / 3 + 1
					if self.r.mode == "graphics" then
						sx, sy = self.r.ox + x * self.r.sx, self.r.oy + y * self.r.sy
					end
					viewportBefore = { x = beforeX, y = beforeY, zoom = beforeZoom, since = os.epoch("utc") }
					os.queueEvent("mouse_scroll", 1, math.floor(sx), math.floor(sy))
					os.queueEvent("mouse_click", 1, math.floor(sx), math.floor(sy))
					os.queueEvent("mouse_drag", 1, math.floor(sx + 2), math.floor(sy + 1))
					os.queueEvent("mouse_up", 1, math.floor(sx + 2), math.floor(sy + 1))
					record("viewport_input_queued", { panX = beforeX, panY = beforeY, zoom = beforeZoom, note = "mouse wheel, click-drag, release; subsequent frame records resulting state" })
					end
				elseif stage == "ui-sample" and samples.draws > 8 then
					stage = "sample-complete"
					samples.sampleComplete = true
					record("bounded_ui_sample_complete", {
						draws = samples.draws,
						maximumFrameMillis = samples.maximumDrawMillis,
						commands = #samples.commands,
						note = "No turn/milestone or release-budget conclusion; bounded UI sample only",
					})
					os.queueEvent("key", keys.q)
				elseif viewportBefore then
					record("viewport_frame_result", {
						elapsedMillis = os.epoch("utc") - viewportBefore.since,
						panX = self.panX,
						panY = self.panY,
						zoom = self.zoomLevel,
						previousPanX = viewportBefore.x,
						previousPanY = viewportBefore.y,
						previousZoom = viewportBefore.zoom,
					})
					viewportBefore = nil
				elseif stage == "sample-complete" and options.paused then
					input(self, "EXIT")
					stage = "exit-requested"
				end
				return result
			end
			return view
		end
	end
	return module
end

record("workflow_begin", {
	fixedSeed = fixedSeed,
	profile = "Specialization V5",
	mapSize = "compact",
	mapType = "continents",
	players = "1 human + 1 AI (created through lobby UI)",
	milestoneFlow = "pending; this driver measures only lobby/map UI and command dispatch",
})
local success, reason = pcall(function()
	assert(loadfile("/games/civcraft/game.lua", "t", _ENV))("local", "--new", "--debug")
end)
dofile = nativeDofile
record("workflow_end", { success = success, reason = success and nil or tostring(reason), sampleComplete = samples.sampleComplete == true })
assert(success, reason)
