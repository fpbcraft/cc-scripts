local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Migration = dofile("/games/civcraft/campaign_migration.lua")
local MachineryAI = dofile("/games/civcraft/ai_machinery.lua")
local StateWriter = dofile("/games/civcraft/state_writer.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Materials = dofile("/games/civcraft/ai_materials.lua")

local function fixture(project, buildings, stockpile)
	local tiles = {}
	for y = 1, 12 do
		for x = 1, 16 do
			tiles[x .. ":" .. y] = "plains"
		end
	end
	local player = {
		id = 1,
		name = "OWNER",
		civ = "forge",
		gold = 100,
		techs = {},
		stockpile = stockpile or {},
	}
	for id in pairs(Systems.techs) do
		player.techs[id] = true
	end
	local city = {
		id = 1,
		owner = 1,
		x = 4,
		y = 4,
		population = 3,
		buildings = buildings or { waterwheel = true, mixer = true, market = true },
		sites = { works = { id = 1, kind = "works", x = 5, y = 4 } },
		project = project,
	}
	local state = {
		version = 6,
		specialtySchema = 1,
		nextSiteId = 3,
		ruleset = "create",
		contentRules = "balance5",
		phase = "game",
		round = 1,
		nextId = 3,
		players = {
			player,
			{ id = 2, name = "RIVAL", civ = "forge", techs = {}, stockpile = {} },
		},
		cities = {
			city,
			{
				id = 2,
				owner = 2,
				x = 12,
				y = 8,
				population = 2,
				buildings = { mixer = true },
				sites = { works = { id = 2, kind = "works", x = 13, y = 8 } },
			},
		},
		units = {},
		world = { width = 16, height = 12, tiles = tiles, resources = {} },
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	return state
end

local function recommend(state)
	local view = World.forPlayer(state, 1)
	return MachineryAI.recommend(view, view.players[1], Systems)
end

local function apply(state, request)
	local accepted, reason = Actions.apply(state, 1, request, Systems)
	assert(accepted, "Dispatcher rejected recommendation: " .. tostring(reason))
end

local function assertNoAdvice(state, message)
	assert(next(recommend(state)) == nil, message)
end

local function hasRequest(requests, action, resource)
	for _, request in ipairs(requests) do
		if request.action == action and (resource == nil or request.resource == resource) then
			return true
		end
	end
	return false
end

local function saveAndReload(state)
	local chunks = {}
	StateWriter.write({
		write = function(chunk)
			chunks[#chunks + 1] = chunk
		end,
	}, state)
	local serialized = table.concat(chunks)
	local saved = assert(load("return " .. serialized, "machinery-save", "t", {}))()
	return assert(Migration.load(saved))
end

local brassProject = { kind = "unit", id = "brassengineer", progress = 0 }
local state = fixture(brassProject, nil, { copper = 1, zinc = 1 })
local request = recommend(state)
assert(request.action == "selectMachineRecipe" and request.recipe == "brass")
local repeated = recommend(state)
assert(repeated.action == request.action and repeated.recipe == request.recipe)
assert(
	not Actions.apply(state, 2, request, Systems),
	"A rival must not apply the owner recommendation"
)

-- Dispatcher acceptance and a migration-backed save/replay preserve the result.
local replay = saveAndReload(state)
apply(state, request)
apply(replay, request)
assert(state.cities[1].machines.mixer.recipe == "brass")
assert(replay.cities[1].machines.mixer.recipe == "brass")
assertNoAdvice(state, "An active brass plan must remain stable until resolution")
state.cities[1].project = nil
replay.cities[1].project = nil
local nextRequest = recommend(state)
local replayRequest = recommend(replay)
assert(nextRequest.action == replayRequest.action and nextRequest.recipe == replayRequest.recipe)
apply(state, nextRequest)
apply(replay, replayRequest)
assert(state.cities[1].machines.mixer.recipe == replay.cities[1].machines.mixer.recipe)
assertNoAdvice(state, "Applied choices must settle without turn-by-turn churn")

-- A city with a non-brass project uses Mixer industry; an idle city leaves it off.
local industry = fixture({ kind = "unit", id = "warrior", progress = 0 })
request = recommend(industry)
assert(request.action == "selectMachineRecipe" and request.recipe == "industry")
local repeatedIndustry = recommend(industry)
assert(
	repeatedIndustry.action == request.action and repeatedIndustry.recipe == request.recipe,
	"An unapplied industry recommendation must remain stable"
)
apply(industry, request)
assertNoAdvice(industry, "An active industry plan must remain selected while its project needs it")
industry.cities[1].project = nil
request = recommend(industry)
assert(request.action == "selectMachineRecipe" and request.recipe == "no_recipe")
apply(industry, request)
assertNoAdvice(industry, "An idle mixer must settle at no_recipe")

-- Continuous civilian projects consume industry through their canonical divisor.
-- Their progress field is not a finite completion cost.
for _, id in ipairs({ "ponder", "trade", "tend" }) do
	local buildings = {
		waterwheel = true,
		mixer = true,
		market = true,
		library = true,
		farm = true,
		housing = true,
	}
	local projectState = fixture({ kind = "project", id = id, progress = 100 }, buildings)
	local projectPlayer, projectCity = projectState.players[1], projectState.cities[1]
	if id == "ponder" then
		projectPlayer.techs.agriculture = nil
		projectPlayer.researchTarget = "agriculture"
	end
	local definition = Systems.projects[id]
	projectCity.projectRemainders = { [id] = definition.divisor - 1 }
	assert(Systems.canProject(projectPlayer, projectCity, id), id)
	request = recommend(projectState)
	assert(
		request.action == "selectMachineRecipe" and request.recipe == "industry",
		"A valid continuous project must keep Mixer industry useful: " .. id
	)
	apply(projectState, request)
	local projectView = World.forPlayer(projectState, 1)
	local plan = Systems.machineForecast(projectView, 1).plan
	local industryYield = (plan.effects[projectCity.id] or {}).industry or 0
	local conversion = Systems.projectPreview(projectPlayer, projectCity, id, projectView, {
		industry = industryYield,
	})
	assert(conversion.active and conversion[definition.output] > 0)
	assert(
		conversion.remainder == (industryYield + definition.divisor - 1) % definition.divisor,
		"The canonical conversion must preserve its fractional remainder"
	)
	assertNoAdvice(projectState, "Continuous project industry should converge: " .. id)

	if id == "ponder" then
		projectPlayer.researchTarget = nil
	else
		projectCity.project = nil
	end
	request = recommend(projectState)
	assert(request.action == "selectMachineRecipe" and request.recipe == "no_recipe")
	apply(projectState, request)
	assertNoAdvice(
		projectState,
		"Inactive continuous projects must stop consuming industry: " .. id
	)
end

local invalidProject = fixture({ kind = "project", id = "missing", progress = 0 })
invalidProject.cities[1].machines.mixer.recipe = "industry"
request = recommend(invalidProject)
assert(request.action == "selectMachineRecipe" and request.recipe == "no_recipe")

-- Missing inputs block brass selection until recovery; the helper never purchases inputs.
local shortage = fixture(brassProject, nil, { copper = 1 })
request = recommend(shortage)
assert(request.action == "selectMachineRecipe" and request.recipe ~= "brass")
apply(shortage, request)
shortage.players[1].stockpile.zinc = 1
request = recommend(shortage)
assert(request.action == "selectMachineRecipe" and request.recipe == "brass")

-- Output cap and exhausted demand select a productive alternative or stop the mixer.
local capped = fixture(brassProject, nil, { copper = 1, zinc = 1, brass = 10 })
capped.cities[1].machines.mixer.recipe = "brass"
request = recommend(capped)
assert(request.action == "selectMachineRecipe" and request.recipe == "industry")
local full = fixture(nil, nil, { copper = 1, zinc = 1 })
full.cities[1].machines.mixer.recipe = "brass"
request = recommend(full)
assert(request.action == "selectMachineRecipe" and request.recipe == "no_recipe")

-- Re-enable a deliberately idle machine only when its projected operation serves a need.
local disabled = fixture(brassProject, nil, { copper = 1, zinc = 1 })
disabled.cities[1].machines.mixer.enabled = false
request = recommend(disabled)
assert(request.action == "setMachineEnabled" and request.enabled == true)
local repeatedEnable = recommend(disabled)
assert(repeatedEnable.action == request.action and repeatedEnable.enabled == request.enabled)
apply(disabled, request)
request = recommend(disabled)
assert(request.action == "selectMachineRecipe" and request.recipe == "brass")
local repeatedEnabledRecipe = recommend(disabled)
assert(
	repeatedEnabledRecipe.action == request.action
		and repeatedEnabledRecipe.recipe == request.recipe
)
apply(disabled, request)
assertNoAdvice(disabled, "An enabled brass operation must converge")
local disabledIdle = fixture(nil, nil, { copper = 1, zinc = 1 })
disabledIdle.cities[1].machines.mixer.enabled = false
assertNoAdvice(disabledIdle, "An idle disabled mixer stays off")

-- Steam uses coal only for a runnable need; production recovers when fuel returns.
local steam = fixture({ kind = "unit", id = "warrior", progress = 0 }, {
	mixer = true,
	steamplant = true,
}, {})
assertNoAdvice(steam, "No-fuel operation must not trigger a recipe order")
steam.players[1].stockpile.coal = 1
request = recommend(steam)
assert(request.action == "selectMachineRecipe" and request.recipe == "industry")

-- Prioritize a genuinely useful mixer only when that order makes it runnable.
local constrained = fixture(brassProject, {
	waterwheel = true,
	press = true,
	mixer = true,
}, { copper = 1, zinc = 1 })
request = recommend(constrained)
assert(request.action == "setMachinePriority" and request.priority == 1)
local repeatedPriority = recommend(constrained)
assert(repeatedPriority.action == request.action and repeatedPriority.priority == request.priority)
apply(constrained, request)
request = recommend(constrained)
assert(request.action == "selectMachineRecipe" and request.recipe == "brass")
local repeatedPriorityRecipe = recommend(constrained)
assert(
	repeatedPriorityRecipe.action == request.action
		and repeatedPriorityRecipe.recipe == request.recipe
)
apply(constrained, request)
assertNoAdvice(constrained, "A prioritized brass operation must converge")

-- Match the dispatcher gates so the policy does not suggest rejected game actions.
local lobby = fixture(brassProject, nil, { copper = 1, zinc = 1 })
lobby.phase = "lobby"
assertNoAdvice(lobby, "Lobby observations do not permit machine orders")
local endedTurn = fixture(brassProject, nil, { copper = 1, zinc = 1 })
endedTurn.players[1].ready = true
assertNoAdvice(endedTurn, "An ended-turn player cannot receive ordinary machine orders")

-- Rival private stocks and settings cannot affect an owner's recommendation.
local private = fixture(brassProject, nil, { copper = 1, zinc = 1 })
local before = recommend(private)
private.players[2].stockpile.brass = 10
private.cities[2].machines.mixer.recipe = "brass"
private.cities[2].machines.mixer.priority = 1
local after = recommend(private)
assert(before.action == after.action and before.recipe == after.recipe)

-- The AI entrypoint imports Mixer inputs only for a current, feasible brass use.
local imports = fixture(nil, nil, {})
local view = World.forPlayer(imports, 1)
local requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc and not hasRequest(requests, "exchange"))
imports.cities[1].project = { kind = "unit", id = "brassengineer", progress = 0 }
view = World.forPlayer(imports, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(targets.copper == 1 and targets.zinc == 1 and targets.brass == nil)
assert(hasRequest(requests, "exchange", "copper") and hasRequest(requests, "exchange", "zinc"))
assert(not hasRequest(requests, "exchange", "brass"))
AI.materials(imports, imports.players[1], Systems)
assert(imports.players[1].stockpile.copper == 1 and imports.players[1].stockpile.zinc == 1)
assert(imports.players[1].stockpile.brass == nil or imports.players[1].stockpile.brass == 0)
view = World.forPlayer(imports, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc and not targets.brass)
assert(
	not hasRequest(requests, "exchange"),
	"Feasible Mixer output suppresses repeat input imports"
)
local importedAdvice = recommend(imports)
assert(importedAdvice.action == "selectMachineRecipe" and importedAdvice.recipe == "brass")
local importReplay = saveAndReload(imports)
assert(AI.machinery(imports, imports.players[1], Systems))
assert(AI.machinery(importReplay, importReplay.players[1], Systems))
assert(imports.cities[1].machines.mixer.recipe == "brass")
assert(importReplay.cities[1].machines.mixer.recipe == "brass")
assert(not AI.machinery(imports, imports.players[1], Systems), "Machine decisions must converge")

local privacy = fixture(brassProject, nil, {})
view = World.forPlayer(privacy, 1)
local privateRequests = Materials.orders(view, view.players[1], Systems)
privacy.players[2].stockpile.copper = 0
privacy.cities[2].machines.mixer.recipe = "brass"
privacy.cities[2].machines.mixer.priority = 1
view = World.forPlayer(privacy, 1)
local publicRequests = Materials.orders(view, view.players[1], Systems)
assert(#privateRequests == #publicRequests)
for index, request in ipairs(privateRequests) do
	assert(
		request.action == publicRequests[index].action
			and request.resource == publicRequests[index].resource,
		"Rival private data must not change import orders"
	)
end

local disabledInputs = fixture(brassProject, nil, {})
disabledInputs.cities[1].machines.mixer.enabled = false
view = World.forPlayer(disabledInputs, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc)
assert(
	not hasRequest(requests, "exchange", "copper") and not hasRequest(requests, "exchange", "zinc")
)
assert(targets.brass == 2 and hasRequest(requests, "exchange", "brass"))

local inactiveInputs = fixture(brassProject, { mixer = true, market = true }, {})
inactiveInputs.cities[1].sites.works = nil
view = World.forPlayer(inactiveInputs, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc)
assert(
	not hasRequest(requests, "exchange", "copper") and not hasRequest(requests, "exchange", "zinc")
)
assert(hasRequest(requests, "exchange", "brass"), "Inactive works retains lawful direct import")

local underpoweredInputs = fixture(brassProject, { mixer = true, market = true }, {})
view = World.forPlayer(underpoweredInputs, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc)
assert(
	not hasRequest(requests, "exchange", "copper") and not hasRequest(requests, "exchange", "zinc")
)
assert(hasRequest(requests, "exchange", "brass"), "Unavailable power retains lawful direct import")
local unfueledInputs = fixture(brassProject, { mixer = true, steamplant = true, market = true }, {})
view = World.forPlayer(unfueledInputs, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc)
assert(
	not hasRequest(requests, "exchange", "copper") and not hasRequest(requests, "exchange", "zinc")
)
assert(hasRequest(requests, "exchange", "brass"), "Missing fuel retains lawful direct import")

local cappedInputs = fixture(brassProject, nil, { copper = 0, zinc = 0, brass = 10 })
view = World.forPlayer(cappedInputs, 1)
requests, targets = Materials.orders(view, view.players[1], Systems)
assert(not targets.copper and not targets.zinc)
assert(
	not hasRequest(requests, "exchange", "copper") and not hasRequest(requests, "exchange", "zinc")
)

-- The actual machinery entrypoint stops after a dispatcher rejection.
local rejected = fixture(brassProject, nil, { copper = 1, zinc = 1 })
local realApply, calls = Actions.apply, 0
Actions.apply = function()
	calls = calls + 1
	return false, "injected rejection"
end
assert(not AI.machinery(rejected, rejected.players[1], Systems))
Actions.apply = realApply
assert(calls == 1 and rejected.cities[1].machines.mixer.recipe == "no_recipe")

local gate = fixture(brassProject, nil, { copper = 1, zinc = 1 })
gate.players[1].ready = true
calls = 0
Actions.apply = function()
	calls = calls + 1
	return false, "must not be called"
end
assert(not AI.machinery(gate, gate.players[1], Systems))
Actions.apply = realApply
assert(calls == 0, "The actual AI entrypoint must honor ordinary action gates")

local staged = fixture(brassProject, { mixer = true, waterwheel = true }, { copper = 1, zinc = 1 })
staged.cities[1].machines.mixer.enabled = false
assert(AI.machinery(staged, staged.players[1], Systems))
assert(
	staged.cities[1].machines.mixer.enabled and staged.cities[1].machines.mixer.recipe == "brass",
	"The dispatcher path must converge through enable and recipe actions"
)
local stagedPriority = fixture(brassProject, {
	waterwheel = true,
	press = true,
	mixer = true,
}, { copper = 1, zinc = 1 })
assert(AI.machinery(stagedPriority, stagedPriority.players[1], Systems))
assert(
	stagedPriority.cities[1].machines.mixer.priority == 1
		and stagedPriority.cities[1].machines.mixer.recipe == "brass",
	"The dispatcher path must converge through priority and recipe actions"
)
assert(not AI.machinery(stagedPriority, stagedPriority.players[1], Systems))
print("CIVCRAFT: bounded owner-only machinery AI recommendations and replay passed")
