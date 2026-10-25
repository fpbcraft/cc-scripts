local native = dofile
local ui, scoutDraws
local instrumented = setmetatable({}, { __mode = "k" })
dofile = function(path)
	local module = native(path:gsub("^/games/civcraft/", "games/civcraft/"))
	if path == "/games/civcraft/icons.lua" and not instrumented[module] then
		instrumented[module] = true
		local draw = module.draw
		module.draw = function(r, kind, ...)
			local viewport = ui and ui.mapViewport
			if
				kind == "scout"
				and r.clip
				and viewport
				and r.clip.x == viewport.x
				and r.clip.y == viewport.y
			then
				scoutDraws = scoutDraws + 1
			end
			return draw(r, kind, ...)
		end
	end
	return module
end
local Actions = dofile("games/civcraft/actions.lua")
local Hex = dofile("games/civcraft/hex.lua")
local Events = dofile("games/civcraft/events.lua")
local Playback = dofile("games/civcraft/playback_ui.lua")
local Presentation = dofile("games/civcraft/presentation.lua")
local Systems = dofile("games/civcraft/systems.lua")
local UI = dofile("games/civcraft/ui.lua")
local World = dofile("games/civcraft/world.lua")
local originalEpoch = os.epoch
local time = 1000
os.epoch = function()
	return time
end

for _, graphics in ipairs({ false, true }) do
	local world =
		{ width = 18, height = 12, tiles = {}, resources = {}, landmarks = {}, rails = {} }
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[World.key(x, y)] = "plains"
		end
	end
	local state = {
		version = 6,
		phase = "game",
		campaignID = "playback-ui",
		ruleset = "create",
		round = 1,
		nextId = 10,
		world = world,
		players = { { id = 1, name = "ONE", techs = {} }, { id = 2, name = "TWO", techs = {} } },
		cities = {},
		units = { { id = 3, owner = 1, kind = "scout", x = 3, y = 5, movesLeft = 6 } },
	}
	Systems.migrate(state)
	World.reveal(state, Hex, Systems)
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 800, 603
			end
			return 133, 67
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
	local commands = 0
	ui = UI.new(monitor, function()
		commands = commands + 1
	end)
	ui.animationPreferences = { speed = "normal", automatic = true, reducedMotion = false }
	local function draw(observer, opts)
		scoutDraws = 0
		ui:draw(
			Presentation.capture(state, observer or 1),
			observer or 1,
			opts or { screen = "game" }
		)
	end
	local function click(label)
		for _, button in ipairs(ui.r.buttons) do
			if button.label == label then
				button.fn()
				return true
			end
		end
		return false
	end
	time = 1000
	draw()
	assert(Actions.apply(state, 1, { action = "move", sx = 3, sy = 5, x = 8, y = 5 }, Systems))
	draw()
	assert(ui:animating() and ui.animationFrame.hidden["unit:3"])
	assert(scoutDraws == 1, "The animated scout replaces its static final instance")
	local start = ui.animationFrame.sprites[1].position.x
	time = 1240
	draw()
	assert(ui.animationFrame.sprites[1].position.x > start and scoutDraws == 1)
	assert(click("SKIP") and not ui:animating())
	assert(
		commands == 0 and state.units[1].x == 8,
		"Presentation controls cannot dispatch simulation commands"
	)
	draw()
	assert(click("OBSERVED EVENTS"))
	draw()
	assert(ui.modalBounds and click("PLAY ALL"))
	draw()
	local viewport = ui.mapViewport
	local expectedPan = math.max(
		0,
		math.min(
			viewport.maxX,
			ui.animationFrame.sprites[1].position.x * viewport.tile - viewport.w / 2
		)
	)
	assert(
		ui:animating() and math.abs(ui.panX - expectedPan) < 0.00001,
		"Playback automatically centers its current action within map bounds"
	)
	ui:command("skipPlayback")
	local ownFeed = ui.playback.feed
	draw(2, { screen = "game", handoff = true })
	assert(not ui:animating() and not ui.animationFrame)
	assert(
		ui.playback.observer == 2 and #ui.playback.feed == 0,
		"Hotseat must never borrow another observer's replay"
	)
	draw(1, { screen = "game", handoff = true })
	assert(#ui.playback.feed == #ownFeed and not ui.animationFrame)
	draw()
	ui.animationPreferences.reducedMotion = true
	Playback.watch(ui, ownFeed)
	draw()
	assert(
		not ui:animating() and #ui.playback.feed > 0,
		"Reduced motion keeps final state and summaries"
	)
	-- A new turn plays only this observer's permitted events, without a replay question.
	ui.animationPreferences.reducedMotion = false
	draw(1, { screen = "game", localMode = true })
	ui:command("end", { confirmed = true })
	Events.emit(state, {
		type = "move",
		actor = { id = 9, owner = 2, kind = "scout" },
		frames = {
			{ x = 1, y = 1, visible = { [2] = true } },
			{ x = 8, y = 5, visible = { [1] = true, [2] = true } },
			{ x = 9, y = 5, visible = { [1] = true, [2] = true } },
		},
	})
	draw(2, { screen = "game", localMode = true, handoff = true })
	assert(not ui.recap and not ui.animationFrame)
	draw(1, { screen = "game", localMode = true, handoff = true })
	assert(not ui.recap and not ui.animationFrame)
	draw(1, { screen = "game", localMode = true })
	assert(ui.panel == "context" and ui:animating() and not ui.modalBounds)
	local replay = ui.animationFrame.event
	assert(
		#replay.paths[1] == 2 and replay.paths[1][1].x == 8,
		"Automatic playback cannot reconstruct a hidden origin from current exploration"
	)
	assert(click("SKIP") and ui.recap == nil and #ui.playback.feed >= 2)
	draw(1, { screen = "game", localMode = true })
	assert(ui.panel == "context", "Dismissed recap stays dismissed")
	ui:close()
end
os.epoch = originalEpoch
print(
	"CIVCRAFT: text/graphics automatic playback, one sprite, feed controls, reduced motion and private handoffs passed."
)
