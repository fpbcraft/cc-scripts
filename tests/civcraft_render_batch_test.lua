local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
colors = {
	black = 32768,
	white = 1,
	gray = 128,
	lightGray = 256,
	orange = 2,
	lightBlue = 8,
	yellow = 16,
	green = 8192,
	blue = 2048,
	lime = 32,
	red = 16384,
	brown = 4096,
}
local Renderer = native("games/civcraft/render.lua")
local calls, pixels = 0, nil
local m = {
	getSize = function(mode)
		if mode == 2 then
			return 120, 90
		end
		return 20, 10
	end,
	setGraphicsMode = function() end,
	getPaletteColor = function()
		return 0, 0, 0
	end,
	setPaletteColor = function() end,
}
function m.drawPixels(x, y, rows, w, h)
	calls = calls + 1
	assert(x == 0 and y == 0 and w == 120 and h == 90 and type(rows) == "table")
	assert(#rows == 90)
	for _, row in ipairs(rows) do
		assert(#row == 120)
	end
	pixels = rows
end
local r = Renderer.new(m)
r:begin()
r:fill(0, 0, r.w, r.h, 2)
r:withClip({ x = 4, y = 3, w = 5, h = 4 }, function()
	r:fill(0, 0, 30, 30, 8)
end)
r:fill(20, 10, 3, 3, 13)
r:finish()
assert(calls == 1, "A complete graphics frame must use one batched peripheral update")
local function pixel(x, y)
	return pixels[math.floor(r.oy + y * r.sy) + 1]:byte(math.floor(r.ox + x * r.sx) + 1)
end
assert(
	pixel(0, 0) == 2 and pixel(4, 3) == 8 and pixel(8, 6) == 8 and pixel(9, 6) == 2,
	"Viewport clipping survives batching"
)
assert(
	pixel(20, 10) == 13 and pixels[1]:byte(1) == 0,
	"Palette values and letterboxing survive batching"
)
local originalGsub = string.gsub
local expansions = 0
local frameRows = r.frameRows
string.gsub = function(...)
	expansions = expansions + 1
	return originalGsub(...)
end
r:begin()
r:fill(0, 0, r.w, r.h, 2)
r:withClip({ x = 4, y = 3, w = 5, h = 4 }, function()
	r:fill(0, 0, 30, 30, 8)
end)
r:fill(20, 10, 3, 3, 13)
r:finish()
string.gsub = originalGsub
assert(expansions == 0, "Identical frames reuse scaled rows without allocating replacements")
assert(
	r.frameRows == frameRows,
	"Frame pixel storage is reused instead of rebuilt for each primitive"
)
-- Clearing an already blank frame is free, but clearing after drawing must
-- still overwrite every pixel (including a cached scaled row).
r:begin()
r:fill(0, 0, r.w, r.h, 0)
assert(r.frameClear, "A redundant full-frame clear leaves the buffer untouched")
r:fill(3, 3, 2, 2, 8)
assert(not r.frameClear, "A painted frame is no longer clean")
r:fill(0, 0, r.w, r.h, 0)
r:finish()
assert(pixel(3, 3) == 0, "Full-frame clearing after drawing is never skipped")
local cached = r.scaledRows
r:resize()
assert(r.scaledRows == nil, "Resizing invalidates scaled rows")
assert(next(cached), "The previous frame has a bounded row cache")
r:begin()
r:fill(0, 0, r.w, r.h, 2)
local transparent = string.char(255)
r:withClip({ x = 5, y = 4, w = 2, h = 2 }, function()
	r:blit({ string.char(8, 8, 8), transparent .. string.char(13, 13) }, 4, 4)
end)
r:finish()
assert(
	pixel(4, 4) == 2 and pixel(5, 4) == 8 and pixel(6, 4) == 8 and pixel(5, 5) == 13,
	"Cached sprites respect transparency and viewport clipping"
)
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Icons = dofile("games/civcraft/icons.lua")
local function strip(x, y)
	r:begin()
	Icons.yieldValue(r, "industry", 3, x, y, 17, true)
	local rows = {}
	for i, row in ipairs(r.buffer) do
		rows[i] = table.concat(row)
	end
	return table.concat(rows)
end
local aligned = strip(10, 10)
for _, fraction in ipairs({ 0.1, 0.5, 0.9 }) do
	assert(
		strip(10 + fraction, 10 + fraction) == aligned,
		"Fractional yield placement must not thicken cog pixels"
	)
end
assert(r.buffer[13][13] == string.char(0), "The central hole of a cog stays dark")
local function label(x, y, scale)
	r:begin()
	r:text(x, y, "AMETHYST", 7, scale)
	local rows = {}
	for index, row in ipairs(r.buffer) do
		rows[index] = table.concat(row)
	end
	r:finish()
	return table.concat(rows), table.concat(pixels)
end
for _, scale in ipairs({ 1, 2 }) do
	local alignedGlyphs, alignedFrame = label(10, 10, scale)
	for _, offset in ipairs({ { 0.37, 0.62 }, { 0.9, 0.1 }, { 0.5, 0.5 } }) do
		local glyphs, frame = label(10 + offset[1], 10 + offset[2], scale)
		assert(glyphs == alignedGlyphs, "Fractional zoom origins must not thicken city-name glyphs")
		assert(
			frame == alignedFrame,
			"The first fractional-origin frame stays sharp with cached rows"
		)
		r.scaledRows = nil
		local _, freshFrame = label(10 + offset[1], 10 + offset[2], scale)
		assert(freshFrame == alignedFrame, "Cache invalidation does not change label sharpness")
	end
end
local writes = 0
local t = {
	getSize = function()
		return 20, 10
	end,
	setCursorPos = function(x, y)
		assert(x == 1 and y >= 1 and y <= 10)
	end,
	blit = function(text, fg, bg)
		assert(#text == 20 and #fg == 20 and #bg == 20)
		writes = writes + 1
	end,
}
local text = Renderer.new(t)
local function frame()
	text:begin()
	text:fill(0, 0, 40, 30, 2)
	text:text(2, 3, "HELLO", 8)
	text:finish()
end
frame()
assert(writes == 10, "Text mode flushes one blit per row")
frame()
assert(writes == 10, "Unchanged text rows never reach the peripheral")
print(
	"CIVCRAFT: one-call graphics frames, cached sprite clipping, text row batching and unchanged-row reuse passed."
)
local oldEpoch, oldQueue, oldPull = os.epoch, os.queueEvent, os.pullEvent
local events = {
	{ "mouse_click", 1, 12, 15 },
	{ "mouse_drag", 1, 14, 16 },
	{ "mouse_up", 1, 14, 16 },
	{ "rednet_message", 7, { action = "end" }, "protocol" },
}
os.epoch = function()
	return 100
end
os.queueEvent = function(...)
	events[#events + 1] = { ... }
end
os.pullEvent = function()
	local e = table.remove(events, 1)
	assert(e, "Checkpoint must not wait forever")
	return table.unpack(e)
end
r:cooperate(true)
assert(
	#events == 0 and #r.pendingEvents == 4,
	"Yield buffers every event preceding the render sentinel"
)
local e, b, x, y = r:pullEvent()
assert(e == "mouse_click" and b == 1 and x == 12 and y == 15)
assert(r:pullEvent() == "mouse_drag")
assert(r:pullEvent() == "mouse_up")
local e, id, data, protocol = r:pullEvent()
assert(e == "rednet_message" and id == 7 and data.action == "end" and protocol == "protocol")
os.epoch, os.queueEvent, os.pullEvent = oldEpoch, oldQueue, oldPull
print("CIVCRAFT: cooperative render yields preserve click, drag, release and network event order.")
local oldStart, oldCancel = os.startTimer, os.cancelTimer
events = { { "mouse_click", 1, 4, 5 }, { "timer", 777 } }
os.epoch = function()
	return 200
end
os.queueEvent = function() end -- Simulate a lost sentinel event.
os.startTimer = function(delay)
	assert(delay == 0.05)
	return 777
end
local cancelled
os.cancelTimer = function(timer)
	cancelled = timer
end
os.pullEvent = function()
	local event = table.remove(events, 1)
	assert(event, "Yield needs a bounded fallback")
	return table.unpack(event)
end
r:cooperate(true)
assert(
	cancelled == 777 and r:pullEvent() == "mouse_click",
	"Timer fallback preserves input if the render sentinel is lost"
)
os.epoch, os.queueEvent, os.pullEvent = oldEpoch, oldQueue, oldPull
os.startTimer, os.cancelTimer = oldStart, oldCancel
print("CIVCRAFT: render checkpoint recovers when its sentinel event is lost.")

-- A slow display/runtime can spend its whole watchdog budget in fewer than
-- 128 primitives, or in a single sprite. Model elapsed work between rows.
local now, yielded = 1000, 0
events = {}
os.epoch = function()
	return now
end
os.queueEvent = function(...)
	events[#events + 1] = table.pack(...)
end
os.pullEvent = function()
	yielded = yielded + 1
	return table.unpack(assert(table.remove(events, 1)))
end
os.startTimer, os.cancelTimer = nil, nil
r:begin()
local beforeSprite = yielded
local sprite = setmetatable({}, {
	__index = function(_, row)
		assert(now - r.lastYield <= 40, "Sprite rows must not accumulate unyielded work")
		if row > 12 then
			return nil
		end
		now = now + 40
		return string.char(8):rep(20)
	end,
})
r:blit(sprite, 0, 0)
assert(yielded >= beforeSprite + 12, "One expensive sprite yields between rows")
local beforeFill = yielded
now = now + 40
r:fill(0, 0, 1, 1, 8)
assert(yielded > beforeFill, "An overdue primitive yields without waiting for 128 calls")
r:finish()
os.epoch, os.queueEvent, os.pullEvent = oldEpoch, oldQueue, oldPull
os.startTimer, os.cancelTimer = oldStart, oldCancel
print("CIVCRAFT: slow sprites and infrequent drawing calls respect the render time budget.")
