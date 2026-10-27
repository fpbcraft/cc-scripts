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
local state, p, u, c = fixture()
assert(S.canRecruit(p, "builder", state, H, c))
assert(not S.canBuild(p, c, "farm", state) and not S.canBuild(p, c, "mine", state))
assert(not S.canProject(p, c, "tend"))
c.buildings.housing = true
assert(S.canProject(p, c, "tend"))
local before = S.yields(p, c, state, H)
local preview = assert(Works.preview(state, p, u, "farm", 5, 4, S))
assert(preview.chargesAfter == 2 and preview.after.food - preview.before.food == 3)
assert(not state.world.improvements and u.charges == 3, "Preview cannot spend or initialize work")
assert(A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
assert(u.charges == 2 and u.movesLeft == 0 and u.actedThisRound)
assert(
	S.yields(p, c, state, H).food - before.food == 3,
	"Only the staffed field, including faction bonus, adds food"
)
assert(not A.apply(state, 0, { action = "improve", unitID = 2, x = 5, y = 4, kind = "farm" }, S))
assert(u.charges == 2)
c.buildings.farm, c.buildings.mine = true, true
assert(
	S.yields(p, c, state, H).food - before.food == 3,
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
local attacker = { id = 8, owner = 0, kind = "warrior", x = 4, y = 4, movesLeft = 2 }
state.units[#state.units + 1] = attacker
W.reveal(state, H, S)
assert(Combat.attack(state, attacker, { x = 5, y = 4 }, S))
assert(u.owner == 0 and u.charges == 2 and not u.workQueue and u.movesLeft == 0)
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
assert(A.apply(state, 0, { action = "queueMove", unitID = 2, sx = 5, sy = 4, x = 4, y = 5 }, S))
assert(not u.workQueue and u.moveQueue)
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
assert(ui.pendingMove.workPreview.after.food - ui.pendingMove.workPreview.before.food == 3)
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
assert(table.concat(texts, " "):find("WORK PREVIEW", 1, true) and buttons["PLAN WHEAT FIELD"])
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
	}
	assert(Saves.writeFile(Saves.path(1), state))
	local restored = S.migrate(assert(Saves.load(1)))
	assert(restored.contentRules == "balance3" and restored.units[1].charges == 2)
	assert(
		restored.units[1].workQueue.paused == "Work route blocked"
			and restored.world.improvements["5:4"].damaged
	)
end
if term and fs and textutils then
	state, p, u, c = fixture()
	local actual = UI.new(term.current(), function(action, request)
		request.action = action
		assert(A.apply(state, 0, request, S))
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
			if button.label == "PLAN WHEAT FIELD" then
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
	actual:tile(5, 4)
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
	actual:close()
end
print(
	"PASS: charged Builder work, tile yields, retired city bonuses, capture, safe queues, fog memory and native saves"
)
