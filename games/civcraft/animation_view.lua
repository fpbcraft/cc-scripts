-- Draw event-time observations even when current fog or entity membership changed.
local FactionColors = dofile("/games/civcraft/faction_colors.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local AnimationFrame = dofile("/games/civcraft/animation_frame.lua")
local DisplayGeometry = dofile("/games/civcraft/display_geometry.lua")
local View = {}
local function frameForDisplay(ui, state)
	local frame = ui.animationFrame
	if not frame or not frame.event or not DisplayGeometry.isWrapped(state) then
		return frame
	end
	local display = {
		hidden = frame.hidden,
		sprites = {},
		effects = {},
		event = frame.event,
		progress = frame.progress,
		waiting = frame.waiting,
	}
	AnimationFrame.paint(display, frame.event, frame.progress, state)
	if frame.waiting then
		display.focus = display.effects[1] and display.effects[1].position
			or display.sprites[1] and display.sprites[1].position
		display.effects, display.projectile = {}, nil
	end
	return display
end

function View.center(ui, rect, size, state)
	local frame = frameForDisplay(ui, state)
	if not frame then
		return
	end
	local position = frame.focus
		or frame.effects[1] and frame.effects[1].position
		or frame.projectile and frame.projectile.position
		or frame.sprites[1] and frame.sprites[1].position
	if position then
		local referenceX = ((ui.panX or 0) + rect.w / 2) / size
		local x = DisplayGeometry.nearestX(position.x, referenceX, state)
		ui.panX = x * size - rect.w / 2
		ui.panY = position.y * size - rect.h / 2
	end
end

local ownerColor = FactionColors.owner

function View.draw(ui, state, rect, size)
	local frame = frameForDisplay(ui, state)
	if not frame then
		return
	end
	local r = ui.r
	local referenceX = ((ui.panX or 0) + rect.w / 2) / size
	local anchor = frame.focus
		or frame.sprites[1] and frame.sprites[1].position
		or frame.projectile and frame.projectile.position
		or frame.effects[1] and frame.effects[1].position
	local shift = anchor and DisplayGeometry.nearestX(anchor.x, referenceX, state) - anchor.x or 0
	local function point(position)
		return rect.x + (position.x + shift) * size - ui.panX, rect.y + position.y * size - ui.panY
	end
	for _, sprite in ipairs(frame.sprites) do
		local x, y = point(sprite.position)
		local actor = sprite.actor
		local opacity = sprite.opacity
		if opacity >= 1 or math.floor(ui.animationTime * 20) % 4 < opacity * 4 then
			if size < 16 then
				r:fill(x - 1, y - 1, 3, 3, ownerColor(state, actor.owner))
			else
				Icons.faction(r, actor.kind, x - 5, y - 5, 11, ownerColor(state, actor.owner))
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
