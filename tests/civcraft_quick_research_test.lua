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

local Q = dofile("/games/civcraft/quick_research.lua")
local function available(id, options)
	for _, option in ipairs(options) do
		if option.id == id then
			return option
		end
	end
end
local player = state.players[1]
player.techs = {}
player.researchProgress = { agriculture = 7, mining = 3 }
local before = Q.options(Systems, player, 2)
assert(
	available("agriculture", before) and not available("writing", before),
	"Locked technologies are absent"
)
assert(available("agriculture", before).progress == 7)
assert(
	available("agriculture", before).turns
		== math.max(1, math.ceil((Systems.techCost("agriculture", player) - 7) / 2))
)
assert(available("agriculture", Q.options(Systems, player, 0)).turns == nil)
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 80, 40 } }) do
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
			setCursorPos = function() end,
			setBackgroundColor = function() end,
			setTextColor = function() end,
			write = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.drawPixels = function() end
		end
		local commands = 0
		local ui = UI.new(monitor, function(action, request)
			assert(action == "researchTech")
			assert(Systems.research(player, request.id))
			commands = commands + 1
		end)
		local function draw()
			if os.queueEvent and os.pullEvent then
				os.queueEvent("quick_test_yield")
				os.pullEvent("quick_test_yield")
			end
			ui:draw(World.forPlayer(state, 0), 0, { screen = "game" })
			for _, button in ipairs(ui.r.buttons) do
				assert(
					button.x >= 0
						and button.y >= 0
						and button.x + button.w <= ui.r.w
						and button.y + button.h <= ui.r.h,
					"Quick control stays on screen"
				)
			end
		end
		local function press(label)
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn()
					return true
				end
			end
			return false
		end
		draw()
		assert(press("QUICK RESEARCH"))
		draw()
		assert(ui.panel == "quickResearch" and ui.modalBounds)
		if ui.r.w >= 220 and ui.r.h >= 110 then
			assert(
				ui.modalBounds.w < ui.r.w and ui.modalBounds.y >= 22,
				"Wide quick selection keeps the map visible below the HUD"
			)
		end
		local oldTile = ui.tile
		ui.tile = function()
			error("Quick modal cannot click through to map")
		end
		ui:tap(1, 1)
		ui.tile = oldTile
		assert(press("RESEARCH agriculture"))
		draw()
		assert(
			player.researchTarget == "agriculture"
				and player.researchProgress.agriculture == 7
				and player.researchProgress.mining == 3
		)
		local current = available("agriculture", ui.quickResearchOptions)
		assert(current.current)
		-- A delayed button cannot research an option removed by the latest snapshot.
		local stale
		for _, button in ipairs(ui.r.buttons) do
			if button.label == "RESEARCH agriculture" then
				stale = button.fn
			end
		end
		assert(stale)
		local selectedMining = false
		for _ = 1, 64 do
			if press("RESEARCH mining") then
				selectedMining = true
				break
			end
			assert(press("NEXT"), "Available mining remains reachable")
			draw()
		end
		assert(selectedMining)
		draw()
		assert(
			player.researchTarget == "mining"
				and player.researchProgress.agriculture == 7
				and player.researchProgress.mining == 3,
			"Switching through the quick picker preserves both projects' progress"
		)
		for _, candidate in ipairs(ui.state.players) do
			if candidate.id == 0 then
				candidate.techs.agriculture = true
			end
		end
		local count = commands
		stale()
		assert(commands == count, "Stale completed research is not submitted")
		assert(press("TECH TREE"))
		draw()
		assert(ui.panel == "tech")
		ui.panel = "quickResearch"
		ui.quickResearchOffset = 10000
		draw()
		assert(ui.quickResearchOffset <= #ui.quickResearchOptions)
		player.techs = {}
		player.researchTarget = nil
		for _, id in ipairs(Systems.techOrder) do
			player.techs[id] = true
		end
		draw()
		assert(#ui.quickResearchOptions == 0)
		assert(press("TECH TREE"))
		draw()
		assert(ui.panel == "tech")
		player.techs = {}
		player.researchTarget = nil
		ui:close()
	end
end
print(
	"PASS: eligible-only quick research, progress, estimates, stale commands, modal ownership, full tree and complete state"
)
