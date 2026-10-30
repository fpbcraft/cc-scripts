local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
-- Match the installed program's shared internal module identities.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Animations = dofile("games/civcraft/animations.lua")
local AnimationFrame = dofile("games/civcraft/animation_frame.lua")
local AnimationView = dofile("games/civcraft/animation_view.lua")
local Presentation = dofile("games/civcraft/presentation.lua")
local World = dofile("games/civcraft/world.lua")

local function close(actual, expected)
	assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. expected)
end
local actor = { id = 7, kind = "scout", owner = 1, hp = 100 }
local function move(seq, paths)
	return { type = "move", seq = seq, round = 1, actor = actor, paths = paths }
end
local function stream(events, observer, campaign)
	return {
		observer = observer or 1,
		campaign = campaign or "ONE",
		lastSeq = #events,
		entries = events,
	}
end
local route = { {} }
for x = 1, 6 do
	route[1][#route[1] + 1] = { x = x, y = 1 }
end
local event = move(1, route)
local timeline = Animations.new()
timeline:ingest(stream({ event }), function()
	return true
end, true)
local first, active = timeline:frame(0, 1)
assert(active and first.hidden["unit:7"])
close(first.sprites[1].position.x, 0.5)
local halfway = timeline:frame(0.3, 1)
close(halfway.sprites[1].position.x, 3)
local beforeFinish = timeline:frame(0.599, 1)
assert(beforeFinish.sprites[1].position.x > 5.49)
local final, finished = timeline:frame(0.601, 1)
assert(not finished and not next(final.hidden), "Static final sprite returns after playback")
assert(actor.hp == 100 and route[1][1].x == 1, "Playback never mutates input events")
timeline:ingest(stream({ event }), function()
	return true
end, true)
assert(
	#timeline.pending == 0 and #timeline.feed == 1,
	"Duplicate snapshots do not replay or duplicate summaries"
)

timeline:setSpeed("fast")
timeline:play({ event })
timeline:frame(1, 1)
close(timeline:frame(1.15, 1).sprites[1].position.x, 3)
timeline:skip()
assert(not timeline.active and #timeline.pending == 0 and #timeline.feed == 1)
timeline:setSpeed("off")
timeline:play({ event })
assert(not select(2, timeline:frame(2, 1)) and #timeline.feed == 1)

local fragments = move(1, {
	{ { x = 1, y = 1 }, { x = 2, y = 1 } },
	{ { x = 8, y = 2 }, { x = 9, y = 2 } },
})
timeline = Animations.new()
timeline:play({ fragments })
timeline:frame(0, 1)
assert(
	#timeline:frame(0.15, 1).sprites == 0,
	"Hidden route gap must disappear without interpolation"
)
local later = timeline:frame(0.24, 1).sprites[1].position
close(later.x, 8.5)
close(later.y, 1.25)

local combat = {
	seq = 2,
	round = 1,
	type = "combat",
	actor = actor,
	start = { x = 2, y = 1 },
	target = { x = 3, y = 1 },
	defender = { id = 8, kind = "warrior", owner = 2, hp = 20 },
	result = { attackerHP = 70, defenderHP = 0, defenderDied = true, ranged = false },
}
timeline = Animations.new()
timeline:play({ combat })
local windup = timeline:frame(0, 1)
assert(windup.hidden["unit:7"] and windup.hidden["unit:8"])
assert(windup.sprites[2].hp == 20)
local impact = timeline:frame(0.4, 1)
assert(impact.sprites[1].hp == 70 and impact.sprites[2].hp == 0)
assert(impact.sprites[2].opacity < 1 and impact.effects[1].kind == "impact")
assert(impact.sprites[1].position.x > 1.9, "Victorious melee advances after impact")
local previous = impact.sprites[1].position.x
close(timeline:frame(0.2, 1).sprites[1].position.x, previous)
assert(combat.defender.hp == 20 and combat.actor.hp == 100)
combat.result.ranged = true
timeline:play({ combat })
timeline:frame(1, 1)
local ranged = timeline:frame(1.2, 1)
assert(ranged.projectile and #ranged.effects == 0)
close(ranged.sprites[1].position.x, 1.5)

-- Partial observations have no concealed combatant to draw or aim a projectile at.
local partial = {
	seq = 3,
	round = 1,
	type = "impact",
	target = combat.target,
	defender = combat.defender,
	result = { defenderHP = 5 },
}
timeline:play({ partial })
local partialFrame = timeline:frame(2, 1)
assert(#partialFrame.sprites == 1 and partialFrame.sprites[1].actor.id == 8)
assert(not partialFrame.projectile and not partialFrame.hidden["unit:7"])

-- Keep essential summaries under motion bursts and bound all presentation storage.
local burst = {}
for i = 1, 200 do
	burst[i] = move(i, route)
end
combat.seq = 201
burst[201] = combat
timeline = Animations.new()
timeline:ingest(stream(burst), function()
	return true
end, true)
assert(#timeline.feed == Animations.maxFeed and #timeline.pending == Animations.maxPending)
assert(
	timeline.feed[#timeline.feed].type == "combat"
		and timeline.pending[#timeline.pending].type == "combat"
)
timeline:frame(0, 1)
timeline:frame(1, 10)
assert(#timeline.feed == 0 and #timeline.pending == 0 and not timeline.active)
timeline:ingest(stream({ event }, 2, "TWO"), function()
	return false
end, true)
assert(#timeline.feed == 1 and #timeline.pending == 0 and timeline.observer == 2)
timeline:ingest(stream({ event }, 1, "ONE"), function()
	return true
end, false)
assert(
	#timeline.feed == 1 and #timeline.pending == 0,
	"Concealed hotseat screens only retain permitted summaries"
)

-- Nested references in a local projection must not escape into the renderer.
local state = {
	version = 6,
	phase = "game",
	round = 1,
	campaignID = "ONE",
	players = {
		{ id = 1, techs = {}, explored = { ["1:1"] = true }, visible = { ["1:1"] = true } },
	},
	units = { { id = 7, owner = 1, kind = "scout", hp = 100, x = 1, y = 1 } },
	cities = {},
	world = {
		width = 1,
		height = 1,
		tiles = { ["1:1"] = "plains" },
		geography = { ["1:1"] = { biome = "plains", elevation = "flat" } },
	},
}
local projected = World.forPlayer(state, 1)
assert(
	projected.players[1] == state.players[1],
	"Test must cover actual aliased own-player projection"
)
local captured = Presentation.capture(state, 1)
state.players[1].techs.farming = true
state.units[1].x = 9
state.world.geography["1:1"].biome = "desert"
assert(not captured.players[1].techs.farming and captured.units[1].x == 1)
assert(captured.world.geography["1:1"].biome == "plains")
captured.units[1].hp = 0
assert(state.units[1].hp == 100)
timeline = Animations.new()
timeline:play({ event })
timeline:frame(0, 1)
local pausedPosition = timeline:frame(0.24, 1).sprites[1].position.x
timeline:setPaused(true, 0.24)
assert(#timeline:frame(5, 1).sprites == 0)
timeline:setPaused(false, 5)
close(timeline:frame(5, 1).sprites[1].position.x, pausedPosition)
timeline:skip()
local automated = move(1, route)
automated.ownAutoExplore = true
timeline:ingest(stream({ automated }), function()
	return true
end, true)
assert(#timeline.feed == 0 and #timeline.pending == 0, "Own auto-exploration never enters replay")
timeline:play({ automated })
assert(not select(2, timeline:frame(6, 1)))
print(
	"CIVCRAFT: interpolation, fog gaps, combat timing, skips, bounded replay and detached rendering passed."
)

-- Every turn-recap event holds its observed opening pose, even under backlog acceleration.
timeline = Animations.new()
local nextEvent = move(2, { { { x = 8, y = 2 }, { x = 9, y = 2 } } })
timeline:play({ event, nextEvent }, true)
local waiting = timeline:frame(10, 1)
assert(
	waiting.waiting and waiting.progress == 0 and #waiting.effects == 0 and not waiting.projectile
)
close(timeline:frame(10.2, 1).sprites[1].position.x, waiting.sprites[1].position.x)
timeline:setPaused(true, 10.2)
timeline:setPaused(false, 20.2)
assert(timeline:frame(20.2, 1).waiting, "Pause menus cannot consume the opening delay")
assert(not timeline:frame(20.4, 1).waiting and timeline.active.event.seq == 1)
local finish = timeline.active.finish
assert(
	timeline:frame(finish + 0.001, 1).waiting and timeline.active.event.seq == 2,
	"The next event gets its own delay rather than sharing the first event's"
)
timeline:setSpeed("fast")
timeline:play({ event }, true)
timeline:frame(30, 1)
close(timeline.active.start - 30, Animations.leadIn / 2)
timeline:setSpeed("off")
assert(not timeline.active and #timeline.pending == 0)
assert(not event.replayLeadIn, "Presentation metadata never mutates the saved event")
print(
	"CIVCRAFT: serial replay lead-ins, paused timing, fast/off preferences and event immutability passed."
)

-- Display interpolation may use repeated copies, but projected event coordinates stay canonical.
local wrappedWorld = { width = 8, height = 6, wrapX = true }
local seamMove = move(4, { { { x = 8, y = 1 }, { x = 1, y = 1 } } })
local seamFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(seamFrame, seamMove, 0.5, wrappedWorld)
close(seamFrame.sprites[1].position.x, 8)
assert(
	seamMove.paths[1][1].x == 8 and seamMove.paths[1][2].x == 1,
	"Wrapped display interpolation must not rewrite canonical observer events"
)

local boundedFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(boundedFrame, seamMove, 0.5, { width = 8, height = 6 })
close(boundedFrame.sprites[1].position.x, 4)

local oddRowMove = move(5, { { { x = 8, y = 2 }, { x = 1, y = 2 } } })
local oddRowFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(oddRowFrame, oddRowMove, 0.5, wrappedWorld)
close(oddRowFrame.sprites[1].position.x, 8.5)
close(oddRowFrame.sprites[1].position.y, 1.25)

local seamCombat = {
	seq = 6,
	round = 1,
	type = "combat",
	actor = actor,
	start = { x = 8, y = 1 },
	target = { x = 1, y = 1 },
	defender = { id = 9, kind = "warrior", owner = 2, hp = 40 },
	result = { ranged = true, attackerHP = 100, defenderHP = 40 },
}
local projectileFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(projectileFrame, seamCombat, 0.2, wrappedWorld)
assert(projectileFrame.projectile, "Wrapped ranged combat still paints a projectile")
close(projectileFrame.projectile.start.x, 7.5)
close(projectileFrame.projectile.position.x, 7.9)
close(projectileFrame.sprites[2].position.x, 8.5)
assert(
	seamCombat.start.x == 8 and seamCombat.target.x == 1,
	"Wrapped combat must retain canonical endpoints"
)
seamCombat.result.ranged = false
seamCombat.result.defenderDied = true
local meleeFrame = { hidden = {}, sprites = {}, effects = {} }
AnimationFrame.paint(meleeFrame, seamCombat, 0.5, wrappedWorld)
close(meleeFrame.sprites[1].position.x, 7.9)
close(meleeFrame.sprites[2].position.x, 8.5)
close(meleeFrame.effects[1].position.x, 8.5)
seamCombat.result.ranged = true
seamCombat.result.defenderDied = nil

local followTimeline = Animations.new()
followTimeline:play({ seamMove })
local followFirst = followTimeline:frame(0, 1)
local followNext = followTimeline:frame(0.06, 1)
local followUI = { animationFrame = followFirst, panX = 0, panY = 0 }
local rect = { x = 10, y = 5, w = 80, h = 40 }
AnimationView.center(followUI, rect, 10, wrappedWorld)
close(followUI.panX, 35)
followUI.animationFrame = followNext
AnimationView.center(followUI, rect, 10, wrappedWorld)
close(followUI.panX, 40)
local drawn
followUI.r = {
	fill = function(_, x, y)
		drawn = drawn or { x, y }
	end,
}
followUI.animationTime = 1
AnimationView.draw(followUI, { world = wrappedWorld, players = { { id = 1 } } }, rect, 10)
assert(drawn and drawn[1] == 49, "Animated sprite draws in the camera's repeated world copy")
print("CIVCRAFT: wrapped animation interpolation uses short display paths and canonical events.")
