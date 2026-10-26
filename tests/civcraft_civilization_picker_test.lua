local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local UI = dofile("/games/civcraft/ui.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 80, 45 }, { 120, 60 } }) do
		local state = {
			phase = "lobby",
			round = 1,
			players = {
				{ id = 0, name = "HOST", civ = "iron" },
				{ id = 1, name = "GUEST", civ = "scholar" },
			},
			units = {},
			cities = {},
		}
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
		local ui = UI.new(monitor, function(action, params)
			assert(action == "civ" and Rules.selectCivilization(state, 0, params, Systems.civs))
		end)
		local function draw()
			ui:draw(state, 0, { localMode = true, host = true, screen = "game" })
			if ui.civDropdown then
				for _, button in ipairs(ui.r.buttons) do
					assert(
						button.x >= 0
							and button.y >= 0
							and button.x + button.w <= ui.r.w
							and button.y + button.h <= ui.r.h
					)
				end
			end
		end
		for _, civ in ipairs(Systems.civs) do
			ui:command("civ", { player = 2 })
			assert(ui.civDropdown == 2, "CIV opens a chooser without changing the simulation")
			local selected = false
			for _ = 1, 12 do
				draw()
				local nextPage
				for _, button in ipairs(ui.r.buttons) do
					if button.label == "NEXT" then
						nextPage = button
					end
					if button.label == civ.name then
						button.fn()
						selected = true
						break
					end
				end
				if selected then
					break
				end
				assert(nextPage, "Every civilization is reachable").fn()
			end
			assert(selected and not ui.civDropdown and state.players[2].civ == civ.id)
		end
		ui:command("civ", { player = 1 })
		draw()
		assert(ui:back() and not ui.civDropdown, "Escape closes the dropdown")
		ui:close()
	end
end
local state = { phase = "lobby", players = { { id = 0 }, { id = 1 }, { id = 2, ai = true } } }
assert(Rules.selectCivilization(state, 1, { player = 2, id = "nomad" }, Systems.civs))
assert(not Rules.selectCivilization(state, 1, { player = 1, id = "nomad" }, Systems.civs))
assert(not Rules.selectCivilization(state, 2, { player = 3, id = "nomad" }, Systems.civs))
assert(not Rules.selectCivilization(state, 99, { player = 2, id = "nomad" }, Systems.civs))
assert(not Rules.selectCivilization(state, 0, { player = 2, id = "invalid" }, Systems.civs))
assert(not Rules.selectCivilization(state, 0, { player = 1.5, id = "nomad" }, Systems.civs))
assert(Rules.selectCivilization(state, 0, { player = 3, id = "nomad" }, Systems.civs))
state.phase = "game"
assert(not Rules.selectCivilization(state, 0, { player = 1, id = "nomad" }, Systems.civs))
print(
	"CIVCRAFT: civilization dropdown reaches every choice on six layouts; host/guest selection and phase validation passed."
)
