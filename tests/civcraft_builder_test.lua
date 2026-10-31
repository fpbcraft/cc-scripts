local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local H = dofile("/games/civcraft/hex.lua")
local W = dofile("/games/civcraft/world.lua")
local A = dofile("/games/civcraft/actions.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local Queue = dofile("/games/civcraft/queued_work.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local function fixture()
	local state = {
		version = 6,
		ruleset = "create",
		contentRules = "balance3",
		phase = "game",
		logs = {},
		round = 1,
		nextId = 20,
		players = {
			{
				id = 0,
				name = "OAK",
				civ = "verdant",
				techs = { agriculture = true, mining = true, crafting = true },
				gold = 100,
			},
			{ id = 1, name = "IRON", civ = "iron", techs = {}, gold = 100 },
		},
		cities = {
			{
				id = 1,
				owner = 0,
				x = 4,
				y = 4,
				population = 2,
				buildings = {},
				worked = {
					["5:4"] = true,
				},
			},
		},
		units = {
			{ id = 2, owner = 0, kind = "builder", x = 5, y = 4, charges = 3, movesLeft = 2 },
		},
		world = { width = 12, height = 10, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, state.players[1], state.units[1], state.cities[1]
end
for _, version in ipairs({ "baseline", "p1", "balance1", "balance2" }) do
	local old, player, builder, city = fixture()
	old.contentRules = version
	S.migrate(old)
	assert(old.contentRules == "balance5" and S.canRecruit(player, "builder", old, H, city))
	assert(not S.canBuild(player, city, "farm", old) and not S.canBuild(player, city, "mine", old))
	assert(Works.complete(old, player, builder, "farm", S) and builder.charges == 2)
end
local state, p, u, c = fixture()
assert(S.canRecruit(p, "builder", state, H, c))
assert(not S.canBuild(p, c, "farm", state) and not S.canBuild(p, c, "mine", state))
assert(not S.canProject(p, c, "tend"))
c.buildings.housing = true
assert(S.canProject(p, c, "tend"))
local before = S.yields(p, c, state, H)
local preview = assert(Works.preview(state, p, u, "farm", 5, 4, S))
assert(preview.chargesAfter == 2 and preview.after.food - preview.before.food == 2)
assert(not state.world.improvements and u.charges == 3, "Preview cannot spend or initialize work")
assert(A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
assert(u.charges == 2 and u.movesLeft == 0 and u.actedThisRound)
assert(
	S.yields(p, c, state, H).food - before.food == 2,
	"Only the staffed field, including faction bonus, adds food"
)
assert(not A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
assert(u.charges == 2)
c.buildings.farm, c.buildings.mine = true, true
assert(
	S.yields(p, c, state, H).food - before.food == 2,
	"Retired city Farm cannot duplicate tile output"
)
assert(S.centerYields(p, c, state).industry == 1, "Retired city Quarry cannot duplicate industry")
assert(not Works.canPlace(state, p, "farm", 4, 4, S))
assert(not Works.canPlace(state, p, "quarry", 3, 4, S))
state.world.tiles["3:4"] = "hills"
assert(Works.canPlace(state, p, "quarry", 3, 4, S))
state.world.tiles["4:5"] = "forest"
assert(Works.canPlace(state, p, "lumber", 4, 5, S))
assert(not Works.canPlace(state, p, "farm", 4, 5, S))
-- Wonder projects reserve land, and completion replaces prior tile work.
local Landmarks = dofile("/games/civcraft/landmarks.lua")
state, p, u, c = fixture()
c.project = { kind = "wonder", id = "greattree", x = 5, y = 4, progress = 0 }
assert(not Works.canPlace(state, p, "farm", 5, 4, S))
c.project = nil
p.techs.husbandry = true
state.world.improvements = { ["5:4"] = { kind = "farm" } }
assert(Landmarks.complete(state, c, { id = "greattree", x = 5, y = 4 }, S))
assert(not state.world.improvements["5:4"] and not Works.canPlace(state, p, "farm", 5, 4, S))
-- Last charge removes the unit without orphaning its escort.
state, p, u, c = fixture()
u.charges = 1
local guard = { id = 3, owner = 0, kind = "warrior", x = u.x, y = u.y, movesLeft = 2 }
state.units[#state.units + 1] = guard
assert(Stacks.link(state, u, guard, S))
assert(A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
assert(not Stacks.byID(state, 2) and not guard.escortID)
-- Saved queued work revalidates ownership and pauses before spending a charge.
state, p, u, c = fixture()
assert(Queue.submit(state, p, u, "farm", 5, 4, false, S))
c.owner = 1
Queue.run(state, 0, S, A.apply)
assert(u.workQueue.paused and u.charges == 3 and not state.world.improvements)
c.owner = 0
u.workQueue.paused = nil
Queue.run(state, 0, S, A.apply, u)
assert(u.charges == 2 and not u.workQueue)
-- A visible hostile pauses work even on the current tile; hidden hostiles do not leak.
state, p, u, c = fixture()
state.units[#state.units + 1] = { id = 5, owner = 1, kind = "warrior", x = 6, y = 4, movesLeft = 2 }
W.reveal(state, H, S)
assert(Queue.submit(state, p, u, "farm", 5, 4, false, S))
Queue.run(state, 0, S, A.apply)
assert(u.workQueue.paused == "Visible threat nearby" and u.charges == 3)
p.visible["6:4"] = nil
u.workQueue.paused = nil
Queue.run(state, 0, S, A.apply, u)
assert(u.charges == 2)
-- Melee capture preserves labor but clears the previous owner's intentions.
state, p, u, c = fixture()
state.cities = {}
u.owner = 1
u.charges = 2
u.workQueue = { tasks = { { kind = "farm", x = 5, y = 4 } } }
u.autoWork, u.autoWorkPaused = true, "Visible threat nearby"
local attacker = { id = 8, owner = 0, kind = "warrior", x = 4, y = 4, movesLeft = 2 }
state.units[#state.units + 1] = attacker
W.reveal(state, H, S)
assert(Combat.attack(state, attacker, { x = 5, y = 4 }, S))
assert(
	u.owner == 0
		and u.charges == 2
		and not u.workQueue
		and not u.autoWork
		and not u.autoWorkPaused
		and u.movesLeft == 0
)
-- Fog memory stores observed improvements and does not leak unseen changes.
state, p, u, c = fixture()
assert(A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
local view = W.forPlayer(state, 0)
assert(view.world.improvements["5:4"].kind == "farm")
view.world.improvements["5:4"].damaged = true
assert(not state.world.improvements["5:4"].damaged)
p.visible["5:4"] = nil
state.world.improvements["5:4"].damaged = true
view = W.forPlayer(state, 0)
assert(not view.world.improvements["5:4"].damaged, "Hidden damage must remain hidden")
-- Queued movement and appended work spend one charge per completed task.
state, p, u, c = fixture()
u.moved = true
u.movesLeft = 0
assert(Queue.submit(state, p, u, "farm", 5, 4, false, S))
assert(Queue.submit(state, p, u, "farm", 5, 5, true, S))
assert(not Queue.submit(state, p, u, "farm", 5, 5, true, S))
state.round = 2
u.moved = false
u.movesLeft = 2
Queue.run(state, 0, S, A.apply)
assert(u.charges == 2 and #u.workQueue.tasks == 1)
Queue.run(state, 0, S, A.apply)
assert(u.charges == 2, "Repeated actor pumps cannot repeat a completed task")
state.round = 3
u.moved = false
u.movesLeft = 2
Queue.run(state, 0, S, A.apply)
assert(
	u.x == 5 and u.y == 5 and u.charges == 1 and not u.workQueue,
	tostring(u.x)
		.. ","
		.. tostring(u.y)
		.. " charges="
		.. u.charges
		.. " paused="
		.. tostring(u.workQueue and u.workQueue.paused)
		.. " moves="
		.. u.movesLeft
)
-- Auto work is opt-in, saved as unit intent, and uses only generated queue provenance.
state, p, u, c = fixture()
local intentRequest = { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = true }
u.owner = 1
assert(not A.apply(state, 0, intentRequest, S) and not u.autoWork)
u.owner = 0
u.kind = "settler"
assert(not A.apply(state, 0, intentRequest, S) and not u.autoWork)
u.kind = "builder"
u.charges = 0
assert(not A.apply(state, 0, intentRequest, S) and not u.autoWork)
u.charges = 3
state.contentRules = "baseline"
assert(not A.apply(state, 0, intentRequest, S) and not u.autoWork)
state.contentRules = "balance3"
u.moved, u.movesLeft = true, 0
assert(A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = true }, S))
assert(u.autoWork and u.workQueue and u.workQueue.auto, "Auto mode must create a tagged saved task")
local plannedCharges = u.charges
u.workQueue = nil
Queue.planAuto(state, 0, S, A.apply)
assert(
	not u.workQueue and u.charges == plannedCharges and u.autoWorkScanStamp,
	"Repeated pumps in one actor stamp must not rescan or spend another charge"
)
assert(
	A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = "pause" }, S)
)
assert(u.autoWork and u.autoWorkPaused == "Paused by player" and not u.workQueue)
assert(
	A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = "stop" }, S)
)
assert(not u.autoWork and not u.autoWorkPaused)
assert(Queue.submit(state, p, u, "farm", 5, 4, false, S))
local manualQueue = u.workQueue
u.autoWork = true
assert(
	A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = "stop" }, S)
)
assert(u.workQueue == manualQueue and not u.workQueue.auto, "Stop must preserve manual work")
-- A hidden enemy cannot perturb auto planning or expose a pause reason.
state, p, u, c = fixture()
local Builders = dofile("/games/civcraft/ai_builders.lua")
local knownView = W.forPlayer(state, 0)
local knownOrder = Builders.order(knownView, knownView.players[1], knownView.units[1], S)
state.units[#state.units + 1] = {
	id = 11,
	owner = 1,
	kind = "warrior",
	x = 12,
	y = 10,
	movesLeft = 2,
}
local hiddenView = W.forPlayer(state, 0)
local hiddenOrder = Builders.order(hiddenView, hiddenView.players[1], hiddenView.units[1], S)
assert(
	knownOrder.kind == hiddenOrder.kind
		and knownOrder.tileX == hiddenOrder.tileX
		and knownOrder.tileY == hiddenOrder.tileY,
	"Hidden enemies must not affect auto work planning"
)
-- Visible danger pauses an auto order without spending a charge.
state, p, u, c = fixture()
state.units[#state.units + 1] =
	{ id = 12, owner = 1, kind = "warrior", x = 6, y = 4, movesLeft = 2 }
W.reveal(state, H, S)
assert(A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = true }, S))
assert(u.autoWorkPaused == "Visible threat nearby" and u.charges == 3 and not u.workQueue)
-- A last-charge auto job finishes without leaving a phantom unit.
state, p, u, c = fixture()
u.charges = 1
assert(A.apply(state, 0, { action = "autoWork", unitID = u.id, x = u.x, y = u.y, value = true }, S))
assert(not Stacks.byID(state, u.id) and u.charges == 0)
-- A new civilian blocking a saved route pauses work without spending labor.
state, p, u, c = fixture()
assert(Queue.submit(state, p, u, "farm", 4, 5, false, S))
state.units[#state.units + 1] = { id = 6, owner = 0, kind = "settler", x = 4, y = 5, movesLeft = 3 }
Queue.run(state, 0, S, A.apply)
assert(u.workQueue.paused and u.charges == 3 and u.x == 5)
-- A manual movement queue replaces Builder work, including when movement is exhausted.
state.units[#state.units] = nil
u.movesLeft = 0
u.moved = true
u.autoWork = true
assert(
	not A.apply(
			state,
			0,
			{ action = "queueMove", unitID = 2, sx = 5, sy = 4, x = 100, y = 100 },
			S
		) and u.autoWork,
	"Rejected manual movement must leave auto intent unchanged"
)
assert(A.apply(state, 0, { action = "queueMove", unitID = 2, sx = 5, sy = 4, x = 4, y = 5 }, S))
assert(not u.workQueue and u.moveQueue and not u.autoWork)
-- AI chooses legal tile development and recruits labor only when needed.
local AI = dofile("/games/civcraft/ai.lua")
local Production = dofile("/games/civcraft/ai_production.lua")
state, p, u, c = fixture()
assert(AI.builder(state, p, u, S))
assert(u.charges == 2 and state.world.improvements)
state, p, u, c = fixture()
state.units = {}
W.reveal(state, H, S)
local recruits = false
local aiView = W.forPlayer(state, 0)
for _, choice in ipairs(Production.ranked(aiView, p, aiView.cities[1], S, false)) do
	if choice.kind == "unit" and choice.id == "builder" then
		recruits = true
	end
end
assert(recruits, "AI must value recruiting a Builder for undeveloped city tiles")
-- Saved work, including a safety pause, does not trap END TURN behind unit orders.
local Tasks = dofile("/games/civcraft/turn_tasks.lua")
state, p, u, c = fixture()
c.productionIdle = true
p.researchTarget = "writing"
u.workQueue =
	{ version = 1, tasks = { { kind = "farm", x = 5, y = 4 } }, paused = "Visible threat nearby" }
assert(#Tasks.pending(state, 0, S) == 0)
local guard2 = { id = 9, owner = 0, kind = "warrior", x = u.x, y = u.y, movesLeft = 2 }
state.units[#state.units + 1] = guard2
assert(Stacks.link(state, u, guard2, S))
assert(
	#Tasks.pending(state, 0, S) == 0,
	"A queued Builder's escort should not block end turn either"
)
assert(A.apply(state, 0, { action = "skipTurn", unitID = u.id, x = u.x, y = u.y }, S))
assert(u.workQueue and u.workQueue.paused, "Waiting one turn retains saved Builder work")
-- Actual UI placement/confirmation delegates the selected preview to shared actions.
state, p, u, c = fixture()
local UI = dofile("/games/civcraft/ui.lua")
local ui = setmetatable({
	state = W.forPlayer(state, 0),
	playerID = 0,
	selected = { kind = "unit", unitID = 2, x = 5, y = 4 },
}, { __index = UI })
function ui:feedback(value)
	self.notice = value
end
function ui:command(action, request)
	request.action = action
	return A.apply(state, 0, request, S)
end
ui:armPlacement("work", ui.state.units[1], "farm")
ui:tile(5, 4)
assert(ui.pendingMove.workPreview.after.food - ui.pendingMove.workPreview.before.food == 2)
assert(
	u.charges == 3 and not state.world.improvements,
	"Map selection previews instead of spending"
)
local Panels = dofile("/games/civcraft/panels.lua")
local Inspector = dofile("/games/civcraft/inspector.lua")
local originalRows = Panels.rows
local texts, buttons = {}, {}
Panels.rows = function(_, _, rows)
	for _, row in ipairs(rows) do
		if row.text then
			texts[#texts + 1] = row.text
		end
		for _, button in ipairs(row.buttons or {}) do
			buttons[button.label] = true
		end
	end
end
local renderer = {}
function renderer:fill() end
function renderer:outline() end
function renderer:text() end
function renderer:button() end
function renderer:textWidth(value)
	return #tostring(value) * 4
end
ui.r = renderer
Inspector.draw(ui, ui.state, ui.state.players[1], { x = 1, y = 1, w = 240, h = 200 }, true)
assert(
	table.concat(texts, " "):find("WORK PREVIEW", 1, true)
		and buttons["PLAN WHEAT FIELD"]
		and buttons["WHEAT FIELD HERE"]
		and buttons["AUTO WORK"]
)
u.autoWork, u.autoWorkPaused = true, "Paused by player"
ui.state = W.forPlayer(state, 0)
texts, buttons = {}, {}
Inspector.draw(ui, ui.state, ui.state.players[1], { x = 1, y = 1, w = 240, h = 200 }, true)
assert(
	table.concat(texts, " "):find("Paused by player", 1, true)
		and buttons["RESUME AUTO WORK"]
		and buttons["STOP AUTO WORK"]
)
u.autoWork, u.autoWorkPaused = false, nil
Panels.rows = originalRows
assert(ui:confirmMove())
assert(u.charges == 2 and state.world.improvements["5:4"].kind == "farm")
-- A visible removal must not fall back to an older remembered improvement.
state.world.improvements["5:4"] = nil
assert(not W.forPlayer(state, 0).world.improvements["5:4"])
state.world.improvements["5:4"] = { kind = "farm", damaged = true }
if fs and textutils then
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/builder-validation"
	u.charges = 2
	u.workQueue = {
		version = 1,
		tasks = { { kind = "quarry", x = 3, y = 4 } },
		paused = "Work route blocked",
		auto = true,
	}
	u.autoWork, u.autoWorkPaused, u.autoWorkScanStamp = true, "Work route blocked", "1:0"
	assert(Saves.writeFile(Saves.path(1), state))
	local restored = S.migrate(assert(Saves.load(1)))
	assert(restored.contentRules == "balance3" and restored.units[1].charges == 2)
	assert(
		restored.units[1].workQueue.paused == "Work route blocked"
			and restored.units[1].workQueue.auto
			and restored.units[1].autoWork
			and restored.units[1].autoWorkPaused == "Work route blocked"
			and restored.units[1].autoWorkScanStamp == "1:0"
			and restored.world.improvements["5:4"].damaged
	)
end
if term and fs and textutils then
	state, p, u, c = fixture()
	local ended = false
	local actual = UI.new(term.current(), function(action, request)
		request.action = action
		if action == "end" then
			assert(dofile("/games/civcraft/match_lifecycle.lua").finish(state, 0))
			ended = true
		else
			assert(A.apply(state, 0, request, S))
		end
	end)
	local function draw()
		actual:draw(W.forPlayer(state, 0), 0, {})
	end
	draw()
	actual:focus("unit", u)
	actual.panel = "inspector"
	local chosen = false
	for offset = 0, 70 do
		actual.inspectorOffset = offset
		draw()
		for _, button in ipairs(actual.r.buttons) do
			if button.label == "WHEAT FIELD HERE" then
				local px, py = button.x + button.w / 2, button.y + button.h / 2
				if actual.r.mode == "graphics" then
					px, py = actual.r.ox + px * actual.r.sx, actual.r.oy + py * actual.r.sy
				else
					px, py = px / 2 + 1, py / 3 + 1
				end
				actual:tap(math.floor(px), math.floor(py))
				chosen = true
				break
			end
		end
		if chosen then
			break
		end
	end
	assert(
		chosen and actual.placement and actual.placement.kind == "work",
		"Native inspector must expose Builder planning"
	)
	draw()
	assert(actual.pendingMove and actual.pendingMove.workPreview and u.charges == 3)
	local confirm
	for _, button in ipairs(actual.r.buttons) do
		if button.label == "CONFIRM" then
			confirm = button
		end
	end
	assert(confirm, "Native work preview must expose confirmation")
	local px, py = confirm.x + confirm.w / 2, confirm.y + confirm.h / 2
	if actual.r.mode == "graphics" then
		px, py = actual.r.ox + px * actual.r.sx, actual.r.oy + py * actual.r.sy
	else
		px, py = px / 2 + 1, py / 3 + 1
	end
	actual:tap(math.floor(px), math.floor(py))
	assert(u.charges == 2 and state.world.improvements["5:4"])
	c.productionIdle = true
	p.researchTarget = "writing"
	state.world.tiles["4:5"] = "forest"
	W.reveal(state, H, S)
	assert(A.apply(state, 0, {
		action = "queueWork",
		unitID = u.id,
		x = u.x,
		y = u.y,
		tileX = 4,
		tileY = 5,
		kind = "lumber",
	}, S))
	assert(u.workQueue and u.movesLeft == 0)
	draw()
	assert(actual:turnAction() == "END TURN", "Queued work must permit the normal end-turn control")
	local endButton
	for _, button in ipairs(actual.r.buttons) do
		if button.label == "END TURN" then
			endButton = button
		end
	end
	assert(endButton)
	local ex, ey = endButton.x + endButton.w / 2, endButton.y + endButton.h / 2
	if actual.r.mode == "graphics" then
		ex, ey = actual.r.ox + ex * actual.r.sx, actual.r.oy + ey * actual.r.sy
	else
		ex, ey = ex / 2 + 1, ey / 3 + 1
	end
	actual:tap(math.floor(ex), math.floor(ey))
	assert(ended and p.ready and u.workQueue, "Native END TURN preserves unfinished Builder work")
	actual:close()
end
print(
	"PASS: charged Builder work, tile yields, retired city bonuses, capture, safe queues, fog memory and native saves"
)
