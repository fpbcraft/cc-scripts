-- Three computers on an isolated emulated-modem network; generated campaigns only.
local reverseRace, observeTimings = false, false
for _, flag in ipairs({ ... }) do
	reverseRace = reverseRace or flag == "--reverse-race"
	observeTimings = observeTimings or flag == "--timings"
end
local timingSamples = {}
local raceReleased = false
local emulator = assert(_G.periphemu, "Run this test in CraftOS-PC")
local id = os.getComputerID()
assert(id >= 0 and id <= 2, "Use dedicated computers 0, 1 and 2")
local protocol, controlProtocol = "fpbcraft.civcraft.v2", "civcraft-native-test-v09"
if not peripheral.isPresent("left") then
	assert(emulator.create("left", "modem", 1711700649))
end
rednet.open("left")
if id > 0 then
	os.setComputerLabel("CLIENT " .. id)
end
local controls, results, joins, lastRequest, raceAnswers, reports = {}, {}, {}, {}, {}, {}
local phase, complete, created, createdTwo, addedAI = 0, false, false, false, false
local commandTag, sentMove, reportedMove, ended, sentSpoof, voted, blockedProbe =
	nil, false, false, false, false, false, false
local prepared, resumed = false, false
local expected, prediction, attackerID
local fallbackSent = false
local civStarted, civOwnSent, civReported = false, false, false
local blockReconnectUntil
if id == 1 and fs.exists("/network-reconnect.dat") then
	local file = assert(fs.open("/network-reconnect.dat", "r"))
	expected = textutils.unserialize(file.readAll())
	file.close()
end
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
local baseNet, baseFile = rednet, env.dofile
env.rednet = {}
for name, value in pairs(baseNet) do
	env.rednet[name] = value
end
local function trace(label)
	local file = assert(fs.open("/civcraft-network-progress.txt", "w"))
	file.write("computer " .. id .. ": " .. label)
	file.close()
end
local function unitFor(state, owner)
	for _, unit in ipairs(state.units or {}) do
		if unit.owner == owner and unit.kind == "warrior" then
			return unit
		end
	end
end
local function playerFor(state, owner)
	for _, player in ipairs(state.players or {}) do
		if player.id == owner then
			return player
		end
	end
end
local function sendControl(to, kind, values)
	values = values or {}
	values.kind = kind
	assert(baseNet.send(to, values, controlProtocol))
end
local function issue(ui, action, values, tag)
	commandTag = tag
	values = values or {}
	values.testTag = tag
	ui:command(action, values)
	os.queueEvent("civcraft_state_changed")
end
local function checkPrivate(state)
	for _, player in ipairs(state.players or {}) do
		if player.id ~= id then
			assert(
				not player.techs
					and not player.gold
					and not player.stockpile
					and not player.visible
					and not player.aiPlan
					and not player.mapMemory,
				"Foreign private fields crossed the modem"
			)
		end
	end
	assert(not state.eventJournal)
	if state.eventStream then
		assert(state.eventStream.observer == id)
	end
	if state.council and state.council.session and state.council.session.status == "voting" then
		assert(not state.council.session.election, "An open election exposed rival ballots")
	end
end
function env.rednet.receive(filter, timeout)
	local sender, packet, receivedProtocol = baseNet.receive(filter, timeout)
	if filter == protocol and type(packet) == "table" then
		if
			id == 0
			and sender == 1
			and packet.action == "join"
			and not controls.droppedFirstJoin
		then
			controls.droppedFirstJoin = true
			return env.rednet.receive(filter, timeout)
		end
		if id == 0 then
			lastRequest[sender] = packet
			if packet.action == "join" then
				joins[sender] = (joins[sender] or 0) + 1
			end
		elseif sender == 0 then
			if packet.type == "state" then
				checkPrivate(packet.state)
				for _, sample in pairs(timingSamples) do
					local unit = unitFor(packet.state, id)
					if
						not sample.snapshotMillis
						and unit
						and unit.id == sample.unitID
						and unit.x == sample.x
						and unit.y == sample.y
						and unit.movesLeft == sample.budget
					then
						sample.snapshotMillis = os.epoch("utc") - sample.sentAt
					end
				end
			elseif packet.type == "result" and commandTag then
				results[commandTag] = packet
				local sample = timingSamples[commandTag]
				if sample and not sample.ackMillis then
					assert(packet.ok, "Timed movement rejected")
					sample.ackMillis = os.epoch("utc") - sample.sentAt
				end
			end
		end
	end
	return sender, packet, receivedProtocol
