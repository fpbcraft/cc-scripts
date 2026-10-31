-- Compact action tiles for owned-unit inspector controls.
local A = {}
local builderWork = {
	["WHEAT FIELD"] = { icon = "food", name = "WHEAT FIELD" },
	QUARRY = { icon = "ore", name = "QUARRY" },
	["LUMBER CAMP"] = { icon = "wood", name = "LUMBER CAMP" },
}
local definitions = {
	["ATTACH ESCORT"] = {
		icon = "plus",
		short = "LINK",
		help = "Attach this formation to its escort.",
	},
	["DETACH ESCORT"] = { icon = "minus", short = "UNLINK", help = "Detach the linked escort." },
	["MOVE / ATTACK"] = {
		icon = "right",
		short = "MOVE",
		help = "Show legal movement and attack destinations.",
	},
	["QUEUE MOVES"] = {
		icon = "map",
		short = "QUEUE",
		help = "Choose a route destination for this unit.",
	},
	["ADD WAYPOINT"] = {
		icon = "plus",
		short = "WAYPT",
		help = "Append a destination to the current route.",
	},
	["CANCEL ROUTE"] = { icon = "back", short = "CANCEL", help = "Cancel the queued route." },
	["SKIP TURN"] = {
		icon = "clock",
		short = "SKIP",
		help = "Skip this unit for the current turn.",
	},
	["SLEEP UNIT"] = {
		icon = "pause",
		short = "SLEEP",
		help = "Keep this unit out of future turn reminders.",
	},
	["WAKE UNIT"] = { icon = "bolt", short = "WAKE", help = "Restore this unit to active orders." },
	["FORTIFY / HEAL"] = {
		icon = "shield",
		short = "HEAL",
		help = "Rest this unit and recover health.",
	},
	["CANCEL WORK"] = {
		icon = "wrench",
		short = "CANCEL",
		help = "Cancel this builder's queued work.",
	},
	["RESUME WORK"] = { icon = "right", short = "RESUME", help = "Resume the paused work queue." },
	["AUTO WORK"] = {
		icon = "bolt",
		short = "AUTO",
		help = "Choose useful legal improvements on your observed owned land.",
	},
	["PAUSE AUTO WORK"] = {
		icon = "pause",
		short = "PAUSE",
		help = "Pause automatic Builder orders and cancel its current task.",
	},
	["RESUME AUTO WORK"] = {
		icon = "right",
		short = "RESUME",
		help = "Resume automatic Builder orders using current observations.",
	},
	["STOP AUTO WORK"] = {
		icon = "back",
		short = "STOP",
		help = "Stop automatic Builder orders and cancel its current task.",
	},
	["WORK MODE: APPEND"] = {
		icon = "plus",
		short = "APPEND",
		help = "Append new work to the current queue.",
	},
	["WORK MODE: REPLACE"] = {
		icon = "contract",
		short = "REPLACE",
		help = "Replace the current work queue.",
	},
	["BUILD RAIL (2 IRON)"] = {
		icon = "train",
		short = "RAIL",
		help = "Build a railway for two iron.",
	},
	["AUTO EXPLORE"] = {
		icon = "search",
		short = "EXPLORE",
		help = "Explore automatically along safe routes.",
	},
	["STOP EXPLORING"] = { icon = "back", short = "STOP", help = "Stop automatic exploration." },
	["CANCEL MOVE"] = {
		icon = "minus",
		short = "CANCEL",
		help = "Cancel movement selection without changing orders.",
	},
	["DISBAND"] = { icon = "danger", short = "REMOVE", help = "Permanently disband this unit." },
	["DESELECT"] = { icon = "minus", short = "CLEAR", help = "Clear the current unit selection." },
	["FOUND CITY"] = { icon = "station", short = "FOUND", help = "Found a city at this location." },
	["FOUND CAPITAL"] = {
		icon = "star",
		short = "CAPITAL",
		help = "Found your capital at this location.",
	},
}

function A.decorate(button)
	local label = tostring(button.label or "")
	local definition = definitions[label]
	local workName = label:match("^PLAN (.+)$") or label:match("^(.+) HERE$")
	local work = builderWork[workName]
	if work then
		local planning = label:match("^PLAN ") ~= nil
		definition = {
			icon = work.icon,
			short = planning and "PLAN" or "HERE",
			help = planning and ("Plan a " .. work.name .. " on a legal owned tile.")
				or ("Build a " .. work.name .. " here after confirming its preview."),
			workAction = planning and "plan" or "here",
		}
	end
	if not definition and (label:match("^PLAN ") or label:match(" HERE$")) then
		definition = { icon = "wrench", short = label:match(" HERE$") and "BUILD" or "PLAN" }
	end
	if not definition then
		definition = { icon = "wrench", short = label:sub(1, 6) }
	end
	button.icon = button.icon or definition.icon
	button.shortLabel = button.shortLabel or definition.short
	button.help = button.help or definition.help or button.label
	button.workAction = button.workAction or definition.workAction
	return button
end

function A.columns(width)
	local labels = width >= 90
	local minimum = labels and 44 or 20
	local gap = 2
	local columns = math.floor((width + gap) / (minimum + gap))
	return math.max(1, math.min(4, columns)), labels
end

function A.expand(rows, width)
	local expanded, pending = {}, {}
	local function flush()
		if #pending == 0 then
			return
		end
		local columns, labels = A.columns(width)
		for first = 1, #pending, columns do
			local buttons = {}
			for index = first, math.min(#pending, first + columns - 1) do
				buttons[#buttons + 1] = pending[index]
			end
			expanded[#expanded + 1] = {
				actionButtons = buttons,
				columns = columns,
				showLabels = labels,
			}
		end
		pending = {}
	end
	for _, row in ipairs(rows) do
		if row.unitActions then
			for _, button in ipairs(row.buttons or {}) do
				pending[#pending + 1] = button
			end
		else
			flush()
			expanded[#expanded + 1] = row
		end
	end
	flush()
	return expanded
end

function A.draw(r, rect, row, y)
	local gap = 2
	local columns = row.columns
	local width = math.floor((rect.w - gap * (columns - 1)) / columns)
	for index, button in ipairs(row.actionButtons) do
		local x = rect.x + (index - 1) * (width + gap)
		local iconOnly = not row.showLabels or width < 40
		local options = {}
		for key, value in pairs(button.style or {}) do
			options[key] = value
		end
		options.icon = button.icon
		options.help = button.help or button.label
		options.compactAction = true
		options.iconOnly = iconOnly
		options.displayLabel = not iconOnly and button.shortLabel or nil
		r:button(x, y, width, 11, button.label, button.run, options)
		if button.workAction and iconOnly then
			-- A small plus marks a planned site; a small outlined target marks
			-- the immediate HERE shortcut. Both stay visible with the work glyph.
			local markerX = x + width - 5
			local markerY = y + 2
			local markerColor = options.primary and 7 or 13
			if button.workAction == "plan" then
				r:fill(markerX, markerY + 1, 3, 1, markerColor)
				r:fill(markerX + 1, markerY, 1, 3, markerColor)
			else
				r:fill(markerX, markerY, 3, 1, markerColor)
				r:fill(markerX, markerY, 1, 3, markerColor)
				r:fill(markerX + 2, markerY, 1, 3, markerColor)
				r:fill(markerX, markerY + 2, 3, 1, markerColor)
			end
		end
	end
end

return A
