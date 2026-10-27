--[[
	Transport sequencing is separate from private action journal sequencing.
	A reconnect window is merged before acknowledgement so fast snapshots cannot
	wipe events before the presentation loop has seen them.
]]
local Events = dofile("/games/civcraft/events.lua")
local Snapshots = {}
local function isSequence(value)
	return type(value) == "number" and value >= 0 and value % 1 == 0 and value < math.huge
end

local function validStream(stream, observer)
	if
		type(stream) ~= "table"
		or stream.version ~= Events.version
		or stream.observer ~= observer
		or type(stream.campaign) ~= "string"
		or type(stream.entries) ~= "table"
		or not isSequence(stream.lastSeq)
		or #stream.entries > Events.maxEvents
	then
		return false
	end
	local previous = 0
	for _, event in ipairs(stream.entries) do
		if
			type(event) ~= "table"
			or event.version ~= Events.version
			or not isSequence(event.seq)
			or event.seq <= previous
			or event.seq > stream.lastSeq
			or not isSequence(event.round)
			or type(event.type) ~= "string"
		then
			return false
		end
		previous = event.seq
	end
	return true
end

function Snapshots.sender(session)
	local serials = {}
	return function(observer, state)
		serials[observer] = (serials[observer] or 0) + 1
		return { type = "state", session = session, serial = serials[observer], state = state }
	end
end

function Snapshots.receiver()
	local receiver = { serial = 0, retired = {}, retiredOrder = {} }
	function receiver:accept(packet, observer)
		if type(packet.state) ~= "table" then
			return nil
		end
		if self.session and self.session ~= "legacy" and packet.session == nil then
			return nil
		end
		if packet.session ~= nil and packet.serial == nil then
			return nil
		end
		if packet.state.round ~= nil and not isSequence(packet.state.round) then
			return nil
		end
		local session = packet.session or "legacy"
		local serial = packet.serial or self.serial + 1
		if
			type(session) ~= "string"
			or type(serial) ~= "number"
			or serial % 1 ~= 0
			or serial < 1
		then
			return nil
		end
		local stream = packet.state.eventStream
		if stream and not validStream(stream, observer) then
			return nil
		end
		if self.retired[session] or session == self.session and serial <= self.serial then
			return nil
		end
		if self.session and session ~= self.session then
			self.retired[self.session] = true
			self.retiredOrder[#self.retiredOrder + 1] = self.session
			if #self.retiredOrder > 8 then
				self.retired[table.remove(self.retiredOrder, 1)] = nil
			end
		end
		local previous = self.stream
		if self.session ~= session then
			previous = nil
		end
		self.session, self.serial = session, serial
		self.stream = Events.merge(previous, stream, packet.state.round)
		packet.state.snapshotSession = session
		packet.state.eventStream = self.stream
		return packet.state, self.stream and self.stream.lastSeq
	end
	return receiver
end

return Snapshots