end
function env.rednet.send(to, packet, outgoingProtocol)
	if
		id == 0
		and to == 1
		and outgoingProtocol == protocol
		and type(packet) == "table"
		and packet.type == "state"
		and blockReconnectUntil
		and (joins[1] or 0) <= blockReconnectUntil
	then
		controls.droppedReconnectState = true
		return true
	end
	if
		id == 0
		and outgoingProtocol == protocol
		and type(packet) == "table"
		and packet.type == "result"
	then
		local request = lastRequest[to] or {}
		if request.testTag == "race" then
			raceAnswers[to] = packet.ok
		elseif request.testTag == "spoof" then
			assert(not packet.ok, "A client moved another player's unit")
			controls.spoofRejected = true
		elseif request.testTag == "blockedDefender" then
			assert(not packet.ok, "The defender acted before the attacker's window ended")
			controls.defenderBlocked = true
		end
	end
	return baseNet.send(to, packet, outgoingProtocol)
end
local overlapStep, overlapJoin, overlapGold = 0, 0, nil
local splitVerified, mergeVerified = false, false
local stepSent, stepReported, roundReported = nil, nil, false
local function requestStep(target, token, action, values, budget)
	sendControl(
		target,
		"step",
		{ token = token, action = action, values = values or {}, budget = budget }
	)
end
local function stepResult(target, token, accepted)
	local result = controls["stepResult" .. target]
	if not result or result.token ~= token then
		return nil
	end
	assert(result.ok == accepted, token .. ": " .. tostring(result.message))
	return result
end
local function transition(step)
	overlapStep = step
	trace("overlap step " .. step)
end
local function clientStep(ui, state, unit)
	local step = controls.step
	if step then
		if stepSent ~= step.token then
			stepSent = step.token
			local action, values = step.action, step.values
			if action == "moveOne" then
				local Hex = env.dofile("/games/civcraft/hex.lua")
				local Systems = env.dofile("/games/civcraft/systems.lua")
				local found
				for _, choice in ipairs(Hex.reachable(state, unit, id, Systems)) do
					if choice.cost == 1 and not choice.attack then
						found = choice
						break
					end
				end
				assert(found, "Generated scene must have a legal one-point move")
				action, values =
					"move", { unitID = unit.id, sx = unit.x, sy = unit.y, x = found.x, y = found.y }
			elseif action == "probeWaiting" then
				action, values =
					"standby", { unitID = unit.id, x = unit.x, y = unit.y, value = false }
			end
			if
				observeTimings
				and id == 2
				and (step.token == "spendBeforeMerge" or step.token == "peacefulConcurrentMove")
			then
				timingSamples[step.token] = {
					sentAt = os.epoch("utc"),
					unitID = unit.id,
					x = values.x,
					y = values.y,
					budget = step.budget,
				}
			end
			issue(ui, action, values, step.token)
		elseif
			stepReported ~= step.token
			and results[step.token]
			and unit.movesLeft == step.budget
		then
			local peaceID
			for _, offer in ipairs(state.diplomacy.offers) do
				if offer.kind == "peace" and offer.status == "pending" then
					peaceID = offer.id
				end
			end
			if step.action ~= "diplomaticOffer" or peaceID then
				stepReported = step.token
				local result = results[step.token]
				local timing = timingSamples[step.token]
				if timing then
					assert(
						timing.ackMillis and timing.snapshotMillis,
						"Timed movement needs independent acknowledgement and snapshot"
					)
					local file = assert(fs.open("/civcraft-network-timings.json", "w"))
					file.write(textutils.serializeJSON({
						computer = id,
						reverseRace = reverseRace,
						samples = timingSamples,
					}))
					file.close()
				end
				sendControl(0, "stepResult" .. id, {
					token = step.token,
					ok = result.ok,
					message = result.message,
					budget = unit.movesLeft,
					round = state.round,
					peaceID = peaceID,
				})
			end
		end
	end
