-- Optional pixel framebuffer for the FPB Canvas graphics backend.
-- Draws logical pixels in Lua, then flushes dirty scanlines as strings via
-- CraftOS-PC / CC:Graphics drawPixels. Text-mode canvases are untouched.
local B = {}

local function rounded(v)
	local n = math.floor(v + 0.5)
	if math.abs(v - n) > 0.0001 then
		return nil
	end
	return n
end

function B.attach(canvas)
	if canvas.mode ~= "graphics" or not canvas.m.drawPixels then
		return canvas
	end
	local scaleX, scaleY = rounded(canvas.sx), rounded(canvas.sy)
	if not scaleX or not scaleY or scaleX < 1 or scaleY < 1 or scaleX > 4 or scaleY > 4 then
		return canvas -- Odd-sized emulator windows retain the existing backend.
	end

	local device = canvas.m
	local oldResize = canvas.resize
	local oldClose = canvas.close
	local black = string.char(0)
	local glyphs = {}
	if scaleX > 1 then
		for n = 0, 255 do
			local char = string.char(n)
			glyphs[char] = char:rep(scaleX)
		end
	end

	local function setup(self)
		local sx, sy = rounded(self.sx), rounded(self.sy)
		if sx ~= scaleX or sy ~= scaleY then
			return false
		end
		self.fbClearRow = black:rep(self.w)
		self.fbRows = {}
		self.fbPrevious = nil
		-- Clear only when the framebuffer is installed or resized, not per frame.
		device.drawPixels(0, 0, 0, self.pw, self.ph)
		return true
	end

	function canvas:begin()
		self.buttons = {}
		self.fbRows = {}
		for y = 1, self.h do
			self.fbRows[y] = self.fbClearRow
		end
	end

	function canvas:fill(x, y, w, h, color)
		local left = math.max(0, math.floor(x))
		local top = math.max(0, math.floor(y))
		local right = math.min(self.w, math.ceil(x + w))
		local bottom = math.min(self.h, math.ceil(y + h))
		if left >= right or top >= bottom then
			return
		end
		local span = string.char(color or 0):rep(right - left)
		for yy = top + 1, bottom do
			local previous = self.fbRows[yy]
			self.fbRows[yy] = previous:sub(1, left) .. span .. previous:sub(right + 1)
		end
	end

	local function flush(self, first, last)
		local lines = {}
		for y = first, last do
			local line = self.fbRows[y]
			if scaleX > 1 then
				line = line:gsub(".", glyphs)
			end
			for _ = 1, scaleY do
				lines[#lines + 1] = line
			end
		end
		device.drawPixels(self.ox, self.oy + (first - 1) * scaleY, lines)
	end

	function canvas:finish()
		local previous = self.fbPrevious
		local rows = self.fbRows
		local first = nil
		local groups = {}
		for y = 1, self.h + 1 do
			local changed = y <= self.h and (not previous or previous[y] ~= rows[y])
			if changed and not first then
				first = y
			elseif not changed and first then
				groups[#groups + 1] = { first, y - 1 }
				first = nil
			end
		end
		if #groups > 12 then
			-- One bulk bitmap is cheaper than many short API calls.
			flush(self, 1, self.h)
		elseif #groups > 0 then
			if device.setFrozen and #groups > 1 then
				pcall(device.setFrozen, true)
			end
			for _, group in ipairs(groups) do
				flush(self, group[1], group[2])
			end
			if device.setFrozen and #groups > 1 then
				pcall(device.setFrozen, false)
			end
		end
		self.fbPrevious = rows
	end

	function canvas:resize()
		oldResize(self)
		if not setup(self) then
			error("Pixelbuffer graphics scale changed. Restart WORMFRONT to reinitialize.")
		end
	end

	function canvas:close()
		self.fbRows, self.fbPrevious = nil, nil
		oldClose(self)
	end

	setup(canvas)
	canvas.buffered = true
	return canvas
end

return B
