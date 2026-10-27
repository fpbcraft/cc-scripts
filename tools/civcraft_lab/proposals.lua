local Works = dofile("/games/civcraft/tile_improvements.lua")
-- Observation-only action candidates.
--
-- The authoritative dispatcher remains the legality oracle. This module must
-- never inspect hidden host state or mutate the detached observer view. Some
-- candidates can still be rejected when a public projection omits a hidden
-- obstacle, treaty term, resource or route constraint.
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")

local Proposals = {
	coverage = "observer candidates for research, production, city work, unit modes, movement, founding, rail, strikes, exchange, envoys, bounded diplomacy and Council; not exhaustive legal actions",
	coverageMetadata = {
		schemaVersion = 2,
		exhaustive = false,
		observerOnly = true,
		legalityOracle = "games/civcraft/actions.lua",
		families = {
			"research",
			"production",
			"cityWork",
			"unitMovement",
			"unitModes",
			"founding",
			"escort",
			"rail",
			"cityStrike",
			"exchange",
			"envoy",
			"diplomacy",
			"council",
		},
		unbounded = {
			diplomaticOffer = {
				knownKinds = {
					"alliance",
					"commerce",
					"councilSupport",
					"defensivePact",
					"jointWar",
					"openBorders",
					"peace",
					"trade",
					"withdrawal",
				},
				terms = "bounded templates only; offer amount/resource/deadline combinations are not exhaustive",
			},
			diplomaticCounter = {
				terms = "bounded templates only; trade amount/resource combinations are not exhaustive",
			},
			councilPropose = {
				kinds = { "censure", "embargo", "peace", "trade" },
				terms = "public-member and active-war combinations only",
			},
		},
		knownLimits = {
			"Hidden terrain, obstacles, private offers, stockpiles and treaty constraints may cause authoritative rejection.",
			"The candidate list is not a legal-action mask and must not be used as an exhaustive action space.",
			"Diplomatic offers and Council resolutions intentionally expose bounded templates, not every term combination.",
		},
	},
}

