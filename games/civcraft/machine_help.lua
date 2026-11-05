local Choices = dofile("/games/civcraft/machine_choices.lua")
local Help = {}
Help.overview =
	"Open an owned city's MACH tab for planned operation forecasts. Local Create stress capacity (SU) is separate from stored materials and coal fuel; rails do not transfer SU. Lower priority numbers run first, followed by city and building identity. Preview a recipe, then APPLY to save it; previewing spends nothing. PAUSE/ENABLE and priority choices persist. These planned settings do not yet change the current production shown under INFO."
function Help.building(id)
	local spec = Choices.machines[id]
	if not spec then
		if id == "workshop" or id == "redstoneworkshop" then
			return { "Unpowered basic: continues without machine SU or coal fuel." }
		end
		return {}
	end
	local lines =
		{ "Planned operation forecast: inspect MACH; current city production remains under INFO." }
	if spec.generator then
		lines[#lines + 1] = "Adds "
			.. spec.capacity
			.. " local SU capacity when active; rails do not transfer SU."
		if spec.fuel then
			lines[#lines + 1] = "Steam reserves "
				.. spec.fuel.coal
				.. " coal only when otherwise eligible local work needs extra capacity. No useful demand means no fuel spent or Steam operating industry."
		end
	else
		lines[#lines + 1] = "Impact "
			.. spec.impact
			.. " SU; default priority "
			.. spec.priority
			.. ". Priorities 1 through 4 run in that order; insufficient capacity pauses lower-priority work."
	end
	if id == "mixer" then
		lines[#lines + 1] =
			"Starts with no recipe. Brass uses 1 copper and 1 zinc for 2 brass, with no industry bonus. Industry gives +2 industry and makes no brass."
	end
	lines[#lines + 1] =
		"Paused, disabled or unavailable machines grant no operating output. Complete output room is required before inputs are spent; this round's outputs cannot supply other machines until next round. Choices survive temporary shortages and inactive Works."
	return lines
end
return Help