end
local function overlap(ui, state)
	local Scheduler = env.dofile("/games/civcraft/turn_scheduler.lua")
	local group = Scheduler.group(state, 0)
	if overlapStep == 0 then
		overlapGold = playerFor(state, 0).gold
		requestStep(2, "spendBeforeMerge", "moveOne", {}, 1)
		transition(1)
	elseif overlapStep == 1 and stepResult(2, "spendBeforeMerge", true) then
		requestStep(2, "mergeWars", "declareWar", { target = 1, kind = "surprise" }, 1)
		transition(2)
	elseif overlapStep == 2 and stepResult(2, "mergeWars", true) then
		assert(state.round == 2 and #group.order == 3 and group.active == 2)
		local peaceful = state.players[4]
		assert(peaceful and not Scheduler.group(state, peaceful.id) and peaceful.ready)
		assert(unitFor(state, 0).movesLeft == 2 and playerFor(state, 0).gold == overlapGold)
		mergeVerified, overlapJoin = true, joins[1]
		peripheral.call("computer_1", "reboot")
		transition(3)
	elseif overlapStep == 3 and joins[1] > overlapJoin then
		requestStep(1, "rejoinedWaiting", "probeWaiting", {}, 2)
		transition(4)
	elseif overlapStep == 4 and stepResult(1, "rejoinedWaiting", false) then
		requestStep(
			2,
			"negotiateSplit",
			"diplomaticOffer",
			{ target = 1, kind = "peace", terms = { duration = 5 } },
			1
		)
		transition(5)
	elseif overlapStep == 5 and stepResult(2, "negotiateSplit", true) then
		requestStep(
			1,
			"acceptSplit",
			"diplomaticReply",
			{ offerID = controls.stepResult2.peaceID, response = "accept" },
			2
		)
		transition(6)
	elseif overlapStep == 6 and stepResult(1, "acceptSplit", true) then
		assert(state.round == 2 and #group.order == 3 and group.active == 2)
		requestStep(2, "endMergedFirst", "end", { confirmed = true }, 1)
		transition(7)
	elseif overlapStep == 7 and stepResult(2, "endMergedFirst", true) and group.active == 1 then
		requestStep(1, "spendMergedSecond", "moveOne", {}, 1)
		transition(8)
	elseif overlapStep == 8 and stepResult(1, "spendMergedSecond", true) then
		requestStep(1, "endMergedSecond", "end", { confirmed = true }, 1)
		transition(9)
	elseif overlapStep == 9 and stepResult(1, "endMergedSecond", true) and group.active == 0 then
		assert(state.round == 2 and playerFor(state, 0).gold == overlapGold)
		local Hex = env.dofile("/games/civcraft/hex.lua")
		local unit, found = unitFor(state, 0)
		for _, choice in
			ipairs(Hex.reachable(state, unit, 0, env.dofile("/games/civcraft/systems.lua")))
		do
			if choice.cost == 1 and not choice.attack then
				found = choice
				break
			end
		end
		assert(found)
		issue(ui, "move", { unitID = unit.id, sx = unit.x, sy = unit.y, x = found.x, y = found.y })
		transition(10)
	elseif overlapStep == 10 and unitFor(state, 0).movesLeft == 1 then
		transition(11)
		issue(ui, "end", { confirmed = true })
	elseif overlapStep == 11 and state.round == 3 then
		assert(#group.order == 2 and group.active == 0 and not Scheduler.group(state, 2))
		assert(unitFor(state, 0).movesLeft == 2 and not state.scheduler.reactions[1])
		splitVerified = true
		requestStep(2, "peacefulConcurrentMove", "moveOne", {}, 1)
		transition(12)
	elseif overlapStep == 12 and stepResult(2, "peacefulConcurrentMove", true) then
		assert(group.active == 0 and unitFor(state, 0).movesLeft == 2 and state.round == 3)
		requestStep(1, "stillWaitingAfterSplit", "probeWaiting", {}, 2)
		transition(13)
	elseif overlapStep == 13 and stepResult(1, "stillWaitingAfterSplit", false) then
		requestStep(2, "normalPending", "declareWar", { target = 0, kind = "normal" }, 1)
		transition(14)
	elseif overlapStep == 14 and stepResult(2, "normalPending", true) then
		assert(state.round == 3 and #group.order == 2 and not Scheduler.group(state, 2))
		local pending = false
		for _, war in ipairs(state.diplomacy.wars) do
			if
				(war.a == 2 and war.b == 0 or war.a == 0 and war.b == 2)
				and not war.active
				and war.activatesRound == 4
			then
				pending = true
			end
		end
		assert(pending, "Normal war activated before the boundary")
		requestStep(2, "endPeaceful", "end", { confirmed = true }, 1)
		transition(15)
	elseif overlapStep == 15 and stepResult(2, "endPeaceful", true) then
		assert(group.active == 0 and unitFor(state, 0).movesLeft == 2)
		transition(16)
		issue(ui, "end", { confirmed = true })
	elseif overlapStep == 16 and group.active == 1 then
		requestStep(1, "finishBeforeNormal", "end", { confirmed = true }, 2)
		transition(17)
	elseif overlapStep == 17 and state.round == 4 and stepResult(1, "finishBeforeNormal", true) then
		assert(#group.order == 3 and group.active == 0)
		transition(18)
		issue(ui, "save")
	elseif overlapStep == 18 then
		local file = fs.open("/games/civcraft/data/save.dat", "r")
		if file then
			local saved = textutils.unserialize(file.readAll())
			file.close()
			if saved.round == 4 then
				assert(mergeVerified and splitVerified and #saved.scheduler.groups[1].order == 3)
				for owner = 0, 2 do
					local unit = unitFor(saved, owner)
					assert(unit.movesLeft == 2 and unit.movementAllowanceRound == 4)
				end
				sendControl(1, "finishTest")
				sendControl(2, "finishTest")
				transition(19)
			end
		end
	elseif overlapStep == 19 and controls.finished1 and controls.finished2 then
		complete = true
		trace("PASS: merged, reconnected, split and normal-war boundary")
		issue(ui, "exit")
	end
end

local function hostDraw(ui, state)
	if state.phase == "lobby" then
		if state.contentRules ~= "balance3" then
			issue(ui, "contentRules", { version = "balance3" })
			return
		end
		if not created then
			created = true
			assert(emulator.create("1", "computer"))
			trace("waiting for two real modem joins")
		elseif playerFor(state, 1) and not createdTwo then
			createdTwo = true
			assert(emulator.create("2", "computer"))
		elseif #state.players == 3 and not addedAI then
			addedAI = true
			issue(ui, "addAI")
		elseif #state.players == 4 and phase == 0 and controls.civChecked then
			phase = 1
			trace("starting four-faction game")
			issue(ui, "start")
		end
		return
	end
	if state.phase ~= "game" then
		return
	end
	if phase == 1 and reverseRace and raceAnswers[2] ~= nil and not raceReleased then
		raceReleased = true
		sendControl(1, "releaseRace")
	end
	if phase == 1 and reports[1] and reports[2] then
		assert(
			raceAnswers[1] ~= nil and raceAnswers[2] ~= nil and raceAnswers[1] ~= raceAnswers[2],
			"Exactly one competing move must succeed"
		)
		assert(reports[1].owner == reports[2].owner)
		local occupants = 0
		for _, unit in ipairs(state.units) do
			if unit.x == 7 and unit.y == 7 then
				occupants = occupants + 1
			end
		end
		assert(occupants == 1, "Simultaneous moves stacked enemy units")
		phase = 2
		trace("race passed; ending remote turns")
		sendControl(1, "raceDone")
		sendControl(2, "raceDone")
	elseif
		phase == 2
		and playerFor(state, 1).ready
		and playerFor(state, 2).ready
		and controls.spoofRejected
	then
		phase = 3
		trace("voting after Ready through the modem")
		sendControl(2, "voteReady")
	elseif phase == 3 and controls.readyVote then
		assert(controls.readyVote.budget == reports[2].budget)
		phase = 4
		trace("declaring Surprise War against Ready defender")
		issue(ui, "declareWar", { target = 1, kind = "surprise" })
	elseif phase == 4 and state.scheduler.reactions[1] then
		phase = 5
		sendControl(1, "probeDefender")
		trace("checking blocked premature defender order")
	elseif phase == 5 and controls.defenderBlocked then
		local unit = assert(unitFor(state, 0))
		local Hex = env.dofile("/games/civcraft/hex.lua")
		local Systems = env.dofile("/games/civcraft/systems.lua")
		for _, move in ipairs(Hex.reachable(state, unit, 0, Systems)) do
			if move.attack and move.x == 6 and move.y == 6 then
				prediction = env.dofile("/games/civcraft/combat.lua")
					.predictOrder(state, unit, move, Systems)
			end
		end
		assert(prediction, "The public city forecast must exist")
		attackerID = unit.id
		phase = 6
		trace("attacking during first strike")
		issue(ui, "move", { unitID = unit.id, sx = unit.x, sy = unit.y, x = 6, y = 6 })
	elseif phase == 6 then
		local unit = assert(unitFor(state, 0))
		if unit.attackedRound == state.round then
			assert(unit.hp == prediction.attackerHP and unit.movesLeft == 1)
			local target
			for _, city in ipairs(state.cities) do
				if city.owner == 1 then
					target = city
				end
			end
			assert(target and target.hp == prediction.cityHP and target.wallHP == prediction.wallHP)
			phase = 7
			trace("using the attacker's remaining movement")
			issue(ui, "move", { unitID = unit.id, sx = unit.x, sy = unit.y, x = 5, y = 5 })
		end
	elseif phase == 7 and unitFor(state, 0).movesLeft == 0 then
		phase = 8
		issue(ui, "end", { confirmed = true })
		trace("waiting for defender response")
	elseif phase == 8 and state.scheduler.reactions[1] then
		local Scheduler = env.dofile("/games/civcraft/turn_scheduler.lua")
		if (Scheduler.group(state, 1) or {}).active == 1 then
			phase = 9
			issue(ui, "save")
			trace("saving an active response window")
		end
	elseif phase == 9 then
		local file = fs.open("/games/civcraft/data/save.dat", "r")
		if file then
			local saved = textutils.unserialize(file.readAll())
			file.close()
			if saved and saved.scheduler.reactions[1] and unitFor(saved, 0).movesLeft == 0 then
				assert(
					saved.round == 1
						and playerFor(saved, 1).ready
						and unitFor(saved, 1).movesLeft == reports[1].budget
				)
				phase = 10
				sendControl(1, "prepareReconnect")
				trace("preparing real client reboot")
			end
		end
	elseif phase == 10 and controls.prepared then
		phase = 11
		blockReconnectUntil = (joins[1] or 0) + 1
		peripheral.call("computer_1", "reboot")
		trace("client rebooted; waiting for reconnect")
	elseif phase == 11 and controls.reconnected and (joins[1] or 0) >= 2 then
		assert(controls.reconnected.budget == reports[1].budget)
		phase = 12
		sendControl(1, "respond")
		trace("ending restored response window")
	elseif phase == 12 and state.round == 2 and controls.done1 and controls.done2 then
		assert(
			controls.droppedFirstJoin
				and controls.droppedReconnectState
				and not state.scheduler.reactions[1]
				and unitFor(state, 0).movesLeft == 2
		)
		phase = 13
		overlap(ui, state)
	elseif phase == 13 then
		overlap(ui, state)
	end
end
local function clientDraw(ui, state)
	if state and state.phase == "lobby" and id == 1 and not expected then
		if not civStarted then
			civStarted = true
			issue(ui, "civ", { player = 1, id = "nomad" }, "civSpoof")
		elseif results.civSpoof and not civOwnSent then
			assert(not results.civSpoof.ok, "A guest changed the host civilization")
			civOwnSent = true
			issue(ui, "civ", { player = 2, id = "nomad" }, "civOwn")
		elseif results.civOwn and playerFor(state, id).civ == "nomad" and not civReported then
			assert(results.civOwn.ok, "A guest could not select its own civilization")
			civReported = true
			sendControl(0, "civChecked")
		end
		return
	end
	if not state or state.phase ~= "game" then
		return
	end
	local unit = assert(unitFor(state, id))
	if state.round >= 2 then
		clientStep(ui, state, unit)
	end
	if expected then
		if not resumed and state.round == 1 and state.scheduler.reactions[id] then
			assert(
				unit.id == expected.unitID
					and unit.movesLeft == expected.budget
					and playerFor(state, id).ready
			)
			assert(state.eventStream.lastSeq >= expected.eventSeq)
			resumed = true
			sendControl(0, "reconnected", { budget = unit.movesLeft })
			trace("response restored after reconnect")
		elseif resumed and controls.respond and not ended and state.round == 1 then
			ended = true
			issue(ui, "end", { confirmed = true }, "responseEnd")
		end
	else
		if not sentMove then
			if reverseRace and id == 1 and not controls.releaseRace then
				return
			end
			sentMove = true
			phase = 1
			trace("racing for shared tile")
			issue(ui, "move", { unitID = unit.id, sx = unit.x, sy = unit.y, x = 7, y = 7 }, "race")
		elseif not reportedMove and results.race then
			local owner
			for _, other in ipairs(state.units) do
				if other.x == 7 and other.y == 7 then
					owner = other.owner
				end
			end
			if owner ~= nil then
				if id == 1 and not results.race.ok then
					if not fallbackSent then
						assert(unit.movesLeft == 2)
						fallbackSent = true
						issue(
							ui,
							"move",
							{ unitID = unit.id, sx = unit.x, sy = unit.y, x = 8, y = 6 },
							"fallback"
						)
						return
					elseif not results.fallback or unit.x ~= 8 or unit.y ~= 6 then
						return
					end
					assert(results.fallback.ok)
				end
				assert(
					(owner == id) == results.race.ok
						and unit.movesLeft == ((results.race.ok or id == 1) and 1 or 2),
					"Race actor "
						.. id
						.. " owner "
						.. owner
						.. " accepted "
						.. tostring(results.race.ok)
						.. " movement "
						.. unit.movesLeft
				)
				reportedMove = true
				reports[id] = { owner = owner, budget = unit.movesLeft, unitID = unit.id }
				sendControl(0, "raceReport", reports[id])
				trace("race result confirmed")
			end
		elseif reportedMove and controls.raceDone and id == 2 and not sentSpoof then
			local foreign = assert(unitFor(state, 1))
			sentSpoof = true
			issue(ui, "move", {
				playerID = 1,
				unitID = foreign.id,
				sx = foreign.x,
				sy = foreign.y,
				x = foreign.x + 1,
				y = foreign.y,
			}, "spoof")
		elseif reportedMove and controls.raceDone and not ended and (id == 1 or results.spoof) then
			if id == 2 then
				assert(not results.spoof.ok)
			end
			ended = true
			issue(ui, "end", { confirmed = true }, "end")
		elseif id == 2 and controls.voteReady and not voted then
			assert(playerFor(state, id).ready)
			voted = true
			issue(
				ui,
				"councilVote",
				{ session = state.council.session.id, candidate = id },
				"readyVote"
			)
		elseif
			id == 2
			and results.readyVote
			and not prepared
			and state.council.session.ownElection
		then
			assert(results.readyVote.ok and state.council.session.ownElection.candidate == id)
			prepared = true
			sendControl(0, "readyVote", { budget = unit.movesLeft })
			trace("Ready ballot retained its action budget")
		elseif id == 1 and controls.probeDefender and not blockedProbe then
			blockedProbe = true
			issue(
				ui,
				"standby",
				{ unitID = unit.id, x = unit.x, y = unit.y, value = false },
				"blockedDefender"
			)
		elseif id == 1 and controls.prepareReconnect and not prepared then
			assert(results.blockedDefender and not results.blockedDefender.ok)
			prepared = true
			local data =
				{ unitID = unit.id, budget = unit.movesLeft, eventSeq = state.eventStream.lastSeq }
			local file = assert(fs.open("/network-reconnect.dat", "w"))
			file.write(textutils.serialize(data))
			file.close()
			sendControl(0, "prepared")
			trace("saved client expectation before reboot")
		end
	end
	if state.round == 2 and not roundReported then
		assert(unit.movesLeft == 2 and not state.scheduler.reactions[id])
		roundReported = true
		sendControl(
			0,
			"done" .. id,
			{ round = state.round, budget = unit.movesLeft, reconnect = expected ~= nil }
		)
	end
	if controls.finishTest and not complete then
		complete = true
		sendControl(0, "finished" .. id)
		trace("PASS")
		issue(ui, "exit")
	end
end
env.dofile = function(path)
	local module = baseFile(path)
	if path == "/games/civcraft/world.lua" and id == 0 then
		local generate = module.generate
		module.generate = function(...)
			local world = generate(...)
			local positions =
				{ { x = 4, y = 6 }, { x = 6, y = 6 }, { x = 5, y = 8 }, { x = 7, y = 8 } }
			for index = 1, #world.starts do
				world.starts[index] = positions[index]
			end
			for y = 4, 10 do
				for x = 3, 10 do
					local key = module.key(x, y)
					world.tiles[key] = "plains"
					world.geography[key] =
						{ biome = "plains", elevation = "flat", feature = "none" }
					world.landmarks[key] = nil
				end
			end
			return world
		end
	elseif path == "/games/civcraft/council.lua" and id == 0 then
		local advance = module.advance
		module.advance = function(state)
			if state.phase == "game" then
				state.players[1].techs.currency = true
			end
			return advance(state)
		end
	elseif path == "/games/civcraft/ui.lua" then
		local construct = module.new
		module.new = function(display, dispatch)
			local ui = construct(display, dispatch)
			local draw = ui.draw
			ui.draw = function(self, state, observer, options)
				draw(self, state, observer, options)
				if self:animating() then
					self:command("skipPlayback")
					os.queueEvent("civcraft_state_changed")
					return
				end
				self.panel = "context"
				if id == 0 then
					hostDraw(self, state)
				else
					clientDraw(self, state)
				end
			end
			return ui
		end
	end
	return module
end
local modemJoins = {}
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
			if type(packet) == "table" then
				if id == 0 then
					assert(sender == 1 or sender == 2)
					assert(
						packet.kind ~= "clientFailed",
						"Client failure: " .. tostring(packet.reason)
					)
					if packet.kind == "raceReport" then
						reports[sender] = packet
					else
						controls[packet.kind] = packet
					end
				else
					assert(sender == 0)
					controls[packet.kind] = packet
				end
				os.queueEvent("civcraft_state_changed")
			end
		end
	end, function()
		while true do
			local event = table.pack(os.pullEvent())
			local packet = event[5]
			if
				id == 0
				and event[1] == "modem_message"
				and type(packet) == "table"
				and packet.sProtocol == protocol
				and type(packet.message) == "table"
				and packet.message.action == "join"
			then
				modemJoins[#modemJoins + 1] =
					{ sender = packet.nSender, messageID = packet.nMessageID }
				local file = assert(fs.open("/network-join-ids.txt", "w"))
				file.write(textutils.serialize(modemJoins))
				file.close()
			end
			if event[1] == "timer" and event[2] == deadline then
				error("Network test timed out at phase " .. phase)
			end
		end
	end)
	assert(complete, "Network game exited before validation completed")
end)
local output = assert(fs.open("/civcraft-network-test.txt", "w"))
output.write(textutils.serialize({
	passed = ok,
	reason = tostring(why),
	computer = id,
	reverseRace = reverseRace,
	phase = phase,
	overlapStep = overlapStep,
	mergeVerified = mergeVerified,
	splitVerified = splitVerified,
	joins = joins,
	raceAnswers = raceAnswers,
	controls = id == 0 and controls or nil,
	reports = reports,
	attackerID = attackerID,
}))
output.close()
if id == 0 then
	for _, name in ipairs({ "computer_1", "computer_2" }) do
		if peripheral.isPresent(name) then
			pcall(peripheral.call, name, "shutdown")
		end
	end
else
	if not ok then
		sendControl(0, "clientFailed", { reason = tostring(why) })
	end
	-- Keep modem Lua states alive until the host has exited and written its result.
	-- CraftOS-PC may still deliver the host's final disconnect packets; shutting
	-- these computers down first can crash its native modem receive handler.
	while true do
		os.pullEventRaw()
	end
end
os.shutdown()
