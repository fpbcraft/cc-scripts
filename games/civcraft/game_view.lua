local Empire = dofile("/games/civcraft/empire_menu.lua")
local Codex = dofile("/games/civcraft/encyclopedia.lua")
local EventFeed = dofile("/games/civcraft/event_feed.lua")
local Danger = dofile("/games/civcraft/danger_view.lua")
local HUD = dofile("/games/civcraft/hud.lua")
local Inspector = dofile("/games/civcraft/inspector.lua")
local Map = dofile("/games/civcraft/map_view.lua")
local Minimap = dofile("/games/civcraft/minimap.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Reports = dofile("/games/civcraft/reports.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local TechTree = dofile("/games/civcraft/tech_tree.lua")
local G = {}
local modes = { "terrain", "territory", "resources", "yields" }
local function modal(ui, rect, preserve)
	ui.modalBounds = rect
	ui.lastDrag = nil
	ui.r.buttons = {}
	ui.r.scrollbars = {}
	if preserve then
		ui.r:fill(rect.x, rect.y, rect.w, rect.h, 1)
		ui.r:outline(rect.x, rect.y, rect.w, rect.h, 8)
	else
		ui.r:fill(0, 0, ui.r.w, ui.r.h, 0)
	end
end
function G.draw(ui, state, player)
	Danger.update(ui, state, player)
	local r = ui.r
	local w, h = r.w, r.h
	local wide = w >= 220 and h >= 140
	local header = 30
	local bottom = h - 15
	local sidebarColumns = h < 145 and 2 or 1
	local left = sidebarColumns == 2 and 30 or 16
	local right = wide and math.max(92, math.floor(w * 0.32))
		or math.max(48, math.min(72, math.floor(w * 0.42)))
	if ui.panel ~= "context" then
		ui.pendingMove = nil
		ui.cityStrikeSource = nil
		ui.source = nil
		ui.reachable = {}
	end
	ui.inputMode = "map"
	r:fill(0, 0, w, h, 0)
	r:fill(0, 0, w, header, 1)
	r:text(4, 3, "CIVCRAFT", 8, 1, 40)
	local infoX = 12 + r:textWidth("CIVCRAFT")
	r:text(
		infoX,
		3,
		"R"
			.. state.round
			.. " "
			.. (player and player.name or "")
			.. " / "
			.. (player and Systems.ages[Systems.age(player)].name or ""),
		7,
		1,
		w - 66 - infoX
	)
	HUD.resources(ui, state, player)
	r:text(
		4,
		header - 7,
		ui.hoverLabel or (ui.notice ~= "" and ui.notice or "SELECT A HEX OR AN ACTION"),
		6,
		1,
		w - 8
	)
	local function iconButton(x, y, width, label, icon, run, style)
		r:button(x, y, width, 12, nil, run, style)
		r:icon(icon, x + math.floor((width - 9) / 2), y + 1, 1)
		r.buttons[#r.buttons].label = label
		r.buttons[#r.buttons].icon = icon
	end
	for i, action in ipairs({
		{
			"EMPIRE",
			"station",
			function()
				ui.panel = "empire"
				ui.lastDrag = nil
			end,
		},
		{
			"CODEX",
			"book",
			function()
				ui.panel = "encyclopedia"
				ui.lastDrag = nil
			end,
		},
		{
			"REPORT",
			"contract",
			function()
				ui.panel = "report"
				ui.reportOffset = 0
			end,
		},
		{
			"PAUSE",
			"pause",
			function()
				ui:command("pause")
			end,
		},
	}) do
		iconButton(w - 62 + (i - 1) * 15, 1, 14, action[1], action[2], action[3])
	end
	Map.draw(
		ui,
		state,
		player,
		{ x = left + 4, y = header + 2, w = w - left - right - 10, h = bottom - header - 4 }
	)
	local y = header + 3
	local modeStep = 14
	for i, mode in ipairs(modes) do
		local icon = ({ "map", "station", "ore", "food" })[i]
		local x = 2 + ((i - 1) % sidebarColumns) * 14
		local width = 12
		y = header + 3 + math.floor((i - 1) / sidebarColumns) * 14
		ui.overlays = ui.overlays or {}
		r:button(x, y, 12, 12, nil, function()
			if mode == "terrain" then
				ui.overlays = {}
			else
				ui.overlays[mode] = not ui.overlays[mode]
				if mode == "yields" and ui.overlays.yields then
					local steps = (math.max(40, ui.mapViewport.tile) - ui.mapViewport.tile) / 4
					ui:zoom(steps)
				end
			end
		end, { selected = mode == "terrain" and not next(ui.overlays) or ui.overlays[mode] })
		do
			r:icon(
				icon,
				x + math.floor((width - 9) / 2),
				y + math.max(0, math.floor((modeStep - 11) / 2)),
				1
			)
			r.buttons[#r.buttons].label = mode:upper()
		end
	end
	for i, action in ipairs({ { "ZOOM IN", "plus", 1 }, { "ZOOM OUT", "minus", -1 } }) do
		local slot = #modes + i - 1
		iconButton(
			2 + (slot % sidebarColumns) * 14,
			header + 3 + math.floor(slot / sidebarColumns) * 14,
			12,
			action[1],
			action[2],
			function()
				ui:zoom(action[3])
			end
		)
	end
	iconButton(2, bottom - 13, 12, "WORLD OVERVIEW", "fullscreen", function()
		ui.panel = "minimap"
	end)
	Inspector.draw(
		ui,
		state,
		player,
		{ x = w - right - 2, y = header + 1, w = right, h = bottom - header - 3 }
	)

	local actions = {
		{
			"TECH TREE",
			"tree",
			function()
				ui.panel = "tech"
				ui.source = nil
				ui.reachable = {}
				ui.workCity = nil
				ui.lastDrag = nil
			end,
		},
		{
			"NEXT IDLE UNIT",
			"nextUnit",
			function()
				ui:nextIdle()
			end,
		},
	}
	local width = 12
	r:fill(0, bottom, w, 15, 1)
	for i, action in ipairs(actions) do
		iconButton(2 + (i - 1) * (width + 2), bottom + 1, width, action[1], action[2], action[3])
	end
	if ui:animating() then
		iconButton(30, bottom + 1, 12, "SKIP", "nextUnit", function()
			ui:command("skipPlayback")
		end)
	else
		iconButton(30, bottom + 1, 12, "OBSERVED EVENTS", "contract", function()
			ui.panel = "events"
			ui.eventOffset = 0
		end)
	end
	r:button(w - 54, bottom + 1, 52, 12, "END TURN", function()
		ui:command("end")
	end, { primary = true, icon = "endTurn" })
	r.buttons[#r.buttons].icon = "endTurn"
	local rect = { x = 3, y = 3, w = w - 6, h = h - 6 }
	if ui.disbandConfirm then
		modal(ui, rect, true)
		r:text(8, 8, "DISBAND UNIT?", 8)
		local pending = ui.disbandConfirm
		local rows = {
			{ text = "This permanently removes the unit." },
			{ text = "Its gold upkeep will stop." },
			{
				buttons = {
					{
						label = "CANCEL",
						run = function()
							ui.disbandConfirm = nil
						end,
					},
					{
						label = "DISBAND",
						run = function()
							ui.disbandConfirm = nil
							pending.confirmed = true
							ui:command("disband", pending)
							ui:deselect()
						end,
					},
				},
			},
		}
		Panels.rows(r, { x = 8, y = 22, w = w - 16, h = h - 30 }, rows, ui, "disbandOffset")
	elseif ui.endConfirm then
		modal(ui, rect)
		r:text(8, 7, "END TURN?", 8, 1, w - 16)
		r:button(7, 19, math.floor((w - 18) / 2), 11, "GO BACK", function()
			ui.endConfirm = nil
		end)
		r:button(math.floor(w / 2) + 2, 19, math.floor((w - 18) / 2), 11, "END ANYWAY", function()
			ui.endConfirm = nil
			ui:command("end", { confirmed = true })
		end)
		local rows = {}
		for _, entry in ipairs(ui.endConfirm) do
			for _, line in ipairs(Panels.wrap(r, entry.text, w - 22)) do
				rows[#rows + 1] = { text = line }
			end
			rows[#rows + 1] = {
				buttons = {
					{
						label = entry.kind == "research" and "CHOOSE RESEARCH"
							or "GO TO " .. entry.kind:upper(),
						run = function()
							ui.endConfirm = nil
							if entry.kind == "research" then
								ui.panel = "tech"
							else
								ui:focus(entry.kind, entry.item)
								if entry.kind == "city" then
									ui.cityPanel = "production"
								end
							end
						end,
					},
				},
			}
		end
		Panels.rows(r, { x = 8, y = 34, w = w - 16, h = h - 42 }, rows, ui, "endOffset")
	elseif ui.productionConfirm then
		modal(ui, rect, true)
		local pending = ui.productionConfirm
		local rows = {}
		for _, line in
			ipairs(
				Panels.wrap(
					r,
					"CHANGE "
						.. pending.previous:upper()
						.. " TO "
						.. (pending.params.kind == "none" and "NO PRODUCTION" or tostring(
							pending.params.id
						):upper())
						.. "? Current progress "
						.. pending.progress
						.. " is saved.",
					w - 22
				)
			)
		do
			rows[#rows + 1] = { text = line }
		end
		rows[#rows + 1] = {
			buttons = {
				{
					label = "KEEP CURRENT",
					run = function()
						ui.productionConfirm = nil
					end,
				},
				{
					label = "CHANGE",
					run = function()
						ui.productionConfirm = nil
						pending.params.confirmed = true
						ui:command("queue", pending.params)
					end,
				},
			},
		}
		r:text(8, 8, "CHANGE PRODUCTION?", 8)
		Panels.rows(r, { x = 8, y = 22, w = w - 16, h = h - 30 }, rows, ui, "productionOffset")
	elseif ui.pendingMove then
		local v = ui.mapViewport
		r:button(v.x + 2, v.y + 2, 12, 12, nil, function()
			ui.pendingMove = nil
		end)
		r:icon("back", v.x + 3, v.y + 3, 1)
		r.buttons[#r.buttons].label = "CANCEL"
		r:button(v.x + 16, v.y + 2, 12, 12, nil, function()
			ui:confirmMove()
		end, { primary = true })
		r:icon("endTurn", v.x + 17, v.y + 3, 1)
		r.buttons[#r.buttons].label = "CONFIRM"
	elseif ui.panel == "events" then
		modal(ui, rect)
		EventFeed.draw(ui, rect)
	elseif ui.panel == "report" then
		local dw, dh = math.min(w - 20, 280), math.min(math.floor(h * 0.7), 140)
		local box = { x = math.floor((w - dw) / 2), y = math.floor((h - dh) / 2), w = dw, h = dh }
		modal(ui, box, true)
		r:text(box.x + 5, box.y + 5, "ROUND " .. state.round .. " REPORT", 8, 1, dw - 50)
		r:button(box.x + dw - 41, box.y + 2, 36, 11, "CLOSE", function()
			ui.panel = "context"
		end)
		local rows = {}
		local lines = player.reportRound == state.round and player.turnReport
			or Reports.build(state, player)
		for _, entry in ipairs(lines or {}) do
			for _, line in ipairs(Panels.wrap(r, entry, dw - 22)) do
				rows[#rows + 1] = { text = line }
			end
		end
		Panels.rows(
			r,
			{ x = box.x + 5, y = box.y + 17, w = dw - 10, h = dh - 22 },
			rows,
			ui,
			"reportOffset"
		)
	elseif ui.panel == "tech" then
		modal(ui, rect)
		ui.techModel = ui.techModel or {}
		r:withClip(rect, function()
			TechTree.draw(r, Systems, player, rect, ui.techModel, function(id)
				ui:command("researchTech", { id = id })
			end, function()
				ui.panel = "context"
			end)
		end)
	elseif ui.panel == "inspector" then
		modal(ui, rect)
		Inspector.draw(ui, state, player, rect, true)
	elseif ui.panel == "minimap" then
		modal(ui, rect, true)
		r:text(rect.x + 4, rect.y + 4, "WORLD OVERVIEW", 8, 1, rect.w - 45)
		r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
			ui.panel = "context"
		end)
		Minimap.draw(
			ui,
			state,
			player,
			{ x = rect.x + 4, y = rect.y + 15, w = rect.w - 8, h = rect.h - 20 }
		)
	elseif ui.panel == "resources" then
		modal(ui, rect, true)
		HUD.ledger(ui, rect, player)
	elseif ui.panel == "empire" then
		local box = { x = 6, y = 6, w = w - 12, h = h - 12 }
		modal(ui, box, true)
		Empire.draw(ui, box)
	elseif ui.panel == "encyclopedia" then
		modal(ui, rect)
		Codex.draw(ui, rect)
	end
end
return G
