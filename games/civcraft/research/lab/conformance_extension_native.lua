-- Native CraftOS-PC side of the research-only conformance extension.
-- The Python driver compares these canonical payloads with the Lupa fixture.
local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.dofile = function(path)
	local file = assert(fs.open(path, "r"))
	local source = file.readAll()
	file.close()
	return assert(load(source, "@" .. path, "t", environment))()
end

environment.dofile("/games/civcraft/module_cache.lua").install(environment)
local Engine = environment.dofile("/lab/engine.lua")
local Canonical = environment.dofile("/lab/canonical.lua")
local Fixture = environment.dofile("/lab/conformance_extension_fixture.lua")

local config = {
	seed = 75123,
	mapSize = "compact",
	mapType = "pangaea",
	hostileMode = "off",
	players = {
		{ civilization = "forge", ai = false },
		{ civilization = "scholar", ai = false },
	},
	maxRounds = 4,
}

local function outcome(ok, message, detail)
	return { ok = ok == true, message = message, detail = detail }
end

local function capture(label, state)
	local proposals = Engine.legalActions(state, 0)
	return {
		label = label,
		state = Canonical.encode(state),
		observation0 = Canonical.encode(Engine.observe(state, 0)),
		observation1 = Canonical.encode(Engine.observe(state, 1)),
		proposals0 = Canonical.encode(proposals),
	}
end

local function operations(positions)
	return {
		{
			kind = "action",
			player = 0,
			request = { action = "declareWar", target = 1, kind = "surprise" },
		},
		{ kind = "endTurn", player = 0 },
		{
			kind = "action",
			player = 1,
			request = {
				action = "move",
				sx = positions.target.x,
				sy = positions.target.y,
				x = positions.attacker.x,
				y = positions.attacker.y,
			},
		},
		{ kind = "endTurn", player = 1 },
	}
end

local function execute(state, operation)
	local ok, message, detail
	if operation.kind == "endTurn" then
		ok, message, detail = Engine.endTurn(state, operation.player)
	else
		ok, message, detail = Engine.applyAction(state, operation.player, operation.request)
	end
	return outcome(ok, message, detail)
end

local function run_sequence(state, fixture, traceEnabled)
	local positions = fixture.setupSurprise(state)
	local telemetry
	if traceEnabled then
		telemetry =
			environment.dofile("/lab/telemetry.lua").install({ trace = true, actionBudget = 64 })
	end
	local ops = operations(positions)
	local checkpoints, outcomes = {}, {}
	local responseMovementMarked = false
	local reactionGrantedBeforeHandoff = false
	for index, operation in ipairs(ops) do
		local result = execute(state, operation)
		outcomes[#outcomes + 1] = {
			kind = operation.kind,
			result = result,
		}
		local label = "after-" .. tostring(index - 1) .. "-" .. operation.kind
		checkpoints[#checkpoints + 1] = capture(label, state)
		if operation.kind == "endTurn" and operation.player == 0 then
			reactionGrantedBeforeHandoff = state.scheduler.reactions[1] == true
			Engine.pump(state)
			responseMovementMarked = state.units[2].responseMovementRound == state.round
			checkpoints[#checkpoints + 1] = capture("after-pump-attacker-handoff", state)
		end
	end
	return {
		positions = positions,
		operations = ops,
		outcomes = outcomes,
		checkpoints = checkpoints,
		trace = telemetry and telemetry.trace or {},
		reactionChecks = {
			warActive = state.diplomacy.wars[1].active == true,
			reactionGrantedBeforeHandoff = reactionGrantedBeforeHandoff,
			responseMovementMarkedAfterPump = responseMovementMarked,
			defenderMoveAccepted = outcomes[3].result.ok == true,
			reactionConsumedAfterDefenderFinish = state.scheduler.reactions[1] == nil,
			reactionPathBlocked = not (responseMovementMarked and outcomes[3].result.ok == true),
		},
		finalState = Canonical.encode(state),
	}
end

local function observer_adversarial()
	local state = Engine.newGame(config)
	local before = {
		observation = Canonical.encode(Engine.observe(state, 0)),
		proposals = Canonical.encode(Engine.legalActions(state, 0)),
	}
	local hidden = Fixture.hideRival(state)
	local after = {
		observation = Canonical.encode(Engine.observe(state, 0)),
		proposals = Canonical.encode(Engine.legalActions(state, 0)),
	}
	return { hiddenTile = hidden, before = before, after = after }
end

-- Keep the traced run last: telemetry wraps the shared Actions module in this
-- single CraftOS environment, so earlier untraced replicas cannot pollute it.
local replica = run_sequence(Engine.newGame(config), Fixture, false)
local replay = run_sequence(Engine.newGame(config), Fixture, false)
local primary = run_sequence(Engine.newGame(config), Fixture, true)
local observer = observer_adversarial()

local output = assert(fs.open("/conformance_extension_native.json", "w"))
output.write(textutils.serializeJSON({
	host = _G._HOST,
	observerAdversarial = observer,
	primary = primary,
	replica = replica,
	replay = replay,
}))
output.close()
return true
