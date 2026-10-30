-- Shared watchdog checkpoints preserve input while long host work yields.
local Cooperative = {}
local function emitTrace(self, stage, detail)
	if self.trace then
		local ok = pcall(self.trace, stage, detail)
		if not ok then
			self.traceFailures = (self.traceFailures or 0) + 1
		end
	end
end
local function collectNative(self, now)
	local host = _G._HOST
	if
		type(host) ~= "string"
		or host:match("CraftOS%-PC v([%d.]+)") ~= "2.8.3"
		or self.gcUnsupported
		or type(collectgarbage) ~= "function"
		or now - (self.lastGC or -math.huge) < 30
	then
		return
	end
	-- This runtime can spend seconds repeatedly marking short-lived snapshots.
	-- A full cycle between cooperative chunks avoids that incremental-GC thrash.
	if self.trace then
		emitTrace(self, "gc.begin", self.yieldToken)
	end
	local started = os.epoch("utc")
	local ok = pcall(collectgarbage, "collect")
	local elapsed = os.epoch("utc") - started
	if self.trace then
		emitTrace(self, "gc.end", "elapsed=" .. elapsed .. " ok=" .. tostring(ok))
	end
	self.gcUnsupported = not ok
	self.lastGC = os.epoch("utc")
	if ok then
		self.gcCycles = (self.gcCycles or 0) + 1
		self.gcMaxMillis = math.max(self.gcMaxMillis or 0, elapsed)
	end
end
function Cooperative.checkpoint(self, force, probe)
	if not (os.epoch and os.queueEvent and os.pullEvent) then
		return
	end
	self.work = (self.work or 0) + 1
	if not force and not probe and self.work % 128 ~= 0 then
		return
	end
	local now = os.epoch("utc")
	self.lastYield = self.lastYield or now
	if not force and now - self.lastYield < 30 then
		return
	end
	self.yieldToken = (self.yieldToken or 0) + 1
	local token = self.yieldToken
	if self.trace then
		emitTrace(self, "yield.begin", token)
	end
	collectNative(self, now)
	local timer = os.startTimer and os.startTimer(0.05)
	os.queueEvent("civcraft_render_yield", token)
	if self.trace then
		emitTrace(self, "yield.wait.begin", token)
	end
	local waiting = os.epoch("utc")
	local queued = 0
	local reason = "sentinel"
	while true do
		local event = table.pack(os.pullEvent())
		if event[1] == "civcraft_render_yield" and event[2] == token then
			break
		end
		if timer and event[1] == "timer" and event[2] == timer then
			reason = "timer"
			if self.trace then
				emitTrace(self, "yield.timeout", token)
			end
			break
		end
		self.pendingEvents = self.pendingEvents or {}
		self.pendingEvents[#self.pendingEvents + 1] = event
		queued = queued + 1
	end
	if self.trace then
		emitTrace(
			self,
			"yield.wait.end",
			"token="
				.. token
				.. " elapsed="
				.. (os.epoch("utc") - waiting)
				.. " reason="
				.. reason
				.. " queued="
				.. queued
				.. " pending="
				.. #(self.pendingEvents or {})
		)
	end
	if timer and os.cancelTimer then
		os.cancelTimer(timer)
	end
	self.lastYield = os.epoch("utc")
	if self.trace then
		emitTrace(self, "yield.end", token)
	end
end
return Cooperative
