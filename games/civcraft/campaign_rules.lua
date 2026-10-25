local Rules = {
	speeds = { "quick", "standard", "epic" },
	presets = {
		quick = { factor = 2 / 3, rounds = 120 },
		standard = { factor = 1, rounds = 180 },
		epic = { factor = 1.5, rounds = 270 },
	},
	victories = { "conquest", "industrial", "expedition", "score" },
}

function Rules.cost(value, context)
	local preset = Rules.presets[context and context.gameSpeed] or Rules.presets.standard
	return math.max(1, math.ceil(value * preset.factor))
end

function Rules.enabled(state, victory)
	return not state.victories or state.victories[victory] ~= false
end

function Rules.configure(state, id, request)
	if state.phase ~= "lobby" then
		return false, "Campaign rules are fixed after starting"
	end
	if not state.players[1] or state.players[1].id ~= id then
		return false, "Host only"
	end
	if request.action == "gameSpeed" then
		local nextSpeed = request.speed
		if nextSpeed == nil then
			local current = 2
			for index, speed in ipairs(Rules.speeds) do
				if speed == state.gameSpeed then
					current = index
				end
			end
			nextSpeed = Rules.speeds[current % #Rules.speeds + 1]
		end
		if not Rules.presets[nextSpeed] then
			return false, "Unknown game length"
		end
		state.gameSpeed = nextSpeed
		state.roundLimit = Rules.presets[nextSpeed].rounds
		for _, player in ipairs(state.players) do
			player.gameSpeed = nextSpeed
		end
		return true
	elseif request.action == "toggleVictory" then
		local known = false
		for _, victory in ipairs(Rules.victories) do
			known = known or victory == request.victory
		end
		if not known then
			return false, "Unknown victory condition"
		end
		local enabled = not Rules.enabled(state, request.victory)
		if request.enabled ~= nil then
			if type(request.enabled) ~= "boolean" then
				return false, "Invalid victory selection"
			end
			enabled = request.enabled
		end
		local remaining = enabled and 1 or 0
		for _, victory in ipairs(Rules.victories) do
			if victory ~= request.victory and Rules.enabled(state, victory) then
				remaining = remaining + 1
			end
		end
		if remaining == 0 then
			return false, "Enable at least one victory condition"
		end
		state.victories = state.victories or {}
		state.victories[request.victory] = enabled
		return true
	end
	return false, "Unknown campaign rule"
end

return Rules
