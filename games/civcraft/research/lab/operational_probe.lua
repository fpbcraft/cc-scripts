-- Read-only observer diagnostics. Never consulted by a policy or action dispatcher.
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Routes = dofile("/games/civcraft/ai_routes.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Probe = {}

local function finite(value)
	if value and value > -math.huge and value < math.huge then
		return value
	end
end

local function rangeCost(view, unit, systems, city, ignoreFriendly)
	local routes =
		Routes.from(view, unit, systems, { ignoreFriendly = ignoreFriendly, maxCost = 64 })
	local best
	for key, cost in pairs(routes.costs) do
		local x, y = key:match("^(%-?%d+):(%-?%d+)$")
		if
			x
			and Hex.distance(tonumber(x), tonumber(y), city.x, city.y)
				<= ((systems.units[unit.kind] or {}).range or 1)
		then
			if not best or cost < best then
				best = cost
			end
		end
	end
	return best, routes.visited
end

function Probe.install(actor)
	local records, indexed = {}, {}
	local original = Tactics.ranked
	Tactics.ranked = function(view, player, unit, systems)
		local choices = original(view, player, unit, systems)
		local stats = systems.units[unit.kind] or {}
		if
			player.id ~= actor
			or view.round < 50
			or not (stats.siege or (stats.range or 1) == 1 and (stats.strength or 0) >= 7)
		then
			return choices
		end
		local key = tostring(view.round) .. ":" .. tostring(unit.id)
		if indexed[key] then
			indexed[key].calls = indexed[key].calls + 1
			return choices
		end
		local plan = player.aiPlan or {}
		local campaign = plan.campaign or {}
		local target, source, distance
		for _, city in ipairs(view.cities or {}) do
			if not city.village and Diplomacy.canAttack(view, player.id, city.owner) then
				local d = Hex.distance(unit.x, unit.y, city.x, city.y)
				if not distance or d < distance then
					target, source, distance = city, "visible", d
				end
			end
		end
		if not target and campaign.kind == "city" then
			target, source = campaign, "campaign-memory"
		end
		if not target then
			target, source = plan.__militaryLastEnemyCampaign, "research-memory"
		end
		local item = {
			round = view.round,
			unitId = unit.id,
			kind = unit.kind,
			x = unit.x,
			y = unit.y,
			hp = unit.hp,
			role = (unit.aiRole or {}).name,
			calls = 1,
			siege = stats.siege == true,
			campaignKind = campaign.kind,
			campaignPhase = campaign.phase,
			campaignX = campaign.x,
			campaignY = campaign.y,
			forecastsWithWallDamage = 0,
			top = {},
		}
		if target then
			item.targetX, item.targetY, item.targetSource = target.x, target.y, source
			item.distanceToEnemy = Hex.distance(unit.x, unit.y, target.x, target.y)
			if stats.siege and view.round % 10 == 0 then
				item.costToGeometricRange, item.routeVisited =
					rangeCost(view, unit, systems, target, false)
				item.friendlyIgnoredCost, item.friendlyIgnoredVisited =
					rangeCost(view, unit, systems, target, true)
			end
		end
		for rank, choice in ipairs(choices) do
			local forecast = choice.forecast or {}
			if (forecast.wallDamage or 0) > 0 then
				item.forecastsWithWallDamage = item.forecastsWithWallDamage + 1
				if not item.firstWallShotRank then
					item.firstWallShotRank, item.firstWallShotScore = rank, finite(choice.score)
				end
			end
			if rank <= 3 then
				local request = choice.request
				item.top[#item.top + 1] = {
					action = request.action,
					x = request.x,
					y = request.y,
					score = finite(choice.score),
					wallDamage = forecast.wallDamage,
					risk = (choice.risk or {}).damage,
				}
			end
		end
		records[#records + 1], indexed[key] = item, item
		return choices
	end
	return records
end

return Probe
