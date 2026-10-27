-- Embed real Basalt widgets in the existing text/pixel canvas and event loop.
local Surface = {}
Surface.__index = Surface
local names = {
	"white",
	"orange",
	"magenta",
	"lightBlue",
	"yellow",
	"lime",
	"pink",
	"gray",
	"lightGray",
	"cyan",
	"purple",
	"blue",
	"brown",
	"green",
	"red",
	"black",
}
local palette = { 7, 9, 10, 13, 8, 11, 10, 1, 5, 13, 23, 19, 16, 12, 31, 0 }
local function splice(line, offset, value)
	return line:sub(1, offset - 1) .. value .. line:sub(offset + #value)
end

local function terminal(surface)
	local t = {}
	local x, y, foreground, background = 1, 1, 1, 32768
	local hex = {}
	for index = 0, 15 do
		hex[2 ^ index] = ("0123456789abcdef"):sub(index + 1, index + 1)
	end
	function t.getSize()
		return surface.columns, surface.rows
	end
	function t.isColor()
		return true
	end
	t.isColour = t.isColor
	function t.setCursorPos(cx, cy)
		x, y = cx, cy
	end
	function t.getCursorPos()
		return x, y
	end
	function t.setTextColor(color)
		foreground = color
	end
	t.setTextColour = t.setTextColor
	function t.getTextColor()
		return foreground
	end
	t.getTextColour = t.getTextColor
	function t.setBackgroundColor(color)
		background = color
	end
	t.setBackgroundColour = t.setBackgroundColor
	function t.getBackgroundColor()
		return background
	end
	t.getBackgroundColour = t.getBackgroundColor
	function t.setCursorBlink(blink)
		surface.cursor = blink and { x = x, y = y, color = foreground } or nil
	end
	function t.getCursorBlink()
		return surface.cursor ~= nil
	end
	function t.clear()
		for row = 1, surface.rows do
			surface.lines[row] = {
				string.rep(" ", surface.columns),
				string.rep(hex[foreground], surface.columns),
				string.rep(hex[background], surface.columns),
			}
		end
	end
	function t.blit(text, fg, bg)
		if y < 1 or y > surface.rows then
			return
		end
		local first, last = math.max(1, 2 - x), math.min(#text, surface.columns - x + 1)
		if last < first then
			return
		end
		local at = x + first - 1
		local line = surface.lines[y]
		line[1] = splice(line[1], at, text:sub(first, last))
		line[2] = splice(line[2], at, fg:sub(first, last))
		line[3] = splice(line[3], at, bg:sub(first, last))
		x = x + #text
	end
	function t.write(text)
		text = tostring(text)
		t.blit(text, string.rep(hex[foreground], #text), string.rep(hex[background], #text))
	end
	function t.getPaletteColor(color)
		local index = tonumber(hex[color], 16) + 1
		local rgb = surface.renderer.palette[palette[index]] or 0
		return math.floor(rgb / 65536) / 255, math.floor(rgb / 256) % 256 / 255, rgb % 256 / 255
	end
	t.getPaletteColour = t.getPaletteColor
	function t.setPaletteColor() end
	t.setPaletteColour = t.setPaletteColor
	t.current = function()
		return t
	end
	t.native = t.current
	t.clear()
	return t
end

local function runtime(t)
	local constants = {}
	for index, name in ipairs(names) do
		constants[name] = 2 ^ (index - 1)
	end
	constants.grey, constants.lightGrey = constants.gray, constants.lightGray
	local keyCodes = {
		escape = 1,
		tab = 15,
		enter = 28,
		space = 57,
		backspace = 14,
		delete = 211,
		left = 203,
		right = 205,
		up = 200,
		down = 208,
		home = 199,
		["end"] = 207,
		pageUp = 201,
		pageDown = 209,
		leftCtrl = 29,
		rightCtrl = 157,
		leftShift = 42,
		rightShift = 54,
	}
	for name, code in pairs(keys or {}) do
		keyCodes[name] = code
	end
	local scope = setmetatable(
		{ colors = constants, colours = constants, keys = keyCodes, term = t },
		{ __index = _ENV }
	)
	scope._G = scope
	scope.load = function(source, name, mode, environment)
		return load(source, name, mode or "t", environment or scope)
	end
	local path = "/games/civcraft/vendor/basalt.lua"
	local chunk, reason = loadfile(path, "t", scope)
	if not chunk then
		chunk, reason = loadfile(path:sub(2), "t", scope)
	end
	assert(chunk, "Bundled Basalt is missing; update CivCraft: " .. tostring(reason))
	return chunk(), constants, keyCodes
end

function Surface.new(renderer, rect)
	local self =
		setmetatable({ renderer = renderer, rect = rect, lines = {}, controls = {} }, Surface)
	self.cellW, self.cellH = renderer.mode == "text" and 2 or 4, renderer.mode == "text" and 3 or 6
	self.columns, self.rows =
		math.max(1, math.floor(rect.w / self.cellW)), math.max(1, math.floor(rect.h / self.cellH))
	self.terminal = terminal(self)
	self.basalt, self.colors, self.keys = runtime(self.terminal)
	self.root = self.basalt.createFrame(self.terminal)
	self.root.background = self.colors.black
	return self
end

function Surface:register(element, label, region)
	self.controls[#self.controls + 1] = { element = element, label = label, region = region }
	return element
end

local function descendant(element, ancestor)
	while element do
		if element == ancestor then
			return true
		end
		element = rawget(element, "parent")
	end
	return false
end

function Surface:bounds(control)
	local element = control.element
	if
		element.disabled
		or self.modal and self.modal.visible and not descendant(element, self.modal)
	then
		return
	end
	local current = element
	while current do
		if current.visible == false then
			return
		end
		current = rawget(current, "parent")
	end
	local x, y = element:getAbsolutePosition()
	local region = type(control.region) == "function" and control.region() or control.region
	local w, h = element.width, element.height
	if region then
		if region.hidden then
			return
		end
		x, y, w, h = x + (region.x or 0), y + (region.y or 0), region.w or w, region.h or h
	end
	local right, bottom = x + w, y + h
	current = rawget(element, "parent")
	while current do
		local ax, ay = current:getAbsolutePosition()
		x, y = math.max(x, ax), math.max(y, ay)
		right, bottom = math.min(right, ax + current.width), math.min(bottom, ay + current.height)
		current = rawget(current, "parent")
	end
	if right <= x or bottom <= y then
		return
	end
	return {
		x = self.rect.x + (x - 1) * self.cellW,
		y = self.rect.y + (y - 1) * self.cellH,
		w = (right - x) * self.cellW,
		h = (bottom - y) * self.cellH,
		label = control.label,
	}
end

function Surface:mouse(event, button, x, y)
	local cx = math.floor((x - self.rect.x) / self.cellW) + 1
	local cy = math.floor((y - self.rect.y) / self.cellH) + 1
	self.lastMouse = { x = x, y = y }
	self.root:handleEvent(event, button, cx, cy)
end

function Surface:click(x, y)
	self:mouse("mouse_click", 1, x, y)
	self:mouse("mouse_up", 1, x, y)
end

function Surface:key(event, a, b)
	if event == "key" and a == self.keys.tab then
		local focus, items, seen = self.root:getFocused(), {}, {}
		for _, control in ipairs(self.controls) do
			if self:bounds(control) and not seen[control.element] then
				seen[control.element] = true
				items[#items + 1] = control.element
			end
		end
		local index = 0
		for i, item in ipairs(items) do
			if item == focus then
				index = i
				break
			end
		end
		if #items > 0 then
			self.root:setFocused(items[index % #items + 1])
		end
	else
		self.root:handleEvent(event, a, b)
	end
end

function Surface:draw()
	self.root:draw()
	local r = self.renderer
	for row, line in ipairs(self.lines) do
		local first = 1
		while first <= self.columns do
			local last = first
			while
				last < self.columns
				and line[2]:sub(last + 1, last + 1) == line[2]:sub(first, first)
				and line[3]:sub(last + 1, last + 1) == line[3]:sub(first, first)
			do
				last = last + 1
			end
			local x, y =
				self.rect.x + (first - 1) * self.cellW, self.rect.y + (row - 1) * self.cellH
			local fg = palette[tonumber(line[2]:sub(first, first), 16) + 1]
			local bg = palette[tonumber(line[3]:sub(first, first), 16) + 1]
			r:fill(x, y, (last - first + 1) * self.cellW, self.cellH, bg)
			local value = line[1]:sub(first, last)
			if value:find("%S") then
				r:text(x, y + (self.cellH > 3 and 1 or 0), value, fg, 1, #value * self.cellW)
			end
			first = last + 1
		end
	end
	if self.cursor then
		local cursor = self.cursor
		r:fill(
			self.rect.x + (cursor.x - 1) * self.cellW,
			self.rect.y + cursor.y * self.cellH - 1,
			self.cellW,
			1,
			8
		)
	end
	r.buttons[#r.buttons + 1] = {
		x = self.rect.x,
		y = self.rect.y,
		w = self.columns * self.cellW,
		h = self.rows * self.cellH,
		label = "DIPLOMACY",
		fn = function(x, y)
			self:click(x, y)
		end,
	}
	for _, control in ipairs(self.controls) do
		local bounds = self:bounds(control)
		if bounds then
			bounds.fn = function(x, y)
				self:click(x or bounds.x + bounds.w / 2, y or bounds.y + bounds.h / 2)
			end
			r.buttons[#r.buttons + 1] = bounds
		end
	end
end

function Surface:close()
	self.root:destroy()
	self.root:cleanup()
	self.controls = {}
end

return Surface
