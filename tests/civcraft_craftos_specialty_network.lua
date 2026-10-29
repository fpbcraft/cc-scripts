-- Real generated cityless V5 startup and site orders on three emulated computers.
-- Post-founding fixture grants research, population, gold, stored food, basic
-- industry and owned claims; workers are assigned through the shared query.
-- terrain, resources, actor positions, site validation and production stay real.
-- A temporary unit-vision boost tests public foreign-city/site snapshots by
-- running the actual reveal and observer-projection code over the real map.
local reverse = ({ ... })[1] == "--reverse-race"
local computer = os.getComputerID()
assert(computer >= 0 and computer <= 2)
local emulator = assert(periphemu, "Run in CraftOS-PC")
if not peripheral.isPresent("left") then
	assert(emulator.create("left", "modem", 1711700651))
end
rednet.open("left")
local protocol, controlProtocol = "fpbcraft.civcraft.v2", "civcraft-native-specialties"
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
local baseFile, baseNet = env.dofile, rednet
local controls, results, lastRequest, joins = {}, {}, {}, {}
local phase, complete, authoritative, pendingTag = "lobby", false, nil, nil
local restartExpected
if fs.exists("/specialty-rejoin.dat") then
	local file = assert(fs.open("/specialty-rejoin.dat", "r"))
	restartExpected = textutils.unserialize(file.readAll())
	file.close()
end
local openingChecked = false
local foundSent, foundingMove, foundingRound = false, false, nil
local createdOne, createdTwo, setup = false, false, false
local sentStep, reportedStep, endedRound = nil, nil, nil
local snapshotSerial, sentExpectation = 0, nil
local publicSiteExpectationSnapshot
local foreignProjectExpectationSnapshot
local publicVisionGranted = false
local originalWarriorVision
local unseenSiteChecked = false
local foreignProjectID, foreignProjectProgress
local target, siteID, projectID, campaignID, restarted = nil, nil, nil, nil, false
local raceFirst = reverse and 2 or 1
local savedProgress
local function trace(message)
	local file = assert(fs.open("/specialty-network-progress.txt", "a"))
	file.writeLine(phase .. ": " .. message)
	file.close()
end
local function player(state, id)
	for _, p in ipairs(state.players or {}) do
		if p.id == id then
			return p
		end
	end
end
local function city(state, id)
	for _, c in ipairs(state.cities or {}) do
		if c.owner == id then
			return c
		end
	end
end
local function send(to, kind, values)
	values = values or {}
	values.kind = kind
	assert(baseNet.send(to, values, controlProtocol))
end
local function issue(ui, action, values, tag)
	trace("SEND " .. action .. " " .. tostring(tag))
	if tag then
		pendingTag = tag
	end
	values = values or {}
	values.testTag = tag
	ui:command(action, values)
	os.queueEvent("civcraft_state_changed")
end
local function advancePhase(nextPhase)
	phase = nextPhase
	trace(nextPhase)
	os.queueEvent("civcraft_state_changed")
end
local function private(state)
	for _, p in ipairs(state.players or {}) do
		if p.id ~= computer then
			assert(
				not p.techs
					and not p.gold
					and not p.stockpile
					and not p.aiPlan
					and not p.visible
					and not p.mapMemory
			)
		end
	end
	for _, c in ipairs(state.cities or {}) do
		if c.owner ~= computer then
			assert(
				not c.siteProjects
					and not c.sites
					and not c.focus
					and not c.project
					and not c.projectProgress
					and not c.familyAvailability
			)
		end
	end
	for _, site in pairs(state.world and state.world.specialtySites or {}) do
		assert(
			not site.progress and not site.sourceSiteId and not site.projectId and not site.reason,
			"Public site records cannot expose private investments or pause reasons"
		)
	end
	assert(not state.eventJournal)
