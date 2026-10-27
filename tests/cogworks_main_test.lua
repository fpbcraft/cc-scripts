-- Mock game loop, Advanced Monitor, save slots, and right-click extension.
package.path = "./?.lua;./?/init.lua;" .. package.path
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
local monitor = { w = 70, h = 40, scale = 1, writes = 0, history = {} }
function monitor.getSize()
	return monitor.w, monitor.h
end
function monitor.getTextScale()
	return monitor.scale
end
function monitor.setTextScale(v)
	monitor.scale = v
	monitor.history[#monitor.history + 1] = v
end
function monitor.setBackgroundColor() end
function monitor.setTextColor() end
function monitor.clear() end
function monitor.isColor()
	return true
end
function monitor.setCursorPos(x, y)
	assert(x >= 1 and y >= 1 and x <= monitor.w and y <= monitor.h, "Text cursor invalid")
end
function monitor.write(text)
	monitor.writes = monitor.writes + #text
end
-- Even a larger monochrome monitor must not displace a usable Advanced
-- Monitor, and the latter must run automatically at half text scale.
local plain = {
	getSize = function()
		return 90, 50
	end,
	isColor = function()
		return false
	end,
}
peripheral = {
	getNames = function()
		return { "monitor_plain", "monitor_1" }
	end,
	getType = function(side)
		return (side == "monitor_plain" or side == "monitor_1") and "monitor" or nil
	end,
	wrap = function(side)
		if side == "monitor_plain" then
			return plain
		end
		return side == "monitor_1" and monitor or nil
	end,
}
local files, dirs = {}, {}
local history = {}
local values = {}
local sequence = 0
local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local result = {}
	for k, v in pairs(t) do
		result[k] = copy(v)
	end
	return result
end
fs = {}
function fs.exists(path)
	return files[path] ~= nil or dirs[path] ~= nil
end
function fs.makeDir(path)
	dirs[path] = true
end
function fs.delete(path)
	files[path] = nil
	dirs[path] = nil
end
function fs.move(a, b)
	assert(files[a] ~= nil, "Missing file for rename " .. a)
	files[b] = files[a]
	files[a] = nil
end
function fs.open(path, mode)
	if mode == "r" then
		if files[path] == nil then
			return nil
		end
		local data = files[path]
		return {
			readAll = function()
				return data
			end,
			close = function() end,
		}
	end
	assert(mode == "w")
	local data = ""
	return {
		write = function(s)
			data = data .. s
		end,
		close = function()
			files[path] = data
		end,
	}
end
textutils = {
	serialize = function(data)
		sequence = sequence + 1
		local id = "SERIAL:" .. sequence
		values[id] = copy(data)
		if data.sessions and data.level then
			history[#history + 1] = copy(data)
		end
		return id
	end,
	unserialize = function(data)
		return values[data] and copy(values[data]) or nil
	end,
}
local events = {
	{ "monitor_touch", "monitor_1", 6, 13 }, -- title: save slots
	{ "monitor_touch", "monitor_1", 5, 5 }, -- slot one
	{ "monitor_touch", "monitor_1", 6, 18 }, -- briefing
	{ "monitor_touch", "monitor_1", 6, 18 }, -- tutorial
	{ "monitor_touch", "monitor_1", 10, 10 }, -- tap empty cell to place
	{ "monitor_touch", "monitor_1", 10, 10 }, -- tap occupied cell to inspect
	{ "char", "x" }, -- select the delete tool on a text monitor
	{ "monitor_touch", "monitor_1", 10, 10 }, -- remove occupied cell
	{ "char", "q" }, -- pause
	{ "monitor_touch", "monitor_1", 6, 24 }, -- title menu
	{ "char", "q" }, -- exit
}
local counter = 0
local oldPull, oldTimer = os.pullEventRaw, os.startTimer
os.startTimer = function()
	return 1
end
os.pullEventRaw = function()
	counter = counter + 1
	assert(events[counter], "No more mock events")
	return table.unpack(events[counter])
end
local ok, err = pcall(function()
	assert(loadfile("games/cogworks/main.lua"))()
end)
os.pullEventRaw, os.startTimer = oldPull, oldTimer
assert(ok, tostring(err))
assert(counter == #events, "All scenes must consume their test events")
assert(monitor.history[1] == 0.5, "Startup sets monitor text scale to 0.5")
assert(monitor.scale == 1, "Exit restores previous monitor scale")
assert(monitor.writes > 50, "Monitor should draw the title and game screens")
assert(files["/games/cogworks/saves/slot-1.dat"], "Save slot should exist")
local placed, removed = false, false
for _, progress in ipairs(history) do
	local parts = progress.sessions and progress.sessions[1] and progress.sessions[1].parts or {}
	if #parts == 1 and parts[1].kind == "I" then
		placed = true
	end
	if placed and #parts == 0 then
		removed = true
	end
end
assert(placed and removed, "Tap selection and erase tool must work on a vanilla monitor")
assert(#history >= 4, "Monitor placement/removal progress was persisted")
assert(files["/games/cogworks/settings.dat"], "Settings should persist")
print("COGWORKS: monitor choice, tap selection, delete, save, exit and 0.5 text scale passed.")
