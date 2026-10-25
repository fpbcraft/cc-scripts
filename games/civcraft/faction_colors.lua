-- Distinct player colors in both graphics and the standard terminal palette.
local Colors = { players = { 8, 13, 30, 10 }, names = { "GOLD", "CYAN", "IVORY", "ROSE" } }
function Colors.owner(state, id)
	for index, player in ipairs(state.players or {}) do
		if player.id == id then
			return Colors.players[index] or 8
		end
	end
	return id == -2147483647 and 31 or 9
end
return Colors
