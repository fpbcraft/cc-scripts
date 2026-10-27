-- Distinct player colors in both graphics and the standard terminal palette.
local Colors = { players = { 32, 33, 34, 35 }, names = { "AMBER", "VIOLET", "PINK", "AZURE" } }
function Colors.owner(state, id)
	for index, player in ipairs(state.players or {}) do
		if player.id == id then
			return Colors.players[index] or 32
		end
	end
	return id == -2147483647 and 31 or 9
end
return Colors
