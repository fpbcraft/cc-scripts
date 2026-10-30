-- Fault-injection probe for cooperative GC/wait instrumentation. Not device evidence.
local root = ""
local oldHost, oldGC = _G._HOST, collectgarbage
local oldEpoch, oldQueue, oldPull = os.epoch, os.queueEvent, os.pullEvent
local oldStart, oldCancel = os.startTimer, os.cancelTimer
local oldDofile = dofile
local events, trace, clock, timerCancelled = {}, {}, 100, nil
_G._HOST = "CraftOS-PC v2.8.3"
dofile = function(path)
	return oldDofile(path:gsub("^/games/civcraft/", root .. "games/civcraft/"))
end
os.epoch = function()
	return clock
end
collectgarbage = function(command)
	assert(command == "collect")
	clock = clock + 125 -- deterministic simulated slow-GC interval
	return true
end
os.startTimer = function(delay)
	assert(delay == 0.05)
	return 777
end
os.cancelTimer = function(id)
	timerCancelled = id
end
os.queueEvent = function(name, token)
	assert(name == "civcraft_render_yield")
	events[#events + 1] = { "mouse_click", 1, 8, 9 }
	events[#events + 1] = { "rednet_message", 7, { action = "snapshot" }, "protocol" }
	events[#events + 1] = { name, token }
end
os.pullEvent = function()
	local event = table.remove(events, 1)
	assert(event, "mock event queue unexpectedly empty")
	return table.unpack(event)
end
local function run()
	local Cooperative = oldDofile(root .. "games/civcraft/cooperative.lua")
	local runtime = {
		trace = function(stage, detail)
			trace[#trace + 1] = { stage, detail, clock }
		end,
	}
	Cooperative.checkpoint(runtime, true, true)
	local stages = {}
	for _, row in ipairs(trace) do
		stages[#stages + 1] = row[1]
	end
	local function index(stage)
		for i, value in ipairs(stages) do
			if value == stage then
				return i
			end
		end
	end
	assert(index("gc.begin") and index("gc.end"), "missing distinct GC trace boundaries")
	assert(
		index("yield.wait.begin") and index("yield.wait.end"),
		"missing distinct event-wait trace boundaries"
	)
	assert(index("yield.begin") < index("gc.begin") and index("gc.begin") < index("gc.end"))
	assert(
		index("gc.end") < index("yield.wait.begin")
			and index("yield.wait.begin") < index("yield.wait.end")
	)
	assert(index("yield.wait.end") < index("yield.end"))
	local gcStart, gcEnd
	for _, row in ipairs(trace) do
		if row[1] == "gc.begin" then
			gcStart = row[3]
		end
		if row[1] == "gc.end" then
			gcEnd = row[3]
		end
	end
	assert(gcEnd - gcStart == 125, "GC duration trace should expose injected 125ms stall")
	assert(
		timerCancelled == 777 and #runtime.pendingEvents == 2,
		"click and network event must remain queued"
	)
	local first = table.remove(runtime.pendingEvents, 1)
	local second = table.remove(runtime.pendingEvents, 1)
	assert(
		first[1] == "mouse_click" and second[1] == "rednet_message",
		"pending input order changed"
	)
	print("PASS: GC and wait stages are separated; slow-GC duration and input order are visible")
end

-- Restore globals for callers that load this probe into an existing Lua state.
local ok, err = pcall(run)
dofile, _G._HOST, collectgarbage = oldDofile, oldHost, oldGC
os.epoch, os.queueEvent, os.pullEvent = oldEpoch, oldQueue, oldPull
os.startTimer, os.cancelTimer = oldStart, oldCancel
if not ok then
	error(err, 0)
end
