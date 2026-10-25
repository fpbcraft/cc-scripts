-- CIVCRAFT pixel canvas adapted from RAILBREAK.\n-- Low-resolution CC: Graphics canvas. Layout coordinates are virtual pixels:
-- Graphics mode uses a denser 3x4 virtual grid per text cell (2x2.25 real pixels).
-- The native text fallback retains its original 2x3 layout for compatibility.
-- In CC: Graphics mode monitor_touch is ZERO-based PIXELS. Vanilla is ONE-based cells.
local Icons = dofile("/games/civcraft/icons.lua")
local R = {}
R.__index = R
R.palette = {
	[0] = 0x0D1A21,
	[1] = 0x192D35,
	[2] = 0x223A42,
	[3] = 0x31515A,
	[4] = 0x64756C,
	[5] = 0x789390,
	[6] = 0xE7E6CA,
	[7] = 0xFFF0C2,
	[8] = 0xEAB45D,
	[9] = 0xCD824B,
	[10] = 0xAE5B49,
	[11] = 0x8EBA78,
	[12] = 0x3E725D,
	[13] = 0x6AACC7,
	[14] = 0x23343A,
	[15] = 0x121E25,
	[16] = 0x996537,
	[17] = 0x747A7F,
	[18] = 0xF0CF68,
	[19] = 0x3F6381,
	[20] = 0x263C4D,
	[21] = 0x496B4A,
	[22] = 0x405C52,
	[23] = 0x17151D,
	[24] = 0xB7C7C1,
	[25] = 0x39616C,
	[26] = 0x6A4038,
	[27] = 0x93A2A6,
	[28] = 0x5F7E53,
	[29] = 0xA5A09A,
	[30] = 0xCCDCD5,
	[31] = 0xE66D47,
}
local terminalColors = {
	[0] = 32768,
	[1] = 128,
	[2] = 256,
	[3] = 512,
	[4] = 8,
	[5] = 512,
	[6] = 1,
	[7] = 1,
	[8] = 16,
	[9] = 2,
	[10] = 16384,
	[11] = 32,
	[12] = 8192,
	[13] = 512,
	[14] = 128,
	[15] = 32768,
	[16] = 4096,
	[17] = 8,
	[18] = 16,
	[19] = 512,
	[20] = 128,
	[21] = 8192,
	[22] = 32,
	[23] = 32768,
	[24] = 1,
	[25] = 512,
	[26] = 4096,
	[27] = 8,
	[28] = 8192,
	[29] = 8,
	[30] = 1,
	[31] = 16384,
}
local FONT = {
	["&"] = { "01100", "10010", "10100", "01000", "10101", "10010", "01101" },
	["A"] = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
	["B"] = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
	["C"] = { "01111", "10000", "10000", "10000", "10000", "10000", "01111" },
	["D"] = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
	["E"] = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
	["F"] = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
	["G"] = { "01111", "10000", "10000", "10111", "10001", "10001", "01111" },
	["H"] = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
	["I"] = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
	["J"] = { "00111", "00010", "00010", "00010", "10010", "10010", "01100" },
	["K"] = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" },
	["L"] = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
	["M"] = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
	["N"] = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
	["O"] = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
	["P"] = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
	["Q"] = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" },
	["R"] = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
	["S"] = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
	["T"] = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
	["U"] = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
	["V"] = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
	["W"] = { "10001", "10001", "10001", "10101", "10101", "10101", "01010" },
	["X"] = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
	["Y"] = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
	["Z"] = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
	["0"] = { "01110", "10011", "10101", "10101", "11001", "10001", "01110" },
	["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
	["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" },
	["3"] = { "11110", "00001", "00001", "00110", "00001", "00001", "11110" },
	["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
	["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
	["6"] = { "00111", "01000", "10000", "11110", "10001", "10001", "01110" },
	["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
	["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
	["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "11100" },
	["-"] = { "00000", "00000", "00000", "11111", "00000", "00000", "00000" },
	["+"] = { "00000", "00100", "00100", "11111", "00100", "00100", "00000" },
	["/"] = { "00001", "00001", "00010", "00100", "01000", "10000", "10000" },
	[":"] = { "00000", "00110", "00110", "00000", "00110", "00110", "00000" },
	["."] = { "00000", "00000", "00000", "00000", "00000", "00110", "00110" },
	["!"] = { "00100", "00100", "00100", "00100", "00100", "00000", "00100" },
	["?"] = { "01110", "10001", "00001", "00110", "00100", "00000", "00100" },
	["="] = { "00000", "11111", "00000", "11111", "00000", "00000", "00000" },
	[","] = { "00000", "00000", "00000", "00000", "00010", "00100", "01000" },
	["("] = { "00010", "00100", "01000", "01000", "01000", "00100", "00010" },
	[")"] = { "01000", "00100", "00010", "00010", "00010", "00100", "01000" },
	["%"] = { "11001", "11001", "00010", "00100", "01000", "10011", "10011" },
	[">"] = { "10000", "01000", "00100", "00010", "00100", "01000", "10000" },
	["<"] = { "00001", "00010", "00100", "01000", "00100", "00010", "00001" },
	[" "] = { "00000", "00000", "00000", "00000", "00000", "00000", "00000" },
	["'"] = { "00100", "00100", "00000", "00000", "00000", "00000", "00000" },
}

-- Compact 3x5 pixel font for standard labels. 5x7 font is retained for headings.
local SMALL_FONT = {
	["A"] = { "010", "101", "111", "101", "101" },
	["B"] = { "110", "101", "110", "101", "110" },
	["C"] = { "011", "100", "100", "100", "011" },
	["D"] = { "110", "101", "101", "101", "110" },
	["E"] = { "111", "100", "110", "100", "111" },
	["F"] = { "111", "100", "110", "100", "100" },
	["G"] = { "011", "100", "101", "101", "011" },
	["H"] = { "101", "101", "111", "101", "101" },
	["I"] = { "111", "010", "010", "010", "111" },
	["J"] = { "001", "001", "001", "101", "010" },
	["K"] = { "101", "101", "110", "101", "101" },
	["L"] = { "100", "100", "100", "100", "111" },
	["M"] = { "101", "111", "111", "101", "101" },
	["N"] = { "101", "111", "111", "111", "101" },
	["O"] = { "010", "101", "101", "101", "010" },
	["P"] = { "110", "101", "110", "100", "100" },
	["Q"] = { "010", "101", "101", "010", "001" },
	["R"] = { "110", "101", "110", "110", "101" },
	["S"] = { "011", "100", "010", "001", "110" },
	["T"] = { "111", "010", "010", "010", "010" },
	["U"] = { "101", "101", "101", "101", "111" },
	["V"] = { "101", "101", "101", "101", "010" },
	["W"] = { "101", "101", "111", "111", "101" },
	["X"] = { "101", "101", "010", "101", "101" },
	["Y"] = { "101", "101", "010", "010", "010" },
	["Z"] = { "111", "001", "010", "100", "111" },
	["0"] = { "111", "101", "101", "101", "111" },
	["1"] = { "010", "110", "010", "010", "111" },
	["2"] = { "110", "001", "010", "100", "111" },
	["3"] = { "110", "001", "011", "001", "110" },
	["4"] = { "101", "101", "111", "001", "001" },
	["5"] = { "111", "100", "110", "001", "110" },
	["6"] = { "011", "100", "110", "101", "010" },
	["7"] = { "111", "001", "010", "010", "010" },
	["8"] = { "010", "101", "010", "101", "010" },
	["9"] = { "010", "101", "011", "001", "110" },
	["-"] = { "000", "000", "111", "000", "000" },
	["+"] = { "000", "010", "111", "010", "000" },
	["/"] = { "001", "001", "010", "100", "100" },
	[":"] = { "000", "010", "000", "010", "000" },
	["."] = { "000", "000", "000", "000", "010" },
	["!"] = { "010", "010", "010", "000", "010" },
	["?"] = { "110", "001", "010", "000", "010" },
	["="] = { "000", "111", "000", "111", "000" },
	[","] = { "000", "000", "000", "010", "100" },
	["("] = { "001", "010", "010", "010", "001" },
	[")"] = { "100", "010", "010", "010", "100" },
	["%"] = { "101", "001", "010", "100", "101" },
	[">"] = { "100", "010", "001", "010", "100" },
	["<"] = { "001", "010", "100", "010", "001" },
	[" "] = { "000", "000", "000", "000", "000" },
	["'"] = { "010", "010", "000", "000", "000" },
}

function R.new(mon)
	local cw, ch = mon.getSize()
	local self = setmetatable({
		m = mon,
		cw = cw,
		ch = ch,
		w = cw * 2,
		h = ch * 3,
		mode = "text",
		buttons = {},
		sx = 0.5,
		sy = 1 / 3,
	}, R)
	if mon.setGraphicsMode and mon.drawPixels then
		local success = pcall(mon.setGraphicsMode, 2)
		if success then
			local got, pw, ph = pcall(mon.getSize, 2)
			if got and type(pw) == "number" and pw > cw then
				self.mode = "graphics"
				self.w = cw * 3
				self.h = ch * 4
				self.pw = pw
				self.ph = ph
				self:fitGraphics()
				self.originalPalette = {}
				for index, color in pairs(R.palette) do
					if mon.getPaletteColor then
						local ok, r, g, b = pcall(mon.getPaletteColor, index)
						if ok then
							self.originalPalette[index] = { r, g, b }
						end
					end
					if mon.setPaletteColor then
						pcall(mon.setPaletteColor, index, color)
					end
				end
			else
				pcall(mon.setGraphicsMode, 0)
			end
		end
	end
	return self
end
-- Graphics mode 2 may report arbitrary emulator pixel dimensions.
-- A nonuniform X/Y scale stretched glyphs into tall, narrow columns.
function R:fitGraphics()
	local scale = math.min(self.pw / self.w, self.ph / self.h)
	self.sx, self.sy = scale, scale
	self.ox = math.floor((self.pw - self.w * scale) / 2)
	self.oy = math.floor((self.ph - self.h * scale) / 2)
end
function R:resize()
	self.scaledRows = nil
	self.frameRows = nil
	local cw, ch = self.m.getSize()
	if cw ~= self.cw or ch ~= self.ch then
		self.lastTextRows = nil
	end
	self.cw, self.ch = cw, ch
	if self.mode == "graphics" then
		self.w = self.cw * 3
		self.h = self.ch * 4
	else
		self.w = self.cw * 2
		self.h = self.ch * 3
	end
	if self.mode == "graphics" then
		local ok, pw, ph = pcall(self.m.getSize, 2)
		if ok then
			self.pw = pw
			self.ph = ph
			self:fitGraphics()
		end
	end
end
-- Every map primitive shares this viewport clip, including text and icons.
function R:withClip(rect, draw)
	local previous = self.clip
	local x, y = rect.x, rect.y
	local right, bottom = x + rect.w, y + rect.h
	if previous then
		x = math.max(x, previous.x)
		y = math.max(y, previous.y)
		right = math.min(right, previous.x + previous.w)
		bottom = math.min(bottom, previous.y + previous.h)
	end
	self.clip = { x = x, y = y, w = math.max(0, right - x), h = math.max(0, bottom - y) }
	local ok, err = pcall(draw)
	self.clip = previous
	if not ok then
		error(err, 0)
	end
end
local function blitColor(index)
	local color = terminalColors[index] or 32768
	local value = 0
	while color > 1 do
		color = color / 2
		value = value + 1
	end
	return ("0123456789abcdef"):sub(value + 1, value + 1)
end
local function splice(value, x1, x2, replacement)
	return value:sub(1, x1 - 1) .. replacement .. value:sub(x2 + 1)
end
local pixelColors = {}
for color = 0, 31 do
	pixelColors[color] = string.char(color)
end
function R:cooperate(force)
	if not (os.epoch and os.queueEvent and os.pullEvent) then
		return
	end
	self.work = (self.work or 0) + 1
	if not force and self.work % 128 ~= 0 then
		return
	end
	local now = os.epoch("utc")
	if not force and now - (self.lastYield or now) < 30 then
		return
	end
	self.yieldToken = (self.yieldToken or 0) + 1
	local token = self.yieldToken
	if self.trace then
		self.trace("yield.begin", token)
	end
	local timer = os.startTimer and os.startTimer(0.05)
	os.queueEvent("civcraft_render_yield", token)
	while true do
		local event = table.pack(os.pullEvent())
		if event[1] == "civcraft_render_yield" and event[2] == token then
			break
		end
		if timer and event[1] == "timer" and event[2] == timer then
			if self.trace then
				self.trace("yield.timeout", token)
			end
			break
		end
		self.pendingEvents = self.pendingEvents or {}
		self.pendingEvents[#self.pendingEvents + 1] = event
	end
	if timer and os.cancelTimer then
		os.cancelTimer(timer)
	end
	self.lastYield = os.epoch("utc")
	if self.trace then
		self.trace("yield.end", token)
	end
end
function R:pullEvent()
	local queue = self.pendingEvents
	if queue and #queue > 0 then
		local event = table.remove(queue, 1)
		return table.unpack(event, 1, event.n)
	end
	return os.pullEvent()
end
function R:fill(x, y, w, h, color)
	self:cooperate()
	local x0 = math.max(0, math.floor(x))
	local y0 = math.max(0, math.floor(y))
	local x1 = math.min(self.w, math.ceil(x + w))
	local y1 = math.min(self.h, math.ceil(y + h))
	if self.clip then
		x0 = math.max(x0, self.clip.x)
		y0 = math.max(y0, self.clip.y)
		x1 = math.min(x1, self.clip.x + self.clip.w)
		y1 = math.min(y1, self.clip.y + self.clip.h)
	end
	if x1 <= x0 or y1 <= y0 then
		return
	end
	if self.mode == "graphics" then
		if self.buffer then
			-- Mutate reusable pixels; rebuilding strings per stroke causes heavy GC on CraftOS.
			local pixel = pixelColors[color or 0]
			for row = y0 + 1, y1 do
				local pixels = self.buffer[row]
				for column = x0 + 1, x1 do
					pixels[column] = pixel
				end
			end
		else
			local a = math.floor(self.ox + x0 * self.sx)
			local b = math.floor(self.oy + y0 * self.sy)
			local rw = math.max(1, math.floor(self.ox + x1 * self.sx) - a)
			local rh = math.max(1, math.floor(self.oy + y1 * self.sy) - b)
			self.m.drawPixels(a, b, color or 0, rw, rh)
		end
	else
		local ax = math.floor(x0 / 2) + 1
		local ay = math.floor(y0 / 3) + 1
		local bx = math.min(self.cw, math.ceil(x1 / 2))
		local by = math.min(self.ch, math.ceil(y1 / 3))
		local count = math.max(0, bx - ax + 1)
		if self.textBuffer then
			for row = ay, by do
				local line = self.textBuffer[row]
				line[1] = splice(line[1], ax, bx, (" "):rep(count))
				line[3] = splice(line[3], ax, bx, blitColor(color):rep(count))
			end
		else
			self.m.setBackgroundColor(terminalColors[color] or 32768)
			for row = ay, by do
				self.m.setCursorPos(ax, row)
				self.m.write((" "):rep(count))
			end
		end
	end
end
function R:outline(x, y, w, h, color)
	self:fill(x, y, w, 1, color)
	self:fill(x, y + h - 1, w, 1, color)
	self:fill(x, y, 1, h, color)
	self:fill(x + w - 1, y, 1, h, color)
end
function R:blit(rows, x, y)
	self:cooperate()
	if not self.buffer then
		return false
	end
	x, y = math.floor(x), math.floor(y)
	local clip = self.clip or { x = 0, y = 0, w = self.w, h = self.h }
	local left = math.max(0, clip.x)
	local right = math.min(self.w, clip.x + clip.w)
	local top = math.max(0, clip.y)
	local bottom = math.min(self.h, clip.y + clip.h)
	local pattern = "[^" .. string.char(255) .. "]+"
	for i, row in ipairs(rows) do
		local target = y + i - 1
		if target >= top and target < bottom then
			local start = 1
			while start <= #row do
				local a, b = row:find(pattern, start)
				if not a then
					break
				end
				local x0 = math.max(left, x + a - 1)
				local x1 = math.min(right, x + b)
				if x1 > x0 then
					local pixels = self.buffer[target + 1]
					for column = x0, x1 - 1 do
						pixels[column + 1] = pixelColors[row:byte(column - x + 1)]
					end
				end
				start = b + 1
			end
		end
	end
	return true
end
function R:line(x1, y1, x2, y2, color)
	-- Thick sections are fast; diagonal lines are sampled into a 1-pixel stroke.
	local dx = x2 - x1
	local dy = y2 - y1
	local n = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy))))
	for i = 0, n do
		self:fill(x1 + dx * i / n, y1 + dy * i / n, 1, 1, color)
	end
end
function R:textWidth(value, scale)
	scale = scale or 1
	if self.mode == "text" then
		return #tostring(value or "") * 2
	end
	return #tostring(value or "") * (scale >= 2 and 6 * scale or 4)
end
function R:text(x, y, txt, color, scale, maxWidth)
	txt = tostring(txt or ""):upper()
	scale = scale or 1
	maxWidth = maxWidth or self.w - x
	local widthPerChar = self.mode == "text" and 2 or (scale >= 2 and 6 * scale or 4)
	txt = txt:sub(1, math.max(0, math.floor(maxWidth / widthPerChar)))
	if self.mode == "text" then
		if self.clip then
			local c = self.clip
			if y < c.y or y + 3 > c.y + c.h then
				return
			end
			local skip = math.max(0, math.ceil((c.x - x) / 2))
			txt = txt:sub(skip + 1)
			x = x + skip * 2
			txt = txt:sub(1, math.max(0, math.floor((c.x + c.w - x) / 2)))
		end
		if y < 0 or y >= self.h then
			return
		end
		local tx = math.floor(x / 2) + 1
		local ty = math.floor(y / 3) + 1
		if tx >= 1 and tx <= self.cw and ty >= 1 and ty <= self.ch then
			txt = txt:sub(1, self.cw - tx + 1)
			if self.textBuffer then
				local line = self.textBuffer[ty]
				local last = tx + #txt - 1
				line[1] = splice(line[1], tx, last, txt)
				line[2] = splice(line[2], tx, last, blitColor(color):rep(#txt))
			else
				self.m.setCursorPos(tx, ty)
				self.m.setBackgroundColor(terminalColors[0])
				self.m.setTextColor(terminalColors[color] or 1)
				self.m.write(txt)
			end
		end
		return
	end
	local big = scale >= 2
	local glyphs = big and FONT or SMALL_FONT
	local stride = big and 6 * scale or 4
	local size = big and 5 or 3
	local rows = big and 7 or 5
	local pixelScale = big and scale or 1
	for i = 1, #txt do
		local glyph = glyphs[txt:sub(i, i)] or glyphs["?"]
		local left = x + (i - 1) * stride
		for row = 1, rows do
			local bits = glyph[row]
			local firstPixel = nil
			for col = 1, size + 1 do
				local lit = col <= size and bits:sub(col, col) == "1"
				if lit and not firstPixel then
					firstPixel = col
				end
				if not lit and firstPixel then
					self:fill(
						left + (firstPixel - 1) * pixelScale,
						y + (row - 1) * pixelScale,
						(col - firstPixel) * pixelScale,
						pixelScale,
						color
					)
					firstPixel = nil
				end
			end
		end
	end
end
function R:center(y, txt, color, scale, x, w)
	x = x or 0
	w = w or self.w
	scale = scale or 1
	self:text(
		x + math.max(0, math.floor((w - self:textWidth(txt, scale)) / 2)),
		y,
		txt,
		color,
		scale,
		w
	)
end
function R:icon(id, x, y, s)
	s = s or 1
	if id == "food" or id == "industry" then
		Icons.yield(self, id, x, y, 9 * s)
		return
	end
	local shapes = {
		coin = {
			"011111110",
			"111111111",
			"110000011",
			"110111011",
			"110101011",
			"110111011",
			"110000011",
			"111111111",
			"011111110",
		},
		coal = {
			"000110000",
			"011111000",
			"111111100",
			"111111110",
			"111111111",
			"111111110",
			"111111100",
			"011111000",
			"001110000",
		},
		parts = {
			"001110000",
			"011111000",
			"111111100",
			"110001110",
			"100001110",
			"110001110",
			"111111100",
			"011111000",
			"001110000",
		},
		people = {
			"110001100",
			"110001100",
			"000000000",
			"111001110",
			"111001110",
			"111001110",
			"111001110",
			"000000000",
			"000000000",
		},
		plus = {
			"000010000",
			"000010000",
			"000010000",
			"000010000",
			"111111111",
			"000010000",
			"000010000",
			"000010000",
			"000010000",
		},
		minus = {
			"000000000",
			"000000000",
			"000000000",
			"000000000",
			"111111111",
			"000000000",
			"000000000",
			"000000000",
			"000000000",
		},
		book = {
			"111101111",
			"100111001",
			"101101101",
			"100101001",
			"101101101",
			"100101001",
			"100101001",
			"111101111",
			"000010000",
		},
		search = {
			"001110000",
			"010001000",
			"100000100",
			"100000100",
			"100000100",
			"010001000",
			"001110100",
			"000000010",
			"000000001",
		},
		tree = {
			"000111000",
			"000101000",
			"000111000",
			"000010000",
			"011111110",
			"010000010",
			"111000111",
			"101000101",
			"111000111",
		},
		pause = {
			"011000110",
			"011000110",
			"011000110",
			"011000110",
			"011000110",
			"011000110",
			"011000110",
			"011000110",
			"011000110",
		},
		fullscreen = {
			"000001111",
			"000000011",
			"000000101",
			"000001001",
			"100010000",
			"100100000",
			"101000000",
			"110000000",
			"111100000",
		},
		empire = {
			"001000100",
			"011101110",
			"111111111",
			"101111101",
			"111010111",
			"101010101",
			"111111111",
			"000000000",
			"000000000",
		},
		nextCity = {
			"001000000",
			"011100100",
			"111111110",
			"110011111",
			"110011110",
			"111111100",
			"000000000",
			"000000000",
			"000000000",
		},
		nextUnit = {
			"111100100",
			"100101110",
			"111111111",
			"011101110",
			"011100100",
			"001100000",
			"001100000",
			"000000000",
			"000000000",
		},
		endTurn = {
			"001000000",
			"001100000",
			"001110000",
			"001111000",
			"001111100",
			"001111000",
			"001110000",
			"001100000",
			"001000000",
		},
		box = {
			"111111111",
			"100010001",
			"101010101",
			"100010001",
			"101010101",
			"100010001",
			"101010101",
			"100010001",
			"111111111",
		},
		wood = {
			"000000000",
			"111111100",
			"111111100",
			"000000000",
			"011111110",
			"011111110",
			"000000000",
			"111111100",
			"111111100",
		},
		sheet = {
			"000000000",
			"011111110",
			"011111110",
			"000000000",
			"111111100",
			"111111100",
			"000000000",
			"011111110",
			"011111110",
		},
		fuel = {
			"001111000",
			"011111100",
			"011111100",
			"011001100",
			"011101100",
			"011101100",
			"011111100",
			"001111000",
			"000000000",
		},
		wrench = {
			"000000111",
			"000001110",
			"000011100",
			"000111000",
			"001110000",
			"011100000",
			"111000000",
			"110000000",
			"000000000",
		},
		map = {
			"111011101",
			"101010101",
			"101010101",
			"101010101",
			"101010101",
			"101010101",
			"101010101",
			"101010101",
			"111011101",
		},
		station = {
			"000111000",
			"001111100",
			"011111110",
			"111111111",
			"110010011",
			"110010011",
			"110010011",
			"110010011",
			"111111111",
		},
		contract = {
			"001111100",
			"001001100",
			"001111100",
			"001000100",
			"001111100",
			"001000100",
			"001111100",
			"001000100",
			"001111100",
		},
		train = {
			"000111000",
			"001111100",
			"011111110",
			"111111111",
			"111111111",
			"111111111",
			"011111110",
			"010000010",
			"010000010",
		},
		bolt = {
			"000011110",
			"000011100",
			"000111000",
			"001110000",
			"011111100",
			"000111000",
			"001110000",
			"011100000",
			"111000000",
		},
		back = {
			"000100000",
			"001100000",
			"011111110",
			"111111110",
			"011111110",
			"001100000",
			"000100000",
			"000000000",
			"000000000",
		},
		right = {
			"000001000",
			"000001100",
			"011111110",
			"011111111",
			"011111110",
			"000001100",
			"000001000",
			"000000000",
			"000000000",
		},
		danger = {
			"000010000",
			"000111000",
			"001111100",
			"011101110",
			"111101111",
			"111101111",
			"111111111",
			"000000000",
			"000000000",
		},
		star = {
			"000010000",
			"000010000",
			"111111111",
			"011111110",
			"001111100",
			"011111110",
			"010000010",
			"000000000",
			"000000000",
		},
		press = {
			"111111111",
			"001101100",
			"001101100",
			"001111100",
			"000111000",
			"111111111",
			"111111111",
			"001000100",
			"001000100",
		},
		saw = {
			"000010000",
			"001111100",
			"011111110",
			"111111111",
			"011111110",
			"001111100",
			"000010000",
			"111111111",
			"111111111",
		},
		foundry = {
			"001111100",
			"011111110",
			"011111110",
			"111111111",
			"111011111",
			"111011111",
			"111111111",
			"111111111",
			"111111111",
		},
		crane = {
			"111111111",
			"011111111",
			"001000100",
			"001000100",
			"001000100",
			"001000100",
			"001000100",
			"001011100",
			"001011100",
		},
		signal = {
			"001111100",
			"001101100",
			"001111100",
			"001111100",
			"001101100",
			"001111100",
			"000110000",
			"000110000",
			"000110000",
		},
		clock = {
			"001111100",
			"011111110",
			"111101111",
			"111101111",
			"111100111",
			"111111111",
			"011111110",
			"001111100",
			"000000000",
		},
		ore = {
			"000111000",
			"001111100",
			"011111110",
			"111111111",
			"111111111",
			"111111111",
			"011111110",
			"001111100",
			"000000000",
		},
		food = {
			"000000000",
			"000000000",
			"000010000",
			"000111000",
			"001010100",
			"000010000",
			"000010000",
			"000000000",
			"000000000",
		},
	}
	local bits = shapes[id] or shapes.box
	for i, row in ipairs(bits) do
		local run = nil
		for col = 1, 10 do
			local lit = col <= 9 and row:sub(col, col) == "1"
			if lit and not run then
				run = col
			end
			if not lit and run then
				self:fill(x + (run - 1) * s, y + (i - 1) * s, (col - run) * s, s, ({
					coin = 8,
					coal = 17,
					parts = 17,
					people = 13,
					box = 9,
					wood = 9,
					sheet = 6,
					fuel = 10,
					wrench = 17,
					map = 11,
					station = 9,
					contract = 8,
					train = 10,
					bolt = 8,
					back = 6,
					right = 6,
					danger = 10,
					star = 8,
					press = 17,
					saw = 17,
					foundry = 10,
					crane = 9,
					signal = 11,
					clock = 5,
					ore = 17,
					food = 18,
				})[id] or 8)
				run = nil
			end
		end
	end
end
function R:button(x, y, w, h, label, fn, opt)
	opt = opt or {}
	if w < 10 or h < 8 then
		return
	end
	if
		self.clip
		and (
			x < self.clip.x
			or y < self.clip.y
			or x + w > self.clip.x + self.clip.w
			or y + h > self.clip.y + self.clip.h
		)
	then
		return
	end
	local bg = opt.selected and 12 or opt.primary and 11 or opt.danger and 10 or 2
	self:fill(x, y, w, h, bg)
	self:outline(x, y, w, h, opt.primary and 8 or 3)
	if opt.icon and w >= 48 then
		self:icon(opt.icon, x + 4, y + math.max(3, math.floor((h - 9) / 2)), 1)
	end
	local tx = x + (opt.icon and w >= 48 and 17 or 4)
	local max = w - (tx - x) - 3
	if not opt.icon and label then
		tx = x + math.max(3, math.floor((w - self:textWidth(label)) / 2))
		max = w - (tx - x) - 2
	end
	if label then
		self:text(
			tx,
			y + math.max(2, math.floor((h - 7) / 2)),
			label,
			opt.primary and 0 or 7,
			1,
			max
		)
	end
	if fn then
		self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn, label = label }
	end
end
function R:touch(x, y)
	if type(x) ~= "number" or type(y) ~= "number" then
		return nil, nil
	end
	local vx, vy
	if self.mode == "graphics" then
		vx = math.floor((x - self.ox) / self.sx)
		vy = math.floor((y - self.oy) / self.sy)
	else
		vx = (x - 1) * 2
		vy = (y - 1) * 3
	end
	if vx < 0 or vy < 0 or vx >= self.w or vy >= self.h then
		return nil, nil
	end
	return vx, vy
end
function R:hit(x, y)
	for i = #self.buttons, 1, -1 do
		local b = self.buttons[i]
		if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
			if self.onActivate then
				self.onActivate(b.label)
			end
			b.fn(x, y)
			return b.label or true
		end
	end
	return false
end
function R:begin()
	self:cooperate(true)
	self.buttons = {}
	self.scrollbars = {}
	self.clip = nil
	if self.mode == "graphics" then
		self.frameRows = self.frameRows or {}
		self.buffer = self.frameRows
		for y = 1, self.h do
			local row = self.buffer[y] or {}
			self.buffer[y] = row
			for x = 1, self.w do
				row[x] = pixelColors[0]
			end
		end
	else
		self.textBuffer = {}
		for y = 1, self.ch do
			self.textBuffer[y] = { (" "):rep(self.cw), ("0"):rep(self.cw), ("f"):rep(self.cw) }
		end
	end
end
function R:finish()
	if self.buffer then
		if self.trace then
			self.trace("frame.scale.begin")
		end
		local rows = {}
		local blank = string.rep(string.char(0), self.pw)
		local previous = self.scaledRows or {}
		local expanded, sourceRows = {}, {}
		local integer = self.sx == math.floor(self.sx)
		local lut = {}
		if integer then
			for c = 0, 31 do
				lut[string.char(c)] = string.rep(string.char(c), self.sx)
			end
		end
		for y = 0, self.ph - 1 do
			self:cooperate()
			local source = math.ceil((y + 1 - self.oy) / self.sy)
			if y < self.oy or source < 1 or source > self.h then
				rows[y + 1] = blank
			else
				local row = sourceRows[source]
				if not row then
					row = table.concat(self.buffer[source])
					sourceRows[source] = row
				end
				if not expanded[row] then
					local value
					if previous[row] then
						value = previous[row]
					elseif integer then
						value = row:gsub(".", lut)
					else
						local parts = {}
						for x = 1, self.w do
							local count = math.floor(self.ox + x * self.sx)
								- math.floor(self.ox + (x - 1) * self.sx)
							parts[x] = row:sub(x, x):rep(count)
						end
						value = table.concat(parts)
					end
					if not previous[row] then
						value = blank:sub(1, self.ox) .. value
						value = (value .. blank):sub(1, self.pw)
					end
					expanded[row] = value
				end
				rows[y + 1] = expanded[row]
			end
		end
		self.scaledRows = expanded
		if self.trace then
			self.trace("frame.upload.begin")
		end
		self.m.drawPixels(0, 0, rows, self.pw, self.ph)
		if self.trace then
			self.trace("frame.upload.end")
		end
		self.buffer = nil
	end
	if self.textBuffer then
		local previous = self.lastTextRows or {}
		for y, line in ipairs(self.textBuffer) do
			local old = previous[y]
			if not old or old[1] ~= line[1] or old[2] ~= line[2] or old[3] ~= line[3] then
				self.m.setCursorPos(1, y)
				if self.m.blit then
					self.m.blit(line[1], line[2], line[3])
				else
					local at = 1
					while at <= self.cw do
						local ending = at
						while
							ending < self.cw
							and line[2]:sub(ending + 1, ending + 1) == line[2]:sub(at, at)
							and line[3]:sub(ending + 1, ending + 1) == line[3]:sub(at, at)
						do
							ending = ending + 1
						end
						self.m.setTextColor(2 ^ tonumber(line[2]:sub(at, at), 16))
						self.m.setBackgroundColor(2 ^ tonumber(line[3]:sub(at, at), 16))
						self.m.write(line[1]:sub(at, ending))
						at = ending + 1
					end
				end
			end
		end
		self.lastTextRows = self.textBuffer
		self.textBuffer = nil
	end
	if self.mode == "graphics" and self.m.setFrozen then
		pcall(self.m.setFrozen, false)
	end
end
function R:close()
	if self.mode == "graphics" then
		if self.m.setFrozen then
			pcall(self.m.setFrozen, false)
		end
		if self.originalPalette and self.m.setPaletteColor then
			for i, c in pairs(self.originalPalette) do
				pcall(self.m.setPaletteColor, i, c[1], c[2], c[3])
			end
		end
		pcall(self.m.setGraphicsMode, 0)
	end
end
return R
