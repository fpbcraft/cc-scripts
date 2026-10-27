--[[
	A yielded host command must finish before another command mutates its state.
	Queue closures belong to the session and are never persisted in game saves.
]]
local CommandQueue = {}

function CommandQueue.new(onIdle)
	local queue = { busy = false, pending = {}, maxPending = 256 }
	function queue:submit(command, notify)
		if #self.pending >= self.maxPending then
			return false, "Host queue full; retry"
		end
		self.pending[#self.pending + 1] = command
		if notify ~= false then
			self.notify = true
		end
		if self.busy then
			return true
		end
		self.busy = true
		local success, reason = pcall(function()
			while #self.pending > 0 do
				local nextCommand = table.remove(self.pending, 1)
				nextCommand()
			end
		end)
		self.busy = false
		if not success then
			self.pending = {}
			self.notify = false
			error(reason, 0)
		end
		local changed = self.notify
		self.notify = false
		if changed and onIdle then
			onIdle()
		end
		return true
	end
	return queue
end

return CommandQueue
