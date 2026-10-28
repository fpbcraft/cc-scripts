-- Builders plan only from the ordinary detached player view.
local Works = dofile("/games/civcraft/tile_improvements.lua")
local WorkQueue = dofile("/games/civcraft/queued_work.lua")
local Routes = dofile("/games/civcraft/queued_routes.lua")
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Builders = {}
function Builders.order(view, player, unit, systems)
	if WorkQueue.threat(view, player.id, unit.x, unit.y, systems) then
		return nil
	end
	local best, bestScore
	for _, city in ipairs(view.cities or {}) do
		if city.owner == player.id then
			local context = Values.context(view, player, city, systems)
			for _, tile in ipairs(systems.workable(view, city)) do
				for _, kind in ipairs(Works.order) do
					local preview = Works.preview(view, player, unit, kind, tile.x, tile.y, systems)
					if preview then
						local path = unit.x == tile.x
								and unit.y == tile.y
								and {
									{ x = unit.x, y = unit.y },
								}
							or Routes.preview(view, unit, tile.x, tile.y, false, systems)
						local safe = path ~= nil
						for _, point in ipairs(path or {}) do
							if WorkQueue.threat(view, player.id, point.x, point.y, systems) then
								safe = false
								break
							end
						end
						if safe then
							local gain = {
								food = preview.after.food - preview.before.food,
								industry = preview.after.industry - preview.before.industry,
								science = 0,
							}
							local score = Values.effects(gain, context)
								* ((city.worked or {})[tile.key] and 2 or 1)
								/ (1 + #path)
							if not bestScore or score > bestScore then
								bestScore = score
								best = {
									action = "queueWork",
									unitID = unit.id,
									x = unit.x,
									y = unit.y,
									tileX = tile.x,
									tileY = tile.y,
									kind = kind,
								}
							end
						end
					end
				end
			end
		end
	end
	return best
end
return Builders
