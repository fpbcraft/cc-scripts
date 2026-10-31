-- Authoritative actor ordering; callbacks belong to the UI or research adapter.
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local CouncilAI = dofile("/games/civcraft/council_ai.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local QueuedRoutes = dofile("/games/civcraft/queued_routes.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Reports = dofile("/games/civcraft/reports.lua")
local WorkQueue = dofile("/games/civcraft/queued_work.lua")
local Actors = {}

function Actors.pump(state, callbacks)
	callbacks = callbacks or {}
	if state.phase ~= "game" then
		return
	end
	for _ = 1, #state.players do
		local ranAI = false
		for _, participant in ipairs(state.players) do
			if participant.ai then
				Systems.diplomaticResponses(state, participant)
				if
					state.council
					and state.council.session
					and state.council.session.status == "voting"
				then
					CouncilAI.run(state, participant, Presentation.capture(state, participant.id))
				end
			end
			if Scheduler.canAct(state, participant.id) then
				for _, unit in ipairs(state.units) do
					if
						unit.owner == participant.id and state.scheduler.reactions[participant.id]
					then
						MovementBudget.response(
							state,
							unit,
							Systems.units[unit.kind] or Systems.units.warrior,
							participant,
							Hex
						)
					end
					if
						unit.owner == participant.id
						and unit.autoExplore
						and not unit.standby
						and unit.autoExploreRound ~= state.round
					then
						unit.autoExploreRound = state.round
						Systems.autoExplore(state, unit, Hex)
					end
				end
				-- Allowances already exist; queued orders can only spend those budgets.
				QueuedRoutes.run(state, participant.id, Systems, Actions.apply)
				if not participant.ai then
					WorkQueue.planAuto(state, participant.id, Systems, Actions.apply)
				end
				WorkQueue.run(state, participant.id, Systems, Actions.apply)
				if participant.ai then
					if not participant.ready then
						participant.turnBaseline = Reports.capture(state, participant)
					end
					if callbacks.before then
						callbacks.before(state, participant)
					end
					Systems.aiTurn(state, participant, Hex)
					if callbacks.after then
						callbacks.after(state, participant)
					end
					ranAI = true
				end
			end
		end
		if not ranAI then
			break
		end
	end
end

return Actors
