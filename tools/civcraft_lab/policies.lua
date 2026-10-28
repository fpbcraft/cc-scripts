-- Offline policy experiments only. No gameplay values or action allowances change.
local Values = dofile("/games/civcraft/ai_economy_values.lua")
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local Policies = {}
local goals = { conquest = true, industrial = true, expedition = true, diplomatic = true }

function Policies.install(players)
	local contexts, review = Values.context, Strategy.review
	local profiles = {}
	for index, record in ipairs(players) do
		local policy = record.policy or {}
		assert(not policy.version or policy.version == 1, "Unsupported policy format")
		assert(not policy.goal or goals[policy.goal], "Unknown research policy goal")
		for key, weight in pairs(policy.weights or {}) do
			assert(
				key == "food" or key == "industry" or key == "science" or key == "gold",
				"Unknown policy weight"
			)
			assert(
				type(weight) == "number" and weight >= 0.25 and weight <= 4,
				"Policy weights must be bounded positive values"
			)
		end
		profiles[index - 1] = policy
	end
	Values.context = function(view, player, city, systems)
		local context = contexts(view, player, city, systems)
		for key, weight in pairs(profiles[player.id].weights or {}) do
			context[key] = context[key] * weight
		end
		return context
	end
	Strategy.review = function(view, player, seed)
		local plan = review(view, player, seed)
		local goal = profiles[player.id].goal
		if goal and Rules.enabled(view, goal) then
			-- This is policy memory, not a mutation of resources or authoritative rules.
			plan.primary = goal
			plan.priorities = plan.emergency and { plan.emergency, goal }
				or { goal, "developEconomy" }
			plan.objectives = { goal, "secureResources", "connectCities" }
		end
		return plan
	end
end

return Policies
