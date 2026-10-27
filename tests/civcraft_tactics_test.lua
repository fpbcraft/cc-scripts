local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Actions = dofile("/games/civcraft/actions.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Campaigns = dofile("/games/civcraft/ai_campaigns.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Tactics = dofile("/games/civcraft/ai_tactics.lua")
local Threats = dofile("/games/civcraft/threats.lua")
local UI = dofile("/games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local World = dofile("/games/civcraft/world.lua")

local function fixture()
	local world = {
		width = 18,
		height = 12,
		seed = 21,
		tiles = {},
		resources = {},
		landmarks = {},
		rails = {},
	}
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local player = { id = 1, name = "ONE", civ = "iron", techs = {}, gold = 1000, ai = true }
	local state = {
		version = 6,
		campaignID = "tactics",
		phase = "game",
		ruleset = "create",
		round = 1,
		players = { player, { id = 2, name = "TWO", civ = "forge", techs = {} } },
		world = world,
		nextId = 40,
		cities = {
			{ id = 1, owner = 1, capitalOf = 1, x = 3, y = 5, population = 2, buildings = {} },
		},
		units = {},
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	for y = 1, 12 do
		for x = 1, 18 do
			player.explored[World.key(x, y)], player.visible[World.key(x, y)] = true, true
		end
	end
	AI.beginTurn(state, player)
	return state, player
end

local state, player = fixture()
state.units = {
	{
		id = 3,
		owner = 1,
		kind = "archer",
		x = 6,
		y = 5,
		movesLeft = 2,
		hp = 100,
		aiRole = { name = "ranged" },
	},
	{ id = 4, owner = 2, kind = "warrior", x = 8, y = 5, movesLeft = 2, hp = 10 },
	{ id = 5, owner = 2, kind = "golem", x = 10, y = 5, movesLeft = 2, hp = 100 },
}
Systems.migrate(state)
player.aiPlan.campaign = { kind = "city", phase = "approach", x = 12, y = 5 }
local attacker = state.units[1]
local options = Tactics.ranked(AI.knowledge(state, player), player, attacker, Systems)
local chosen = options[1]
assert(
	chosen.forecast
		and chosen.forecast.ranged
		and chosen.request.x == 8
		and chosen.forecast.defenderDied
)
assert(#options <= Tactics.maxCandidates + 1)
assert(Actions.apply(state, player.id, chosen.request, Systems))
assert(attacker.hp == chosen.forecast.attackerHP and #state.units == 2)
assert(attacker.x == 6 and attacker.y == 5, "Ranged focus fire never teleports the attacker")

state, player = fixture()
state.units = {
	{
		id = 3,
		owner = 1,
		kind = "warrior",
		x = 6,
		y = 5,
		movesLeft = 2,
		hp = 15,
		aiRole = { name = "mainArmy" },
	},
	{ id = 4, owner = 2, kind = "golem", x = 7, y = 5, movesLeft = 2, hp = 100 },
}
Systems.migrate(state)
player.aiPlan.campaign = { kind = "city", phase = "approach", x = 7, y = 5 }
attacker = state.units[1]
local map = Threats.build(AI.knowledge(state, player), player, Systems)
local current = Threats.at(map, attacker.x, attacker.y, attacker)
chosen = Tactics.ranked(AI.knowledge(state, player), player, attacker, Systems)[1]
assert(chosen.request.action == "move" and not chosen.forecast)
assert(
	chosen.risk.damage < current.damage
		and Hex.distance(chosen.request.x, chosen.request.y, 3, 5) < 3
)
assert(AI.military(state, player, attacker, Systems) and attacker.hp == 15)
assert(
	Hex.distance(attacker.x, attacker.y, 3, 5) < 3,
	"A damaged unit withdraws instead of making a lethal attack"
)

-- The same visible target produces the same decision regardless of a concealed army.
state, player = fixture()
state.units = {
	{ id = 3, owner = 1, kind = "warrior", x = 4, y = 5, movesLeft = 2, hp = 100 },
	{ id = 4, owner = 2, kind = "golem", x = 7, y = 5, movesLeft = 2, hp = 100 },
}
Systems.migrate(state)
player.visible["7:5"] = nil
map = Threats.build(state, player, Systems)
assert(#map.entries == 0 and Threats.at(map, 6, 5, state.units[1]).damage == 0)
player.visible["7:5"] = true
local view = AI.knowledge(state, player)
Threats.remember(view, player, Systems)
assert(#player.aiPlan.knownThreats == 1 and player.aiPlan.knownThreats[1].x == 7)
assert(Threats.at(Threats.build(view, player, Systems), 6, 5, state.units[1]).attackers == 1)
player.visible["7:5"], player.visible["16:10"] = nil, nil
state.units[2].x, state.units[2].y = 16, 10
state.round = 2
view = AI.knowledge(state, player)
Threats.remember(view, player, Systems)
assert(player.aiPlan.knownThreats[1].x == 7 and player.aiPlan.knownThreats[1].round == 1)
assert(#Threats.build(view, player, Systems).entries == 0)
assert(
	Threats.uncertainty(player, 7, 5, 2) > 0,
	"Remembered uncertainty is separate from confirmed human danger"
)
state.round = 6
Threats.remember(AI.knowledge(state, player), player, Systems)
assert(#player.aiPlan.knownThreats == 0)

state, player = fixture()
state.cities[2] = {
	id = 2,
	owner = 2,
	capitalOf = 2,
	x = 12,
	y = 5,
	population = 2,
	buildings = { walls = true },
}
for i = 1, 4 do
	state.units[i] =
		{ id = i + 3, owner = 1, kind = "warrior", x = i + 2, y = 6, movesLeft = 2, hp = 100 }
end
Systems.migrate(state)
view = AI.knowledge(state, player)
local roles = Campaigns.update(view, player, Systems)
local campaign = player.aiPlan.campaign
assert(campaign.kind == "city" and campaign.phase == "muster" and campaign.needsSiege)
assert(roles[4].name == "garrison" and roles[5].name == "mainArmy" and #campaign.corridor > 0)
local group = campaign.groupID
player.visible["12:5"] = nil
state.cities[2].owner, state.cities[2].x = 3, 15
player.visible["15:5"] = nil
state.round = 2
Campaigns.update(AI.knowledge(state, player), player, Systems)
campaign = player.aiPlan.campaign
assert(
	campaign.groupID == group
		and campaign.x == 12
		and campaign.owner == 2
		and campaign.seenRound == 1
)
assert(campaign.needsSiege, "A remembered fortified objective retains its last observed wall state")
player.techs.engineering = true
local candidates = Production.ranked(
	AI.knowledge(state, player),
	player,
	AI.knowledge(state, player).cities[1],
	Systems,
	false
)
local siege
for _, choice in ipairs(candidates) do
	if choice.id == "catapult" then
		siege = choice
	end
end
assert(
	siege and siege.score > 0,
	"Fortified objectives request siege even when ordinary army quotas are filled"
)

-- A healer values useful support positions; independent village guards stay neutral.
state, player = fixture()
state.cities[2] = { id = 2, owner = 1, x = 8, y = 5, population = 2, buildings = {} }
state.units = {
	{
		id = 3,
		owner = 1,
		kind = "alchemist",
		x = 5,
		y = 5,
		movesLeft = 2,
		hp = 100,
		aiRole = { name = "healer" },
	},
	{ id = 4, owner = 1, kind = "warrior", x = 7, y = 5, movesLeft = 2, hp = 40 },
	{ id = 5, owner = -100, kind = "spearman", x = 6, y = 7, villageGuard = 9, hp = 100 },
}
Systems.migrate(state)
player.aiPlan.campaign = { kind = "defense", phase = "defend", x = 7, y = 5 }
chosen = Tactics.ranked(AI.knowledge(state, player), player, state.units[1], Systems)[1]
assert(
	chosen.request.action == "move" and Hex.distance(chosen.request.x, chosen.request.y, 7, 5) <= 1
)
assert(#Threats.build(AI.knowledge(state, player), player, Systems).entries == 0)
for _, graphics in ipairs({ false, true }) do
	state, player = fixture()
	state.units = {
		{ id = 3, owner = 1, kind = "warrior", x = 4, y = 5, movesLeft = 2, hp = 100 },
		{ id = 4, owner = 2, kind = "golem", x = 7, y = 5, movesLeft = 2, hp = 100 },
	}
	Systems.migrate(state)
	player.visible["7:5"] = nil
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 720, 603
			end
			return 120, 67
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
	else
		monitor.setCursorPos = function() end
		monitor.setBackgroundColor = function() end
		monitor.setTextColor = function() end
		monitor.write = function() end
	end
	local ui = UI.new(monitor, function()
		error("Danger preview must not dispatch")
	end)
	ui:draw(AI.knowledge(state, player), 1, { screen = "game" })
	ui:focus("unit", state.units[1])
	ui.source = { x = 4, y = 5 }
	ui.reachable = Hex.reachable(ui.state, ui.state.units[1], 1, Systems)
	ui:draw(AI.knowledge(state, player), 1, { screen = "game" })
	assert(not ui.destinationThreats["6:5"], "A hidden enemy cannot cause a human danger marker")
	player.visible["7:5"] = true
	ui:draw(AI.knowledge(state, player), 1, { screen = "game" })
	assert(ui.destinationThreats["6:5"] and ui.destinationThreats["6:5"].damage > 0)
	ui:tile(6, 5)
	assert(ui.pendingMove.risk and ui.notice:find("THREAT", 1, true))
	ui:close()
end
print(
	"CIVCRAFT: exact forecast tactics, retreat, visibility-limited threats, persistent campaigns, siege demand and support passed."
)
