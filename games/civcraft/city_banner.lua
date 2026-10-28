-- Compact public city identity and private, read-only owner forecasts.
local Strength = dofile("/games/civcraft/combat_strength.lua")
local Rules = dofile("/games/civcraft/content_rules.lua")
local Banner = {}
function Banner.model(state, player, city, systems)
	local own = player and city.owner == player.id and not city.remembered
	local model = {
		name = city.name or "CITY",
		population = city.population,
		capital = city.capitalOf ~= nil,
		village = city.village,
		remembered = city.remembered,
		hp = city.hp,
		maxHP = city.maxHP or 200,
		walls = city.wallHP,
		maxWalls = city.maxWalls or 0,
		strength = city.publicDefense,
		private = own,
	}
	if own then
		model.strength = Strength.city(state, city, systems)
		local yields = systems.yields(player, city, state, nil, nil, true)
		local growth = systems.growth(player, city, state, yields)
		model.growth = growth.status == "GROWING" and ("G" .. growth.turns .. "T")
			or growth.status == "STARVING" and ("-P" .. growth.turns .. "T")
			or "G--"
		model.starving = growth.status == "STARVING"
		model.capacityLimited = growth.growthFactor
			and growth.growthFactor < 1
			and growth.surplus > 0
		local project = city.project
		if not project then
			model.production = city.productionIdle and "PAUSE" or "IDLE"
		elseif project.kind == "project" then
			model.production = systems.projectOutput(player, city, state, yields).active
					and "REPEAT"
				or "WAIT"
		elseif
			project.kind == "unit"
			and project.id == "settler"
			and Rules.hasDevelopment(state)
			and (city.population or 2) < 2
		then
			model.production = "WAIT"
		else
			local turns = math.max(
				1,
				math.ceil(
					(
						systems.projectCost(project.kind, project.id, player, city)
						- (project.progress or 0)
					) / math.max(1, yields.industry)
				)
			)
			model.production = "P" .. turns .. "T"
		end
		model.needsProduction = not project and not city.productionIdle
	end
	return model
end
local function overlaps(a, b)
	return a.x < b.x + b.w + 2
		and a.x + a.w + 2 > b.x
		and a.y < b.y + b.h + 2
		and a.y + a.h + 2 > b.y
end
function Banner.layout(r, model, anchor, rect, occupied)
	local maxWidth = math.max(12, math.min(rect.w - 4, 112))
	local badge = r:textWidth(tostring(model.population or "?")) + 5
	local icon = (model.capital or model.village) and 8 or 0
	local detailed = model.private and maxWidth >= 52 and rect.h >= 32
	local width = math.min(
		maxWidth,
		math.max(detailed and 52 or 28, r:textWidth(model.name) + badge + icon + 7)
	)
	local statHeight = model.strength and width >= 32 and 5 or 0
	local bars = model.hp ~= nil and (model.maxWalls > 0 and 4 or 2) or 0
	local height = statHeight + bars + 8 + (detailed and 7 or 0)
	if height > rect.h - 2 then
		detailed = false
		statHeight = 0
		bars = 0
		height = 8
	end
	local baseX = math.max(
		rect.x + 1,
		math.min(rect.x + rect.w - width - 1, math.floor(anchor.x - width / 2))
	)
	local baseY = math.max(
		rect.y + 1,
		math.min(rect.y + rect.h - height - 1, math.floor(anchor.y - height + 7))
	)
	local result
	for _, offset in ipairs({ 0, -height - 2, height + 2, -2 * (height + 2), 2 * (height + 2) }) do
		local candidate = {
			x = baseX,
			y = math.max(rect.y + 1, math.min(rect.y + rect.h - height - 1, baseY + offset)),
			w = width,
			h = height,
		}
		local clear = true
		for _, other in ipairs(occupied or {}) do
			if overlaps(candidate, other) then
				clear = false
				break
			end
		end
		if clear then
			result = candidate
			break
		end
	end
	result = result or { x = baseX, y = baseY, w = width, h = height }
	result.statHeight, result.bars, result.detailed, result.badge =
		statHeight, bars, detailed, badge
	return result
end
function Banner.draw(r, model, box, color)
	local x, y, w = box.x, box.y, box.w
	r:fill(x, y, w, box.h, 1)
	r:outline(x, y, w, box.h, color)
	if box.statHeight > 0 then
		r:text(x + 2, y, "D" .. model.strength .. (model.remembered and " OLD" or ""), 7, 1, w - 4)
	end
	local barY = y + box.statHeight
	if box.bars > 0 then
		r:fill(x + 1, barY, w - 2, 2, 3)
		r:fill(
			x + 1,
			barY,
			(w - 2) * math.max(0, math.min(1, model.hp / model.maxHP)),
			2,
			model.hp / model.maxHP < 0.35 and 31 or 11
		)
		if model.maxWalls > 0 then
			r:fill(x + 1, barY + 2, w - 2, 2, 3)
			r:fill(
				x + 1,
				barY + 2,
				(w - 2) * math.max(0, math.min(1, (model.walls or 0) / model.maxWalls)),
				2,
				13
			)
		end
	end
	local nameY = barY + box.bars + 1
	local left = x + 2
	if model.capital then
		r:fill(left, nameY + 1, 6, 4, 8)
		for dx = 0, 4, 2 do
			r:fill(left + dx, nameY, 1, 2, 8)
		end
		left = left + 8
	elseif model.village then
		r:text(left, nameY, "V", 8, 1, 5)
		left = left + 6
	end
	local popX = x + w - box.badge
	r:fill(popX, nameY - 1, box.badge - 1, 7, 0)
	r:text(popX + 2, nameY, tostring(model.population or "?"), 7, 1, box.badge - 3)
	r:text(left, nameY, model.name, color, 1, math.max(0, popX - left - 1))
	if box.detailed then
		local text = model.growth
			.. " "
			.. model.production
			.. (model.capacityLimited and " !" or "")
		r:text(
			x + 2,
			nameY + 8,
			text,
			(model.starving or model.needsProduction) and 31 or 7,
			1,
			w - 4
		)
	end
end
return Banner
