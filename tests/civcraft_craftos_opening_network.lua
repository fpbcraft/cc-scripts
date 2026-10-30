-- Natural generated V5 network opening; no terrain, resource, or technology grants.
local id = os.getComputerID()
assert(id == 0 or id == 1, "Use dedicated computers 0 and 1")
local emulator = assert(_G.periphemu, "Run in CraftOS-PC")
if not peripheral.isPresent("left") then
	assert(emulator.create("left", "modem", 1711700649))
end
rednet.open("left")
local protocol, controlProtocol = "fpbcraft.civcraft.v2", "civcraft-opening-network-observation"
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
local baseFile, baseNet = env.dofile, rednet
local controls, samples, metadata = {}, {}, nil
local pending, complete, created, newRequested, guestFounded
local sentEndRound, guestEndRound, moveRequested, endRequested
local function player(state, owner)
	for _, p in ipairs(state.players or {}) do
		if p.id == owner then
			return p
		end
	end
end
local function unit(state, unitID)
	for _, u in ipairs(state.units or {}) do
		if u.id == unitID then
			return u
		end
	end
end
local function ownCities(state)
	local count = 0
	for _, c in ipairs(state.cities or {}) do
		if c.owner == id then
			count = count + 1
		end
	end
	return count
end
local function control(kind, fields)
	fields = fields or {}
	fields.kind = kind
	assert(baseNet.send(id == 0 and 1 or 0, fields, controlProtocol))
end
local function issue(ui, action, values)
	values = values or {}
	values.confirmed = true
	ui:command(action, values)
	os.queueEvent("civcraft_state_changed")
end
local function writeTimings()
	local file = assert(fs.open("/civcraft-network-timings.json", "w"))
	file.write(textutils.serializeJSON({ computer = id, samples = samples, metadata = metadata }))
	file.close()
end
env.rednet = {}
for name, value in pairs(baseNet) do
	env.rednet[name] = value
end
function env.rednet.send(to, packet, outgoingProtocol)
	if
		id == 1
		and outgoingProtocol == protocol
		and type(packet) == "table"
		and packet.action ~= "join"
		and packet.action ~= "ackEvents"
		and packet.action ~= "eventHistory"
	then
		assert(not pending, "Guest commands must remain serialized")
		pending = { action = packet.action, sentAt = os.epoch("utc") }
		if packet.action == "move" then
			pending.unitID, pending.x, pending.y = packet.unitID, packet.x, packet.y
			if controls.measureMove then
				pending.token, pending.budget = "naturalOpeningMove", controls.measureMove.budget
			end
		elseif packet.action == "found" then
			pending.cityX, pending.cityY = packet.x, packet.y
		elseif packet.action == "end" then
			pending.fromRound = packet.round
			if controls.measureEnd then
				pending.token, pending.targetRound =
					"naturalOpeningRound", controls.measureEnd.targetRound
			end
		end
	end
	return baseNet.send(to, packet, outgoingProtocol)
end
local function matches(state, request)
	if not state then
		return false
	end
	if request.unitID then
		local u = unit(state, request.unitID)
		return u
			and u.x == request.x
			and u.y == request.y
			and (request.budget == nil or u.movesLeft == request.budget)
	elseif request.cityX then
		for _, city in ipairs(state.cities or {}) do
			if city.owner == id and city.x == request.cityX and city.y == request.cityY then
				return true
			end
		end
		return false
	elseif request.targetRound then
		return state.round >= request.targetRound
	elseif request.action == "end" then
		return player(state, id).ready or state.round > request.fromRound
	end
	return false
end
function env.rednet.receive(filter, timeout)
	local sender, packet, receivedProtocol = baseNet.receive(filter, timeout)
	if id == 1 and sender == 0 and filter == protocol and type(packet) == "table" and pending then
		if packet.type == "result" then
			assert(packet.ok, tostring(pending.action) .. ": " .. tostring(packet.message))
			pending.ackMillis = pending.ackMillis or os.epoch("utc") - pending.sentAt
		elseif packet.type == "state" and matches(packet.state, pending) then
			pending.snapshotMillis = pending.snapshotMillis or os.epoch("utc") - pending.sentAt
		end
	end
	return sender, packet, receivedProtocol
end
local function founding(ui, state, p)
	if ownCities(state) > 0 then
		return false
	end
	local systems = env.dofile("/games/civcraft/systems.lua")
	for _, u in ipairs(state.units or {}) do
		if u.owner == id and u.kind == "settler" and (u.movesLeft or 0) > 0 then
			local request = env.dofile("/games/civcraft/ai_settlement.lua")
				.order(state, p, u, systems)
			if request then
				issue(ui, request.action, request)
				return true
			end
		end
	end
	return false
