local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Specialty = dofile("/games/civcraft/specialty_view.lua")
-- World geometry, painting and pointer targets use the same pointy hex polygons.
local Fog = dofile("/games/civcraft/fog_view.lua")
local FactionColors = dofile("/games/civcraft/faction_colors.lua")
local AnimationView = dofile("/games/civcraft/animation_view.lua")
local Animations = dofile("/games/civcraft/animations.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Terrain = dofile("/games/civcraft/terrain_view.lua")
local World = dofile("/games/civcraft/world.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local CityBanner = dofile("/games/civcraft/city_banner.lua")
local QueuedRoutes = dofile("/games/civcraft/queued_routes.lua")
local V = {}
local function at(list, x, y)
	for _, item in ipairs(list or {}) do
		if item.x == x and item.y == y then
			return item
		end
	end
end
local ownerColor = FactionColors.owner

local function copyUnit(unit)
	local result = {}
	for key, value in pairs(unit or {}) do
		result[key] = value
	end
	return result
end

local function virtualPosition(view, unit, partner, x, y)
	local result = {}
	for key, value in pairs(view) do
		result[key] = value
	end
	result.units = {}
	local moved
	for _, actor in ipairs(view.units or {}) do
		local copy = copyUnit(actor)
		if actor.id == unit.id or partner and actor.id == partner.id then
			copy.x, copy.y = x, y
		end
		result.units[#result.units + 1] = copy
		if copy.id == unit.id then
			moved = copy
		end
	end
	if not moved then
		moved = copyUnit(unit)
		moved.x, moved.y = x, y
		result.units[#result.units + 1] = moved
	end
	return result, moved
end

local function samePoint(a, b)
	return a and b and a.x == b.x and a.y == b.y
end

local function copyPoints(points, start, estimated)
	local result = {}
	for index = start, #points do
		local point = points[index]
		result[#result + 1] = { x = point.x, y = point.y, estimated = estimated == true }
	end
	return result
end

-- The active leg is saved verbatim. Later legs are recomputed from the observer's
-- map projection and kept in a UI cache; rendering never edits the saved queue.
function V.queuedRoute(ui, state, player)
	if not ui.selected or ui.selected.kind ~= "unit" or ui.selected.empty then
		return nil
	end
	local selected
	for _, unit in ipairs(state.units or {}) do
		if unit.id == ui.selected.unitID and unit.owner == ui.playerID then
			selected = unit
			break
		end
	end
	if not selected then
		return nil
	end
	local queue, leader = QueuedRoutes.get(state, selected)
	if not queue or type(queue.goals) ~= "table" or #queue.goals == 0 then
		return nil
	end
	local cached = ui.queuedRouteCache
	if
		cached
		and cached.unitID == leader.id
		and cached.queue == queue
		and cached.path == queue.path
		and cached.goals == queue.goals
		and cached.next == queue.next
		and cached.x == leader.x
		and cached.y == leader.y
		and cached.visible == player.visible
		and cached.explored == player.explored
		and cached.tiles == (state.world and state.world.tiles)
		and cached.units == state.units
		and cached.cities == state.cities
		and cached.round == state.round
		and cached.paused == queue.paused
	then
		return cached.route
	end

	local route = { unitID = leader.id, queue = queue, goals = {}, segments = {} }
	for _, goal in ipairs(queue.goals) do
		route.goals[#route.goals + 1] = { x = goal.x, y = goal.y }
	end
	local path = type(queue.path) == "table" and queue.path or {}
	if #path > 0 then
		local cursor = math.max(1, math.min(#path, (queue.next or 2) - 1))
		if samePoint(path[cursor], leader) then
			local remaining = { { x = leader.x, y = leader.y, estimated = false } }
			for _, point in ipairs(copyPoints(path, math.min(#path + 1, queue.next or 2), false)) do
				remaining[#remaining + 1] = point
			end
			route.segments[#route.segments + 1] = { points = remaining, estimated = false }
		else
			local replanned = QueuedRoutes.preview(
				state,
				leader,
				route.goals[1].x,
				route.goals[1].y,
				false,
				Systems,
				{ allowUnknown = true }
			)
			if replanned then
				route.segments[#route.segments + 1] = {
					points = copyPoints(replanned, 1, true),
					estimated = true,
				}
			end
		end
	end

	local partner = Stacks.partner(state, leader)
	for index = 2, #route.goals do
		local start, goal = route.goals[index - 1], route.goals[index]
		local virtual, traveler = virtualPosition(state, leader, partner, start.x, start.y)
		local estimate = QueuedRoutes.preview(
			virtual,
			traveler,
			goal.x,
			goal.y,
			false,
			Systems,
			{ allowUnknown = true }
		)
		if estimate then
			route.segments[#route.segments + 1] = {
				points = copyPoints(estimate, 1, true),
				estimated = true,
			}
		end
	end
	route.paused = not not queue.paused
	ui.queuedRouteCache = {
		unitID = leader.id,
		queue = queue,
		path = queue.path,
		goals = queue.goals,
		next = queue.next,
		x = leader.x,
		y = leader.y,
		visible = player.visible,
		explored = player.explored,
		tiles = state.world and state.world.tiles,
		units = state.units,
		cities = state.cities,
		round = state.round,
		paused = queue.paused,
		route = route,
	}
	return route
end

local function drawSolidPath(r, ax, ay, bx, by, color)
	for offset = -1, 1 do
		r:line(ax + offset, ay, bx + offset, by, 0)
		r:line(ax, ay + offset, bx, by + offset, 0)
	end
	r:line(ax, ay, bx, by, color)
end

local function drawDottedPath(r, ax, ay, bx, by, color)
	local dx, dy = bx - ax, by - ay
	local count = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy))))
	for index = 0, count do
		if index % 4 < 2 then
			local x, y = ax + dx * index / count, ay + dy * index / count
			r:fill(x - 1, y - 1, 3, 3, 0)
			r:fill(x, y, 1, 1, color)
		end
	end
end

local function drawRouteSegments(r, segments, player, center, paused)
	for _, segment in ipairs(segments or {}) do
		local points = segment.points or {}
		local previousHidden = #points > 0
			and World.known(player, points[1].x, points[1].y) == "hidden"
		for index = 2, #points do
			local point, previous = points[index], points[index - 1]
			local pointHidden = World.known(player, point.x, point.y) == "hidden"
			local ax, ay = center(previous)
			local bx, by = center(point)
			if previousHidden or pointHidden then
				drawDottedPath(r, ax, ay, bx, by, 13)
			elseif segment.estimated or previous.estimated or point.estimated then
				drawDottedPath(r, ax, ay, bx, by, 16)
			else
				drawSolidPath(r, ax, ay, bx, by, paused and 31 or 9)
			end
			previousHidden = pointHidden
		end
	end
end

local function drawGoalMarkers(r, goals, player, center, paused)
	for index, goal in ipairs(goals or {}) do
		local x, y = center(goal)
		local hidden = World.known(player, goal.x, goal.y) == "hidden"
		local color = hidden and 13 or index == 1 and (paused and 31 or 18) or 8
		local size = index == 1 and 7 or 5
		r:outline(x - math.floor(size / 2), y - math.floor(size / 2), size, size, color)
	end
end

local function drawPendingPath(r, path, player, center)
	if not path or #path < 2 then
		return
	end
	local previousHidden = World.known(player, path[1].x, path[1].y) == "hidden"
	for index = 2, #path do
		local point, previous = path[index], path[index - 1]
		local pointHidden = World.known(player, point.x, point.y) == "hidden"
		local ax, ay = center(previous)
		local bx, by = center(point)
		if previousHidden or pointHidden then
			drawDottedPath(r, ax, ay, bx, by, 35)
		else
			drawSolidPath(r, ax, ay, bx, by, 18)
		end
		previousHidden = pointHidden
	end
end

function V.draw(ui, state, player, rect)
	local frame = rect
	rect = { x = frame.x + 4, y = frame.y + 4, w = frame.w - 8, h = frame.h - 8 }
	ui.mapFrame = frame
	local r = ui.r
	local canvas = r
	local rememberedRenderer = Fog.forUI(ui)
	local world = state.world
	local overlays = ui.overlays or {}
	local width, height = world and world.width or Hex.width, world and world.height or Hex.height
	local cityLabels = {}
	local size = ui.zoomLevel or math.max(12, math.min(24, math.floor(rect.h / 32) * 4))
	local step = size * 0.75
	local maxX = math.max(0, (width + 0.5) * size - rect.w)
	local maxY = math.max(0, (height - 1) * step + size - rect.h)
	if not ui.worldReady or ui.lastWorldKey ~= ui.worldKey then
		ui.worldReady = true
		ui.lastWorldKey = ui.worldKey
		ui.panX = 0
		ui.panY = 0
		local focus = {}
		for _, c in ipairs(state.cities or {}) do
			focus[#focus + 1] = c
		end
		for _, u in ipairs(state.units or {}) do
			focus[#focus + 1] = u
		end
		for _, c in ipairs(focus) do
			if c.owner == ui.playerID then
				ui.selected = {
					x = c.x,
					y = c.y,
					kind = c.kind and "unit" or "city",
					unitID = c.kind and c.id or nil,
				}
				ui.panX = (c.x - 0.5) * size - rect.w / 2
				ui.panY = (c.y - 0.5) * step - rect.h / 2
				break
			end
		end
	end
	AnimationView.center(ui, rect, size)
	ui.panX = math.max(0, math.min(maxX, ui.panX or 0))
	ui.panY = math.max(0, math.min(maxY, ui.panY or 0))
	ui.mapViewport =
		{ x = rect.x, y = rect.y, w = rect.w, h = rect.h, tile = size, maxX = maxX, maxY = maxY }
	local citySignature = {}
	local cityIndex, unitIndex, civilianIndex = {}, {}, {}
	local hiddenActors = ui.animationFrame and ui.animationFrame.hidden or {}
	local campIndex = {}
	for _, camp in ipairs(World.observedCamps(state, player)) do
		campIndex[World.key(camp.x, camp.y)] = camp
	end
	for _, city in ipairs(state.cities or {}) do
		citySignature[#citySignature + 1] =
			table.concat({ city.id or 0, city.owner, city.x, city.y, city.population or 2 }, ":")
		cityIndex[World.key(city.x, city.y)] = city
	end
	for _, unit in ipairs(state.units or {}) do
		local key = World.key(unit.x, unit.y)
		if not unitIndex[key] or Stacks.isCivilian(unitIndex[key]) then
			unitIndex[key] = unit
		end
		if Stacks.isCivilian(unit) then
			civilianIndex[key] = unit
		end
	end
	local signature = table.concat(citySignature, ";") .. ":" .. (state.territoryRevision or 0)
	local cache = ui.mapCache
	if
		not cache
		or cache.world ~= world
		or cache.cities ~= state.cities
		or cache.signature ~= signature
	then
		cache = { world = world, cities = state.cities, signature = signature, claims = {} }
		ui.mapCache = cache
		for y = 1, height do
			for x = 1, width do
				cache.claims[World.key(x, y)] = World.territoryCity(state, Hex, x, y)
			end
		end
	end
	local claims = cache.claims
	local workingCity = ui.workCity and cityIndex[World.key(ui.workCity.x, ui.workCity.y)]
		or (
			not ui.selected.empty
			and ui.selected.kind ~= "unit"
			and cityIndex[World.key(ui.selected.x, ui.selected.y)]
		)
	if workingCity and workingCity.owner ~= ui.playerID then
		workingCity = nil
	end
	local destinations = {}
	for _, destination in ipairs(ui.reachable or {}) do
		destinations[World.key(destination.x, destination.y)] = destination
	end
	local tiles = {}
	ui.hexTargets = {}
	r:fill(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2, 1)
	r:withClip(rect, function()
		local y0 = math.max(1, math.floor(ui.panY / step) - 1)
		local y1 = math.min(height, math.ceil((ui.panY + rect.h) / step) + 1)
		local x0 = math.max(1, math.floor(ui.panX / size))
		local x1 = math.min(width, math.ceil((ui.panX + rect.w) / size) + 1)
		for y = y0, y1 do
			for x = x0, x1 do
				local px = rect.x + (x - 1) * size + ((y - 1) % 2) * size / 2 - ui.panX
				local py = rect.y + (y - 1) * step - ui.panY
				if
					px + size > rect.x
					and px < rect.x + rect.w
					and py + size > rect.y
					and py < rect.y + rect.h
				then
					local visibility = World.known(player, x, y)
					r = visibility == "explored" and rememberedRenderer or canvas
					local hidden = visibility == "hidden"
					local land = Hex.terrain(x, y, state)
					local claim = claims[World.key(x, y)]
					local owner = World.observedOwner(state, player, x, y)
					local deposit = not hidden and World.deposit(world, x, y)
					local yields = not hidden and World.yields(world, x, y, state)
					local city = cityIndex[World.key(x, y)]
					if city and (city.owner == ui.playerID or visibility == "visible") then
						for _, owner in ipairs(state.players or {}) do
							if owner.id == city.owner then
								yields = Systems.centerYields(owner, city, state)
								break
							end
						end
					end
					local geography = Hex.tile(x, y, state)
					local base = hidden and 15 or Terrain.color(geography, false)
					if visibility == "visible" then
						if overlays.territory then
							base = owner and ownerColor(state, owner) or base
						end
					end
					-- Preserve hit targets without rasterizing terrain in layout-only tests.
					if not canvas.layoutOnly and r.buffer and r.blit then
						r:blit(
							Terrain.sprite(
								geography,
								size,
								x,
								y,
								base,
								not hidden and not overlays.territory,
								hidden and 14 or 3
							),
							px,
							py
						)
					elseif not canvas.layoutOnly then
						for dy = 0, size - 1 do
							local inset = dy < size / 4 and size / 2 - 2 * dy
								or dy >= size * 3 / 4 and 2 * (dy + 1) - size * 1.5
								or 0
							r:fill(px + inset, py + dy, math.max(1, size - inset * 2), 1, base)
						end
						if not hidden and not overlays.territory then
							Terrain.draw(r, geography, px, py, size, x, y)
						end
						local vertices = Hex.vertices(px, py, size)
						for i, a in ipairs(vertices) do
							local b = vertices[i % 6 + 1]
							r:line(a.x, a.y, b.x, b.y, hidden and 14 or 3)
						end
					end
					tiles[#tiles + 1] = {
						x = x,
						y = y,
						px = px,
						py = py,
						owner = owner,
						claim = claim,
						visibility = visibility,
						land = land,
						deposit = deposit,
						yields = yields,
					}
					ui.hexTargets[#ui.hexTargets + 1] =
						{ x = px, y = py, w = size, h = size, tx = x, ty = y }
					-- Banners are interactive hit targets, not just painted pixels.
					-- Collect them even when the visual-only tile pass is skipped.
					if canvas.layoutOnly then
						local city = visibility ~= "hidden"
							and World.observedCity(state, player, x, y)
						if
							city
							and not hiddenActors["city:" .. tostring(city.id)]
							and (
								city.remembered
								or city.owner == ui.playerID
								or visibility == "visible"
							)
						then
							cityLabels[#cityLabels + 1] = {
								city = city,
								x = px + size / 2,
								y = py - 6,
								remembered = visibility == "explored",
							}
						end
					end
				end
			end
		end
		r = canvas
		local function center(point)
			return rect.x + (point.x - 0.5 + ((point.y - 1) % 2) * 0.5) * size - ui.panX,
				rect.y + (point.y - 1) * step + size / 2 - ui.panY
		end
		local queuedRoute = V.queuedRoute(ui, state, player)
		if queuedRoute then
			drawRouteSegments(r, queuedRoute.segments, player, center, queuedRoute.paused)
			drawGoalMarkers(r, queuedRoute.goals, player, center, queuedRoute.paused)
		end
		if ui.pendingMove and ui.pendingMove.path then
			drawPendingPath(r, ui.pendingMove.path, player, center)
			if ui.pendingMove.queued then
				drawGoalMarkers(
					r,
					{ { x = ui.pendingMove.x, y = ui.pendingMove.y } },
					player,
					center,
					false
				)
			end
		end
		-- All map hitboxes were collected above. Skip this visual-only pass
		-- for geometry tests; full renderers still paint every tile.
		for _, t in ipairs(canvas.layoutOnly and {} or tiles) do
			local x, y, px, py = t.x, t.y, t.px, t.py
			r = t.visibility == "explored" and rememberedRenderer or canvas
			if t.owner and t.visibility ~= "hidden" then
				local vertices = Hex.vertices(px, py, size)
				for side, n in ipairs(Hex.edgeNeighbours(x, y)) do
					if World.observedOwner(state, player, n.x, n.y) ~= t.owner then
						local a, b = vertices[side], vertices[side % 6 + 1]
						-- Dark edging keeps bright ownership lines distinct on every biome.
						for _, offset in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
							r:line(
								a.x + offset[1],
								a.y + offset[2],
								b.x + offset[1],
								b.y + offset[2],
								0
							)
						end
						r:line(a.x, a.y, b.x, b.y, ownerColor(state, t.owner))
					end
				end
			end
			if t.visibility ~= "hidden" then
				if t.deposit and overlays.resources then
					if size >= 16 then
						Icons.draw(r, t.deposit, px + size / 2 - 4, py + 2, 9, 9)
					else
						r:fill(px + size / 2 - 1, py + 2, 3, 2, 8)
					end
				end
			end
			local k = World.key(x, y)
			if t.visibility ~= "hidden" then
				local site = Sites.enabled(state) and (world.specialtySites or {})[k]
				if site then
					local sx, sy = math.floor(px + 2), math.floor(py + size - 9)
					r:fill(sx - 1, sy - 1, 7, 8, 1)
					r:text(
						sx,
						sy,
						Specialty.symbols[site.kind] or "?",
						site.inactive and 31 or 13,
						1,
						6
					)
				end
				local improvement = (world.improvements or {})[k]
				if improvement then
					local color = improvement.damaged and 31
						or improvement.kind == "farm" and 5
						or improvement.kind == "lumber" and 13
						or 7
					r:fill(px + math.floor(size / 2) - 2, py + size - 5, 5, 2, color)
				end
				local landmark, rail = World.observedFeatures(state, player, x, y)
				if rail then
					r:line(
						px + size * 0.25,
						py + size * 0.35,
						px + size * 0.75,
						py + size * 0.65,
						7
					)
					r:line(
						px + size * 0.25,
						py + size * 0.45,
						px + size * 0.75,
						py + size * 0.75,
						9
					)
				end
				if landmark then
					local colors = {
						lushcavern = 11,
						amethyst = 10,
						mushroom = 31,
						ice_spikes = 13,
						dripstone = 9,
						ancientcity = 4,
					}
					if landmark.natural then
						r:fill(
							px + size * 0.4,
							py + size * 0.3,
							math.max(3, size * 0.2),
							math.max(4, size * 0.4),
							colors[landmark.kind] or 8
						)
						r:fill(px + size * 0.35, py + size * 0.55, math.max(4, size * 0.3), 2, 7)
					else
						Icons.draw(r, "wonder", px + size / 2 - 4, py + size / 2 - 4, 9)
					end
				end
				local spawner = campIndex[k]
				if spawner and not spawner.cleared then
					Icons.draw(r, "spawner", px + size / 2 - 4, py + size / 2 - 4, 9)
				end
			end
			local city = t.visibility ~= "hidden" and World.observedCity(state, player, x, y)
			if
				city
				and not hiddenActors["city:" .. tostring(city.id)]
				and (city.remembered or city.owner == ui.playerID or t.visibility == "visible")
			then
				cityLabels[#cityLabels + 1] = {
					city = city,
					x = px + size / 2,
					y = py - 6,
					remembered = t.visibility == "explored",
				}
				if size < 16 then
					r:fill(px + size / 2 - 2, py + size / 2 - 2, 5, 5, 0)
					r:fill(
						px + size / 2 - 1,
						py + size / 2 - 1,
						3,
						3,
						ownerColor(state, city.owner)
					)
				else
					Icons.faction(
						r,
						city.village and city.owner == city.villageOwner and "village" or "city",
						px + size / 2 - 5,
						py + size / 2 - 5,
						11,
						ownerColor(state, city.owner)
					)
				end
			end
			if city and hiddenActors["city:" .. tostring(city.id)] then
				city = nil
			end
			local unit = t.visibility == "visible" and unitIndex[World.key(x, y)]
			if unit and hiddenActors[Animations.identity(unit)] then
				unit = nil
			end
			if unit then
				if size < 16 then
					r:fill(px + size / 2 - 1, py + size / 2 - 1, 4, 4, 0)
					r:fill(px + size / 2, py + size / 2, 2, 2, ownerColor(state, unit.owner))
				else
					Icons.faction(
						r,
						unit.kind,
						px + size / 2 - 5,
						py + size / 2 - 5,
						11,
						ownerColor(state, unit.owner)
					)
				end
			end
			local settler = civilianIndex[World.key(x, y)]
			if
				unit
				and settler
				and unit ~= settler
				and t.visibility == "visible"
				and not hiddenActors[Animations.identity(settler)]
			then
				if size >= 16 then
					Icons.faction(
						r,
						settler.kind,
						px + size * 0.65,
						py + size * 0.6,
						math.min(7, size / 2),
						ownerColor(state, settler.owner)
					)
				else
					r:fill(px + size * 0.65 - 1, py + size * 0.6 - 1, 4, 4, 0)
					r:fill(
						px + size * 0.65,
						py + size * 0.6,
						2,
						2,
						ownerColor(state, settler.owner)
					)
				end
			end
			if overlays.yields and t.visibility ~= "hidden" then
				if size >= 40 then
					for i, kind in ipairs({ "food", "industry", "science", "gold" }) do
						local value = t.yields[kind]
						local width = Icons.yieldWidth(r, value)
						local yy = py + size * ({ 0.18, 0.65, 0.82, 0.47 })[i]
						if width > 0 then
							Icons.yieldValue(
								r,
								kind,
								value,
								px + size / 2 - width / 2,
								yy,
								width,
								true
							)
						end
					end
				else
					local kind = "food"
					local value = t.yields.food
					for _, entry in ipairs({
						{ "wood", t.yields.industry },
						{ "science", t.yields.science },
						{ "gold", t.yields.gold or 0 },
					}) do
						if entry[2] > value then
							kind = entry[1]
							value = entry[2]
						end
					end
					if size >= 16 then
						local width = math.min(size - 4, Icons.yieldWidth(r, value))
						Icons.yieldValue(
							r,
							kind,
							value,
							px + size / 2 - width / 2,
							py + size * 0.65,
							width,
							true
						)
					else
						Icons.yield(r, kind, px + size / 2 - 2, py + size / 2 - 2, 5)
					end
				end
			end
			if
				workingCity
				and t.claim == workingCity
				and workingCity.worked
				and workingCity.worked[World.key(x, y)]
			then
				if size >= 12 then
					Icons.marker(r, "worked", px + 2, py + size / 2 - 3)
				else
					r:fill(px + 1, py + size / 2 - 1, 3, 3, 0)
					r:outline(px + 1, py + size / 2 - 1, 3, 3, 8)
				end
			end
			local destination = destinations[World.key(x, y)]
			if destination then
				local vertices = Hex.vertices(px + 1, py + 1, size - 2)
				for i, a in ipairs(vertices) do
					local b = vertices[i % 6 + 1]
					local count =
						math.max(1, math.ceil(math.max(math.abs(b.x - a.x), math.abs(b.y - a.y))))
					for n = 0, count do
						if n % 4 < 2 then
							local xx, yy =
								a.x + (b.x - a.x) * n / count, a.y + (b.y - a.y) * n / count
							r:fill(xx - 1, yy - 1, 3, 3, 0)
							r:fill(
								xx,
								yy,
								1,
								1,
								destination.attack and 31
									or destination.zoneStop and 8
									or (n % 4 == 0 and 7 or 13)
							)
						end
					end
				end
				if size >= 12 then
					Icons.moveCost(r, destination.cost, px + size / 2, py + size * 0.72)
					if destination.attack then
						Icons.marker(r, "attack", px + size * 0.65, py + size * 0.25)
					end
				end
				if (ui.destinationThreats or {})[World.key(x, y)] then
					local dx, dy = px + size * 0.25, py + size * 0.55
					r:fill(dx - 2, dy - 2, 5, 7, 0)
					r:line(dx - 1, dy - 1, dx, dy + 2, 18)
					r:line(dx + 1, dy - 1, dx, dy + 2, 18)
					r:fill(dx, dy + 4, 1, 1, 18)
				end
			end
			if not overlays.yields and size >= 16 then
				local actor = unit or city
				if actor and actor.hp and actor.hp < (unit and 100 or 200) then
					local max = unit and 100 or 200
					local bx, by = px + size / 2 - 4, py + size * 0.72
					r:fill(bx - 1, by - 1, 10, 4, 0)
					r:fill(bx, by, 8 * actor.hp / max, 2, actor.hp / max < 0.35 and 31 or 13)
				end
			end
			if
				unit
				and unit.owner == ui.playerID
				and not unit.standby
				and not unit.moved
				and (unit.movesLeft or 0) > 0
			then
				local ix, iy = px + size * 0.7, py + size * 0.4
				r:fill(ix - 1, iy - 1, 5, 5, 0)
				r:fill(ix, iy, 3, 3, 18)
				r:fill(ix + 1, iy + 1, 1, 1, 7)
			end
			if not ui.selected.empty and ui.selected.x == x and ui.selected.y == y then
				local vertices = Hex.vertices(px + 1, py + 1, size - 2)
				for i, a in ipairs(vertices) do
					local b = vertices[i % 6 + 1]
					r:line(a.x, a.y, b.x, b.y, 7)
				end
			end
		end
		r = canvas
		local occupied = {}
		ui.cityBannerTargets = {}
		table.sort(cityLabels, function(a, b)
			if (a.city.owner == ui.playerID) ~= (b.city.owner == ui.playerID) then
				return a.city.owner == ui.playerID
			end
			return (a.city.id or 0) < (b.city.id or 0)
		end)
		for _, label in ipairs(cityLabels) do
			local model = CityBanner.model(state, player, label.city, Systems)
			local box = CityBanner.layout(r, model, label, rect, occupied)
			occupied[#occupied + 1] = box
			local targetRenderer = label.remembered and rememberedRenderer or canvas
			CityBanner.draw(targetRenderer, model, box, ownerColor(state, label.city.owner))
			ui.cityBannerTargets[#ui.cityBannerTargets + 1] =
				{ x = box.x, y = box.y, w = box.w, h = box.h, city = label.city }
		end
		AnimationView.draw(ui, state, rect, size)
	end)
	r:outline(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2, 3)
	-- Four narrow click strips belong to the map frame, never the side panels.
	local edges = {
		{ x = frame.x, y = frame.y, w = 4, h = frame.h, dx = -3, dy = 0, name = "LEFT" },
		{
			x = frame.x + frame.w - 4,
			y = frame.y,
			w = 4,
			h = frame.h,
			dx = 3,
			dy = 0,
			name = "RIGHT",
		},
		{ x = frame.x + 4, y = frame.y, w = frame.w - 8, h = 4, dx = 0, dy = -3, name = "UP" },
		{
			x = frame.x + 4,
			y = frame.y + frame.h - 4,
			w = frame.w - 8,
			h = 4,
			dx = 0,
			dy = 3,
			name = "DOWN",
		},
	}
	for _, edge in ipairs(edges) do
		r:fill(edge.x, edge.y, edge.w, edge.h, 3)
		local cx = math.floor(edge.x + edge.w / 2)
		local cy = math.floor(edge.y + edge.h / 2)
		if edge.dx ~= 0 then
			local sign = edge.dx < 0 and -1 or 1
			r:line(cx - sign, cy - 2, cx + sign, cy, 7)
			r:line(cx + sign, cy, cx - sign, cy + 2, 7)
		else
			local sign = edge.dy < 0 and -1 or 1
			r:line(cx - 2, cy - sign, cx, cy + sign, 7)
			r:line(cx, cy + sign, cx + 2, cy - sign, 7)
		end
		r.buttons[#r.buttons + 1] = {
			x = edge.x,
			y = edge.y,
			w = edge.w,
			h = edge.h,
			label = "MAP " .. edge.name .. " EDGE",
			fn = function()
				ui:pan(edge.dx * size, edge.dy * size)
			end,
		}
	end
end
return V
