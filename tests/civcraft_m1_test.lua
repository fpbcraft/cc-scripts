local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local W = dofile("/games/civcraft/world.lua")
local H = dofile("/games/civcraft/hex.lua")
local C = dofile("/games/civcraft/combat.lua")
local R = dofile("/games/civcraft/campaign_rules.lua")
local CR = dofile("/games/civcraft/content_rules.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local V = dofile("/games/civcraft/victory.lua")
local E = dofile("/games/civcraft/encyclopedia.lua")
local Strategy = dofile("/games/civcraft/ai_strategy.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local function fixture(version)
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = version,
		phase = "game",
		round = 1,
		victoryRulesVersion = 2,
		nextId = 5,
		players = {
			{ id = 0, name = "A", civ = "forge", techs = {}, gold = 100 },
			{ id = 1, name = "B", civ = "scholar", techs = {}, gold = 100 },
		},
		cities = {
			{
				id = 1,
				x = 4,
				y = 5,
				owner = 0,
				capitalOf = 0,
				population = 2,
				foodStore = 100,
				buildings = {},
			},
			{
				id = 2,
				x = 14,
				y = 5,
				owner = 1,
				capitalOf = 1,
				population = 2,
				foodStore = 100,
				buildings = {},
			},
		},
		units = {},
		diplomacy = Diplomacy.new(),
		world = { width = 20, height = 14, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 14 do
		for x = 1, 20 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	return state, state.players[1], state.cities[1]
end
local state, p, city = fixture("balance1")
assert(state.roundLimit == 250 and p.contentRules == "balance5")
assert(CR.usesP1Economy(state) and CR.hasSpecialties(state))
assert(S.projectCost("unit", "scout", p) == 15 and S.projectCost("unit", "settler", p) == 28)
assert(not S.canBuild(p, city, "farm", state))
city.buildings.library = true
assert(S.canProject(p, city, "ponder"))
p.techs.commerce = true
city.buildings.market = true
assert(not S.canBuild(p, city, "councilhall", state))
assert(
	not R.enabled(state, "industrial")
		and not R.enabled(state, "diplomatic")
		and R.enabled(state, "score")
)
state.victories = { industrial = true, diplomatic = true, score = false }
assert(
	not R.enabled(state, "industrial")
		and not R.enabled(state, "diplomatic")
		and R.enabled(state, "score")
)
local lobby = Lifecycle.newLobby("m1", "balance1")
lobby.players = { { id = 0 } }
assert(lobby.roundLimit == 250)
assert(R.configure(lobby, 0, { action = "gameSpeed", speed = "quick" }) and lobby.roundLimit == 167)
assert(R.configure(lobby, 0, { action = "gameSpeed", speed = "epic" }) and lobby.roundLimit == 375)
assert(
	not R.configure(lobby, 0, { action = "contentRules", version = "p1" })
		and lobby.roundLimit == 375
)
assert(
	not R.configure(lobby, 0, { action = "contentRules", version = "balance1" })
		and lobby.roundLimit == 375
)
assert(
	not R.configure(lobby, 0, { action = "toggleVictory", victory = "diplomatic", enabled = true })
)
assert(not R.configure(lobby, 0, { action = "toggleVictory", victory = "score", enabled = false }))
local old = fixture("p1")
old.gameSpeed = "quick"
old.roundLimit = nil
S.migrate(old)
assert(old.roundLimit == 167, "Old saves normalize to the current selected-speed deadline")
-- Removed routes cannot terminate a new campaign, even with injected old progress.
p.industryTurns = 999
p.techs.commerce = true
city.buildings.councilhall = true
state.council = { victory = { id = 0, round = 1 } }
V.check(state, false)
assert(state.phase == "game")
state.round = 249
V.check(state, false)
assert(state.phase == "game")
state.round = 250
V.check(state, false)
assert(state.phase == "over" and state.victoryReason:find("SCORE", 1, true))
state, p, city = fixture("balance1")
city.buildings.dragon = true
V.check(state, false)
assert(state.victoryReason == "END EXPEDITION")
state = fixture("balance1")
state.cities[2].owner = 0
V.check(state, false)
assert(state.victoryReason == "CONQUEST")
state, p = fixture("p1")
p.industryTurns = 999
V.check(state, false)
assert(state.phase == "game", "Old profile IDs cannot enable retired Industrial victory")
state, p, city = fixture("p1")
p.techs.commerce = true
city.buildings.councilhall = true
state.council = { victory = { id = 0, round = 1 } }
V.check(state, false)
assert(state.phase == "game", "Old profile IDs cannot enable retired Diplomatic victory")
-- Each territory class, with no support, one/two supporters, action use, and HP caps.
local checks = 0
for _, territory in ipairs({ "owned", "neutral", "friendly", "enemy" }) do
	for _, supporters in ipairs({ 0, 1, 2 }) do
		for _, acted in ipairs({ false, true }) do
			for _, hp in ipairs({ 40, 99 }) do
				state = fixture("balance1")
				local x, y =
					territory == "owned" and 4 or territory == "neutral" and 9 or 14,
					territory == "neutral" and 12 or 5
				if territory == "enemy" then
					state.diplomacy.wars = { { a = 0, b = 1, active = true } }
				end
				if territory == "friendly" then
					state.diplomacy.treaties = {
						{
							a = 0,
							b = 1,
							kind = "openBorders",
							status = "active",
							startsRound = 1,
							endsRound = 10,
						},
					}
				end
				local unit = {
					id = 10,
					owner = 0,
					kind = "warrior",
					x = x,
					y = y,
					hp = hp,
					actedThisRound = acted,
					healing = true,
				}
				state.units = { unit }
				for i = 1, supporters do
					state.units[#state.units + 1] =
						{ id = 10 + i, owner = 0, kind = "alchemist", x = x, y = y, hp = 100 }
				end
				local rates = { owned = 20, neutral = 10, friendly = 15, enemy = 5 }
				local amount = acted and 0 or rates[territory] + (supporters > 0 and 10 or 0)
				assert(C.restRecovery(state, unit, S).total == amount, territory)
				C.round(state, S)
				assert(
					unit.hp == math.min(100, hp + amount),
					territory .. " healing must match its forecast"
				)
				checks = checks + 1
			end
		end
	end
end
-- Support must be independent of unit-array order and cannot heal an acting ally.
for _, reverse in ipairs({ false, true }) do
	state = fixture("balance1")
	local target = {
		id = 10,
		owner = 0,
		kind = "warrior",
		x = 9,
		y = 12,
		hp = 40,
		actedThisRound = true,
		healing = true,
	}
	local healer = { id = 11, owner = 0, kind = "alchemist", x = 9, y = 11, hp = 40 }
	state.units = reverse and { healer, target } or { target, healer }
	C.round(state, S)
	assert(target.hp == 40 and healer.hp == 50)
end
state = fixture("balance1")
state.units = { { id = 10, owner = -2147483647, kind = "settler", x = 9, y = 12, hp = 40 } }
C.round(state, S)
assert(state.units[1].hp == 40)
for _, version in ipairs({ false, "p1" }) do
	state = fixture(version or nil)
	state.units =
		{ { id = 10, owner = 0, kind = "warrior", x = 9, y = 12, hp = 40, healing = true } }
	C.round(state, S)
	assert(state.units[1].hp == 50, "Historical IDs migrate to current neutral rest recovery")
end
state = fixture("balance1")
state.diplomacy.wars = { { a = 0, b = 1, active = true } }
state.cities[2].claimed[W.key(11, 5)] = true
state.units = { { id = 10, owner = 0, kind = "warrior", x = 11, y = 5, hp = 40 } }
W.reveal(state, H, S)
local observed = W.forPlayer(state, 0, H, S)
assert(
	C.restRecovery(observed, state.units[1], S).total
		== C.restRecovery(state, state.units[1], S).total,
	"Recovery forecasts use observed border ownership even when the claiming city is hidden"
)
state, p, city = fixture("balance1")
W.reveal(state, H, S)
local view = W.forPlayer(state, 0, H, S)
local plan = Strategy.review(view, p, 123)
assert(plan.primary ~= "industrial" and plan.primary ~= "diplomatic")
plan.primary = "industrial"
plan.lastReviewRound = state.round
assert(
	Strategy.review(view, p, 123).primary ~= "industrial",
	"Saved disabled goals must be reviewed immediately"
)
local text = table.concat(E.describe("mechanics", { id = "turns", text = "old" }, p, state), " ")
assert(text:find("250", 1, true) and text:find("retired", 1, true))
text = table.concat(E.describe("mechanics", { id = "health", text = "old" }, p, state), " ")
assert(text:find("15", 1, true) and text:find("do not stack", 1, true))
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/m1-save-validation"
	city.buildings.library = true
	p.researchTarget = "mining"
	city.project = { kind = "project", id = "ponder" }
	city.projectRemainders = { ponder = 2 }
	state.units = { { id = 10, owner = 0, kind = "warrior", x = 9, y = 12, hp = 40 } }
	assert(Saves.writeFile(Saves.path(1), state))
	local loaded = S.migrate(assert(Saves.load(1)))
	assert(
		loaded.contentRules == "balance1"
			and loaded.roundLimit == 250
			and loaded.cities[1].projectRemainders.ponder == 2
	)
	assert(not R.enabled(loaded, "industrial") and R.enabled(loaded, "score"))
	C.round(state, S)
	C.round(loaded, S)
	assert(
		state.units[1].hp == 50 and loaded.units[1].hp == 50,
		"New recovery survives actual save/load"
	)
end
print(
	"PASS: M1 campaign scope, legacy compatibility, AI goals, help, save/load and "
		.. checks
		.. " recovery boundaries"
)
