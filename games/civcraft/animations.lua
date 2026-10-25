-- Presentation timing consumes only frozen observer events, never simulation data.
local Frame = dofile("/games/civcraft/animation_frame.lua")
local Animations = { maxPending = 32, maxFeed = 128, maxRounds = 8 }
local visual = {
	move = true,
	combat = true,
	cityStrike = true,
	impact = true,
	activity = true,
	found = true,
	disband = true,
	spawn = true,
	wonder = true,
	landmark = true,
	research = true,
}

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

local function lowPriority(event)
	return event.type == "move" or event.type == "order"
end

local function trim(list, limit)
	while #list > limit do
		local index = 1
		for i, event in ipairs(list) do
			if lowPriority(event) then
				index = i
				break
			end
		end
		table.remove(list, index)
	end
end

Animations.identity = Frame.identity

function Animations.new()
	local self = { speed = "normal", automatic = true, feed = {}, pending = {}, cursor = 0 }
	function self:skip()
		self.pending = {}
		self.active = nil
	end
	function self:setSpeed(speed)
		assert(speed == "normal" or speed == "fast" or speed == "off", "Invalid animation speed")
		self.speed = speed
		if speed == "off" then
			self:skip()
		end
	end
	function self:ingest(stream, onscreen, live)
		if not stream then
			return
		end
		if
			self.campaign ~= stream.campaign
			or self.observer ~= stream.observer
			or stream.lastSeq < self.cursor
		then
			self:skip()
			self.feed, self.cursor = {}, 0
		end
		self.campaign, self.observer = stream.campaign, stream.observer
		for _, event in ipairs(stream.entries or {}) do
			if event.seq > self.cursor then
				self.feed[#self.feed + 1] = copy(event)
				if
					live
					and self.automatic
					and self.speed ~= "off"
					and visual[event.type]
					and onscreen(event)
				then
					self.pending[#self.pending + 1] = copy(event)
				end
			end
		end
		self.cursor = stream.lastSeq
		trim(self.feed, Animations.maxFeed)
		trim(self.pending, Animations.maxPending)
	end
	function self:play(events)
		self:skip()
		if self.speed == "off" then
			return
		end
		for _, event in ipairs(events) do
			if visual[event.type] then
				self.pending[#self.pending + 1] = copy(event)
			end
		end
		table.sort(self.pending, function(a, b)
			return a.seq < b.seq
		end)
		trim(self.pending, Animations.maxPending)
	end
	function self:frame(now, round)
		-- Advance by elapsed wall time, without blocking simulation or replaying old frames.
		now = math.max(now, self.lastTime or now)
		self.lastTime = now
		for _, list in ipairs({ self.feed, self.pending }) do
			while list[1] and list[1].round < (round or 1) - Animations.maxRounds do
				table.remove(list, 1)
			end
		end
		if self.active and self.active.event.round < (round or 1) - Animations.maxRounds then
			self.active = nil
		end
		if self.active and now >= self.active.finish then
			self.active = nil
		end
		if not self.active and #self.pending > 0 and self.speed ~= "off" then
			local event = table.remove(self.pending, 1)
			local rate = self.speed == "fast" and 2 or 1
			rate = rate * math.min(3, 1 + #self.pending / 8)
			local seconds = Frame.duration(event) / rate
			self.active = { event = event, start = now, finish = now + seconds }
		end
		local frame = { hidden = {}, sprites = {}, effects = {} }
		if self.active then
			for _, event in ipairs(self.pending) do
				frame.hidden[Frame.identity(event.actor) or "none"] = true
				frame.hidden[Frame.identity(event.defender) or "none"] = true
			end
			local active = self.active
			frame.event = active.event
			frame.progress = (now - active.start) / (active.finish - active.start)
			Frame.paint(frame, active.event, frame.progress)
		end
		return frame, self.active ~= nil
	end
	return self
end

return Animations
