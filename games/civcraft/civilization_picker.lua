local Panels = dofile("/games/civcraft/panels.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Picker = {}
function Picker.draw(ui, state)
	local r = ui.r
	local width, height = math.min(180, r.w - 8), math.min(148, r.h - 17)
	local x, y = r.w - width - 4, 14
	local anchor = ui.civAnchor
	if anchor then
		x = math.max(4, math.min(anchor.x, r.w - width - 4))
		local below, above = r.h - anchor.y - anchor.h - 4, anchor.y - 4
		if below >= 40 then
			height, y = math.min(148, below), anchor.y + anchor.h + 1
		elseif above >= 40 then
			height = math.min(148, above)
			y = anchor.y - height - 1
		end
	end
	local rect = { x = x, y = y, w = width, h = height }
	ui.modalBounds = rect
	r.buttons, r.scrollbars = {}, {}
	r:fill(rect.x, rect.y, width, height, 1)
	r:outline(rect.x, rect.y, width, height, 8)
	r:text(rect.x + 3, rect.y + 3, "CIVILIZATION", 8, 1, width - 42)
	r:button(rect.x + width - 37, rect.y + 1, 35, 10, "CLOSE", function()
		ui.civDropdown = nil
	end)
	local chosen = state.players[ui.civDropdown]
	local rows = {}
	for _, civ in ipairs(Systems.civs) do
		rows[#rows + 1] = {
			buttons = {
				{
					label = civ.name,
					style = { selected = chosen and chosen.civ == civ.id },
					run = function()
						local index = ui.civDropdown
						ui.civDropdown = nil
						ui:command("civ", { player = index, id = civ.id })
					end,
				},
			},
		}
	end
	Panels.rows(
		r,
		{ x = rect.x + 3, y = rect.y + 13, w = width - 6, h = height - 16 },
		rows,
		ui,
		"civOffset"
	)
end
return Picker
