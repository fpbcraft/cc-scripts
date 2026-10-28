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
		draw()
		for _, actor in ipairs(state.units) do
			ui:focus("unit", actor)
			draw()
			local found
			for _, badge in ipairs(ui.unitBadgeTargets) do
				if badge.unit.id == actor.id then
					found = badge
					break
				end
			end
			assert(found, "Each visible stacked/adjacent formation has a target")
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
					"City banner overlaps unit badge"
				)
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
		assert(rivalBadge, "A visible rival has an inspectable badge")
		tap(rivalBadge)
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
		local target = ui.unitBadgeTargets[1]
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
print("PASS: separate city/unit badges, exact stack selection, fog, zoom and armed-target priority")
