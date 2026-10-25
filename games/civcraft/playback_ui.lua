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
	playback.automatic = true
	local visible = state and state.phase == "game" and not opts.handoff and opts.screen ~= "title"
	local now = os.epoch and os.epoch("utc") / 1000 or os.clock()
	local stream = state and state.eventStream
	local baseline = stream
			and stream.campaign == playback.campaign
			and stream.observer == playback.observer
			and playback.cursor
		or 0
	playback:ingest(state and state.eventStream, function()
		return true
	end, visible)
	if not visible then
		if state and state.phase == "game" and playback.deferredSeq == nil then
			playback.deferredSeq = baseline
		end
		playback:skip()
		playback:setPaused(true, now)
		ui.animationFrame = nil
		return
	end
	if playback.awaitingRecap or playback.deferredSeq ~= nil then
		local events = {}
		local baseline = playback.awaitingRecap and playback.lastTurnSeq or playback.deferredSeq
		for _, event in ipairs(playback.feed) do
			if event.seq > (baseline or 0) and event.type ~= "order" then
				events[#events + 1] = event
			end
		end
		playback:play(events)
		playback.awaitingRecap, playback.deferredSeq = false, nil
	end
	local ready = not opts.paused
		and not ui.settingsOpen
		and ui.panel == "context"
		and not ui.productionConfirm
		and not ui.endConfirm
		and not ui.disbandConfirm
	playback:setPaused(not ready, now)
	ui.animationTime = now
	ui.animationFrame = ready and playback:frame(now, state.round) or nil
	if
		ui.animationFrame
		and ui.animationFrame.event
		and ui.lastPlaybackEvent ~= ui.animationFrame.event
	then
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
