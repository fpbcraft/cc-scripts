-- Exercise the actual Cogworks game loop using an attached graphics monitor.
-- Prior tests only covered a text-mode monitor or the renderer in isolation.
package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local saved = {}
local monitor = { w = 70, h = 40, pw = 400, ph = 260, scale = 1, clears = 0, uploads = 0, mode = 0 }
function monitor.getSize(mode)
	if mode == 2 then
		return monitor.pw, monitor.ph
	end
	return monitor.w, monitor.h
end
function monitor.setGraphicsMode(mode)
	monitor.mode = mode
end
function monitor.getTextScale()
	return monitor.scale
end
function monitor.setTextScale(value)
	monitor.scale = value
end
function monitor.isColor()
	return true
end
function monitor.getPaletteColor()
	return 0, 0, 0
end
function monitor.setPaletteColor() end
function monitor.setFrozen() end
function monitor.drawPixels(x, y, data, w, h)
	assert(
		x >= 0 and y >= 0 and x + w <= monitor.pw and y + h <= monitor.ph,
		"Monitor frame out of bounds"
	)
	if type(data) == "number" then
		if x == 0 and y == 0 and w == monitor.pw and h == monitor.ph then
			monitor.clears = monitor.clears + 1
			assert(data == 0, "Full monitor clear must use blueprint color")
		end
	else
		assert(type(data) == "table" and #data == h and #data[1] == w, "Bitmap upload")
		monitor.uploads = monitor.uploads + 1
	end
end
peripheral = {
	getNames = function()
		return { "top" }
	end,
	getType = function(name)
		return name == "top" and "monitor" or nil
	end,
	wrap = function(name)
		return name == "top" and monitor or nil
	end,
}
local seen = {}
local App = {}
App.__index = App
function App.new()
	local g = E.sandbox()
	return setmetatable({
		scene = "title",
		game = g,
		result = E.evaluate(g),
		settings = { animations = true, showPorts = false },
		selected = "I",
		message = "",
		slots = {
			{ number = 1, empty = true },
			{ number = 2, empty = true },
			{ number = 3, empty = true },
		},
		progress = { awards = {}, unlocked = 1 },
	}, App)
end
function App:model()
	return self
end
function App:save()
	return false
end
function App:act(action, x, y)
	seen[#seen + 1] = { action, x, y }
	if action == "sandbox" then
		self.scene = "game"
	elseif action == "inspect" then
		if E.get(self.game, x, y) then
			self.inspected = { x = x, y = y }
		else
			assert(E.place(self.game, x, y, self.selected), "Monitor tap must place a part")
			self.inspected = nil
		end
		self.result = E.evaluate(self.game)
	elseif action == "pause" then
		self.scene = "pause"
	end
end
package.loaded["games.cogworks.app"] = App
local Renderer = require("games.cogworks.render")
local renderer, originalNew = nil, Renderer.new
Renderer.new = function(device)
	renderer = originalNew(device)
	return renderer
end
local function target(action, x, y)
	for _, box in ipairs(renderer.targets) do
		if box.action == action and (x == nil or box.arg == x) and (y == nil or box.arg2 == y) then
			return (box.x + box.w / 2) * renderer.scale, (box.y + box.h / 2) * renderer.scale
		end
	end
	error("Missing monitor control: " .. action)
end
local function touch(action, x, y)
	local px, py = target(action, x, y)
	return "monitor_touch",
		"top",
		math.floor(px / monitor.pw * monitor.w) + 1,
		math.floor(py / monitor.ph * monitor.h) + 1
end
local events = {
	function()
		return touch("sandbox")
	end,
	function()
		return touch("cell", 2, 3)
	end,
	function()
		return touch("cell", 2, 3)
	end,
	function()
		monitor.pw, monitor.ph = 440, 240
		return "monitor_resize", "top"
	end,
	function()
		local x, y = target("cell", 3, 3)
		return "mouse_click", 2, x, y
	end,
	function()
		local x, y = target("cell", 3, 3)
		return "mouse_up", 2, x, y
	end,
	function()
		return "terminate"
	end,
}
local sequence, oldPull, oldTimer = 0, os.pullEventRaw, os.startTimer
os.startTimer = function()
	return 1
end
os.pullEventRaw = function()
	sequence = sequence + 1
	return assert(events[sequence], "Ran out of input events")()
end
local ok, err = pcall(function()
	assert(loadfile("games/cogworks/main.lua"))()
end)
os.pullEventRaw, os.startTimer, Renderer.new = oldPull, oldTimer, originalNew
package.loaded["games.cogworks.app"] = nil
assert(ok, tostring(err))
assert(
	monitor.mode == 0 and monitor.scale == 1,
	"Monitor graphics and text scale restored after exit"
)
assert(monitor.clears >= 2, "Startup and resize both clear all pixels")
assert(monitor.uploads >= 4, "Monitor scenes were drawn as bitmaps")
assert(seen[1][1] == "sandbox", "Vanilla monitor_touch activates Free Sandbox")
assert(
	seen[2][1] == "inspect" and seen[2][2] == 2 and seen[2][3] == 3,
	"Monitor touch targets board coordinates"
)
assert(seen[3][1] == "inspect", "Tapping existing part selects corner controls")
print("COGWORKS: attached graphics monitor buttons, placement, resize and mouse fallback passed.")
