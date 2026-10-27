-- Research stays a connected graph alongside a persistent technology inspector.
local Details = dofile("/games/civcraft/research_details.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local T = {}
local function clamp(value, maximum)
	return math.max(0, math.min(value, maximum))
end

function T.layout(systems)
	local nodes, columns, ranks = {}, {}, {}
	local function depth(id)
		if nodes[id] then
			return nodes[id].column
		end
		local column = 1
		for _, parent in ipairs(systems.techs[id].requires or {}) do
			column = math.max(column, depth(parent) + 1)
		end
		nodes[id] = { column = column }
		columns[column] = columns[column] or {}
		columns[column][#columns[column] + 1] = id
		return column
	end
	for index, id in ipairs(systems.techOrder) do
		ranks[id] = index
		depth(id)
	end
	local rows = 1
	for _, column in ipairs(columns) do
		local function center(id)
			local total, count = 0, 0
			for _, parent in ipairs(systems.techs[id].requires or {}) do
				total, count = total + nodes[parent].row, count + 1
			end
			return count > 0 and total / count or ranks[id]
		end
		table.sort(column, function(a, b)
			local ac, bc = center(a), center(b)
			return ac == bc and ranks[a] < ranks[b] or ac < bc
		end)
		for row, id in ipairs(column) do
			nodes[id].row = row
		end
		rows = math.max(rows, #column)
	end
	return { nodes = nodes, columns = #columns, rows = rows }
end

local function selectTechnology(model, id, focus)
	model.selected, model.offset = id, 0
	model.focus = focus
end

local function inspector(r, systems, player, rect, model, openCodex)
	local chosen = systems.techs[model.selected]
	local rows = {}
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, rect.w - 10)) do
			rows[#rows + 1] = { text = line, color = color or 7 }
		end
	end
	text(chosen.name, 8)
	local cost = systems.techCost(model.selected, player)
	local progress = (player.researchProgress or {})[model.selected] or 0
	text("SCIENCE " .. progress .. "/" .. cost)
	local rate = player.scienceRate or 0
	if rate > 0 then
		text("EST " .. math.max(1, math.ceil((cost - progress) / rate)) .. " TURNS", 6)
	end
	local function link(id, label)
		rows[#rows + 1] = {
			buttons = {
				{
					label = label .. systems.techs[id].name,
					run = function()
						selectTechnology(model, id, true)
					end,
				},
			},
		}
	end
	text("PREREQUISITES", 8)
	if #(chosen.requires or {}) == 0 then
		text("NONE", 6)
	end
	for _, id in ipairs(chosen.requires or {}) do
		link(id, "< ")
	end
	for _, paragraph in ipairs(Details.paragraphs(systems, model.selected, player)) do
		text(paragraph)
	end
	for _, entry in ipairs(Details.unlocks(systems, model.selected)) do
		rows[#rows + 1] = {
			buttons = {
				{
					label = "CODEX " .. entry.record.name,
					run = function()
						if openCodex then
							openCodex(entry.category, entry.id)
						end
					end,
				},
			},
		}
	end
	local children = {}
	for _, id in ipairs(systems.techOrder) do
		for _, parent in ipairs(systems.techs[id].requires or {}) do
			if parent == model.selected then
				children[#children + 1] = id
			end
		end
	end
	if #children > 0 then
		text("LEADS TO", 13)
	end
	for _, id in ipairs(children) do
		link(id, "> ")
	end
	r:fill(rect.x, rect.y, rect.w, rect.h, 1)
	r:outline(rect.x, rect.y, rect.w, rect.h, 3)
	Panels.rows(r, rect, rows, model)
	model.sidebarBounds = rect
end

local function graph(r, systems, player, rect, model)
	local layout = model.layout
	local zoom = model.zoom
	local baseWidth = math.min(72, rect.w - 4)
	if rect.w >= 108 then
		baseWidth = math.min(baseWidth, math.floor((rect.w - 28) / 2))
	end
	local nw = math.min(rect.w - 4, math.max(28, math.floor(baseWidth * zoom)))
	local nh = math.max(11, math.floor(16 * zoom))
	local sx, sy = nw + math.floor(24 * zoom), nh + math.floor(14 * zoom)
	model.maxPanX = math.max(0, (layout.columns - 1) * sx + nw + 4 - rect.w)
	model.maxPanY = math.max(0, (layout.rows - 1) * sy + nh + 4 - rect.h)
	if model.focus then
		local node = layout.nodes[model.selected]
		local lead = rect.w >= nw * 2 + (sx - nw) + 4 and 2 or 1
		model.panX, model.panY = math.max(0, node.column - lead) * sx, (node.row - 1) * sy
		model.focus = false
	end
	model.panX, model.panY = clamp(model.panX, model.maxPanX), clamp(model.panY, model.maxPanY)
	model.dragArea, model.dragMode = rect, "graph"
	local function pos(id)
		local node = layout.nodes[id]
		return rect.x + 2 + (node.column - 1) * sx - model.panX,
			rect.y + 2 + (node.row - 1) * sy - model.panY
	end
	local function stroke(ax, ay, bx, by, color)
		local count = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay))))
		for i = 0, count do
			local x, y =
				math.floor(ax + (bx - ax) * i / count), math.floor(ay + (by - ay) * i / count)
			if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
				r:fill(x, y, 1, 1, color)
			end
		end
	end
	r:fill(rect.x, rect.y, rect.w, rect.h, 0)
	model.highlightedEdges = {}
	-- Paint unrelated links first; selected relationships remain distinct on top.
	for pass = 1, 2 do
		for _, id in ipairs(systems.techOrder) do
			local bx, by = pos(id)
			for index, parent in ipairs(systems.techs[id].requires or {}) do
				local focused = id == model.selected or parent == model.selected
				if focused == (pass == 2) then
					local ax, ay = pos(parent)
					local color = focused and (id == model.selected and 8 or 13) or 3
					local elbow = ax + nw + 5 + index * 2
					stroke(ax + nw, ay + nh / 2, elbow, ay + nh / 2, color)
					stroke(elbow, ay + nh / 2, bx - 5, by + nh / 2, color)
					stroke(bx - 5, by + nh / 2, bx, by + nh / 2, color)
					stroke(bx - 3, by + nh / 2 - 2, bx - 1, by + nh / 2, color)
					stroke(bx - 3, by + nh / 2 + 2, bx - 1, by + nh / 2, color)
					if focused then
						model.highlightedEdges[#model.highlightedEdges + 1] =
							{ parent = parent, child = id }
					end
				end
			end
		end
	end
	for _, id in ipairs(systems.techOrder) do
		local x, y = pos(id)
		if
			x >= rect.x
			and y >= rect.y
			and x + nw <= rect.x + rect.w
			and y + nh <= rect.y + rect.h
		then
			local selected, learned, active =
				id == model.selected, (player.techs or {})[id], player.researchTarget == id
			local color = selected and 8 or active and 13 or learned and 11 or 3
			r:button(x, y, nw, nh, nil, function()
				selectTechnology(model, id, false)
			end, { selected = selected, primary = active })
			r:outline(x, y, nw, nh, color)
			r:text(
				x + 2,
				y + math.floor((nh - 5) / 2),
				systems.techs[id].name,
				selected and 7 or learned and 11 or 7,
				1,
				nw - 4
			)
			r.buttons[#r.buttons].label = id
		end
	end
end

function T.draw(r, systems, player, rect, model, research, onClose, openCodex)
	model = model or {}
	model.selected = model.selected or player.researchTarget or systems.techOrder[1]
	model.zoom, model.panX, model.panY = model.zoom or 1, model.panX or 0, model.panY or 0
	if not model.layout or model.layoutSystems ~= systems then
		model.layout, model.layoutSystems, model.focus = T.layout(systems), systems, true
	end
	model.detail = nil
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	r:fill(x, y, w, h, 1)
	r:outline(x, y, w, h, 8)
	r:icon("science", x + 3, y + 1, 1)
	if w >= 125 then
		r:text(x + 15, y + 3, "RESEARCH", 8, 1, w - 100)
	end
	local active, learned =
		player.researchTarget == model.selected, (player.techs or {})[model.selected]
	local allowed = systems.canResearch(player, model.selected)
	r:button(
		x + w - 80,
		y + 1,
		42,
		10,
		learned and "KNOWN" or active and "ACTIVE" or allowed and "RESEARCH" or "LOCKED",
		function()
			if allowed then
				research(model.selected)
			end
		end,
		{ primary = allowed and not active }
	)
	r:button(x + w - 37, y + 1, 35, 10, "CLOSE", onClose)
	local side = math.max(44, math.min(120, math.floor(w * 0.36)))
	local area = { x = x + 3, y = y + 12, w = w - side - 9, h = h - 26 }
	graph(r, systems, player, area, model)
	inspector(
		r,
		systems,
		player,
		{ x = x + w - side - 3, y = area.y, w = side, h = area.h },
		model,
		openCodex
	)
	local actions = {
		{
			"LEFT",
			function()
				model.panX = clamp(model.panX - area.w * 0.7, model.maxPanX)
			end,
		},
		{
			"RIGHT",
			function()
				model.panX = clamp(model.panX + area.w * 0.7, model.maxPanX)
			end,
		},
		{
			"UP",
			function()
				model.panY = clamp(model.panY - area.h * 0.7, model.maxPanY)
			end,
		},
		{
			"DOWN",
			function()
				model.panY = clamp(model.panY + area.h * 0.7, model.maxPanY)
			end,
		},
		{
			"ZOOM+",
			function()
				model.zoom = math.min(1.5, model.zoom + 0.2)
			end,
		},
		{
			"ZOOM-",
			function()
				model.zoom = math.max(0.65, model.zoom - 0.2)
			end,
		},
	}
	local step = math.floor((w - 6) / #actions)
	for i, action in ipairs(actions) do
		r:button(
			x + 3 + (i - 1) * step,
			y + h - 12,
			step - 1,
			10,
			({ "<", ">", "^", "v", "+", "-" })[i],
			action[2]
		)
		r.buttons[#r.buttons].label = action[1]
	end
	return model
end
return T
