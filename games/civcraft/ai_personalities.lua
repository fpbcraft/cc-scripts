-- Personality describes preferences; difficulty must never change these values.
local Personalities = {}
local archetypes = {
	guardian = {
		aggression = 25,
		ambition = 45,
		risk = 25,
		diplomacy = 75,
		loyalty = 90,
		borders = 85,
	},
	conqueror = {
		aggression = 85,
		ambition = 85,
		risk = 70,
		diplomacy = 35,
		loyalty = 45,
		borders = 80,
	},
	scholar = {
		aggression = 20,
		ambition = 70,
		risk = 30,
		diplomacy = 70,
		loyalty = 75,
		borders = 45,
	},
	expansionist = {
		aggression = 50,
		ambition = 80,
		risk = 60,
		diplomacy = 50,
		loyalty = 55,
		borders = 70,
	},
	industrialist = {
		aggression = 35,
		ambition = 80,
		risk = 40,
		diplomacy = 60,
		loyalty = 65,
		borders = 65,
	},
	merchant = {
		aggression = 20,
		ambition = 65,
		risk = 35,
		diplomacy = 95,
		loyalty = 70,
		borders = 40,
	},
}
local civilizations = {
	verdant = "guardian",
	iron = "conqueror",
	scholar = "scholar",
	nomad = "expansionist",
	mariner = "expansionist",
	forge = "industrialist",
	highland = "guardian",
	merchant = "merchant",
	sentinel = "guardian",
	wild = "expansionist",
}

function Personalities.forCivilization(civilization)
	local name = civilizations[civilization] or "guardian"
	local result = { archetype = name }
	for key, value in pairs(archetypes[name]) do
		result[key] = value
	end
	return result
end

return Personalities
