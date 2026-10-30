local FactionColors = dofile("/games/civcraft/faction_colors.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Terrain = dofile("/games/civcraft/terrain_view.lua")
local Fog = dofile("/games/civcraft/fog_view.lua")
local M = {}
function M.draw(ui, state, player, rect)
	local r = ui.r
	local canvas = r
	local rememberedRenderer = Fog.forUI(ui)
	local world = state.world
	local width, height = world and world.width or Hex.width, world and world.height or Hex.height
	r:fill(rect.x, rect.y, rect.w, rect.h, 15)
	local fullW = width + 0.5
	local fullH = (height - 1) * 0.75 + 1
	local wrappedX = world and world.wrapX == true
	r:withClip(rect, function()
		for y = 1, height do
			for x = 1, width do
				local known = World.known(player, x, y)
				if known ~= "hidden" then
					r = known == "explored" and rememberedRenderer or canvas
					local color = Terrain.color(Hex.tile(x, y, state), false)
					r:fill(
						rect.x + (x - 1 + (y - 1) % 2 * 0.5) * rect.w / fullW,
						rect.y + (y - 1) * 0.75 * rect.h / fullH,
						math.max(1, rect.w / fullW),
						math.max(1, rect.h / fullH),
						color
					)
				end
			end
		end
		r = canvas
		for tileKey, city in pairs(player.mapMemory and player.mapMemory.cities or {}) do
			if (player.explored or {})[tileKey] and not (player.visible or {})[tileKey] then
				rememberedRenderer:fill(
					rect.x + (city.x - 0.5) * rect.w / fullW,
					rect.y + ((city.y - 1) * 0.75 + 0.5) * rect.h / fullH,
					2,
					2,
					7
				)
			end
		end
		for _, list in ipairs({ state.cities, state.units }) do
			for _, item in ipairs(list or {}) do
				if
					item.owner == ui.playerID
					or World.known(player, item.x, item.y) == "visible"
				then
					r:fill(
						rect.x + (item.x - 0.5) * rect.w / fullW,
						rect.y + ((item.y - 1) * 0.75 + 0.5) * rect.h / fullH,
						2,
						2,
						FactionColors.owner(state, item.owner)
					)
				end
			end
		end
		local v = ui.mapViewport
		local viewY = math.min(rect.h, v.h / (fullH * v.tile) * rect.h)
		local viewTop = rect.y + ui.panY / (fullH * v.tile) * rect.h
		if wrappedX and v.periodX and v.periodX > 0 then
			local span = width / fullW * rect.w
			local viewW = math.min(rect.w, v.w / v.periodX * span)
			if viewW >= rect.w then
				r:outline(rect.x, viewTop, rect.w, viewY, 7)
			else
				local viewLeft = rect.x + ui.panX / v.periodX * span
				local right = rect.x + rect.w
				if viewLeft + viewW <= right then
					r:outline(viewLeft, viewTop, viewW, viewY, 7)
				else
					r:outline(viewLeft, viewTop, right - viewLeft, viewY, 7)
					r:outline(rect.x, viewTop, viewLeft + viewW - right, viewY, 7)
				end
			end
		else
			r:outline(
				rect.x + ui.panX / (fullW * v.tile) * rect.w,
				viewTop,
				math.min(rect.w, v.w / (fullW * v.tile) * rect.w),
				viewY,
				7
			)
		end
	end)
	r:outline(rect.x, rect.y, rect.w, rect.h, 3)
	r.buttons[#r.buttons + 1] = {
		x = rect.x,
		y = rect.y,
		w = rect.w,
		h = rect.h,
		label = "MINIMAP",
		fn = function(x, y)
			if (ui.panel ~= "context" and ui.panel ~= "minimap") or ui.pendingMove then
				return
			end
			local v = ui.mapViewport
			if wrappedX and v.periodX and v.periodX > 0 then
				local panX = (x - rect.x) / rect.w * v.periodX - v.w / 2
				ui.panX = ((panX % v.periodX) + v.periodX) % v.periodX
			else
				ui.panX =
					math.max(0, math.min(v.maxX, (x - rect.x) / rect.w * fullW * v.tile - v.w / 2))
			end
			ui.panY =
				math.max(0, math.min(v.maxY, (y - rect.y) / rect.h * fullH * v.tile - v.h / 2))
			if ui.panel == "minimap" then
				ui.panel = "context"
			end
		end,
	}
end
return M
