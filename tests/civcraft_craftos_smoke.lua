--[[
	Manual native CraftOS check. Run in a dedicated emulator computer containing
	/games/civcraft and /tests; its save slot 3 is used and left available to inspect.
	No terminal, event, filesystem or peripheral API is mocked here.
]]
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Actions = dofile("/games/civcraft/actions.lua")
local AI = dofile("/games/civcraft/ai.lua")
local Events = dofile("/games/civcraft/events.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Playback = dofile("/games/civcraft/playback_ui.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local Saves = dofile("/games/civcraft/saves.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local world = World.generate(802, "compact", 2, "pangaea")
local state = {
	version = 6,
	phase = "game",
	ruleset = "create",
	round = 1,
	nextId = 10,
	campaignID = "native-craftos-smoke",
	world = world,
	players = {
		{ id = 1, name = "ONE", civ = "iron", techs = {} },
		{ id = 2, name = "TWO", civ = "verdant", techs = {} },
	},
	cities = {},
	units = {},
}
for index, start in ipairs(world.starts) do
	state.cities[index] =
		{ id = index, owner = index, x = start.x, y = start.y, population = 2, buildings = {} }
end
local start = world.starts[1]
state.units[1] = {
	id = 3,
	owner = 1,
	kind = "scout",
	x = start.x + 1,
	y = start.y,
	movesLeft = 6,
	standby = true,
}
Systems.migrate(state)
World.reveal(state, Hex, Systems)
local applied = 0
local ui = UI.new(term.current(), function(action, request)
	request.action = action
	local ok, reason = Actions.apply(state, 1, request, Systems)
	assert(ok, reason)
	applied = applied + 1
end)
local function draw()
	ui:draw(Presentation.capture(state, 1), 1, { screen = "game" })
end
local function click(label)
	for _, button in ipairs(ui.r.buttons) do
		if button.label == label then
			button.fn()
			return true
		end
	end
end
local function find(label)
	for _ = 1, 60 do
		if click(label) then
			return true
		end
		ui.inspectorOffset = (ui.inspectorOffset or 0) + 1
		draw()
	end
end
draw()
ui:focus("city", state.cities[1])
ui.cityPanel = "production"
draw()
if click("DETAILS") then
	draw()
end
assert(find("NO PRODUCTION"))
draw()
assert(state.cities[1].productionIdle)
ui:focus("unit", state.units[1])
draw()
if click("DETAILS") then
	draw()
end
assert(find("MOVE / ATTACK"))
local target
for _, destination in ipairs(ui.reachable) do
	local observed = true
	for _, point in ipairs(destination.path or {}) do
		if not state.players[1].visible[World.key(point.x, point.y)] then
			observed = false
		end
	end
	if observed and not destination.attack and (not target or #destination.path > #target.path) then
		target = destination
	end
end
assert(target and #target.path > 2, "Native UI must offer an observed multi-step scout route")
ui:tile(target.x, target.y)
draw()
assert(click("CONFIRM"))
assert(not state.units[1].standby and applied == 2)
local before = Events.forPlayer(state, 1)
assert(before.lastSeq >= 2)
draw()
local movement
for _, event in ipairs(ui.playback.feed) do
	if event.type == "move" then
		movement = event
	end
end
assert(movement and #movement.paths[1] > 2, "Native feed must retain the approved route")
ui.animationPreferences.reducedMotion = false
ui.animationPreferences.speed = "normal"
ui.playback:setSpeed("normal")
Playback.watch(ui, { movement }, true)
local began = os.epoch("utc")
local positions, frames = {}, 0
repeat
	draw()
	frames = frames + 1
	local sprite = ui.animationFrame and ui.animationFrame.sprites[1]
	if sprite then
		positions[string.format("%.2f:%.2f", sprite.position.x, sprite.position.y)] = true
	end
	sleep(0.05)
until not ui:animating()
local seconds = (os.epoch("utc") - began) / 1000
local distinct = 0
for _ in pairs(positions) do
	distinct = distinct + 1
end
assert(distinct >= 3 and seconds < 5, "Native playback must interpolate and finish promptly")
Playback.watch(ui, { movement })
draw()
assert(ui:animating() and click("SKIP"))
assert(not ui:animating() and #ui.playback.feed > 0, "Skip retains the observed summary")
state.players[2].ai = true
AI.beginTurn(state, state.players[2])
state.world.wrapX = true
assert(Saves.save(3, state))
state.world.wrapX = false
local restored = Saves.load(3)
assert(
	restored.campaignID == state.campaignID
		and restored.eventJournal.version == 1
		and restored.world.wrapX == true
)
assert(Events.forPlayer(restored, 1).lastSeq == before.lastSeq)
assert(restored.units[1].x == target.x and restored.units[1].y == target.y)
assert(
	restored.players[2].aiPlan.version == 1 and restored.players[2].aiPlan.primary == "industrial"
)
local safe = World.forPlayer(restored, 1)
assert(not safe.eventJournal and safe.eventStream.observer == 1)
local report = assert(fs.open("/civcraft-native-smoke.txt", "w"))
report.write(textutils.serialize({
	host = _G._HOST,
	renderer = ui.r.mode,
	columns = ui.r.cw,
	rows = ui.r.ch,
	appliedOrders = applied,
	replaySeq = before.lastSeq,
	animationFrames = frames,
	animationPositions = distinct,
	animationSeconds = seconds,
	animatedHexes = #movement.paths[1] - 1,
	saveReload = true,
	aiPlanReload = true,
}))
report.close()
ui:close()
print(
	"CIVCRAFT native CraftOS: actual renderer/buttons, validated orders, save serialization and replay reload passed."
)