end
local function assertPublicForeignSite(state)
	local expected = controls.publicSiteExpected
	if computer ~= 2 or not expected or controls.publicSiteObserved then
		return
	end
	if
		snapshotSerial <= publicSiteExpectationSnapshot
		or state.round < expected.round
		or state.campaignID ~= expected.campaignID
	then
		return
	end
	local key = expected.siteX .. ":" .. expected.siteY
	local site = state.world and state.world.specialtySites and state.world.specialtySites[key]
	if not site then
		return
	end
	local foreignCity
	local citySummary = {}
	for _, c in ipairs(state.cities or {}) do
		citySummary[#citySummary + 1] =
			table.concat({ tostring(c.id), tostring(c.owner), tostring(c.x), tostring(c.y) }, ":")
		if c.id == expected.cityID then
			foreignCity = c
			break
		end
	end
	assert(
		foreignCity
			and foreignCity.owner == 1
			and foreignCity.x == expected.cityX
			and foreignCity.y == expected.cityY,
		"Visible foreign city "
			.. tostring(expected.cityID)
			.. " must arrive in the observer snapshot; got "
			.. table.concat(citySummary, ",")
	)
	assert(
		site
			and site.id == expected.siteID
			and site.kind == "works"
			and site.x == expected.siteX
			and site.y == expected.siteY
			and site.city == expected.cityID
			and site.owner == 1,
		"Visible foreign site must arrive with its public identity and location"
	)
	assert(
		not site.progress and not site.sourceSiteId and not site.projectId and not site.reason,
		"Public foreign site cannot expose private investment details"
	)
	controls.publicSiteObserved = true
	send(0, "publicSiteObserved", { cityID = expected.cityID, siteID = expected.siteID })
end
local function assertForeignProjectRedacted(state)
	local expected = controls.foreignProjectExpected
	if computer ~= 2 or not expected or controls.foreignProjectObserved then
		return
	end
	if
		snapshotSerial <= foreignProjectExpectationSnapshot
		or state.round < expected.round
		or state.campaignID ~= expected.campaignID
	then
		return
	end
	assert(
		expected.projectKind == "knowledge"
			and expected.projectID > 0
			and expected.progress > 0
			and expected.siteID > 0,
		"The observer check must correspond to actual positive Knowledge project progress"
	)
	local foreignCity
	for _, c in ipairs(state.cities or {}) do
		if c.id == expected.cityID then
			foreignCity = c
			break
		end
	end
	assert(
		foreignCity
			and foreignCity.owner == 1
			and foreignCity.x == expected.cityX
			and foreignCity.y == expected.cityY,
		"Visible foreign city must remain in the pending-project snapshot"
	)
	assert(
		not foreignCity.siteProjects
			and not foreignCity.sites
			and not foreignCity.project
			and not foreignCity.projectProgress
			and not foreignCity.focus
			and not foreignCity.familyAvailability,
		"Foreign city snapshot cannot expose its active Knowledge project or focus"
	)
	local siteKey = expected.siteX .. ":" .. expected.siteY
	local site = state.world and state.world.specialtySites and state.world.specialtySites[siteKey]
	assert(
		site
			and site.id == expected.siteID
			and site.city == expected.cityID
			and site.owner == 1
			and not site.progress
			and not site.projectId
			and not site.sourceSiteId
			and not site.reason,
		"Completed public site cannot expose the active project's progress or source"
	)
	controls.foreignProjectObserved = true
	send(0, "foreignProjectObserved", {
		cityID = expected.cityID,
		projectID = expected.projectID,
		progress = expected.progress,
		siteID = expected.siteID,
	})
end
env.rednet = {}
for k, v in pairs(baseNet) do
	env.rednet[k] = v
end
function env.rednet.receive(filter, timeout)
	local sender, packet, received = baseNet.receive(filter, timeout)
	if filter == protocol and type(packet) == "table" then
		if computer == 0 then
			trace("RECEIVE " .. sender .. " " .. tostring(packet.action))
			lastRequest[sender] = packet
			if packet.action == "join" then
				joins[sender] = (joins[sender] or 0) + 1
			end
		elseif sender == 0 and packet.type == "state" then
			snapshotSerial = snapshotSerial + 1
		elseif sender == 0 and packet.type == "result" and pendingTag then
			results[pendingTag] = packet
			trace(pendingTag .. " ACK " .. tostring(packet.ok) .. ": " .. tostring(packet.message))
		end
	end
	return sender, packet, received
end
function env.rednet.send(to, packet, outgoing)
	if outgoing == protocol and type(packet) == "table" then
		trace("PACKET to " .. to .. " " .. tostring(packet.action or packet.type))
	end
	if
		computer == 0
		and outgoing == protocol
		and type(packet) == "table"
		and packet.type == "result"
	then
		local request = lastRequest[to] or {}
		if request.testTag then
			controls[request.testTag] = { ok = packet.ok, message = packet.message }
		end
	end
	return baseNet.send(to, packet, outgoing)
end
local function establish(ui, state)
	if not openingChecked then
		assert(not city(state, computer), "Every participant starts without a city")
		local settlers, guards, actors = 0, 0, 0
		for _, unit in ipairs(state.units or {}) do
			if unit.owner == computer then
				actors = actors + 1
				if unit.kind == "settler" then
					settlers = settlers + 1
				end
				if unit.kind == "warrior" then
					guards = guards + 1
				end
			end
		end
		assert(
			settlers == 1 and guards == 1 and actors == 2,
			"Generated V5 opening is one Settler and one Stone Guard"
		)
		openingChecked = true
	end
	if city(state, computer) then
		return true
	end
	if foundingRound ~= state.round then
		foundingRound = state.round
		foundSent = false
		foundingMove = false
	end
	local settler
	for _, u in ipairs(state.units or {}) do
		if u.owner == computer and u.kind == "settler" then
			settler = u
			break
		end
	end
	assert(settler, "Cityless generated opening must preserve a Settler")
	if foundSent then
		if results.found and not results.found.ok then
			error("Founding rejected: " .. tostring(results.found.message))
		end
		return false
	end
	trace(
		"settler "
			.. settler.id
			.. " "
			.. settler.x
			.. ","
			.. settler.y
			.. " moves "
			.. tostring(settler.movesLeft)
			.. " moved "
			.. tostring(foundingMove)
	)
	local Systems = env.dofile("/games/civcraft/systems.lua")
	local Settlement = env.dofile("/games/civcraft/ai_settlement.lua")
	if
		Settlement.value(state, player(state, computer), settler.x, settler.y, settler)
		and (settler.movesLeft or 0) > 0
	then
		foundSent = true
		issue(ui, "found", { unitID = settler.id, x = settler.x, y = settler.y }, "found")
	elseif not foundingMove and (settler.movesLeft or 0) > 0 then
		local order = Settlement.order(state, player(state, computer), settler, Systems)
		assert(
			order and order.action == "move",
			"Generated opening needs a reachable legal first city"
		)
		foundingMove = true
		issue(ui, order.action, order, "foundMove")
	end
	return false
end
local function step(to, token, action, values)
	send(to, "step", { token = token, action = action, values = values })
end
local function stepDone(id, token, accepted)
	local ack = controls[token]
	local observed = controls["observed" .. id]
	if not ack or not observed or observed.token ~= token then
		return false
	end
	assert(ack.ok == accepted, token .. ": " .. tostring(ack.message))
	return true
end
local function legalTarget(state, c, kind, exclude, unseenBy)
	local Sites = env.dofile("/games/civcraft/specialty_sites.lua")
	local World = env.dofile("/games/civcraft/world.lua")
	local p = player(state, c.owner)
	local observer = unseenBy and player(state, unseenBy)
	for y = math.max(1, c.y - 3), math.min(state.world.height, c.y + 3) do
		for x = math.max(1, c.x - 3), math.min(state.world.width, c.x + 3) do
			if
				(not exclude or x ~= exclude.x or y ~= exclude.y)
				and (not observer or not (observer.visible or {})[World.key(x, y)])
				and Sites.canPlace(state, p, c, kind, x, y)
			then
				return { x = x, y = y }
			end
		end
	end
	error("Generated city has no legal " .. kind .. " site")
end
local function configureFixture()
	local Hex = env.dofile("/games/civcraft/hex.lua")
	local World = env.dofile("/games/civcraft/world.lua")
	for _, p in ipairs(authoritative.players) do
		p.techs.engineering, p.techs.writing, p.techs.currency = true, true, true
		p.gold = 500
		local c = assert(city(authoritative, p.id))
		c.population = 7
		c.foodStore = 1000
		c.buildings.craftinghall, c.buildings.furnace, c.buildings.smithy = true, true, true
		p.techs.bronze, p.techs.metallurgy = true, true
		for y = math.max(1, c.y - 3), math.min(authoritative.world.height, c.y + 3) do
			for x = math.max(1, c.x - 3), math.min(authoritative.world.width, c.x + 3) do
				if
					Hex.distance(c.x, c.y, x, y) <= 3
					and not World.territoryCity(authoritative, Hex, x, y)
				then
					c.claimed[World.key(x, y)] = true
				end
			end
		end
	end
	local Systems = env.dofile("/games/civcraft/systems.lua")
	for _, c in ipairs(authoritative.cities) do
		if c.owner >= 0 then
			c.worked = nil
			Systems.ensureWorkers(authoritative, c)
		end
	end
	World.reveal(authoritative, Hex, Systems)
	target = legalTarget(authoritative, assert(city(authoritative, 1)), "works", nil, 2)
	target.city = city(authoritative, 1).id
	campaignID = authoritative.campaignID
end
local function hostDraw(ui, state)
	if state.phase == "lobby" then
		if state.contentRules ~= "balance5" then
			issue(ui, "contentRules", { version = "balance5" })
			return
		end
		if state.hostileMode ~= "off" then
			issue(ui, "hostileMode")
			return
		end
		if not createdOne then
			createdOne = true
			assert(emulator.create("1", "computer"))
			return
		end
		if player(state, 1) and not createdTwo then
			createdTwo = true
			assert(emulator.create("2", "computer"))
			return
		end
		if #state.players == 3 and phase == "lobby" then
			advancePhase("founding")
			issue(ui, "start")
		end
		return
	end
	assert(state.contentRules == "balance5")
	if phase == "founding" then
		if not setup then
			local capital = establish(ui, state)
			if capital and not controls.started1 then
				controls.started1 = true
				send(1, "foundNow")
			elseif capital and controls.founded1 and not controls.started2 then
				controls.started2 = true
				send(2, "foundNow")
			end
			if
				capital
				and city(authoritative, 1)
				and city(authoritative, 2)
				and controls.founded1
				and controls.founded2
			then
				setup = true
				configureFixture()
				advancePhase("fixture")
				issue(ui, "queue", {
					cityX = city(authoritative, 0).x,
					cityY = city(authoritative, 0).y,
					kind = "none",
				})
			end
		end
	elseif phase == "fixture" then
		local request =
			{ city = target.city, kind = "works", x = target.x, y = target.y, playerID = 1 }
		step(raceFirst, "race" .. raceFirst, "placeSite", request)
		advancePhase("raceFirst")
	elseif phase == "raceFirst" and stepDone(raceFirst, "race" .. raceFirst, raceFirst == 1) then
		local second = raceFirst == 1 and 2 or 1
		step(
			second,
			"race" .. second,
			"placeSite",
			{ city = target.city, kind = "works", x = target.x, y = target.y, playerID = 1 }
		)
		advancePhase("raceSecond")
	elseif
		phase == "raceSecond"
		and stepDone(
			raceFirst == 1 and 2 or 1,
			"race" .. (raceFirst == 1 and 2 or 1),
			raceFirst ~= 1
		)
	then
		local c = assert(city(authoritative, 1))
		siteID = c.project.id
		assert(authoritative.nextSiteId == siteID + 1 and c.siteProjects[siteID].progress == 0)
		step(
			1,
			"duplicate",
			"placeSite",
			{ city = c.id, kind = "works", x = target.x, y = target.y }
		)
		advancePhase("duplicate")
	elseif phase == "duplicate" and stepDone(1, "duplicate", false) then
		local c = city(authoritative, 1)
		assert(authoritative.nextSiteId == siteID + 1 and c.siteProjects[siteID].progress == 0)
		local count = 0
		for _ in pairs(c.siteProjects) do
			count = count + 1
		end
		assert(count == 1)
		local focus = env.dofile("/games/civcraft/specialty_sites.lua").allowance(authoritative, c)
		assert(
			focus.used == 1 and focus.reserved == 1,
			"Duplicate site orders cannot consume another focus slot"
		)
		send(2, "publicSiteExpected", {
			campaignID = authoritative.campaignID,
			cityID = c.id,
			cityX = c.x,
			cityY = c.y,
			round = authoritative.round,
			siteID = siteID,
			siteX = target.x,
			siteY = target.y,
		})
		advancePhase("production")
	elseif phase == "production" then
		local c = city(authoritative, 1)
		if c.sites and c.sites.works then
			assert(c.sites.works.id == siteID and not c.siteProjects[siteID])
			if controls.publicSiteObserved then
				local destination = legalTarget(authoritative, c, "knowledge", target)
				step(
					1,
					"pending",
					"placeSite",
					{ city = c.id, kind = "knowledge", x = destination.x, y = destination.y }
				)
				advancePhase("pending")
			elseif not publicVisionGranted then
				local observer = assert(player(authoritative, 2))
				local World = env.dofile("/games/civcraft/world.lua")
				local siteKey = World.key(target.x, target.y)
				assert(
					not (observer.visible or {})[siteKey],
					"The completed foreign site starts outside the observer's vision"
				)
				local unseen = assert(World.forPlayer(authoritative, 2))
				assert(
					unseen.world.specialtySites[siteKey] == nil,
					"Unseen completed foreign site must be absent from the observer projection"
				)
				unseenSiteChecked = true
				local Systems = env.dofile("/games/civcraft/systems.lua")
				originalWarriorVision = Systems.units.warrior.vision
				Systems.units.warrior.vision = authoritative.world.width
					+ authoritative.world.height
					+ 5
				World.reveal(authoritative, env.dofile("/games/civcraft/hex.lua"), Systems)
				assert(
					(observer.visible or {})[siteKey],
					"Controlled reveal must see the completed site"
				)
				local public = assert(World.forPlayer(authoritative, 2))
				local projectedSite = public.world.specialtySites[siteKey]
				local projectedCity
				for _, candidate in ipairs(public.cities) do
					if candidate.id == c.id then
						projectedCity = candidate
					end
				end
				assert(
					projectedCity
						and projectedCity.owner == 1
						and projectedSite
						and projectedSite.id == siteID,
					"Observer projection must expose the actual completed foreign city and site"
				)
				publicVisionGranted = true
				local hostCity = assert(city(authoritative, 0))
				issue(ui, "queue", {
					cityX = hostCity.x,
					cityY = hostCity.y,
					kind = "none",
				})
				advancePhase("publicSite")
			end
		elseif endedRound ~= state.round then
			endedRound = state.round
			send(1, "endRound", { round = state.round })
			send(2, "endRound", { round = state.round })
			issue(ui, "end", { confirmed = true })
		end
	elseif phase == "publicSite" and controls.publicSiteObserved then
		local c = assert(city(authoritative, 1))
		local destination = legalTarget(authoritative, c, "knowledge", target)
		step(
			1,
			"pending",
			"placeSite",
			{ city = c.id, kind = "knowledge", x = destination.x, y = destination.y }
		)
		advancePhase("pending")
	elseif phase == "pending" and stepDone(1, "pending", true) then
		projectID = city(authoritative, 1).project.id
		assert(projectID ~= siteID and city(authoritative, 1).siteProjects[projectID])
		advancePhase("pendingProduction")
	elseif phase == "pendingProduction" then
		local c = city(authoritative, 1)
		local pending = assert(
			c.siteProjects[projectID],
			"Second site must retain an unfinished production record"
		)
		if pending.progress > 0 then
			assert(
				pending.kind == "knowledge"
					and c.project
					and c.project.id == projectID
					and c.project.progress == pending.progress
			)
			if not controls.foreignProjectExpectedSent then
				foreignProjectID, foreignProjectProgress = projectID, pending.progress
				send(2, "foreignProjectExpected", {
					campaignID = authoritative.campaignID,
					cityID = c.id,
					cityX = c.x,
					cityY = c.y,
					projectKind = pending.kind,
					projectID = projectID,
					progress = pending.progress,
					round = authoritative.round,
					siteID = siteID,
					siteX = target.x,
					siteY = target.y,
				})
				controls.foreignProjectExpectedSent = true
				advancePhase("pendingVisibilityPrepare")
			end
		elseif endedRound ~= state.round then
			endedRound = state.round
			send(1, "endRound", { round = state.round })
			send(2, "endRound", { round = state.round })
			issue(ui, "end", { confirmed = true })
		end
	elseif phase == "pendingVisibilityPrepare" and controls.foreignProjectReady then
		local hostCity = assert(city(authoritative, 0))
		issue(ui, "queue", {
			cityX = hostCity.x,
			cityY = hostCity.y,
			kind = "none",
		})
		advancePhase("pendingVisibility")
	elseif phase == "pendingVisibility" and controls.foreignProjectObserved then
		local c = assert(city(authoritative, 1))
		local pending = assert(c.siteProjects[projectID])
		assert(
			pending.kind == "knowledge"
				and pending.progress == foreignProjectProgress
				and pending.progress > 0
				and c.project
				and c.project.id == projectID
				and c.project.progress == pending.progress,
			"Private Knowledge progress must remain active through the observer check"
		)
		if originalWarriorVision then
			env.dofile("/games/civcraft/systems.lua").units.warrior.vision = originalWarriorVision
			originalWarriorVision = nil
		end
		savedProgress = pending.progress
		step(
			1,
			"pausePending",
			"queue",
			{ cityX = c.x, cityY = c.y, kind = "none", confirmed = true }
		)
		advancePhase("pausePending")
	elseif phase == "pausePending" and stepDone(1, "pausePending", true) then
		assert(not city(authoritative, 1).project)
		issue(ui, "save")
		advancePhase("saved")
	elseif phase == "saved" then
		local file = assert(fs.open("/games/civcraft/data/save.dat", "r"))
		local saved = textutils.unserialize(file.readAll())
		file.close()
		local c = city(saved, 1)
		assert(
			saved.campaignID == campaignID
				and c.sites.works.id == siteID
				and c.siteProjects[projectID]
		)
		advancePhase("restart")
		issue(ui, "exit")
	elseif phase == "restored" then
		local c = assert(city(authoritative, 1))
		assert(
			authoritative.campaignID == campaignID
				and c.sites.works.id == siteID
				and not c.project
				and c.siteProjects[projectID]
				and c.siteProjects[projectID].progress == savedProgress
		)
		send(1, "prepareRejoin", {
			siteID = siteID,
			projectID = projectID,
			campaignID = campaignID,
			progress = savedProgress,
		})
		advancePhase("rejoinPrepare")
	elseif phase == "rejoinPrepare" and controls.rejoinPrepared then
		peripheral.call("computer_1", "reboot")
		advancePhase("rejoining")
	elseif phase == "rejoining" and (joins[1] or 0) >= 2 and controls.rejoined1 then
		assert(controls.rejoined1.siteID == siteID and controls.rejoined1.projectID == projectID)
		send(1, "finish")
		send(2, "finish")
		advancePhase("finish")
	elseif phase == "finish" and controls.finished1 and controls.finished2 then
		complete = true
		issue(ui, "exit")
	end
end
local function acceptedSnapshot(state, own, todo)
	local expected = sentExpectation
	if
		not own
		or not expected
		or snapshotSerial <= expected.snapshot
		or state.round < expected.round
		or state.campaignID ~= expected.campaign
	then
		return false
	end
	local request = todo.values
	if todo.action == "queue" and request.kind == "none" then
		local retained = expected.project and (own.siteProjects or {})[expected.project.id]
		return not own.project
			and retained
			and retained.kind == expected.project.kind
			and retained.x == expected.project.x
			and retained.y == expected.project.y
			and retained.progress == expected.project.progress
	end
	if own.id ~= request.city then
		return false
	end
	if todo.action == "cancelSite" then
		return not (own.siteProjects or {})[request.projectId]
			and (
				not own.project
				or own.project.kind ~= "site"
				or own.project.id ~= request.projectId
			)
	end
	local selection = own.project
	local retained = selection
		and selection.kind == "site"
		and (own.siteProjects or {})[selection.id]
	if not retained then
		return false
	end
	if todo.action == "resumeSite" then
		return retained.id == request.projectId
	end
	return (todo.action == "placeSite" or todo.action == "redevelopSite")
		and retained.kind == request.kind
		and retained.x == request.x
		and retained.y == request.y
		and retained.sourceSiteId == request.siteId
		and retained.operation == (todo.action == "redevelopSite" and "redevelop" or "place")
		and not expected.ids[retained.id]
end
local function clientDraw(ui, state)
	if not state then
		return
	end
	private(state)
	assertPublicForeignSite(state)
	assertForeignProjectRedacted(state)
	trace(
		"view "
			.. tostring(state.phase)
			.. " cities "
			.. #(state.cities or {})
			.. " units "
			.. #(state.units or {})
	)
	if controls.finish then
		complete = true
		send(0, "finished" .. computer)
		issue(ui, "exit")
		return
	end
	if state.phase ~= "game" then
		return
	end
	if restartExpected then
		local c = city(state, computer)
		if
			c
			and c.sites
			and c.sites.works
			and c.siteProjects
			and c.siteProjects[restartExpected.projectID]
		then
			assert(
				state.campaignID == restartExpected.campaignID
					and c.sites.works.id == restartExpected.siteID
					and c.siteProjects[restartExpected.projectID].progress
						== restartExpected.progress
			)
			if not controls.rejoinReported then
				controls.rejoinReported = true
				send(0, "rejoined1", restartExpected)
			end
		end
		return
	end
	if not city(state, computer) then
		if controls.foundNow then
			establish(ui, state)
		end
		return
	end
	if not controls.foundReported then
		controls.foundReported = true
		send(0, "founded" .. computer)
	end
	local todo = controls.step
	if todo and sentStep ~= todo.token then
		sentStep = todo.token
		local own = city(state, computer)
		sentExpectation = {
			snapshot = snapshotSerial,
			round = state.round,
			campaign = state.campaignID,
			ids = {},
		}
		for id in pairs(own and own.siteProjects or {}) do
			sentExpectation.ids[id] = true
		end
		for _, site in pairs(own and own.sites or {}) do
			sentExpectation.ids[site.id] = true
		end
		local previous = own and own.project and (own.siteProjects or {})[own.project.id]
		if previous then
			sentExpectation.project = {
				id = previous.id,
				kind = previous.kind,
				x = previous.x,
				y = previous.y,
				progress = previous.progress,
			}
		end
		issue(ui, todo.action, todo.values, todo.token)
	elseif todo and results[todo.token] and reportedStep ~= todo.token then
		local own = city(state, computer)
		local coherent = not results[todo.token].ok or acceptedSnapshot(state, own, todo)
		if coherent then
			if computer == 1 and results[todo.token].ok then
				assert(own.focus)
				if todo.action ~= "queue" then
					assert(own.siteProjects[own.project.id])
				end
			end
			reportedStep = todo.token
			send(
				0,
				"observed" .. computer,
				{ token = todo.token, accepted = results[todo.token].ok }
			)
		end
	end
	local boundary = controls.endRound
	if boundary and state.round == boundary.round and endedRound ~= state.round then
		endedRound = state.round
		issue(ui, "end", { confirmed = true }, "end" .. state.round)
	end
	if controls.prepareRejoin and not controls.rejoinSaved then
		controls.rejoinSaved = true
		local file = assert(fs.open("/specialty-rejoin.dat", "w"))
		file.write(textutils.serialize(controls.prepareRejoin))
		file.close()
		send(0, "rejoinPrepared")
	end
end
env.dofile = function(path)
	local module = baseFile(path)
	if
		path == "/games/civcraft/world.lua"
		and computer == 0
		and not module.specialtyNetworkCapture
	then
		module.specialtyNetworkCapture = true
		local reveal = module.reveal
		module.reveal = function(state, ...)
			if state.phase == "game" and state.world then
				authoritative = state
			end
			return reveal(state, ...)
		end
	elseif path == "/games/civcraft/ui.lua" and not module.specialtyNetworkUI then
		module.specialtyNetworkUI = true
		local construct = module.new
		module.new = function(display, dispatch)
			local ui = construct(display, dispatch)
			local draw = ui.draw
			ui.draw = function(self, state, observer, options)
				draw(self, state, observer, options)
				if self:animating() then
					issue(self, "skipPlayback")
					return
				end
				if computer == 0 then
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
local deadline = os.startTimer(100)
local ok, why = pcall(function()
	parallel.waitForAny(function()
		if computer == 0 then
			assert(env.loadfile("/games/civcraft/game.lua"))("host", "--new", "--debug")
			assert(
				phase == "restart",
				"First host process must stop after an actual saved site campaign"
			)
			restarted = true
			phase = "restored"
			assert(env.loadfile("/games/civcraft/game.lua"))("host", "--debug")
		else
			assert(env.loadfile("/games/civcraft/game.lua"))("join", "0", "--debug")
		end
	end, function()
		while true do
			local sender, packet = baseNet.receive(controlProtocol)
			if type(packet) == "table" then
				assert(computer == 0 and (sender == 1 or sender == 2) or sender == 0)
				assert(packet.kind ~= "failed", "Client failure: " .. tostring(packet.reason))
				controls[packet.kind] = packet
				if packet.kind == "publicSiteExpected" then
					publicSiteExpectationSnapshot = snapshotSerial
				elseif packet.kind == "foreignProjectExpected" then
					foreignProjectExpectationSnapshot = snapshotSerial
					send(0, "foreignProjectReady", { projectID = packet.projectID })
				end
				os.queueEvent("civcraft_state_changed")
			end
		end
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == deadline then
				error("Timed out in " .. phase)
			end
		end
	end)
	assert(complete, "Game returned before validation finished")
end)
local file = assert(fs.open("/civcraft-specialty-network.txt", "w"))
file.write(textutils.serialize({
	passed = ok,
	reason = tostring(why),
	computer = computer,
	openingChecked = openingChecked,
	host = _G._HOST,
	profile = "balance5",
	hostileMode = authoritative and authoritative.hostileMode,
	savedProgress = savedProgress,
	phase = phase,
	reverseRace = reverse,
	restarted = restarted,
	siteID = siteID,
	projectID = projectID,
	foreignCityID = target and target.city,
	foreignCitySiteObserved = controls.publicSiteObserved ~= nil,
	foreignPendingProjectID = foreignProjectID,
	foreignPendingProjectProgress = foreignProjectProgress,
	foreignPendingProjectRedacted = controls.foreignProjectObserved ~= nil,
	unseenForeignSiteAbsent = unseenSiteChecked,
	joins = joins,
}))
file.close()
if computer == 0 then
	for _, name in ipairs({ "computer_1", "computer_2" }) do
		if peripheral.isPresent(name) then
			pcall(peripheral.call, name, "shutdown")
		end
	end
else
	if not ok then
		send(0, "failed", { reason = tostring(why) })
	end
	while true do
		os.pullEventRaw()
	end
end
os.shutdown()
