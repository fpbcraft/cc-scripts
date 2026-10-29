-- Dedicated native test: deliberately model a slow device for twenty seconds.
-- Run in an isolated computer; the normal regression suite uses a virtual clock.
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
local Renderer = env.dofile("/games/civcraft/render.lua")
local renderer = Renderer.new(term)
local instrumented = renderer.mode ~= "graphics"
if instrumented then
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 600, 900
			end
			return 100, 100
		end,
		setGraphicsMode = function() end,
		drawPixels = function() end,
	}
	renderer = Renderer.new(monitor)
end
assert(renderer.mode == "graphics", "This reproduction requires native graphics")
renderer:begin()
local sprite = setmetatable({}, {
	__index = function(_, row)
		if row > 100 then
			return nil
		end
		local started = os.epoch("utc")
		local elapsed = 0
		while elapsed < 200 do
			-- Keep each row bounded but the complete primitive above the watchdog.
			elapsed = os.epoch("utc") - started
		end
		return string.char(8):rep(renderer.w)
	end,
})
local started = os.epoch("utc")
local ok, reason = pcall(function()
	renderer:blit(sprite, 0, 0)
	renderer:finish()
end)
local report = {
	host = _G._HOST,
	instrumented = instrumented,
	ok = ok,
	error = reason,
	elapsed = os.epoch("utc") - started,
	yields = renderer.yieldToken,
}
renderer:close()
local file = assert(fs.open("/civcraft-render-watchdog.txt", "w"))
file.write(textutils.serialize(report))
file.close()
assert(ok, reason)
assert(report.yields >= 100, "Slow sprite rows must yield individually")
print("CIVCRAFT: native slow-sprite watchdog regression passed.")
