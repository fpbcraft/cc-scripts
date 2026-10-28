--[[
	Retain bounded observer journals, never an unrestricted player-facing log.
	Observer-local sequence numbers conceal even the count of hidden actions.
]]
local VisibilityEvents = dofile("/games/civcraft/visibility_events.lua")
local Summary = dofile("/games/civcraft/event_summary.lua")
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

local function history(stream)
	if not stream.history then
		stream.history = { version = 1, entries = {} }
		for _, entry in ipairs(stream.entries or {}) do
			stream.history.entries[#stream.history.entries + 1] = Summary.compact(entry)
		end
	end
	assert(stream.history.version == 1, "Unsupported event history version")
	return stream.history.entries
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
			local archive = history(stream)
			stream.seq = stream.seq + 1
			projected.version = Events.version
			projected.seq = stream.seq
			projected.round = state.round or 1
			stream.entries[#stream.entries + 1] = copy(projected)
			archive[#archive + 1] = Summary.compact(projected)
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

function Events.site(state, city, record)
	Events.emit(state, {
		type = "site",
		actor = VisibilityEvents.actor({ id = record.id, kind = record.kind, owner = city.owner }),
		target = VisibilityEvents.frame(state, { x = record.x, y = record.y, owner = city.owner }),
		content = record.kind,
		specialty = {
			cityId = city.id,
			siteId = record.id,
			sourceSiteId = record.sourceSiteId,
			kind = record.kind,
			x = record.x,
			y = record.y,
		},
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

-- Compact history persists independently of replay retention; only one bounded page is transmitted.
function Events.history(state, observer, beforeSeq, limit)
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
	local entries = stream and history(stream) or {}
	local lastSeq = stream and stream.seq or 0
	local cursor = tonumber(beforeSeq) or lastSeq + 1
	if cursor ~= cursor then
		cursor = lastSeq + 1
	end
	cursor = math.max(1, math.min(lastSeq + 1, math.floor(cursor)))
	limit = math.max(1, math.min(50, math.floor(tonumber(limit) or 20)))
	local low, high = 1, #entries + 1
	while low < high do
		local middle = math.floor((low + high) / 2)
		if entries[middle].seq < cursor then
			low = middle + 1
		else
			high = middle
		end
	end
	local result = {
		observer = observer,
		campaign = state.campaignID or "legacy",
		before = cursor,
		lastSeq = lastSeq,
		entries = {},
		missingEarlier = entries[1] ~= nil and entries[1].seq > 1,
	}
	for index = low - 1, math.max(1, low - limit), -1 do
		result.entries[#result.entries + 1] = copy(entries[index])
	end
	if low - limit > 1 then
		result.nextBefore = entries[low - limit].seq
	end
	return result
end

function Events.historyReply(state, sender, request)
	if
		type(request) ~= "table"
		or request.campaignID ~= state.campaignID
		or type(request.requestID) ~= "number"
		or request.requestID % 1 ~= 0
		or request.requestID < 0
		or request.requestID > 1000000000
	then
		return nil
	end
	local page = Events.history(state, sender, request.before)
	if not page then
		return nil
	end
	return { type = "eventHistory", requestID = request.requestID, history = page }
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
