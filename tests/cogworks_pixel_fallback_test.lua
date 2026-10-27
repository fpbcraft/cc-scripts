package.path = "./?.lua;./?/init.lua;" .. package.path
-- Headless CraftOS exposes pixel methods but cannot enter graphics mode.
-- Exercise the production startup path with a real viewport and renderer.
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
	brown = 4096,
}
local native = { writes = 0, pixelAttempts = 0 }
function native.getSize()
	return 51, 19
end
function native.setGraphicsMode()
	native.pixelAttempts = native.pixelAttempts + 1
	error("Graphics unavailable on this backend")
end
function native.drawPixels()
	error("Must not draw pixels after graphics initialization fails")
end
function native.isColor()
	return true
end
function native.setBackgroundColor() end
function native.setTextColor() end
function native.setCursorBlink() end
function native.clear() end
function native.setCursorPos(x, y)
	assert(x >= 1 and x <= 51 and y >= 1 and y <= 19)
end
function native.write(value)
	assert(#value <= 51, "Viewport clips physical terminal writes")
	native.writes = native.writes + 1
end
term = {
	current = function()
		return native
	end,
}
peripheral = {
	getNames = function()
		return {}
	end,
}
fs = {
	exists = function()
		return false
	end,
}
local viewport = require("games.cogworks.terminal_view")
local wrapped = false
package.loaded["games.cogworks.terminal_view"] = {
	new = function(device, width, height)
		assert(device == native and width == 70 and height == 40)
		wrapped = true
		return viewport.new(device, width, height)
	end,
}
local pull, timer = os.pullEventRaw, os.startTimer
os.startTimer = function()
	return 1
end
os.pullEventRaw = function()
	return "terminate"
end
local ok, reason = pcall(assert(loadfile("games/cogworks/main.lua")))
os.pullEventRaw, os.startTimer = pull, timer
assert(ok, tostring(reason))
assert(
	native.pixelAttempts > 0 and wrapped and native.writes > 0,
	"Failed pixel mode must use the text viewport"
)
print(
	"COGWORKS: advertised but unavailable native pixel mode falls back to a usable text viewport."
)