end
local function workflow(ui, state, options)
	if id == 1 and pending then
		if not (pending.ackMillis and pending.snapshotMillis and matches(state, pending)) then
			return
		end
		if pending.token then
			samples[pending.token] = pending
			writeTimings()
			control(pending.token, { sample = pending })
		end
		pending = nil
	end
	if id == 0 and options.screen == "title" then
		if not newRequested then
			newRequested = true
			issue(ui, "newGame", { confirmed = true })
		end
		return
	end
	if not state then
		return
	end
	if state.phase == "lobby" then
		if id == 0 then
			if not created then
				created = true
				assert(emulator.create("1", "computer"))
			elseif player(state, 1) and #state.players < 3 then
				issue(ui, "addAI")
			elseif #state.players == 3 then
				issue(ui, "start")
			end
		end
		return
	end
	if state.phase ~= "game" then
		return
	end
	assert(state.round <= 10, "Initial network founding exceeded ten-round correctness bound")
	local p = assert(player(state, id))
	if id == 1 and controls.finish then
		complete = true
		issue(ui, "exit")
		return
	end
	if id == 0 and controls.finished then
		complete = true
		issue(ui, "exit")
		return
	end
	if p.ready then
		return
	end
	if ui:animating() then
		issue(ui, "skipPlayback")
		return
	end
	if founding(ui, state, p) then
		return
	end
	if id == 1 then
		if ownCities(state) > 0 and not guestFounded then
			guestFounded = true
			control("founded", { round = state.round })
		end
		if controls.measureMove and not samples.naturalOpeningMove then
			local systems, hex =
				env.dofile("/games/civcraft/systems.lua"), env.dofile("/games/civcraft/hex.lua")
			for _, u in ipairs(state.units) do
				if u.owner == id and u.kind == "warrior" then
					for _, choice in ipairs(hex.reachable(state, u, id, systems)) do
						if choice.cost == 1 and not choice.attack then
							controls.measureMove.budget = u.movesLeft - 1
							issue(
								ui,
								"move",
								{ unitID = u.id, sx = u.x, sy = u.y, x = choice.x, y = choice.y }
							)
							return
						end
					end
				end
			end
			error("Generated guest position has no legal one-point Warrior move")
		end
		if
			controls.measureEnd
			and not samples.naturalOpeningRound
			and guestEndRound ~= state.round
		then
			guestEndRound = state.round
			issue(ui, "end")
		elseif not guestFounded and guestEndRound ~= state.round then
			guestEndRound = state.round
			issue(ui, "end")
		end
	elseif ownCities(state) > 0 and controls.founded then
		if not moveRequested then
			moveRequested = true
			control("measureMove")
		elseif controls.naturalOpeningMove and not endRequested then
			endRequested = true
			control("measureEnd", { targetRound = state.round + 1 })
			issue(ui, "end")
		elseif controls.naturalOpeningRound then
			control("finish")
		end
	elseif sentEndRound ~= state.round then
		sentEndRound = state.round
		issue(ui, "end")
	end
end
env.dofile = function(path)
	local module = baseFile(path)
	if path == "/games/civcraft/match_lifecycle.lua" and id == 0 then
		local initialize = module.initialize
		module.initialize = function(state, ...)
			state.contentRules, state.mapSeed, state.mapSize, state.mapType, state.hostileMode =
				"balance5", 319497, "compact", "continents", "off"
			assert(#state.players == 3 and state.players[3].ai, "Expected host, guest and one AI")
			local result = initialize(state, ...)
			metadata = {
				seed = state.world.seed,
				width = state.world.width,
				height = state.world.height,
				contentRules = state.contentRules,
				players = #state.players,
				runtime = _G._HOST,
				lua = _VERSION,
				controlledTerrain = false,
			}
			local file = assert(fs.open("/civcraft-network-metadata.json", "w"))
			file.write(textutils.serializeJSON(metadata))
			file.close()
			control("metadata", metadata)
			return result
		end
	elseif path == "/games/civcraft/ui.lua" then
		local new = module.new
		module.new = function(display, dispatch)
			local ui = new(display, dispatch)
			local draw = ui.draw
			ui.draw = function(self, state, observer, options)
				draw(self, state, observer, options)
				workflow(self, state, options)
			end
			return ui
		end
	end
	return module
end
local deadline = os.startTimer(60)
local ok, why = pcall(function()
	parallel.waitForAny(function()
		assert(env.loadfile("/games/civcraft/game.lua"))(
			id == 0 and "host" or "join",
			id == 0 and "--new" or "0",
			"--debug"
		)
	end, function()
		while true do
			local sender, packet = baseNet.receive(controlProtocol)
			assert(sender == (id == 0 and 1 or 0) and type(packet) == "table")
			assert(packet.kind ~= "failed", tostring(packet.reason))
			controls[packet.kind] = packet
			if packet.kind == "metadata" then
				metadata = packet
			end
			os.queueEvent("civcraft_state_changed")
		end
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == deadline then
				error("Natural V5 network opening timeout")
			end
		end
	end)
	assert(complete, "Opening network exited before observation completed")
end)
local file = assert(fs.open("/civcraft-network-test.txt", "w"))
file.write(
	textutils.serialize({ passed = ok, reason = tostring(why), computer = id, controls = controls })
)
file.close()
if id == 1 then
	control(ok and "finished" or "failed", { reason = tostring(why) })
	while true do
		os.pullEventRaw()
	end
else
	if peripheral.isPresent("computer_1") then
		pcall(peripheral.call, "computer_1", "shutdown")
	end
	os.shutdown()
end
