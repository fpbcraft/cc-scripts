-- Verify bulk bitmap flushes, dirty rows and unchanged text-mode fallback.
local B = dofile("lib/fpb/pixelbuffer.lua")
local calls = {}
local device = {}
function device.drawPixels(x, y, pixels, width, height)
  calls[#calls + 1] = { x = x, y = y, pixels = pixels, width = width, height = height }
end
local canvas = {
  mode = "graphics",
  m = device,
  sx = 2,
  sy = 2,
  ox = 0,
  oy = 0,
  w = 12,
  h = 6,
  pw = 24,
  ph = 12,
}
function canvas:resize() end
function canvas:close() end
local r = B.attach(canvas)
assert(r.buffered, "Graphics mode must use buffered drawing")
assert(#calls == 1 and calls[1].pixels == 0, "Only one initial native clear")
r:begin()
r:fill(2, 1, 3, 2, 14)
r:finish()
assert(#calls == 2, "Entire first frame must flush in one bulk draw")
local frame = calls[2]
assert(type(frame.pixels) == "table" and #frame.pixels == 12 and #frame.pixels[1] == 24)
assert(frame.pixels[3]:byte(5) == 14 and frame.pixels[3]:byte(11) == 0)
r:begin()
r:fill(2, 1, 3, 2, 14)
r:finish()
assert(#calls == 2, "Identical frames must not redraw pixels")
r:begin()
r:fill(2, 1, 3, 2, 14)
r:fill(6, 4, 1, 1, 8)
r:finish()
assert(#calls == 3, "Changing one row must flush one bulk draw")
assert(calls[3].y == 8 and #calls[3].pixels == 2, "Dirty row should span physical rows")
assert(calls[3].pixels[1]:byte(13) == 8)
r:close()

local text = { mode = "text" }
assert(B.attach(text) == text and not text.buffered, "Text-mode fallback must be unchanged")
local fractional = { mode = "graphics", m = device, sx = 1.5, sy = 2 }
assert(B.attach(fractional) == fractional and not fractional.buffered, "Unsupported scaling must fall back")
print("FPB framebuffer: dirty rows, binary bitmap batching and text fallback passed")
