-- CIVCRAFT research canvas: connected prerequisite DAG with icon/name nodes
-- and a dedicated detail inspector. Coordinates are renderer virtual pixels.
local Details = dofile("/games/civcraft/research_details.lua")
local T = {}
local function clip(s, n)
	return tostring(s or ""):upper():sub(1, math.max(0, n))
end
local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end
local icons = { "food", "map", "ore", "bolt", "wrench", "train" }
local function symbol(tech)
	return icons[math.max(1, math.min(#icons, tech.lane or 1))]
end
local function prerequisites(player, tech)
	local missing = {}
	for _, req in ipairs(tech.requires or {}) do
		if not (player.techs or {})[req] then
			missing[#missing + 1] = req
		end
	end
	return missing
end
local Panels = dofile("/games/civcraft/panels.lua")
local function extent(systems, field)
	local maximum = 1
	for _, id in ipairs(systems.techOrder) do
		maximum = math.max(maximum, systems.techs[id][field] or 1)
	end
	return maximum
end
local function ageName(systems, tier)
	return systems.ages and systems.ages[tier] and systems.ages[tier].name or ("TIER " .. tier)
end
local function smallGraph(r, systems, player, rect, model)
	local x, y, w, h = rect.x + 3, rect.y + 14, rect.w - 6, rect.h - 31
	local zoom = clamp(model.zoom, 0.65, 1.5)
	local nw, nh = math.floor(48 * zoom), math.floor(15 * zoom)
	local sx, sy = math.floor(66 * zoom), math.floor(26 * zoom)
	model.dragArea = { x = x, y = y, w = w, h = h }
	model.dragMode = "graph"
	model.maxPanX = math.max(0, (extent(systems, "tier") - 1) * sx + nw + 6 - w)
	model.maxPanY = math.max(0, (extent(systems, "lane") - 1) * sy + nh + 6 - h)
	if not model.smallGraphInitialized then
		local selected = systems.techs[model.selected]
		model.panX = (selected.tier - 1) * sx
		model.panY = (selected.lane - 1) * sy
		model.smallGraphInitialized = true
	end
	model.panX = clamp(model.panX, 0, model.maxPanX)
	model.panY = clamp(model.panY, 0, model.maxPanY)
	local function pos(id)
		local tech = systems.techs[id]
		return x + 3 + (tech.tier - 1) * sx - model.panX, y + 3 + (tech.lane - 1) * sy - model.panY
	end
	local function stroke(ax, ay, bx, by, color)
		local steps = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay))))
		for i = 0, steps do
			local px, py = ax + (bx - ax) * i / steps, ay + (by - ay) * i / steps
			if px >= x and px < x + w and py >= y and py < y + h then
				r:fill(px, py, 1, 1, color)
			end
		end
	end
	r:fill(x, y, w, h, 0)
	for _, id in ipairs(systems.techOrder) do
		local bx, by = pos(id)
		for _, req in ipairs(systems.techs[id].requires) do
			local ax, ay = pos(req)
			local middle = (ax + nw + bx) / 2
			local color = (player.techs or {})[req] and 11 or 4
			stroke(ax + nw, ay + nh / 2, middle, ay + nh / 2, color)
			stroke(middle, ay + nh / 2, middle, by + nh / 2, color)
			stroke(middle, by + nh / 2, bx, by + nh / 2, color)
		end
	end
	for _, id in ipairs(systems.techOrder) do
		local px, py = pos(id)
		if px >= x and py >= y and px + nw <= x + w and py + nh <= y + h then
			local selected = id == model.selected
			r:button(px, py, nw, nh, nil, function()
				model.selected = id
			end, { selected = selected, primary = player.researchTarget == id })
			r:text(
				px + 2,
				py + math.floor((nh - 5) / 2),
				systems.techs[id].name,
				(player.techs or {})[id] and 11 or 7,
				selected and 3 or 1,
				nw - 4
			)
			r.buttons[#r.buttons].label = id
		end
	end
	local controls = {
		{
			"LEFT",
			function()
				model.panX = clamp(model.panX - sx, 0, model.maxPanX)
			end,
		},
		{
			"RIGHT",
			function()
				model.panX = clamp(model.panX + sx, 0, model.maxPanX)
			end,
		},
		{
			"UP",
			function()
				model.panY = clamp(model.panY - sy, 0, model.maxPanY)
			end,
		},
		{
			"DOWN",
			function()
				model.panY = clamp(model.panY + sy, 0, model.maxPanY)
			end,
		},
		{
			"ZOOM+",
			function()
				model.zoom = clamp(model.zoom + 0.2, 0.65, 1.5)
			end,
		},
		{
			"ZOOM-",
			function()
				model.zoom = clamp(model.zoom - 0.2, 0.65, 1.5)
			end,
		},
	}
	local width = math.floor(w / #controls)
	for index, action in ipairs(controls) do
		r:button(
			x + (index - 1) * width,
			rect.y + rect.h - 14,
			width - 1,
			11,
			width >= 26 and action[1] or ({ "<", ">", "^", "v", "+", "-" })[index],
			action[2]
		)
		r.buttons[#r.buttons].label = action[1]
	end
	return model
end
local function compact(r, systems, player, rect, model, research, onClose, openCodex)
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	r:fill(x, y, w, h, 1)
	r:outline(x, y, w, h, 8)
	r:text(x + 3, y + 3, "TECH", 8, 1, w - 80)
	r:button(x + w - 37, y + 1, 35, 11, "CLOSE", onClose)
	if not model.detail then
		r:button(x + w - 78, y + 1, 39, 11, "DETAILS", function()
			model.detail, model.offset = true, 0
		end)
		return smallGraph(r, systems, player, rect, model)
	end
	local rows = {}
	local tier = clamp(model.tier or 1, 1, extent(systems, "tier"))
	rows[#rows + 1] = { text = ageName(systems, tier) }
	if model.detail then
		local chosen = systems.techs[model.selected]
		rows[#rows + 1] = {
			buttons = {
				{
					label = "BACK TO TREE",
					run = function()
						model.detail = false
						model.offset = 0
					end,
				},
			},
		}
		local paragraphs = {
			ageName(systems, chosen.tier),
			chosen.name,
			"UNLOCK: " .. chosen.unlock,
			"SCIENCE "
				.. ((player.researchProgress or {})[model.selected] or 0)
				.. "/"
				.. systems.techCost(model.selected, player),
			"REQUIRES: "
				.. (#chosen.requires > 0 and table.concat(chosen.requires, ", ") or "NONE"),
		}
		for _, paragraph in ipairs(paragraphs) do
			for _, line in ipairs(Panels.wrap(r, paragraph, w - 12)) do
				rows[#rows + 1] = { text = line }
			end
		end
		for _, paragraph in ipairs(Details.paragraphs(systems, model.selected)) do
			for _, line in ipairs(Panels.wrap(r, paragraph, w - 20)) do
				rows[#rows + 1] = { text = line }
			end
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
		local allowed = systems.canResearch(player, model.selected)
		table.insert(rows, 2, {
			buttons = {
				{
					label = allowed and "RESEARCH"
						or (player.techs[model.selected] and "COMPLETED" or "LOCKED"),
					run = function()
						if allowed then
							research(model.selected)
						end
					end,
					style = { primary = allowed },
				},
			},
		})
	end
	Panels.rows(r, { x = x + 3, y = y + 14, w = w - 6, h = h - 17 }, rows, model)
	model.dragArea = { x = x + 3, y = y + 14, w = w - 13, h = h - 29 }
	model.dragMode = "list"
	model.maxPanY = model.pageMax or 0
	return model
end
function T.draw(r, systems, player, rect, model, research, onClose, openCodex)
	model = model or {}
	model.zoom = model.zoom or 1
	model.dragArea = nil
	model.panX = model.panX or 0
	model.panY = model.panY or 0
	model.tier = model.tier or (systems.age and systems.age(player)) or 1
	if not model.selected then
		model.selected = player.researchTarget
		if not model.selected then
			for _, id in ipairs(systems.techOrder) do
				if systems.techs[id].tier == model.tier then
					model.selected = id
					break
				end
			end
		end
		model.selected = model.selected or systems.techOrder[1]
	end
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	if model.detail or r.mode == "text" or w < 300 or h < 210 then
		return compact(r, systems, player, rect, model, research, onClose, openCodex)
	end
	r:fill(x, y, w, h, 1)
	r:outline(x, y, w, h, 8)
	local header = math.max(15, math.min(21, math.floor(h * 0.13)))
	r:fill(x + 1, y + 1, w - 2, header, 2)
	r:text(
		x + 6,
		y + 6,
		"TECHNOLOGY / " .. ageName(systems, (systems.techs[model.selected] or {}).tier or 1),
		8,
		1,
		w - 52
	)
	r:button(x + w - 40, y + 3, 35, 14, "CLOSE", onClose)
	local graphX, graphY = x + 5, y + header + 6
	local graphH = math.max(26, h - header - 29)
	local wide = w >= 155
	local inspectorW = wide and math.max(62, math.floor(w * 0.34)) or 0
	local graphW = w - 10 - inspectorW - (wide and 6 or 0)
	local chosen = systems.techs[model.selected]

	r:fill(graphX, graphY, graphW, graphH, 0)
	r:outline(graphX, graphY, graphW, graphH, 3)
	local zoom = clamp(model.zoom, 0.65, 1.5)
	local nw, nh = math.floor(76 * zoom), math.floor(23 * zoom)
	local sx, sy = math.floor(96 * zoom), math.floor(37 * zoom)
	local maxX = math.max(0, (extent(systems, "tier") - 1) * sx + nw - graphW + 8)
	local maxY = math.max(0, (extent(systems, "lane") - 1) * sy + nh - graphH + 10)
	model.dragArea = { x = graphX, y = graphY, w = graphW, h = graphH }
	model.dragMode = "graph"
	model.maxPanX = maxX
	model.maxPanY = maxY
	model.panX = clamp(model.panX, 0, maxX)
	model.panY = clamp(model.panY, 0, maxY)
	local function pos(id)
		local t = systems.techs[id]
		return graphX + 7 + (t.tier - 1) * sx - model.panX,
			graphY + 7 + (t.lane - 1) * sy - model.panY
	end
	local function stroke(ax, ay, bx, by, color)
		-- Per-pixel clipping: links never draw across sidebar or controls.
		local n = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay))))
		for i = 0, n do
			local xx = ax + (bx - ax) * i / n
			local yy = ay + (by - ay) * i / n
			if
				xx > graphX + 1
				and yy > graphY + 1
				and xx < graphX + graphW - 2
				and yy < graphY + graphH - 2
			then
				r:fill(xx, yy, 1, 1, color)
			end
		end
	end
	for _, id in ipairs(systems.techOrder) do
		local item = systems.techs[id]
		local x2, y2 = pos(id)
		for _, req in ipairs(item.requires) do
			local x1, y1 = pos(req)
			local color = (player.techs or {})[req] and 11 or 4
			local startX = x1 + nw
			local split = math.floor((startX + x2) / 2)
			local h1 = y1 + nh / 2
			local h2 = y2 + nh / 2
			stroke(startX, h1, split, h1, color)
			stroke(split, h1, split, h2, color)
			stroke(split, h2, x2, h2, color)
		end
	end
	for _, id in ipairs(systems.techOrder) do
		local tech = systems.techs[id]
		local px, py = pos(id)
		if
			px > graphX
			and py > graphY
			and px + nw < graphX + graphW
			and py + nh < graphY + graphH
		then
			local learned = (player.techs or {})[id]
			local selected = model.selected == id
			local active = player.researchTarget == id
			local allowed = systems.canResearch(player, id)
			local border = selected and 9 or learned and 11 or active and 8 or allowed and 6 or 4
			r:fill(px, py, nw, nh, selected and 3 or learned and 12 or active and 2 or 1)
			r:outline(px, py, nw, nh, border)
			r:fill(px + 2, py + 2, 2, nh - 4, border)
			r:icon(symbol(tech), px + 6, py + math.max(3, math.floor((nh - 9) / 2)), 1)
			r:text(
				px + 19,
				py + math.max(3, math.floor((nh - 5) / 2)),
				clip(tech.name, math.floor((nw - 22) / 4)),
				7,
				1,
				nw - 23
			)
			r.buttons[#r.buttons + 1] = {
				x = px,
				y = py,
				w = nw,
				h = nh,
				label = id,
				fn = function()
					model.selected = id
				end,
			}
		end
	end
	if wide then
		local dx = graphX + graphW + 5
		local dw = w - (dx - x) - 5
		r:fill(dx, graphY, dw, graphH, 2)
		r:outline(dx, graphY, dw, graphH, 3)
		r:fill(dx + 3, graphY + 3, 3, 13, 9)
		r:text(dx + 9, graphY + 5, clip(chosen.name, math.floor((dw - 14) / 4)), 7, 1, dw - 14)
		r:icon(symbol(chosen), dx + 7, graphY + 23, 1)
		local researched = (player.techs or {})[model.selected]
		local active = player.researchTarget == model.selected
		local req = prerequisites(player, chosen)
		local prereq = #chosen.requires > 0 and table.concat(chosen.requires, ", ") or "NONE"
		local status = researched and "COMPLETED"
			or active and "RESEARCHING"
			or #req == 0 and "AVAILABLE"
			or "LOCKED"
		r:text(dx + 20, graphY + 24, status, researched and 11 or active and 8 or 9, 1, dw - 24)
		r:text(dx + 7, graphY + 42, "PREREQUISITES", 9, 1, dw - 13)
		r:text(dx + 7, graphY + 51, clip(prereq, math.floor((dw - 14) / 4)), 7, 1, dw - 13)
		r:text(dx + 7, graphY + 69, "UNLOCKS", 9, 1, dw - 13)
		r:text(dx + 7, graphY + 78, clip(chosen.unlock, math.floor((dw - 14) / 4)), 7, 1, dw - 13)
		local cost = systems.techCost(model.selected, player)
		local progress = (player.researchProgress or {})[model.selected] or 0
		local rate = player.scienceRate or 0
		r:text(dx + 7, graphY + 97, "PROGRESS " .. progress .. "/" .. cost, 7, 1, dw - 13)
		local bar = math.max(8, dw - 16)
		r:fill(dx + 7, graphY + 108, bar, 5, 4)
		r:fill(dx + 7, graphY + 108, bar * clamp(progress / cost, 0, 1), 5, 8)
		local estimate = rate > 0 and (math.max(1, math.ceil((cost - progress) / rate)) .. " TURNS")
			or "NO SCIENCE"
		r:text(dx + 7, graphY + 119, "EST " .. estimate, 6, 1, dw - 13)
		r:button(dx + 5, graphY + graphH - 38, dw - 10, 14, "DETAILS / CODEX", function()
			model.detail, model.offset = true, 0
		end)
		if not researched then
			r:button(
				dx + 5,
				graphY + graphH - 20,
				dw - 10,
				16,
				active and "IN PROGRESS" or #req == 0 and "RESEARCH" or "LOCKED",
				function()
					if #req == 0 then
						research(model.selected)
					end
				end,
				{ primary = #req == 0 }
			)
		end
	else
		r:fill(graphX, graphY + graphH - 1, graphW, 1, 9)
		r:text(
			graphX + 3,
			y + h - 23,
			clip(chosen.name .. " -> " .. chosen.unlock, math.floor((w - 12) / 4)),
			7
		)
		if systems.canResearch(player, model.selected) then
			r:button(x + w - 73, y + h - 23, 68, 14, "RESEARCH", function()
				research(model.selected)
			end, { primary = true })
		end
	end
	-- Pan/zoom controls remain on the screen for touch-only clients.
	local controls = {
		{
			"LEFT",
			function()
				model.panX = clamp(model.panX - 75, 0, maxX)
			end,
		},
		{
			"RIGHT",
			function()
				model.panX = clamp(model.panX + 75, 0, maxX)
			end,
		},
		{
			"UP",
			function()
				model.panY = clamp(model.panY - 64, 0, maxY)
			end,
		},
		{
			"DOWN",
			function()
				model.panY = clamp(model.panY + 64, 0, maxY)
			end,
		},
		{
			"ZOOM+",
			function()
				model.zoom = clamp(model.zoom + 0.2, 0.65, 1.5)
			end,
		},
		{
			"ZOOM-",
			function()
				model.zoom = clamp(model.zoom - 0.2, 0.65, 1.5)
			end,
		},
	}
	local cw = math.max(19, math.floor((w - 12) / 6))
	for i, action in ipairs(controls) do
		r:button(x + 4 + (i - 1) * cw, y + h - 19, cw - 2, 15, action[1], action[2])
	end
	return model
end
return T
