-- Draw event-time observations even when current fog or entity membership changed.
local Icons = dofile("/games/civcraft/icons.lua")
local View = {}
local colors = { 8, 13, 11, 21 }
function View.center(ui, rect, size)
	local frame = ui.animationFrame
	if not frame then
		return
	end
	local position = frame.effects[1] and frame.effects[1].position
		or frame.projectile and frame.projectile.position
		or frame.sprites[1] and frame.sprites[1].position
	if position then
		ui.panX = position.x * size - rect.w / 2
		ui.panY = position.y * size - rect.h / 2
	end
end

local function ownerColor(state, owner)
	for i, player in ipairs(state.players or {}) do
		if player.id == owner then
			return colors[i] or 8
		end
	end
	return 31
end

function View.draw(ui, state, rect, size)
	local frame = ui.animationFrame
	if not frame then
		return
	end
	local r = ui.r
	local function point(position)
		return rect.x + position.x * size - ui.panX, rect.y + position.y * size - ui.panY
	end
	for _, sprite in ipairs(frame.sprites) do
		local x, y = point(sprite.position)
		local actor = sprite.actor
		local opacity = sprite.opacity
		if opacity >= 1 or math.floor(ui.animationTime * 20) % 4 < opacity * 4 then
			if size < 16 then
				r:fill(x - 1, y - 1, 3, 3, ownerColor(state, actor.owner))
			else
				Icons.draw(r, actor.kind, x - 5, y - 5, 11, ownerColor(state, actor.owner))
			end
			local maximum = actor.kind == "city" and 200 or 100
			if sprite.hp then
				r:fill(x - 5, y + 5, 10, 3, 0)
				r:fill(x - 4, y + 6, 8 * sprite.hp / maximum, 1, 13)
			end
		end
	end
	if frame.projectile then
		local x, y = point(frame.projectile.position)
		local sx, sy = point(frame.projectile.start)
		r:line(sx, sy, x, y, 18)
		r:fill(x - 1, y - 1, 3, 3, 7)
	end
	for _, effect in ipairs(frame.effects) do
		local x, y = point(effect.position)
		local radius = 2 + effect.progress * size * 0.4
		local color = effect.kind == "impact" and 31 or 18
		r:outline(x - radius, y - radius, radius * 2, radius * 2, color)
		if effect.kind == "impact" and effect.progress < 0.25 then
			r:fill(x - 3, y - 3, 6, 6, 7)
		end
	end
end

return View
