-- Difficulty changes decision quality; it never grants resources, sight or actions.
local Difficulty = { order = { "settler", "chieftain", "prince", "king", "deity" } }
local profiles = {
	settler = {
		candidates = 8,
		review = 14,
		routeCost = 10,
		alternatives = 3,
		warArmy = 7,
		warInterval = 8,
		followup = 0,
		futureSites = 0,
		risk = 0.65,
		description = "Forgiving expansion and tactics; slower planning and limited proactive wars.",
	},
	chieftain = {
		candidates = 16,
		review = 12,
		routeCost = 13,
		alternatives = 2,
		warArmy = 5,
		warInterval = 4,
		followup = 0,
		futureSites = 0,
		risk = 0.85,
		description = "Basic coordination with occasional near-best economic and tactical choices.",
	},
	prince = {
		candidates = 24,
		review = 10,
		routeCost = 16,
		alternatives = 1,
		warArmy = 3,
		warInterval = 1,
		followup = 0,
		futureSites = 0,
		risk = 1,
		description = "Competent baseline: sensible expansion, production, military and diplomacy.",
	},
	king = {
		candidates = 36,
		review = 5,
		routeCost = 20,
		alternatives = 1,
		warArmy = 3,
		warInterval = 1,
		followup = 2,
		futureSites = 0.15,
		risk = 1.15,
		description = "Broader tactical search, coordinated follow-up attacks, earlier reviews and future city yields.",
	},
	deity = {
		candidates = 48,
		review = 3,
		routeCost = 24,
		alternatives = 1,
		warArmy = 3,
		warInterval = 1,
		followup = 4,
		futureSites = 0.3,
		risk = 1.3,
		description = "Deeper bounded coordination, stronger threat anticipation and long-term settlement evaluation.",
	},
}
function Difficulty.id(player)
	return profiles[player and player.aiDifficulty] and player.aiDifficulty or "prince"
end
function Difficulty.profile(player)
	return profiles[Difficulty.id(player)]
end
function Difficulty.configure(state, actor, request)
	if state.phase ~= "lobby" or not state.players[1] or state.players[1].id ~= actor then
		return false, "Only the host can change AI difficulty in the lobby"
	end
	for _, player in ipairs(state.players) do
		if player.id == request.playerID and player.ai then
			local level = request.level
			if level == nil then
				local current = Difficulty.id(player)
				for index, id in ipairs(Difficulty.order) do
					if id == current then
						level = Difficulty.order[index % #Difficulty.order + 1]
						break
					end
				end
			end
			if not profiles[level] then
				return false, "Choose a supported AI difficulty"
			end
			player.aiDifficulty = level
			return true
		end
	end
	return false, "Choose an AI civilization"
end
function Difficulty.choices(choices, player, round, salt)
	local count = Difficulty.profile(player).alternatives
	if count == 1 or #choices < 2 or ((round or 1) + player.id + (salt or 0)) % 4 ~= 0 then
		return choices
	end
	local index = math.min(count, #choices)
	local best, nextBest = choices[1].score, choices[index].score
	if not best or not nextBest or nextBest < best - math.abs(best) * 0.15 - 5 then
		return choices
	end
	local ordered = {}
	for at, choice in ipairs(choices) do
		ordered[at] = choice
	end
	ordered[1], ordered[index] = ordered[index], ordered[1]
	return ordered
end
return Difficulty
