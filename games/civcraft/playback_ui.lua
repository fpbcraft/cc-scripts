local Animations = dofile("/games/civcraft/animations.lua")
local Preferences = dofile("/games/civcraft/animation_preferences.lua")
local Playback = {}

function Playback.attach(ui)
	ui.animationPreferences = Preferences.load()
	ui.observerPlayback = {}
end

function Playback.command(ui, action)
	local preferences = ui.animationPreferences
	if action == "animationSpeed" then
		preferences.speed = ({ normal = "fast", fast = "off", off = "normal" })[preferences.speed]
	elseif action == "reducedMotion" then
		preferences.reducedMotion = not preferences.reducedMotion
	elseif action == "automaticPlayback" then
		preferences.automatic = not preferences.automatic
	elseif action == "skipPlayback" then
		if ui.playback then
			ui.playback:skip()
		end
		ui.animationFrame = nil
		return true
	else
		return false
	end
	Preferences.save(preferences)
	return true
end

function Playback.summary(event)
	local actor = event.actor
	local name = actor and (actor.name or actor.kind) or ""
	local result = event.result or {}
	local label = result.captured and "CAPTURE" or event.type:upper()
	local point = event.target
		or event.start
		or event.paths and event.paths[1] and event.paths[1][1]
	return label
		.. " "
		.. name
		.. (event.content and " " .. event.content or "")
		.. (point and " @ " .. point.x .. "," .. point.y or "")
end

local function onscreen(ui, event)
	local viewport = ui.mapViewport
	if not viewport then
		return false
	end
	local function contains(point)
		if not point then
			return false
		end
		local x = (point.x - 0.5 + ((point.y - 1) % 2) * 0.5) * viewport.tile - ui.panX
		local y = ((point.y - 1) * 0.75 + 0.5) * viewport.tile - ui.panY
		return x >= 0 and y >= 0 and x <= viewport.w and y <= viewport.h
	end
	if contains(event.target) or contains(event.start) then
		return true
	end
	for _, path in ipairs(event.paths or {}) do
		for _, point in ipairs(path) do
			if contains(point) then
				return true
			end
		end
	end
	return false
end

function Playback.update(ui, state, observer, opts)
	local key = observer or "lobby"
	local playback = ui.observerPlayback[key]
	if not playback then
		playback = Animations.new()
		ui.observerPlayback[key] = playback
	end
	ui.playback = playback
	ui.localPlayback = opts.localMode == true
	local preferences = ui.animationPreferences
	playback:setSpeed(preferences.reducedMotion and "off" or preferences.speed)
	playback.automatic = preferences.automatic
	local visible = state
		and state.phase == "game"
		and not opts.handoff
		and not opts.paused
		and opts.screen ~= "title"
	local switching = ui.playbackObserver ~= observer or ui.playbackConcealed
	playback:ingest(state and state.eventStream, function(event)
		return onscreen(ui, event)
	end, visible and not switching and ui.panel == "context")
	ui.playbackObserver, ui.playbackConcealed = observer, not visible
	if not visible then
		playback:skip()
		ui.animationFrame = nil
		return
	end
	if ui.localPlayback and playback.awaitingRecap then
		local events = {}
		for _, event in ipairs(playback.feed) do
			if event.seq > (playback.lastTurnSeq or 0) and event.type ~= "order" then
				events[#events + 1] = event
			end
		end
		ui.recap = #events > 0
				and { observer = observer, campaign = playback.campaign, events = events }
			or nil
		playback.awaitingRecap = false
	end
	ui.animationTime = os.epoch and os.epoch("utc") / 1000 or os.clock()
	ui.animationFrame = playback:frame(ui.animationTime, state.round)
	if ui.animationFrame.event and ui.lastPlaybackEvent ~= ui.animationFrame.event then
		ui.lastPlaybackEvent = ui.animationFrame.event
		ui:feedback(Playback.summary(ui.animationFrame.event))
	end
end

function Playback.endTurn(ui)
	if ui.localPlayback and ui.playback then
		ui.playback.lastTurnSeq = ui.playback.cursor
		ui.playback.awaitingRecap = true
		ui.playback:skip()
	end
end

function Playback.watch(ui, events, follow)
	if not ui.playback then
		return
	end
	ui.playback:play(events)
	ui.panel = "context"
	if follow and events[1] then
		local event = events[1]
		local point = event.start
			or event.target
			or event.paths and event.paths[1] and event.paths[1][1]
		local viewport = ui.mapViewport
		if point and viewport then
			ui.panX = (point.x - 0.5 + ((point.y - 1) % 2) * 0.5) * viewport.tile - viewport.w / 2
			ui.panY = ((point.y - 1) * 0.75 + 0.5) * viewport.tile - viewport.h / 2
		end
	end
end

return Playback
