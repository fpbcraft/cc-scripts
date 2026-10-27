local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
colors = colors
	or {
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
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local state = {
	phase = "game",
	round = 1,
	ruleset = "create",
	players = { { id = 0, name = "HOST", civ = "iron", techs = {} } },
	cities = { { id = 1, owner = 0, x = 4, y = 4, population = 2, buildings = {} } },
	units = {},
	world = { width = 12, height = 8, tiles = {}, resources = {}, rails = {}, landmarks = {} },
}
for y = 1, 8 do
	for x = 1, 12 do
		state.world.tiles[World.key(x, y)] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 57, 26 }, { 57, 32 }, { 57, 38 } }) do
		local monitor = {
			getSize = function(mode)
				if mode == 2 then
					return size[1] * 6, size[2] * 9
				end
				return size[1], size[2]
			end,
			getPaletteColor = function()
				return 0, 0, 0
			end,
			setPaletteColor = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.drawPixels = function() end
		else
			monitor.setCursorPos = function() end
			monitor.setBackgroundColor = function() end
			monitor.setTextColor = function() end
			monitor.write = function() end
		end
		local ui = UI.new(monitor, function()
			error("Map tools must not issue simulation commands")
		end)
		local function draw()
			if os and os.queueEvent and os.pullEvent then
				os.queueEvent("toolbar_test_yield")
				os.pullEvent("toolbar_test_yield")
			end
			ui:draw(World.forPlayer(state, 0), 0, { screen = "game" })
			for index, button in ipairs(ui.r.buttons) do
				assert(
					button.x >= 0
						and button.y >= 0
						and button.x + button.w <= ui.r.w
						and button.y + button.h <= ui.r.h,
					"Map control outside screen: " .. tostring(button.label)
				)
				for prior = 1, index - 1 do
					local other = ui.r.buttons[prior]
					assert(
						button.x >= other.x + other.w
							or other.x >= button.x + button.w
							or button.y >= other.y + other.h
							or other.y >= button.y + button.h,
						"Map controls overlap: "
							.. tostring(button.label)
							.. " / "
							.. tostring(other.label)
					)
				end
			end
		end
		local function click(label)
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn()
					return true
				end
			end
		end
		local function find(label)
			for attempt = 1, 20 do
				draw()
				if click(label) then
					return
				end
				assert(click("NEXT"), label)
			end
			error("Unreachable map tool: " .. label)
		end
		draw()
		if ui.r.h < 100 then
			find("MAP TOOLS")
			find("YIELDS")
			assert(ui.overlays.yields and ui.panel == "context")
			draw()
			local tile = ui.mapViewport.tile
			find("MAP TOOLS")
			find("ZOOM IN")
			assert(ui.panel == "context")
			draw()
			assert(ui.mapViewport.tile == tile + 4)
			find("MAP TOOLS")
			find("WORLD OVERVIEW")
			assert(ui.panel == "minimap")
			draw()
			assert(click("CLOSE"))
		else
			assert(click("ZOOM IN"), "Taller screens keep direct toolbar actions")
		end
	end
end
print("CIVCRAFT: Eight short-screen layouts keep map controls in bounds, separate and reachable.")
