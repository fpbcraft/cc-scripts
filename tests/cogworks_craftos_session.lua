-- Run inside an isolated CraftOS-PC computer, with this repository at /source:
-- shell.run('/source/tests/cogworks_craftos_session.lua', '--text', '--exit')
-- This is a scripted runtime/interaction check, not a blind human playtest.
package.path = "/source/?.lua;/source/?/init.lua;" .. package.path
local args = { ... }
local flags = {}
for _, value in ipairs(args) do
	flags[value] = true
end
local E = require("games.cogworks.engine")
local App = require("games.cogworks.app")
local Renderer = require("games.cogworks.render")
local S = require("games.cogworks.storage")
local native = term.current()
local Viewport = require("games.cogworks.terminal_view")
local Display = require("lib.fpb.display")
local display = flags["--text"] and Viewport.new(native, 70, 40)
	or Display.select(nil, native, Viewport, 70, 40)
os.setComputerLabel("Cogworks isolated playtest")
local renderer = Renderer.new(display)
if display == native and renderer.mode == "text" then
	renderer:close()
	display = Viewport.new(native, 70, 40)
	renderer = Renderer.new(display)
end
local app = App.new({ dev = true })
app.settings.animations = false
app:act("devLevels")
local actions, completed = 0, 0
local function tap(action, x, y)
	renderer:draw(app:model())
	for _, target in ipairs(renderer.targets) do
		if
			target.action == action
			and (x == nil or target.arg == x)
			and (y == nil or target.arg2 == y)
		then
			local px, py = target.x + target.w / 2, target.y + target.h / 2
			if renderer.mode == "graphics" then
				px, py = renderer.ox + px * renderer.scale, renderer.oy + py * renderer.scale
			end
			local actual, first, second = renderer:hit(px, py)
			assert(
				actual == action and first == target.arg and second == target.arg2,
				"Runtime hit map mismatch"
			)
			app:act(actual, first, second)
			actions = actions + 1
			if actions % 20 == 0 then
				sleep(0)
			end
			return
		end
	end
	error("Missing runtime control: " .. action .. " " .. tostring(x))
end
local ok, reason = pcall(function()
	for _, number in ipairs({ 4, 9, 20, 28, 44, 49, 64 }) do
		local stage = E.levels[number]
		local names = { "normal", "alternate" }
		if stage.solutions.other then
			names[#names + 1] = "other"
		end
		for _, name in ipairs(names) do
			app.progress.sessions[number] = nil
			app:openLevel(number)
			tap("beginLevel")
			if app.scene == "tutorial" then
				tap("tutorialSkip")
			end
			local witness = name == "normal"
					and { parts = stage.build, remove = stage.removeRedstone }
				or stage.solutions[name]
			for _, cell in ipairs(witness.remove or {}) do
				tap("tool", "erase")
				tap("cell", cell[1], cell[2])
			end
			for _, piece in ipairs(witness.parts) do
				tap("tool", piece.kind)
				tap("cell", piece.x, piece.y)
				for _ = 1, piece.r do
					tap("cell", piece.x, piece.y)
				end
			end
			assert(app.result.win, "Runtime construction failed: " .. number .. "/" .. name)
			local restored = E.new(number)
			assert(
				E.restore(restored, E.snapshot(app.game)) and E.evaluate(restored).win,
				"Runtime snapshot roundtrip failed"
			)
			local bonuses = E.challenges(app.game, app.result)
			for index, spec in ipairs(stage.bonuses) do
				if spec.witness == name then
					assert(bonuses[index].earned, "Runtime bonus failed")
				end
				tap("inspectBonus", spec.id)
				assert(app.message == spec.description)
			end
			renderer:draw(app:model())
			if display.present then
				display.present()
			end
			completed = completed + 1
			sleep(0)
		end
	end
	for slot = 1, 3 do
		assert(not fs.exists(S.path(slot)), "Developer playtest must not create campaign slots")
	end
end)
local mode = renderer.mode
if flags["--hold"] and ok then
	sleep(45)
end
renderer:close()
if display.close then
	display.close()
end
local report = (ok and "PASS" or "FAIL")
	.. ": "
	.. completed
	.. " builds, "
	.. actions
	.. " hit-tested actions; "
	.. mode
if not ok then
	report = report .. "\n" .. tostring(reason)
end
local file = assert(fs.open("/cogworks-session-result.txt", "w"))
file.write(report)
file.close()
print(report)
if flags["--exit"] then
	os.shutdown()
end
assert(ok, reason)
