-- Real high-resolution Create-inspired machinery renderer regressions.
package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local R = require("games.cogworks.render")
local monitor = { cw = 120, ch = 66, pw = 960, ph = 660, mode = 0 }
function monitor.getSize(mode)
	if mode == 2 then
		return monitor.pw, monitor.ph
	end
	return monitor.cw, monitor.ch
end
function monitor.setGraphicsMode(value)
	monitor.mode = value
end
function monitor.getPaletteColor()
	return 0, 0, 0
end
function monitor.setPaletteColor() end
function monitor.setFrozen() end
function monitor.drawPixels(x, y, fill, w, h)
	assert(x >= 0 and y >= 0 and x + w <= monitor.pw and y + h <= monitor.ph)
end
local r = R.new(monitor)
assert(r.wide, "Create-inspired sprites need high-resolution graphics")
r.cell = 32
local function fingerprint()
	local rows = {}
	for y = 1, 42 do
		local cells = {}
		for x = 1, 42 do
			cells[x] = string.char((r.buffer[y] and r.buffer[y][x]) or 0)
		end
		rows[#rows + 1] = table.concat(cells)
	end
	return table.concat(rows)
end
local moving = { powered = true, ports = { [1] = { sign = 1, rate = 1 } } }
local backwards = { powered = true, ports = { [1] = { sign = -1, rate = 1 } } }
local fast = { powered = true, ports = { [1] = { sign = 1, rate = 2 } } }
local stopped = { powered = false }
local function sprite(kind, lighting, seconds)
	r.motionNow = seconds
	r.buffer = {}
	r:piece(5, 5, 32, { kind = kind, r = 1, speed = 1, sign = 1 }, lighting)
	return fingerprint()
end
for _, kind in ipairs({ "I", "G", "O", "Q", "V", "D", "C", "Z", "S", "M", "X" }) do
	local frame = sprite(kind, moving, 0)
	assert(
		frame ~= string.rep(string.char(0), #frame),
		"Each mechanism draws a real sprite: " .. kind
	)
end
assert(
	sprite("G", moving, 0) ~= sprite("O", moving, 0),
	"Cogwheel and large cogwheel have different silhouettes"
)
assert(sprite("I", moving, 0) ~= sprite("Q", moving, 0), "Shaft and gearbox have different casings")
assert(
	sprite("D", moving, 0) ~= sprite("V", moving, 0),
	"Chain drive and belt have different pulley artwork"
)
assert(
	sprite("C", moving, 0) ~= sprite("Z", moving, 0),
	"Clutch and reversing gearbox have distinct states"
)
assert(
	sprite("G", moving, 0.0) ~= sprite("G", moving, 0.14),
	"Small cog animates between subsecond frames"
)
assert(
	sprite("O", moving, 0.0) ~= sprite("O", moving, 0.14),
	"Large cog animates between subsecond frames"
)
assert(
	sprite("I", moving, 0.0) ~= sprite("I", moving, 0.14),
	"Metal shaft rotates its specular highlight"
)
assert(sprite("G", moving, 0.14) ~= sprite("G", backwards, 0.14), "Rotation sign reverses the gear")
assert(sprite("G", moving, 0.14) ~= sprite("G", fast, 0.14), "Kinetic speed changes the gear phase")
assert(
	sprite("G", stopped, 0.0) == sprite("G", stopped, 0.14),
	"An unpowered gear does not animate"
)
r.buffer = {}
r.motionNow = 0
r:drawSpan(5, 16, 36, 16, "V", true, moving)
local beltA = fingerprint()
r.buffer = {}
r.motionNow = 0.17
r:drawSpan(5, 16, 36, 16, "V", true, moving)
assert(fingerprint() ~= beltA, "Powered belt strands scroll smoothly")
r.buffer = {}
r.motionNow = 0
r:drawSpan(5, 16, 36, 16, "D", true, moving)
assert(fingerprint() ~= beltA, "Encased chain and belt have distinct transmission surfaces")
r.buffer = {}
r:redstonePiece(nil, { kind = "B", id = 1 }, { redstone = { [1] = true } }, 5, 5, 31)
local litBlock = fingerprint()
r.buffer = {}
r:redstonePiece(nil, { kind = "B", id = 1 }, { redstone = { [1] = false } }, 5, 5, 31)
assert(fingerprint() ~= litBlock, "Redstone block communicates powered state")
r:close()
assert(monitor.mode == 0, "Graphics renderer restores terminal mode")
print(
	"COGWORKS: Create-style gear, shaft, gearbox, pulley, chain, clutch, redstone and smooth motion sprites passed."
)