local function add(result, action)
	result[#result + 1] = action
end

local function ownPlayer(view, playerId)
	for _, player in ipairs(view.players or {}) do
		if player.id == playerId then
			return player
		end
	end
end

local function otherPlayers(view, playerId)
	local result = {}
	for _, player in ipairs(view.players or {}) do
		if player.id ~= playerId then
			result[#result + 1] = player
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	return result
end

local function key(x, y)
	return tostring(x) .. ":" .. tostring(y)
end

local function knownTile(view, x, y, playerId)
	local world = view.world
	local k = key(x, y)
	return world
		and world.tiles
		and world.tiles[k] ~= nil
		and (world.observedOwners or {})[k] == playerId
end

local function worldTileKeys(view)
	local result = {}
	for tileKey in pairs(view.world and view.world.tiles or {}) do
		result[#result + 1] = tileKey
	end
	table.sort(result)
	return result
end

local function ownUnits(view, playerId)
	local result = {}
	for _, unit in ipairs(view.units or {}) do
		if unit.owner == playerId then
			result[#result + 1] = unit
		end
	end
	table.sort(result, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)
	return result
end

local function ownCities(view, playerId)
	local result = {}
	for _, city in ipairs(view.cities or {}) do
		if city.owner == playerId then
			result[#result + 1] = city
		end
	end
	table.sort(result, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)
	return result
end

local function relationKnown(view, player, playerId, otherId)
	if not player or not player.contacts or player.contacts[otherId] ~= true then
		return false
	end
	local relations = view.diplomacy and view.diplomacy.relations or {}
	return relations[tostring(playerId) .. ":" .. tostring(otherId)]
		or relations[tostring(otherId) .. ":" .. tostring(playerId)]
end

local function warFor(view, playerId, otherId)
	for _, war in ipairs(view.diplomacy and view.diplomacy.wars or {}) do
		if (war.a == playerId and war.b == otherId) or (war.a == otherId and war.b == playerId) then
			return war
		end
	end
end

local function activeTreaty(view, playerId, otherId, kind)
	for _, treaty in ipairs(view.diplomacy and view.diplomacy.treaties or {}) do
		if
			(not kind or treaty.kind == kind)
			and ((treaty.a == playerId and treaty.b == otherId) or (treaty.a == otherId and treaty.b == playerId))
			and treaty.status == "active"
		then
			return treaty
		end
	end
end

local function councilMember(view, id)
	for _, member in
		ipairs(view.council and view.council.session and view.council.session.members or {})
	do
		if member.id == id and member.alive ~= false then
			return true
		end
	end
	return false
end

local function addResearch(result, player)
	for _, id in ipairs(Systems.techOrder) do
		if Systems.canResearch(player, id) then
			add(result, { action = "researchTech", id = id })
		end
	end
end

local function addProduction(result, view, player, playerId, cities)
	local buildings, units, wonders = {}, {}, {}
	for id in pairs(Systems.buildings) do
		buildings[#buildings + 1] = id
	end
	for id in pairs(Systems.units) do
		units[#units + 1] = id
	end
	for id in pairs(Systems.wonders) do
		wonders[#wonders + 1] = id
	end
	table.sort(buildings)
	table.sort(units)
	table.sort(wonders)
	for _, city in ipairs(cities) do
		for _, id in ipairs({ "ponder", "tend", "trade" }) do
			if Systems.canProject(player, city, id) then
				add(
					result,
					{ action = "queue", kind = "project", id = id, cityX = city.x, cityY = city.y }
				)
			end
		end
		for _, id in ipairs(buildings) do
			if Systems.canBuild(player, city, id, view) then
				add(
					result,
					{ action = "queue", kind = "building", id = id, cityX = city.x, cityY = city.y }
				)
			end
		end
		for _, id in ipairs(units) do
			if Systems.canRecruit(player, id, view, Hex, city) then
				add(
					result,
					{ action = "queue", kind = "unit", id = id, cityX = city.x, cityY = city.y }
				)
			end
		end
		if city.project then
			add(result, { action = "queue", kind = "none", cityX = city.x, cityY = city.y })
		end
		-- Wonder placement is public only where the observer has seen an owned
		-- tile. Hidden landmarks and world-unique races remain authoritative.
		for _, id in ipairs(wonders) do
			local wonder = Systems.wonders[id]
			if wonder and (not wonder.tech or (player.techs or {})[wonder.tech]) then
				for _, tileKey in ipairs(worldTileKeys(view)) do
					local x, y = tileKey:match("^(%d+):(%d+)$")
					x, y = tonumber(x), tonumber(y)
					if
						x
						and y
						and (view.world.observedOwners or {})[tileKey] == playerId
						and not (x == city.x and y == city.y)
						and Hex.distance(city.x, city.y, x, y) <= 3
					then
						add(result, {
							action = "queue",
							kind = "wonder",
							id = id,
							cityX = city.x,
							cityY = city.y,
							tileX = x,
							tileY = y,
						})
					end
				end
			end
		end
	end
end

local function addCityWork(result, view, playerId, cities)
	local jobs = { "idle", "food", "wood", "science" }
	for _, city in ipairs(cities) do
		for _, from in ipairs(jobs) do
			local count = from == "idle"
					and math.max(
						0,
						(city.population or 2)
							- ((city.jobs or {}).food or 0)
							- ((city.jobs or {}).wood or 0)
							- ((city.jobs or {}).science or 0)
					)
				or ((city.jobs or {})[from] or 0)
			if count > 0 then
				for _, to in ipairs(jobs) do
					if from ~= to then
						add(result, {
							action = "assign",
							cityX = city.x,
							cityY = city.y,
							from = from,
							to = to,
						})
					end
				end
			end
		end
		for _, tileKey in ipairs(worldTileKeys(view)) do
			local x, y = tileKey:match("^(%d+):(%d+)$")
			x, y = tonumber(x), tonumber(y)
			if
				x
				and y
				and (view.world.observedOwners or {})[tileKey] == playerId
				and not (x == city.x and y == city.y)
				and Hex.distance(city.x, city.y, x, y) <= 3
			then
				add(result, { action = "workTile", cityX = city.x, cityY = city.y, x = x, y = y })
			end
		end
	end
end

local function addUnitActions(result, view, playerId, units)
	for _, unit in ipairs(units) do
		if unit.kind == "builder" then
			local player
			for _, candidate in ipairs(view.players or {}) do
				if candidate.id == playerId then
					player = candidate
				end
			end
			if unit.workQueue then
				add(result, { action = "cancelWork", unitID = unit.id, x = unit.x, y = unit.y })
				if unit.workQueue.paused then
					add(result, { action = "resumeWork", unitID = unit.id, x = unit.x, y = unit.y })
				end
			end
			for _, city in ipairs(view.cities or {}) do
				if city.owner == playerId then
					for _, tile in ipairs(Systems.workable(view, city)) do
						for _, kind in ipairs(Works.order) do
							if Works.preview(view, player, unit, kind, tile.x, tile.y, Systems) then
								add(result, {
									action = "queueWork",
									unitID = unit.id,
									x = unit.x,
									y = unit.y,
									tileX = tile.x,
									tileY = tile.y,
									kind = kind,
								})
							end
						end
					end
				end
			end
		end
		add(result, { action = "heal", unitID = unit.id, x = unit.x, y = unit.y })
		add(result, { action = "skipTurn", unitID = unit.id, x = unit.x, y = unit.y })
		add(result, {
			action = "standby",
			unitID = unit.id,
			x = unit.x,
			y = unit.y,
			value = unit.standby ~= true,
		})
		add(result, { action = "cancelRoute", unitID = unit.id, x = unit.x, y = unit.y })
		add(result, { action = "disband", unitID = unit.id, x = unit.x, y = unit.y })
		if unit.kind == "scout" or unit.kind == "explorer" then
			add(result, {
				action = "autoExplore",
				unitID = unit.id,
				x = unit.x,
				y = unit.y,
				value = unit.autoExplore ~= true,
			})
		end
		for _, tile in ipairs(Hex.reachable(view, unit, playerId, Systems)) do
			add(result, {
				action = "move",
				unitID = unit.id,
				sx = unit.x,
				sy = unit.y,
				x = tile.x,
				y = tile.y,
			})
		end
		if unit.kind == "settler" and (unit.movesLeft or 0) > 0 then
			add(result, { action = "found", unitID = unit.id, x = unit.x, y = unit.y })
		end
		if (Systems.units[unit.kind] or {}).engineer and (unit.movesLeft or 0) > 0 then
			for _, tile in ipairs(Hex.neighbours(unit.x, unit.y, view)) do
				if knownTile(view, tile.x, tile.y, playerId) then
					add(result, {
						action = "buildRail",
						unitID = unit.id,
						sx = unit.x,
						sy = unit.y,
						x = tile.x,
						y = tile.y,
					})
				end
			end
		end
	end
	for i, unit in ipairs(units) do
		if unit.escortID then
			add(result, { action = "detachEscort", unitID = unit.id, x = unit.x, y = unit.y })
		else
			for j = i + 1, #units do
				local other = units[j]
				if
					not other.escortID
					and unit.x == other.x
					and unit.y == other.y
					and ((unit.kind == "settler") ~= (other.kind == "settler"))
				then
					add(result, {
						action = "attachEscort",
						unitID = unit.id,
						partnerID = other.id,
						x = unit.x,
						y = unit.y,
					})
				end
			end
		end
	end
end

local function addCityStrikes(result, view, playerId, cities)
	for _, city in ipairs(cities) do
		if (city.maxWalls or 0) > 0 and (city.wallHP or 0) > 0 then
			for _, unit in ipairs(view.units or {}) do
				if unit.owner ~= playerId and Hex.distance(city.x, city.y, unit.x, unit.y) <= 2 then
					add(
						result,
						{ action = "cityStrike", x = city.x, y = city.y, tx = unit.x, ty = unit.y }
					)
				end
			end
		end
	end
end

local function addExchangeEnvoys(result, view, player, playerId)
	if (player.techs or {}).currency and (player.gold or 0) > 0 then
		local market = false
		for _, city in ipairs(view.cities or {}) do
			if city.owner == playerId and (city.buildings or {}).market then
				market = true
			end
		end
		if market then
			local resources = {}
			for id in pairs(Systems.resources or {}) do
				resources[#resources + 1] = id
			end
			table.sort(resources)
			for _, id in ipairs(resources) do
				local record = Systems.resources[id]
				if
					id ~= "horses"
					and id ~= "saltpeter"
					and (not record.tech or (player.techs or {})[record.tech])
				then
					add(result, { action = "exchange", resource = id })
				end
			end
		end
	end
	for _, city in ipairs(view.cities or {}) do
		if
			city.village
			and city.villageOwner == city.owner
			and city.owner ~= playerId
			and (player.gold or 0) >= 25
		then
			add(result, { action = "envoy", x = city.x, y = city.y })
		end
	end
end

local function addDiplomacy(result, view, player, playerId)
	for _, other in ipairs(otherPlayers(view, playerId)) do
		if relationKnown(view, player, playerId, other.id) then
			for _, topic in ipairs({ "greeting", "apologize", "warning", "denounce" }) do
				add(result, { action = "diplomaticTalk", target = other.id, topic = topic })
			end
			local war = warFor(view, playerId, other.id)
			if not war then
				add(result, { action = "declareWar", target = other.id, kind = "normal" })
				add(result, { action = "declareWar", target = other.id, kind = "surprise" })
			end
			for _, kind in ipairs({ "openBorders", "commerce", "alliance", "defensivePact" }) do
				if not activeTreaty(view, playerId, other.id, kind) and not war then
					add(result, {
						action = "diplomaticOffer",
						target = other.id,
						kind = kind,
						terms = { duration = 10 },
					})
				end
			end
			if
				view.council
				and view.council.session
				and view.council.session.status == "voting"
				and councilMember(view, other.id)
			then
				add(result, {
					action = "diplomaticOffer",
					target = other.id,
					kind = "councilSupport",
					terms = { session = view.council.session.id },
				})
			end
			if not war and not activeTreaty(view, playerId, other.id, "withdrawal") then
				add(result, {
					action = "diplomaticOffer",
					target = other.id,
					kind = "withdrawal",
					terms = { by = playerId, duration = 2 },
				})
			end
			if war and not war.endsRound then
				add(result, {
					action = "diplomaticOffer",
					target = other.id,
					kind = "peace",
					terms = { duration = 5 },
				})
			end
			for _, possibleWar in ipairs(view.diplomacy and view.diplomacy.wars or {}) do
				if possibleWar.active then
					local enemy
					if possibleWar.a == playerId then
						enemy = possibleWar.b
					end
					if possibleWar.b == playerId then
						enemy = possibleWar.a
					end
					if
						enemy
						and enemy ~= other.id
						and relationKnown(view, player, playerId, enemy)
					then
						add(result, {
							action = "diplomaticOffer",
							target = other.id,
							kind = "jointWar",
							terms = { duration = 10, enemy = enemy },
						})
					end
				end
			end
		end
	end
	for _, offer in ipairs(view.diplomacy and view.diplomacy.offers or {}) do
		if offer.to == playerId and offer.status == "pending" then
			add(result, { action = "diplomaticReply", offerID = offer.id, response = "accept" })
			add(result, { action = "diplomaticReply", offerID = offer.id, response = "reject" })
			if offer.kind == "trade" then
				add(result, {
					action = "diplomaticCounter",
					offerID = offer.id,
					terms = { duration = 10, gold = 0, requestGold = 1 },
				})
			end
		end
	end
end

local function addCouncil(result, view, playerId)
	local session = view.council and view.council.session
	if not session or session.status ~= "voting" then
		return
	end
	local ownMember
	for _, member in ipairs(session.members or {}) do
		if member.id == playerId and member.alive ~= false then
			ownMember = member
		end
	end
	if ownMember and session.ownElection == nil then
		add(result, { action = "councilVote", session = session.id, candidate = false })
		for _, member in ipairs(session.members or {}) do
			if member.alive ~= false then
				add(result, { action = "councilVote", session = session.id, candidate = member.id })
			end
		end
	end
	for _, resolution in ipairs(session.agenda or {}) do
		if resolution.ownVote == nil then
			add(result, {
				action = "councilVote",
				session = session.id,
				resolution = resolution.id,
				support = true,
			})
			add(result, {
				action = "councilVote",
				session = session.id,
				resolution = resolution.id,
				support = false,
			})
		end
	end
	if session.opensRound == view.round then
		add(result, { action = "councilPropose", session = session.id, kind = "trade" })
		for _, member in ipairs(session.members or {}) do
			if member.alive ~= false then
				for _, kind in ipairs({ "embargo", "censure" }) do
					add(result, {
						action = "councilPropose",
						session = session.id,
						kind = kind,
						target = member.id,
					})
				end
			end
		end
		for _, war in ipairs(view.diplomacy and view.diplomacy.wars or {}) do
			if councilMember(view, war.a) and councilMember(view, war.b) then
				add(result, {
					action = "councilPropose",
					session = session.id,
					kind = "peace",
					target = war.a,
					other = war.b,
				})
			end
		end
	end
end

function Proposals.list(view, playerId)
	local player = ownPlayer(view, playerId)
	assert(player and view.observerID == playerId, "Require the player's own observation")
	local result = {}
	local cities = ownCities(view, playerId)
	local units = ownUnits(view, playerId)
	addResearch(result, player)
	addProduction(result, view, player, playerId, cities)
	addCityWork(result, view, playerId, cities)
	addUnitActions(result, view, playerId, units)
	addCityStrikes(result, view, playerId, cities)
	addExchangeEnvoys(result, view, player, playerId)
	addDiplomacy(result, view, player, playerId)
	addCouncil(result, view, playerId)
	if view.phase ~= "game" then
		return {}
	end
	if not Scheduler.canAct(view, playerId) then
		local responses = {}
		for _, action in ipairs(result) do
			if
				action.action == "diplomaticReply"
				or action.action == "diplomaticCounter"
				or action.action == "councilVote"
				or action.action == "councilPropose"
			then
				responses[#responses + 1] = action
			end
		end
		return responses
	end
	return result
end

return Proposals
