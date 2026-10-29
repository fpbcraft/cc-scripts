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
	units = {
		{ id = 2, owner = 0, kind = "warrior", x = 4, y = 4, movesLeft = 2 },
		{ id = 3, owner = 0, kind = "settler", x = 4, y = 4, movesLeft = 2 },
		{ id = 4, owner = 0, kind = "scout", x = 5, y = 4, movesLeft = 2 },
	},
	world = { width = 12, height = 8, tiles = {}, resources = {}, rails = {}, landmarks = {} },
}
for y = 1, 8 do
	for x = 1, 12 do
		state.world.tiles[World.key(x, y)] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)

for _, graphics in ipairs({ false, true }) do
	for _, zoom in ipairs({ 12, 20, 32 }) do
		local monitor = {
			getSize = function(mode)
				if mode == 2 then
					return 480, 360
				end
				return 80, 40
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
		local ui = UI.new(monitor, function()
			error("Selection cannot issue simulation commands")
		end)
		ui.zoomLevel = zoom
		local function draw()
			if os.queueEvent and os.pullEvent then
				os.queueEvent("badge_test_yield")
				os.pullEvent("badge_test_yield")
			end
			ui:draw(World.forPlayer(state, 0), 0, { screen = "game" })
		end
		local function tap(box)
			local x, y = box.x + math.floor(box.w / 2), box.y + math.floor(box.h / 2)
			if ui.r.mode == "graphics" then
				x, y = ui.r.ox + x * ui.r.sx, ui.r.oy + y * ui.r.sy
			else
				x, y = math.floor(x / 2) + 1, math.floor(y / 3) + 1
			end
			assert(ui:tap(x, y), "Badge pointer was not consumed")
		end
		local function overlaps(a, b)
			return a.x < b.x + b.w and a.x + a.w > b.x
				and a.y < b.y + b.h and a.y + a.h > b.y
		end
		local function findTarget(list, id)
			for _, target in ipairs(list or {}) do
				if target.unit.id == id then
					return target
				end
			end
			return nil
		end
		-- Independent reference for the painted glyph bounds. City callouts
		-- must depend on glyph/banner overlap, never just sharing a hex.
		local function glyphAt(hex, secondary)
			local size = ui.mapViewport.tile
			if size < 16 then
				return {
					x = hex.x + (secondary and size * 0.65 or size / 2),
					y = hex.y + (secondary and size * 0.6 or size / 2),
					w = 2, h = 2,
				}
			end
			if secondary then
				local diameter = math.min(7, size / 2)
				return { x = hex.x + size * 0.65, y = hex.y + size * 0.6,
					w = diameter, h = diameter }
			end
			return { x = hex.x + size / 2 - 5, y = hex.y + size / 2 - 5,
				w = 11, h = 11 }
		end
		local function projectedHex(actor)
			for _, hex in ipairs(ui.hexTargets or {}) do
				if hex.tx == actor.x and hex.ty == actor.y then
					return hex
				end
			end
			return nil
		end
		local function needsCallout(actor)
			local hex = projectedHex(actor)
			if not hex then return false end
			local secondary = false
			if actor.kind == "settler" then
				for _, other in ipairs(state.units) do
					if other.id ~= actor.id and other.x == actor.x and other.y == actor.y
						and other.kind ~= "settler" then
						secondary = true
					end
				end
			end
			local glyph = glyphAt(hex, secondary)
			for _, banner in ipairs(ui.cityBannerTargets or {}) do
				if overlaps(glyph, banner) then return true end
			end
			return false
		end
		local function targetFor(actor)
			local covered = needsCallout(actor)
			local badge = findTarget(ui.unitBadgeTargets, actor.id)
			local icon = findTarget(ui.unitIconTargets, actor.id)
			assert((badge ~= nil) == covered,
				"Circle must appear if and only if a city banner obscures the unit glyph: "
					.. actor.id .. " graphics=" .. tostring(graphics) .. " zoom=" .. zoom)
			if covered then
				assert(not icon, "Covered unit should not have a direct glyph target")
				return badge, true
			end
			assert(icon, "Uncovered unit remains selectable without a callout")
			return icon, false
		end
		draw()
		local anchored = assert(ui.cityBannerTargets[1], "City banner is visible")
		local initialX, initialY = anchored.x, anchored.y
		local coveredHex, clearHex
		for _, hex in ipairs(ui.hexTargets) do
			if state.players[1].visible[World.key(hex.tx, hex.ty)] then
				local glyph = glyphAt(hex, false)
				local hidden = overlaps(glyph, anchored)
				local atCity = hex.tx == state.cities[1].x and hex.ty == state.cities[1].y
				if hidden and not coveredHex then
					coveredHex = hex
				elseif not hidden and not atCity and not clearHex then
					clearHex = hex
				end
			end
		end
		assert(coveredHex and clearHex,
			"Map viewport should contain visible covered and uncovered hexes for the regression")
		local scout = state.units[3]
		local scoutX, scoutY = scout.x, scout.y
		scout.x, scout.y = coveredHex.tx, coveredHex.ty
		World.reveal(state, Hex, Systems)
		draw()
		assert(needsCallout(scout), "Fixture must actually put the scout beneath the city banner")
		local coveredTarget, isCovered = targetFor(scout)
		assert(isCovered and coveredTarget, "Covered scout needs a circular, clickable callout")
		tap(coveredTarget)
		assert(ui.selected.kind == "unit" and ui.selected.unitID == scout.id,
			"Covered callout selects its exact unit")
		scout.x, scout.y = clearHex.tx, clearHex.ty
		World.reveal(state, Hex, Systems)
		draw()
		assert(not needsCallout(scout), "Fixture must move the scout clear of the banner")
		local clearTarget, clearCovered = targetFor(scout)
		assert(not clearCovered and clearTarget, "Clear scout uses its normal unit icon")
		ui:focus("city", state.cities[1])
		draw()
		-- A moving formation must not make the city's label jump to another row.
		local previousX, previousY = state.units[1].x, state.units[1].y
		state.units[1].x, state.units[1].y = 6, 4
		World.reveal(state, Hex, Systems)
		draw()
		local shifted = assert(ui.cityBannerTargets[1])
		assert(
			shifted.x == initialX and shifted.y == initialY,
			"City banners must stay anchored when units enter or leave their tile"
		)
		-- The larger zoom levels can place the moved hex outside the viewport.
		-- Center the moved unit before checking its selectable callout.
		ui:focus("unit", state.units[1])
		draw()
		local movedBadge
		for _, badge in ipairs(ui.unitBadgeTargets) do
			if badge.unit.id == 2 then
				movedBadge = badge
				break
			end
		end
		assert(not movedBadge, "A unit away from the city should not have a floating marker")
		local movedHex
		for _, hex in ipairs(ui.hexTargets) do
			if hex.tx == 6 and hex.ty == 4 then
				movedHex = hex
				break
			end
		end
		assert(movedHex, "Moved unit's actual world tile is projected")
		assert(
			not needsCallout(state.units[1]) and findTarget(ui.unitIconTargets, 2),
			"Moving outside the banner must reveal the normal on-hex icon"
		)
		state.units[1].x, state.units[1].y = previousX, previousY
		scout.x, scout.y = scoutX, scoutY
		World.reveal(state, Hex, Systems)
		draw()
		for _, actor in ipairs(state.units) do
			ui:focus("unit", actor)
			draw()
			local found, covered = targetFor(actor)
			assert(found, "Each visible formation has a selectable icon or callout")
			if covered then
				assert(
					found.w == found.h and found.w >= 9 and found.w % 2 == 1,
					"Covered unit callout is circular"
				)
			end
			if covered then
			local hexAnchor
			for _, hex in ipairs(ui.hexTargets) do
				if hex.tx == actor.x and hex.ty == actor.y then
					hexAnchor = hex
					break
				end
			end
			assert(hexAnchor, "The unit's hex must be in the map viewport")
			assert(
				found.anchorX == math.floor(hexAnchor.x + hexAnchor.w / 2 + 0.5)
					and found.anchorY == math.floor(hexAnchor.y + hexAnchor.h / 2 + 0.5),
				"Unit callout pointer is anchored to the actual hex center at every zoom"
			)
			local cx = found.x + math.floor(found.w / 2)
			local cy = found.y + math.floor(found.h / 2)
			local dx, dy = found.anchorX - cx, found.anchorY - cy
			local px, py = found.pointerX - cx, found.pointerY - cy
			local distance = math.sqrt(dx * dx + dy * dy)
			assert(distance > 0, "Callout cannot obscure the unit's original tile")
			assert(
				dx * px + dy * py > 0
					and math.abs(dx * py - dy * px)
						<= distance * math.sqrt(px * px + py * py) * 0.2 + 2,
				"Bubble tail must point toward the true unit position, not its banner"
			)
			assert(
				(found.anchorX - found.pointerX) ^ 2 + (found.anchorY - found.pointerY) ^ 2
					< dx * dx + dy * dy,
				"The tail tip must be closer to the real unit than the badge center"
			)
			for _, other in ipairs(ui.unitBadgeTargets) do
				if other ~= found then
					assert(
						found.x >= other.x + other.w
							or other.x >= found.x + found.w
							or found.y >= other.y + other.h
							or other.y >= found.y + found.h,
						"Adjacent formation targets cannot overlap"
					)
				end
			end
			for _, banner in ipairs(ui.cityBannerTargets) do
				assert(
					found.x >= banner.x + banner.w
						or banner.x >= found.x + found.w
						or found.y >= banner.y + banner.h
						or banner.y >= found.y + found.h,
					"City banner overlaps unit badge: graphics="
						.. tostring(graphics)
						.. " zoom="
						.. zoom
						.. " unit="
						.. actor.id
						.. " badge="
						.. found.x
						.. ","
						.. found.y
						.. ","
						.. found.w
						.. ","
						.. found.h
						.. " banner="
						.. banner.x
						.. ","
						.. banner.y
						.. ","
						.. banner.w
						.. ","
						.. banner.h
						.. " viewport="
						.. ui.mapViewport.x
						.. ","
						.. ui.mapViewport.y
						.. ","
						.. ui.mapViewport.w
						.. ","
						.. ui.mapViewport.h
				)
			end
			end
			tap(found)
			assert(
				ui.selected.kind == "unit" and ui.selected.unitID == actor.id,
				"Exact stacked unit identity must be selectable: "
					.. tostring(graphics)
					.. " zoom="
					.. zoom
					.. " expected="
					.. actor.id
					.. " got="
					.. tostring(ui.selected.unitID)
					.. " kind="
					.. tostring(ui.selected.kind)
					.. " badge="
					.. found.x
					.. ","
					.. found.y
			)
		end
		local rival = { id = 5, owner = 1, kind = "warrior", x = 6, y = 4, movesLeft = 2 }
		state.players[2] = { id = 1, name = "RIVAL", civ = "iron", techs = {} }
		state.units[#state.units + 1] = rival
		World.reveal(state, Hex, Systems)
		ui:focus("unit", rival)
		draw()
		local rivalBadge
		for _, badge in ipairs(ui.unitBadgeTargets) do
			if badge.unit.id == 5 then
				rivalBadge = badge
			end
		end
		local rivalTarget = targetFor(rival)
		assert(rivalTarget, "A visible rival has a selectable icon or covered callout")
		tap(rivalTarget)
		draw()
		assert(
			ui.selected.kind == "unit" and ui.selected.unitID == 5 and not ui.selected.empty,
			"Visible rival identity remains selected after redraw"
		)
		for _, button in ipairs(ui.r.buttons) do
			assert(
				button.label ~= "MOVE / ATTACK" and button.label ~= "QUEUE MOVES",
				"Rival selection cannot expose owner commands"
			)
		end
		state.players[1].visible[World.key(rival.x, rival.y)] = nil
		draw()
		assert(ui.selected.empty, "A rival leaving vision clears its selection")
		table.remove(state.units)
		World.reveal(state, Hex, Systems)
		ui:focus("city", state.cities[1])
		draw()
		assert(#ui.cityBannerTargets == 1)
		tap(ui.cityBannerTargets[1])
		assert(ui.selected.kind == "city", "Banner remains independently clickable")
		draw()
		ui.source = { x = 4, y = 4, unitID = 2 }
		local target = ui.unitBadgeTargets[1] or ui.unitIconTargets[1]
		assert(target, "Visible unit can be targeted in armed movement mode")
		local called = false
		local original = ui.tile
		ui.tile = function()
			called = true
		end
		tap(target)
		assert(called, "Armed movement owns map clicks before unit badges")
		ui.tile = original
		ui.source = nil
		-- Even unprojected authoritative units cannot acquire remembered/hidden targets.
		state.players[1].visible = {}
		ui:draw(state, 0, { screen = "game" })
		assert(#ui.unitBadgeTargets == 0, "Fog cannot expose unit badges")
		World.reveal(state, Hex, Systems)
		ui.panX = ui.mapViewport.maxX
		ui.panY = ui.mapViewport.maxY
		draw()
		for _, badge in ipairs(ui.unitBadgeTargets) do
			local anchor
			for _, hex in ipairs(ui.hexTargets) do
				if hex.tx == badge.unit.x and hex.ty == badge.unit.y then
					anchor = hex
					break
				end
			end
			local viewport = ui.mapViewport
			assert(
				anchor
					and anchor.x + anchor.w / 2 >= viewport.x
					and anchor.x + anchor.w / 2 < viewport.x + viewport.w
					and anchor.y + anchor.h / 2 >= viewport.y
					and anchor.y + anchor.h / 2 < viewport.y + viewport.h,
				"Offscreen formations are not pulled into clickable edge badges"
			)
		end
		ui:close()
	end
end
print("PASS: only covered units have callouts; clear icons, rivals, stacks, fog and armed input remain selectable")
