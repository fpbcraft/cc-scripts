-- Verify windowed computer fallback independently of Minecraft/CC: Graphics.
local script = assert(loadfile("games/cogworks/terminal_view.lua"))
local V = script()
colors = { white = 1, black = 32768, gray = 128 }
local device = { w = 51, h = 19, calls = 0, output = {} }
function device.getSize()
	return device.w, device.h
end
function device.isColor()
	return true
end
function device.setTextColor(c)
	device.fg = c
end
function device.setBackgroundColor(c)
	device.bg = c
end
function device.setCursorPos(x, y)
	assert(
		x >= 1 and y >= 1 and x <= device.w and y <= device.h,
		"Attempt to draw outside physical terminal"
	)
	device.x, device.y = x, y
end
function device.setCursorBlink() end
function device.write(s)
	assert(device.x + #s - 1 <= device.w, "Physical write overflows row")
	device.calls = device.calls + 1
	device.output[device.y] = device.output[device.y] or {}
	device.output[device.y][device.x] = s
end
function device.clear() end
local v = V.new(device, 80, 54)
assert(v.terminal and v.getSize() == 80, "Virtual dimensions")
v.setCursorPos(70, 32)
v.setTextColor(colors.white)
v.setBackgroundColor(colors.black)
v.write("POWER")
v.present()
assert(device.calls > 0, "Renders physical terminal")
local x, y = v.mouse(3, 4)
assert(x == 3 and y == 4, "Initial screen maps to virtual origin")
v.pan(30, 25)
local a, b = v.mouse(3, 4)
assert(a == 32 and b == 29, "Pan must clamp to virtual bounds")
v.setCursorPos(32, 29)
v.write("GEAR")
v.present()
assert(v.mouse(1, 19) == nil, "Footer cannot click through")
device.w, device.h = 39, 17
v.present()
local ox, oy = v.viewport()
assert(ox <= 41 and oy <= 38, "Clamped after terminal resize")
v.pan(-100, -100)
assert(v.mouse(2, 2) == 2, "Pan reset")
v.close()
print("Computer terminal viewport: rendering, panning, resizing and click offsets passed.")
