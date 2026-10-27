-- Research adapter; gameplay transitions stay in the installed game's modules.
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Actors = dofile("/games/civcraft/actor_lifecycle.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local World = dofile("/games/civcraft/world.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Metrics = dofile("/lab/metrics.lua")
local Proposals = dofile("/lab/proposals.lua")
local Engine = { version = 1 }

function Engine.newGame(config)
	assert(
		type(config.players) == "table" and #config.players >= 2 and #config.players <= 4,
		"Research games require two to four registered players"
	)
	local state = Lifecycle.newLobby(
		"lab:" .. tostring(config.seed or 12345),
		config.contentRules or "baseline"
	)
	state.mapSeed, state.mapSize, state.mapType =
		config.seed or 12345, config.mapSize or "compact", config.mapType or "continents"
	state.hostileMode = config.hostileMode or "standard"
	local knownSize = false
	for _, size in ipairs(World.sizeOrder) do
		knownSize = knownSize or size == state.mapSize
	end
	assert(knownSize, "Unknown map size")
	assert(
		state.mapType == "continents"
			or state.mapType == "pangaea"
			or state.mapType == "archipelago"
			or state.mapType == "highlands",
		"Unknown map type"
	)
	assert(
		state.hostileMode == "off"
			or state.hostileMode == "standard"
			or state.hostileMode == "dangerous",
		"Unknown hostile mode"
	)
	for index, record in ipairs(config.players) do
		assert(Systems.civ(record.civilization).id == record.civilization, "Unknown civilization")
		assert(
			not record.difficulty
				or Difficulty.id({ aiDifficulty = record.difficulty }) == record.difficulty,
			"Unknown AI difficulty"
		)
		state.players[index] = {
			id = index - 1,
			name = "P" .. index,
			civ = record.civilization,
			ai = record.ai ~= false,
			aiDifficulty = record.difficulty or "prince",
		}
	end
	assert(Rules.configure(state, 0, { action = "gameSpeed", speed = config.speed or "standard" }))
	for id, enabled in pairs(config.victories or {}) do
		assert(
			Rules.configure(state, 0, { action = "toggleVictory", victory = id, enabled = enabled })
		)
	end
	return Lifecycle.initialize(state)
end

function Engine.observe(state, playerId)
	return Presentation.capture(state, playerId)
end

function Engine.legalActions(state, playerId)
	-- Candidates use observer knowledge; this is not an exhaustive legal mask.
	return Proposals.list(Engine.observe(state, playerId), playerId), Proposals.coverage
end

function Engine.legalActionMetadata()
	-- Kept separate from legalActions so existing two-return-value callers stay
	-- compatible while research consumers can inspect the non-exhaustiveness
	-- and unbounded-family limits explicitly.
	return Proposals.coverageMetadata
end

function Engine.applyAction(state, playerId, action)
	return Actions.apply(state, playerId, action, Systems)
end

function Engine.endTurn(state, playerId)
	return Lifecycle.finish(state, playerId)
end

function Engine.advance(state)
	assert(state.phase == "game", "Game not running")
	assert(Scheduler.complete(state), "Players have not completed the round")
	Lifecycle.advance(state)
	Victory.check(state, true)
end

function Engine.pump(state, callbacks)
	Actors.pump(state, callbacks)
end

function Engine.isFinished(state)
	return state.phase == "over"
end

Engine.metrics = Metrics.capture
return Engine
