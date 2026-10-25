local Colors = dofile("/games/civcraft/faction_colors.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Factions = {}

function Factions.draw(ui, state, observer, rect)
	local r = ui.r
	r:text(rect.x + 4, rect.y + 4, "FACTIONS", 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local rows = {}
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, rect.w - 20)) do
			rows[#rows + 1] = { text = line, color = color }
		end
	end
	for index, player in ipairs(state.players or {}) do
		local own = player.id == observer.id
		local civilization = Systems.civ(player.civ)
		text(player.name .. (own and " (YOU)" or ""), Colors.players[index] or 8)
		text(civilization.name .. " / " .. (player.ai and "AI" or "HUMAN"))
		text("BONUS: " .. civilization.bonus)
		if player.ai then
			text("PERSONALITY: " .. Personalities.forCivilization(player.civ).archetype:upper())
		end
		local age = own and Systems.age(player) or player.age
		text("AGE: " .. (age and Systems.ages[age] and Systems.ages[age].name or "UNKNOWN"))
		local cities, units = 0, 0
		for _, city in ipairs(state.cities or {}) do
			if
				city.owner == player.id
				and (own or World.known(observer, city.x, city.y) == "visible")
			then
				cities = cities + 1
			end
		end
		for _, unit in ipairs(state.units or {}) do
			if
				unit.owner == player.id
				and (own or World.known(observer, unit.x, unit.y) == "visible")
			then
				units = units + 1
			end
		end
		text(
			(own and "TOTAL" or "CURRENTLY VISIBLE")
				.. ": "
				.. cities
				.. " CITIES, "
				.. units
				.. " UNITS"
		)
		rows[#rows + 1] = { text = "" }
	end
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 21 },
		rows,
		ui,
		"factionOffset"
	)
end

return Factions
