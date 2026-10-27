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
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local World = dofile("/games/civcraft/world.lua")
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 80, 45 } }) do
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
		local state = {
			phase = "lobby",
			round = 1,
			gameSpeed = "standard",
			hostileMode = "dangerous",
			players = {
				{ id = 0, name = "HOST", civ = "iron", techs = {} },
				{ id = -1, name = "BOT", ai = true, civ = "merchant", techs = {} },
			},
			cities = {},
			units = {},
		}
		local calls = 0
		local ui = UI.new(monitor, function(action, request)
			assert(action == "aiDifficulty")
			assert(Difficulty.configure(state, 0, request))
			calls = calls + 1
		end)
		local function draw()
			if os and os.queueEvent and os.pullEvent then
				os.queueEvent("difficulty_test_yield")
				os.pullEvent("difficulty_test_yield")
			end
			ui:draw(World.forPlayer(state, 0), 0, { screen = "game", localMode = true })
			if ui.panel == "campaign" then
				for _, button in ipairs(ui.r.buttons) do
					assert(
						button.x >= 0
							and button.y >= 0
							and button.x + button.w <= ui.r.w
							and button.y + button.h <= ui.r.h,
						"Difficulty control outside screen"
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
			ui.campaignOffset = 0
			for attempt = 1, 30 do
				draw()
				if click(label) then
					return
				end
				assert(click("NEXT"), label)
			end
			error("Difficulty control unreachable: " .. label)
		end
		find("CAMPAIGN OPTIONS")
		for _, level in ipairs({ "PRINCE", "KING", "DEITY", "SETTLER", "CHIEFTAIN" }) do
			find("BOT " .. level)
		end
		assert(calls == 5 and state.players[2].aiDifficulty == "prince")
		assert(
			state.hostileMode == "dangerous",
			"AI difficulty never changes hostile-mob difficulty"
		)
		find("CLOSE")
		assert(ui.panel == "context")
	end
end
print(
	"CIVCRAFT: compact/wide text/graphics campaign panels configure every AI difficulty independently of mobs."
)
