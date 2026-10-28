local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Renderer = native("games/civcraft/render.lua")
local uploads = 0
local monitor = {
	getSize = function(mode)
		if mode == 2 then
			return 240, 180
		end
		return 40, 20
	end,
	setGraphicsMode = function() end,
	getPaletteColor = function()
		return 0, 0, 0
	end,
	setPaletteColor = function() end,
	drawPixels = function()
		uploads = uploads + 1
	end,
}
local full = Renderer.new(monitor)
local layout = Renderer.new(monitor, { layoutOnly = true })
assert(layout.mode == full.mode and layout.w == full.w and layout.h == full.h)
assert(layout:textWidth("HELLO") == full:textWidth("HELLO"))
local selected = false
layout:begin()
layout:fill(0, 0, layout.w, layout.h, 0)
layout:text(4, 4, "HELLO", 7)
layout:icon("station", 5, 5, 1)
layout:line(0, 0, 40, 30, 8)
layout:blit({ string.char(2, 2) }, 0, 0)
layout:button(4, 5, 48, 12, "SELECT", function()
	selected = true
end)
assert(layout.buffer == nil and layout.textBuffer == nil)
assert(#layout.buttons == 1 and layout.buttons[1].label == "SELECT")
assert(layout:hit(10, 10) == "SELECT" and selected)
layout:finish()
assert(uploads == 0, "Layout-only renderer cannot upload pixels")
full:begin()
full:fill(0, 0, full.w, full.h, 0)
full:button(4, 5, 48, 12, "SELECT", function() end)
full:finish()
assert(#full.buttons == 1 and uploads == 1)
assert(full.buttons[1].x == layout.buttons[1].x)
assert(full.buttons[1].w == layout.buttons[1].w)
print("CIVCRAFT: layout-only buttons, geometry and hit tests match the full renderer.")
