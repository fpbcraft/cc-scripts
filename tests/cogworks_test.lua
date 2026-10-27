package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local function eq(actual, expected, context)
	assert(
		actual == expected,
		(context or "Mismatch")
			.. ": expected "
			.. tostring(expected)
			.. ", got "
			.. tostring(actual)
	)
end
eq(#E.levels, 64, "Eight chapters of eight playable campaign levels")
eq(#E.order, 10, "Eight Create mechanisms plus redstone dust and block")
for _, kind in ipairs(E.order) do
	assert(E.parts[kind], "Selectable component missing: " .. kind)
end
for _, removed in ipairs({ "L", "T" }) do
	assert(not E.parts[removed], "Fictitious mechanism still available: " .. removed)
end
local goals = 0
for index, data in ipairs(E.levels) do
	local game = E.new(index)
	assert(not E.evaluate(game).win, "New level cannot start completed: " .. index)
	eq(game.moves, 0, "Fresh move counter")
	assert(
		not E.place(game, data.source.x, data.source.y, "I"),
		"Fixed generator cannot be replaced"
	)
	assert(not E.remove(game, data.source.x, data.source.y), "Generator cannot be removed")
	assert(not E.rotate(game, data.source.x, data.source.y), "Generator cannot be rotated")
	assert(
		not E.place(game, 0, 1, "I") and not E.place(game, game.width + 1, 1, "I"),
		"Bounds enforced"
	)
	assert(game.width == data.width and game.height == data.height, "Per-stage grid size applied")
	assert(
		data.chapter == math.ceil(index / 8) and data.stage == (index - 1) % 8 + 1,
		"Eight-stage chapters"
	)
	if index % 8 == 0 then
		assert(data.finale, "Every eighth puzzle is a chapter test")
	end
	assert(not E.place(game, 2, 2, "L"), "Elbow no longer offered")
	for _, obstacle in ipairs(data.blocks) do
		assert(E.get(game, obstacle[1], obstacle[2]).kind == "X", "Stone obstacle retained")
	end
	local solved = E.new(index, true)
	local result = E.evaluate(solved)
	assert(
		result.win,
		"Bad Create-based reference solution at "
			.. index
			.. ": "
			.. result.correct
			.. "/"
			.. result.goals
			.. ", jam="
			.. tostring(result.jam)
	)
	for _, tile in ipairs(solved.tiles) do
		if not tile.fixed and tile.kind ~= "R" and tile.kind ~= "B" then
			assert(
				result.lights[tile.id].powered,
				"Reference contains idle player machinery at " .. index
			)
		end
	end
	goals = goals + result.goals
	for _, bonus in ipairs(E.challenges(solved, result)) do
		if bonus.id == "sealed" then
			assert(bonus.earned, "Reference should never contain unused parts at " .. index)
		end
	end
	local manual = E.new(index)
	for _, position in ipairs(data.removeRedstone or {}) do
		assert(E.remove(manual, position[1], position[2]), "Reference starting-part removal failed")
	end
	for _, part in ipairs(data.build) do
		assert(
			E.place(manual, part.x, part.y, part.kind, part.r),
			"Reference part placement failed on stage " .. index
		)
	end
	assert(E.evaluate(manual).win, "Building the reference manually failed at " .. index)
	local saved = E.snapshot(manual)
	local restored = E.new(index)
	assert(E.restore(restored, saved), "Snapshot restore failed at " .. index)
	assert(E.evaluate(restored).win, "Restored solution failed at " .. index)
	local before = #E.snapshot(restored)
	assert(
		not E.restore(restored, { { x = -1, y = 1, kind = "I", r = 0 } }),
		"Reject malformed saved coordinates"
	)
	eq(#E.snapshot(restored), before, "Invalid restore must be atomic")
	for _, part in ipairs(data.build) do
		local active = E.get(manual, part.x, part.y).engaged
		if E.remove(manual, part.x, part.y) then
			assert(
				E.place(manual, part.x, part.y, part.kind, part.r),
				"Refunded part cannot be reused"
			)
			assert(
				not active,
				"Redstone switches use neighboring blocks instead of per-part toggles"
			)
			break
		end
	end
	assert(E.evaluate(manual).win, "Replacing a part must preserve the solution")
end
assert(goals >= #E.levels, "Campaign must have meaningful objectives")
local unlimited = E.sandbox()
assert(unlimited.sandbox and #E.challenges(unlimited, E.evaluate(unlimited)) == 0)
assert(
	not E.evaluate(unlimited).win and E.evaluate(unlimited).goals == 0,
	"Sandbox never has a victory condition"
)
for _, kind in ipairs(E.order) do
	assert(unlimited.remaining[kind] == math.huge)
end
for x = 1, unlimited.width do
	for y = 1, unlimited.height do
		if x ~= 1 or y ~= 3 then
			assert(
				E.place(unlimited, x, y, E.order[(x + y) % #E.order + 1]),
				"Sandbox must place components without stock limits"
			)
		end
	end
end
assert(not E.place(unlimited, 1, 3, "I"), "Sandbox generator remains fixed")
local count = #E.snapshot(unlimited)
assert(
	count == unlimited.width * unlimited.height - 1,
	"Unlimited sandbox uses the full 10x10 board"
)
assert(E.restore(E.sandbox(), E.snapshot(unlimited)), "Sandbox layout restorable")
assert(
	E.sandbox(5, 5).width == 5 and E.sandbox(10, 10).height == 10,
	"Sandbox board size is configurable"
)
assert(not E.inside(6, 5, E.sandbox(5, 5)), "Board bounds track the current sandbox size")
print(
	"COGWORKS: all "
		.. #E.levels
		.. " Create-style references and "
		.. goals
		.. " goals, construction, redstone and sandbox validated."
)
