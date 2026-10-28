-- Offline operational ablation: prefer safe legal steps on a discovered route.
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Policy = {}

function Policy.install()
	local original = Tactics.ranked
	Tactics.ranked = function(view, player, unit, systems)
		local choices = original(view, player, unit, systems)
		local plan, role = player.aiPlan or {}, (unit.aiRole or {}).name
		local campaign = plan.campaign or {}
		if
			plan.primary ~= "conquest"
			or campaign.kind ~= "city"
			or (campaign.phase ~= "approach" and campaign.phase ~= "siege")
			or (role ~= "siege" and role ~= "mainArmy")
			or (unit.hp or 100) < 50
		then
			return choices
		end
		local routes = Routes.from(view, unit, systems, { maxCost = 64, maxNodes = 1024 })
		local best, bestCost
		for key, cost in pairs(routes.costs) do
			local x, y = key:match("^(%-?%d+):(%-?%d+)$")
			x, y = tonumber(x), tonumber(y)
			if
				x
				and Hex.distance(x, y, campaign.x, campaign.y) <= ((systems.units[unit.kind] or {}).range or 1)
				and (
					not bestCost
					or cost < bestCost
					or cost == bestCost and (y < best.y or y == best.y and x < best.x)
				)
			then
				best, bestCost = { x = x, y = y }, cost
			end
		end
		if not best or bestCost == 0 then
			return choices
		end
		local path, progress = routes.pathTo(best.x, best.y), {}
		for index = 2, #path do
			local key = path[index].x .. ":" .. path[index].y
			progress[key] = routes.costs[key]
		end
		for _, choice in ipairs(choices) do
			local request = choice.request
			local amount = progress[tostring(request.x) .. ":" .. tostring(request.y)]
			if
				request.action == "move"
				and not choice.forecast
				and amount
				and ((choice.risk or {}).damage or 0) < (unit.hp or 100) * 0.5
			then
				choice.score = choice.score + 40 + math.min(20, amount * 6)
			end
		end
		table.sort(choices, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			local aa, bb = a.request, b.request
			if aa.action ~= bb.action then
				return aa.action < bb.action
			end
			return aa.y == bb.y and aa.x < bb.x or aa.y < bb.y
		end)
		return choices
	end
end

return Policy
