local Hex = dofile("/games/civcraft/hex.lua")
local Values = {}

function Values.context(view, player, city, systems)
	local yields = systems.yields(player, city, view, Hex)
	local treasury = systems.treasury(player, view)
	local plan = player.aiPlan or {}
	local specialization = (plan.citySpecializations or {})[city.id]
	local surplus = yields.food - 2 * (city.population or 2)
	return {
		yields = yields,
		treasury = treasury,
		surplus = surplus,
		goal = plan.primary or "industrial",
		specialization = specialization,
		emergency = plan.emergency,
		food = surplus < 0 and 9 or surplus < 2 and 3.5 or 0.6,
		industry = (yields.industry < 6 and 3 or 1.8)
			* ((specialization == "industry" or specialization == "infrastructure") and 1.3 or 1),
		science = (plan.primary == "expedition" and 2.8 or 1.8)
			* (specialization == "science" and 1.3 or 1),
		gold = (treasury.net < 0 and 8 or (player.gold or 0) < 40 and 3 or 0.9)
			* (specialization == "commerce" and 1.3 or 1),
	}
end

function Values.effects(effects, context)
	local score = 0
	for _, key in ipairs({ "food", "industry", "science", "gold" }) do
		score = score + (effects[key] or 0) * context[key]
	end
	return score
end

function Values.dependencies(records, target, completed, weight, result)
	result = result or {}
	if completed[target] or not records[target] or weight < 0.5 then
		return result
	end
	-- Keep the strongest dependency path instead of repeatedly counting a shared prerequisite.
	if (result[target] or 0) >= weight then
		return result
	end
	result[target] = weight
	for _, need in ipairs(records[target].requires or {}) do
		Values.dependencies(records, need, completed, weight * 0.78, result)
	end
	return result
end

return Values
