--[[
	Retain bounded observer journals, never an unrestricted player-facing log.
	Observer-local sequence numbers conceal even the count of hidden actions.
]]
local VisibilityEvents = dofile("/games/civcraft/visibility_events.lua")
local MAX_EVENTS = 128
local MAX_ROUNDS = 8
local Events = { version = 1, maxEvents = MAX_EVENTS, maxRounds = MAX_ROUNDS }

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

local function trim(entries, round)
	while #entries > MAX_EVENTS or entries[1] and entries[1].round < round - MAX_ROUNDS do
		table.remove(entries, 1)
	end
end

local function journal(state)
	if not state.eventJournal then
		state.eventJournal = { version = Events.version, order = 0, streams = {} }
	end
	assert(state.eventJournal.version == Events.version, "Unsupported action-event journal version")
	return state.eventJournal
end

function Events.emit(state, event)
	local storage = journal(state)
	storage.order = storage.order + 1
	for _, player in ipairs(state.players or {}) do
		local projected = VisibilityEvents.project(event, player.id)
		if projected then
			local stream = storage.streams[player.id]
			if not stream then
				stream = { seq = 0, entries = {} }
				storage.streams[player.id] = stream
			end
			stream.seq = stream.seq + 1
			projected.version = Events.version
			projected.seq = stream.seq
			projected.round = state.round or 1
			stream.entries[#stream.entries + 1] = copy(projected)
			trim(stream.entries, state.round or 1)
		end
	end
end

function Events.move(state, unit)
	return {
		type = "move",
		actor = VisibilityEvents.actor(unit),
		autoExplore = unit.executingAutoExplore == true,
		frames = { VisibilityEvents.frame(state, unit) },
	}
end

function Events.step(event, state, unit)
	event.frames[#event.frames + 1] = VisibilityEvents.frame(state, unit)
end

function Events.notice(state, kind, entity, content, recipient)
	Events.emit(state, {
		type = kind,
		actor = VisibilityEvents.actor(entity),
		target = entity and VisibilityEvents.frame(state, entity),
		content = content,
		recipient = recipient,
	})
end

function Events.prune(state)
	for _, stream in pairs(state.eventJournal and state.eventJournal.streams or {}) do
		trim(stream.entries, state.round or 1)
	end
end

function Events.forPlayer(state, observer, afterSeq)
	local registered = false
	for _, player in ipairs(state.players or {}) do
		if player.id == observer then
			registered = true
		end
	end
	if not registered then
		return nil
	end
	local stream = state.eventJournal and state.eventJournal.streams[observer]
	local lastSeq = stream and stream.seq or 0
	local cursor = math.max(0, math.floor(tonumber(afterSeq) or 0))
	local entries = {}
	local firstSeq = lastSeq + 1
	for _, entry in ipairs(stream and stream.entries or {}) do
		if entry.round >= (state.round or 1) - MAX_ROUNDS then
			firstSeq = math.min(firstSeq, entry.seq)
			if entry.seq > cursor then
				entries[#entries + 1] = copy(entry)
			end
		end
	end
	return {
		version = Events.version,
		observer = observer,
		campaign = state.campaignID or "legacy",
		firstSeq = firstSeq,
		lastSeq = lastSeq,
		truncated = cursor < firstSeq - 1,
		entries = entries,
	}
end

function Events.merge(previous, incoming, round)
	if not incoming or incoming.version ~= Events.version then
		return previous
	end
	local result = copy(incoming)
	if
		previous
		and previous.campaign == incoming.campaign
		and previous.observer == incoming.observer
		and incoming.lastSeq >= previous.lastSeq
	then
		local entries = copy(previous.entries)
		local cursor = previous.lastSeq
		for _, entry in ipairs(incoming.entries) do
			if entry.seq > cursor then
				entries[#entries + 1] = copy(entry)
			end
		end
		result.entries = entries
		result.lastSeq = math.max(previous.lastSeq, incoming.lastSeq)
		result.truncated = previous.truncated or incoming.truncated
	end
	trim(result.entries, round or 1)
	result.firstSeq = result.entries[1] and result.entries[1].seq or result.lastSeq + 1
	return result
end

return Events
