-- Fault-injection probe for PR143 renderer upload recovery. Not device evidence.
local root = ""
local nativeDofile, oldDofile, oldColors = dofile, dofile, colors
local oldHost = _G._HOST
colors = { black = 32768 }
dofile = function(path)
	return nativeDofile(path:gsub("^/games/civcraft/", root .. "games/civcraft/"))
end
local Renderer = nativeDofile(root .. "games/civcraft/render.lua")
local buffer, frozen, draws = {}, false, 0
local failSecond = false
local failUnfreeze = false
local monitor = {
	getSize = function(mode)
		if mode == 2 then
			return 8, 64
		end
		return 4, 4
	end,
	setGraphicsMode = function() end,
	getPaletteColor = function()
		return 0, 0, 0
	end,
	setPaletteColor = function() end,
	setFrozen = function(value)
		if not value and failUnfreeze then
			error("injected unfreeze failure")
		end
		frozen = value
	end,
	drawPixels = function(_, y, rows)
		draws = draws + 1
		if failSecond and draws == 2 then
			error("injected second-strip failure")
		end
		for i, row in ipairs(rows) do
			buffer[y + i] = row
		end
	end,
}
local function run()
	local renderer = Renderer.new(monitor)
	assert(
		renderer.mode == "graphics" and renderer.ph == 64,
		"mock monitor must use bounded graphics geometry"
	)
	local a, b = {}, {}
	for y = 1, 64 do
		a[y], b[y] = string.rep("A", renderer.pw), string.rep("B", renderer.pw)
	end
	renderer:uploadGraphics(a)
	assert(not frozen, "successful upload should unfreeze")
	failSecond, draws = true, 0
	local ok, err = pcall(renderer.uploadGraphics, renderer, b)
	assert(
		not ok and tostring(err):match("injected second%-strip failure"),
		"second strip fault was not reached"
	)
	assert(not frozen, "failed strip upload should attempt unfreeze")
	-- A successful renderer must invalidate the row cache after a partial native write:
	-- replaying A must repair the first strip from B back to A.
	failSecond, draws = false, 0
	renderer:uploadGraphics(a)
	local wrong = 0

	for y = 1, 64 do
		if buffer[y] ~= a[y] then
			wrong = wrong + 1
		end
	end
	if wrong ~= 0 then
		print("FAIL: partial upload retry leaves " .. wrong .. " rows stale")
	else
		print("PASS: partial upload retry restores the complete prior frame")
	end

	-- A failed final unfreeze cannot be reported as successful with a trusted cache.
	failUnfreeze = true
	local cleanupOk, cleanupErr = pcall(renderer.uploadGraphics, renderer, b)
	local cleanupValid = not cleanupOk and renderer.lastGraphicsRows == nil
	if cleanupValid then
		print("PASS: unfreeze failure surfaces and invalidates upload cache")
	else
		print("FAIL: unfreeze failure was swallowed or left a trusted upload cache")
	end
	-- Cleanup must retain the original draw error when both native calls fail.
	failSecond, failUnfreeze, draws = true, true, 0
	local combinedOK, combinedError = pcall(renderer.uploadGraphics, renderer, a)
	assert(not combinedOK and tostring(combinedError):match("injected second%-strip failure"))
	assert(renderer.lastGraphicsRows == nil, "Combined native faults invalidate the upload cache")
	failUnfreeze = false
	monitor.setFrozen(false)

	-- A diagnostic callback must never prevent the native unfreeze attempt.
	renderer.trace = function(stage)
		if stage == "frame.unfreeze.begin" then
			error("injected diagnostic failure")
		end
	end
	draws = 0
	local tracedOK, tracedError = pcall(renderer.uploadGraphics, renderer, b)
	assert(not tracedOK and tostring(tracedError):match("injected second%-strip failure"))
	assert(not frozen and renderer.lastGraphicsRows == nil and renderer.traceFailures > 0)
	renderer.trace, failSecond = nil, false

	-- Optional freezing remains optional, including hosts rejecting the API.
	local setFrozen = monitor.setFrozen
	monitor.setFrozen = nil
	assert(pcall(renderer.uploadGraphics, renderer, a))
	assert(renderer.lastGraphicsRows == a)
	local rejected = 0
	monitor.setFrozen = function()
		rejected = rejected + 1
		error("Freezing unsupported")
	end
	assert(pcall(renderer.uploadGraphics, renderer, b))
	assert(renderer.lastGraphicsRows == b and rejected == 2)
	monitor.setFrozen = setFrozen
	print("PASS: original errors, diagnostic failures and optional freezing preserve cleanup")
	return wrong == 0 and cleanupValid
end

-- Restore globals for callers that load this probe into an existing Lua state.
local ok, result = pcall(run)
dofile, colors, _G._HOST = oldDofile, oldColors, oldHost
if not ok then
	error(result, 0)
end
if not result then
	error("one or more upload recovery expectations failed", 0)
end
