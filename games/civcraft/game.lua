-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/games/civcraft/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/civcraft" then
	-- selene: allow(undefined_variable) -- Selene misidentifies chunk-level varargs.
	return bootstrap().run("/games/civcraft", "game.lua", _ENV, ...)
end
-- CIVCRAFT: Railbreak-style 4X with local hotseat or rednet networking
-- Host: /games/civcraft/game.lua host [--new]  Join: /games/civcraft/game.lua join [host ID]
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local args = { ... }
local MODE = args[1] or "local"
local PROTOCOL = "fpbcraft.civcraft.v2"
local localMode = MODE == "local"
local SAVE = "/games/civcraft/data/save.dat"
local debugging = false
for _, arg in ipairs(args) do
	if arg == "--debug" then
		debugging = true
	end
end
local function trace(stage, detail)
	if not debugging then
		return
	end
	local path = "/games/civcraft/data/debug.log"
	if not fs.exists("/games/civcraft/data") then
		fs.makeDir("/games/civcraft/data")
	end
	if fs.exists(path) and fs.getSize(path) > 131072 then
		if fs.exists(path .. ".previous") then
			fs.delete(path .. ".previous")
		end
		fs.move(path, path .. ".previous")
	end
	local file = fs.open(path, "a")
	if file then
		local now = os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
		file.writeLine(tostring(now) .. " " .. stage .. " " .. tostring(detail or ""))
		file.close()
	end
end
trace("session.begin", MODE)
local slot = 1
local mapTypes = { "continents", "archipelago", "pangaea", "highlands" }
local function modem()
	for _, side in ipairs(peripheral.getNames()) do
		if peripheral.getType(side) == "modem" then
			if not rednet.isOpen(side) then
				rednet.open(side)
			end
			return true
		end
	end
	return false
end
local function screen()
	local best, bestArea, bestSide = nil, 0, nil
	for _, side in ipairs(peripheral.getNames()) do
		if peripheral.getType(side) == "monitor" then
			local m = peripheral.wrap(side)
			m.setTextScale(0.5)
			local w, h = m.getSize()
			if w * h > bestArea then
				best, bestArea, bestSide = m, w * h, side
			end
		end
	end
	return best or term.current(), bestSide
end
local display, displaySide = screen()
-- CraftOS can provide drag/wheel events for monitor windows; vanilla monitors use edge taps.
local previousMonitorMouse
if displaySide and config and config.get and config.set then
	local ok, value = pcall(config.get, "monitorsUseMouseEvents")
	if ok then
		previousMonitorMouse = value
		pcall(config.set, "monitorsUseMouseEvents", true)
	end
end
local Hex = dofile("/games/civcraft/hex.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Actors = dofile("/games/civcraft/actor_lifecycle.lua")
local World = dofile("/games/civcraft/world.lua")
local mapSizes = World.sizeOrder
local Saves = dofile("/games/civcraft/saves.lua")
local Cooperative = dofile("/games/civcraft/cooperative.lua")
local Audio = dofile("/games/civcraft/audio.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local CommandQueue = dofile("/games/civcraft/command_queue.lua")
local Events = dofile("/games/civcraft/events.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Presentation = dofile("/games/civcraft/presentation.lua")
local Snapshots = dofile("/games/civcraft/snapshots.lua")
local view
local bootstrapWork = { trace = trace }
local function checkpoint()
	Cooperative.checkpoint(view and view.r or bootstrapWork, false, true)
end
Systems.checkpoint, World.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint
local audio = Audio.new()
local stateRevision = 0
local commandQueue = CommandQueue.new(function()
	stateRevision = stateRevision + 1
	if os.queueEvent then
		os.queueEvent("civcraft_state_changed")
	end
end)
local campaignCounter = 0
local function newCampaignID()
	campaignCounter = campaignCounter + 1
	local stamp = os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000000)
	return tostring(stamp) .. ":" .. campaignCounter
end
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local pumpActors = function() end
local W, H = Hex.width, Hex.height
local state
local turnProgress = function() end
local function newGame()
	return Lifecycle.newLobby(newCampaignID(), "balance4")
end
state = newGame()
local hasHumanSave = false
local function log(s)
	table.insert(state.logs, 1, s)
	while #state.logs > 5 do
		table.remove(state.logs)
	end
end

local function player(id)
	for i, p in ipairs(state.players) do
		if p.id == id then
			return p, i
		end
	end
end
local function save()
	trace("save.begin", state.round)
	World.reveal(state, Hex, Systems)
	local saved
	if localMode then
		saved = Saves.save(slot, state)
	else
		saved = Saves.writeFile(SAVE, state)
	end
	if saved then
		hasHumanSave = true
	end
	trace("save.end")
end
local function initMap()
	Lifecycle.initialize(state)
	W, H = state.world.width, state.world.height
	pumpActors()
	log("Game started: " .. #state.players .. " civilizations")
	save()
end
local function winner(advance)
	if state.ruleset == "create" then
		Victory.check(state, advance)
		return
	end
	local lead, best = nil, -1
	for _, p in ipairs(state.players) do
		local cities = 0
		for _, c in ipairs(state.cities) do
			if c.owner == p.id then
				cities = cities + 1
			end
		end
		local researched = 0
		for _ in pairs(p.techs or {}) do
			researched = researched + 1
		end
		local score = cities * 20 + researched * 8 + (p.science or 0)
		if score > best then
			lead, best = p, score
		end
		if cities >= 8 then
			state.winner = p.name
			state.phase = "over"
			return
		end
	end
	if state.round > 90 then
		state.winner = lead and lead.name
		state.phase = "over"
	end
end
local function nextTurn()
	trace("round.begin", state.round)
	turnProgress("PROCESSING ROUND", "Starting round resolution")
	Lifecycle.advance(state, function(stage)
		trace("round.stage", stage)
		turnProgress("PROCESSING ROUND", stage)
	end)
	winner(true)
	pumpActors()
	log("Round " .. state.round)
	save()
	trace("round.end", state.round)
end
pumpActors = function()
	Actors.pump(state, {
		before = function(_, participant)
			turnProgress("AI TAKING ITS TURN", participant.name)
			trace("ai.begin", participant.name)
		end,
		after = function(_, participant)
			trace("ai.end", participant.name)
		end,
	})
end
local function apply(id, req)
	local p = player(id)
	if not p then
		return false, "You are not registered"
	end
	local current, reason = Actions.validateIntent(state, req)
	if not current then
		return false, reason
	end
	if req.action == "civ" then
		return CampaignRules.selectCivilization(state, id, req, Systems.civs)
	end
	if req.action == "save" then
		if state.phase ~= "game" and state.phase ~= "over" then
			return false, "Game not running"
		end
		save()
		return true, "Game saved"
	end
	if req.action == "aiDifficulty" then
		return Difficulty.configure(state, id, req)
	end
	if
		req.action == "gameSpeed"
		or req.action == "toggleVictory"
		or req.action == "contentRules"
	then
		return CampaignRules.configure(state, id, req)
	end
	if req.action == "addAI" or req.action == "removeAI" then
		if state.phase ~= "lobby" or id ~= state.players[1].id then
			return false, "Host lobby only"
		end
		if req.action == "addAI" then
			if #state.players >= 4 then
				return false, "Four civilizations maximum"
			end
			local aiID = -2000000000
			while player(aiID) do
				aiID = aiID - 1
			end
			local index = #state.players + 1
			state.players[index] = {
				id = aiID,
				name = "AI " .. index,
				ai = true,
				civ = Systems.civs[index].id,
				techs = {},
				ready = false,
				gameSpeed = state.gameSpeed,
			}
			return true
		end
		for index = #state.players, 1, -1 do
			if state.players[index].ai then
				table.remove(state.players, index)
				return true
			end
		end
		return false, "No AI civilization to remove"
	end
	if req.action == "hostileMode" and state.phase == "lobby" then
		if id ~= state.players[1].id then
			return false, "Host only"
		end
		state.hostileMode = ({ off = "standard", standard = "dangerous", dangerous = "off" })[state.hostileMode]
			or "standard"
		return true
	end
	if req.action == "start" then
		if id ~= state.players[1].id or state.phase ~= "lobby" then
			return false, "Host only"
		end
		if #state.players < 2 then
			return false, "Need 2 players"
		end
		initMap()
		return true
	end
	if state.phase ~= "game" then
		return false, "Game not running"
	end
	if
		req.action == "diplomaticReply"
		or req.action == "diplomaticCounter"
		or req.action == "councilVote"
		or req.action == "councilPropose"
	then
		local ok, why = Actions.apply(state, id, req, Systems)
		if ok then
			pumpActors()
			save()
		end
		return ok, why
	end
	local eligible, waiting = Scheduler.canAct(state, id)
	if not eligible then
		return false, waiting
	end
	if req.action == "declareWar" then
		local ok, why = Actions.apply(state, id, req, Systems)
		if ok then
			pumpActors()
			save()
		end
		return ok, why
	end
	if req.action == "end" then
		Lifecycle.finish(state, id)
		pumpActors()
		if Scheduler.complete(state) then
			nextTurn()
		else
			save()
		end
		return true
	end
	local ok, why = Actions.apply(state, id, req, Systems)
	if ok then
		if req.action == "diplomaticOffer" then
			pumpActors()
		end
		if state.ruleset ~= "create" then
			winner()
		end
		save()
	end
	return ok, why
end
local hasModem = not localMode and modem() or false
local myId = os.getComputerID and os.getComputerID() or 0
local hostId, localHost = nil, (MODE == "host" or localMode)
local joinRequest
if localHost then
	if localMode then
		local loaded = args[2] ~= "--new" and Saves.load(slot)
		if type(loaded) == "table" then
			state = Systems.migrate(World.migrate(loaded))
			state.campaignID = state.campaignID or newCampaignID()
			hasHumanSave = true
		end
	elseif fs.exists(SAVE) and args[2] ~= "--new" then
		local h = fs.open(SAVE, "r")
		if h then
			local loaded = textutils.unserialize(h.readAll())
			h.close()
			if type(loaded) == "table" and loaded.version then
				state = Systems.migrate(World.migrate(loaded))
				state.campaignID = state.campaignID or newCampaignID()
				hasHumanSave = true
			end
		end
	elseif args[2] == "--new" and fs.exists(SAVE) then
		fs.delete(SAVE)
	end
	if state.world then
		W, H = state.world.width, state.world.height
	end
	if localMode then
		-- Local players receive distinct persistent IDs on a single computer.
		if #state.players == 0 then
			for i = 1, 2 do
				table.insert(
					state.players,
					{ id = myId * 16 + i, name = "PLAYER " .. i, ready = false }
				)
			end
		end
		state.activeIndex = math.max(1, math.min(#state.players, state.activeIndex or 1))
	else
		if not player(myId) then
			if state.phase ~= "lobby" then
				error("Save belongs to another host. Run host --new for a new match")
			end
			table.insert(state.players, { id = myId, name = "P1", ready = false })
		end
	end
	hostId = myId
	if hasModem then
		rednet.host(PROTOCOL, "CIVCRAFT-" .. myId)
	end
else
	assert(hasModem, "A wired/wireless modem is required to join")
	hostId = tonumber(args[2])
	if not hostId then
		print("Searching for a CIVCRAFT host...")
		hostId = rednet.lookup(PROTOCOL)
	end
	assert(hostId, "No game found; use join <host computer ID>")
	joinRequest = { action = "join", name = os.getComputerLabel() or ("Computer " .. myId) }
	rednet.send(hostId, joinRequest, PROTOCOL)
end
Systems.migrate(state)
Diplomacy.migrate(state)
state.campaignID = state.campaignID or newCampaignID()
World.reveal(state, Hex, Systems)
local snapshot = localHost and state or nil
local message = "Tap a tile, then choose an action"
local handoff = false
local exitRequested = false
local appScreen = "title"
for _, argument in ipairs(args) do
	if argument == "--menu" then
		appScreen = "game"
	end
end
local deleteConfirm = nil
local launchMode, launchHost
local replayBaseline
local function baselineLoadedEvents()
	replayBaseline = { campaign = state.campaignID, observers = {} }
	for _, player in ipairs(state.players or {}) do
		replayBaseline.observers[player.id] = Events.forPlayer(state, player.id).lastSeq
	end
end
if hasHumanSave then
	baselineLoadedEvents()
end
local gamePaused = false
local UI = dofile("/games/civcraft/ui.lua")

local function activeID()
	if localMode then
		local index = math.max(1, math.min(#state.players, state.activeIndex or 1))
		return state.players[index] and state.players[index].id
	end
	return myId
end
local displaySnapshot, displayRevision, displayObserver
local function draw()
	if commandQueue.busy then
		return
	end
	trace(
		"draw.begin",
		appScreen
			.. " panel="
			.. tostring(view.panel)
			.. " pan="
			.. tostring(view.panX)
			.. ","
			.. tostring(view.panY)
			.. " zoom="
			.. tostring(view.zoomLevel)
	)
	local observer = localMode and activeID() or myId
	if localHost and (displayRevision ~= stateRevision or displayObserver ~= observer) then
		commandQueue:submit(function()
			displaySnapshot = Presentation.capture(state, observer)
			displayRevision, displayObserver = stateRevision, observer
		end, false)
	end
	local s = localHost and displaySnapshot or snapshot
	view:message(message)
	view:draw(s, observer, {
		handoff = handoff,
		localMode = localMode,
		host = localHost,
		hostID = hostId,
		screen = appScreen,
		report = true,
		paused = gamePaused,
		hasSave = hasHumanSave,
		slot = slot,
		slots = localMode and appScreen == "title" and Saves.list() or nil,
		deleteConfirm = deleteConfirm,
		replayBaseline = replayBaseline or (s and s.replayBaseline),
		audio = audio.enabled,
		music = audio.music,
		volume = audio.volume,
	})
	trace("draw.end")
end
local function dispatch(action, params)
	if action == "eventHistory" then
		local observer = localMode and activeID() or myId
		if localHost then
			view:receiveHistory(Events.history(state, observer, params.before), params.requestID)
		else
			rednet.send(hostId, {
				action = "eventHistory",
				before = params.before,
				requestID = params.requestID,
				campaignID = snapshot and snapshot.campaignID,
			}, PROTOCOL)
		end
		return
	end
	if action == "exit" then
		exitRequested = true
		return
	end
	if action == "remoteHost" or action == "remoteJoin" then
		if not modem() then
			message = "CONNECT A MODEM FIRST"
			return
		end
		if action == "remoteJoin" then
			launchHost = rednet.lookup(PROTOCOL)
			if not launchHost then
				message = "NO HOST FOUND"
				return
			end
		end
		launchMode = action == "remoteHost" and "host" or "join"
		exitRequested = true
		return
	end
	if action == "selectSlot" and localMode then
		local choice = tonumber(params and params.slot)
		if choice and choice >= 1 and choice <= Saves.count then
			slot = choice
			deleteConfirm = nil
			local loaded = Saves.load(slot)
			hasHumanSave = type(loaded) == "table"
			if hasHumanSave then
				state = Systems.migrate(World.migrate(loaded))
				Diplomacy.migrate(state)
				state.campaignID = state.campaignID or newCampaignID()
				if state.world then
					W, H = state.world.width, state.world.height
				end
			else
				state = newGame()
				Systems.migrate(state)
			end
			baselineLoadedEvents()
			view.observerPlayback, view.animationFrame = {}, nil
			World.reveal(state, Hex, Systems)
			message = "SLOT " .. slot .. " SELECTED"
		end
		return
	end
	if action == "deleteSlot" and localMode then
		if deleteConfirm == slot then
			Saves.delete(slot)
			state = newGame()
			hasHumanSave = false
			deleteConfirm = nil
			message = "SLOT CLEARED"
		else
			deleteConfirm = slot
			message = "TAP DELETE AGAIN TO CONFIRM"
		end
		return
	end
	if action == "hostileMode" and state.phase == "lobby" and localHost then
		state.hostileMode = ({ off = "standard", standard = "dangerous", dangerous = "off" })[state.hostileMode]
			or "standard"
		save()
		return
	end
	if action == "mapSize" and state.phase == "lobby" then
		local current = 1
		for i, n in ipairs(mapSizes) do
			if n == state.mapSize then
				current = i
			end
		end
		state.mapSize = mapSizes[current % #mapSizes + 1]
		return
	end
	if action == "mapType" and state.phase == "lobby" then
		local current = 1
		for i, k in ipairs(mapTypes) do
			if k == state.mapType then
				current = i
			end
		end
		state.mapType = mapTypes[current % #mapTypes + 1]
		return
	end
	if action == "mapSeed" and state.phase == "lobby" then
		state.mapSeed = (tonumber(state.mapSeed) or 12345) + 997
		return
	end
	if action == "newGame" then
		if hasHumanSave and not (params and params.confirmed) then
			view.titleMenu, view.titleOffset = "overwrite", 0
			return
		end
		replayBaseline = nil
		if localHost then
			state = newGame()
			Systems.migrate(state)
			hasHumanSave = false
			state.mapSeed = (
				(os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)) % 999999
			) + 1
			if localMode then
				for i = 1, 2 do
					table.insert(state.players, {
						id = myId * 16 + i,
						name = "PLAYER " .. i,
						ready = false,
						civ = Systems.civs[i].id,
						ai = false,
						techs = {},
					})
				end
				state.activeIndex = 1
			else
				table.insert(state.players, {
					id = myId,
					name = "P1",
					ready = false,
					civ = Systems.civs[1].id,
					ai = false,
					techs = {},
				})
			end
		end
		appScreen = "game"
		gamePaused = false
		return
	end
	if action == "continue" then
		if not hasHumanSave then
			message = "NO CAMPAIGN IN THIS SLOT"
			return
		end
		appScreen = "game"
		gamePaused = false
		return
	end
	if action == "audio" then
		audio:toggle(appScreen)
		return
	end
	if action == "music" then
		audio:toggleMusic(appScreen)
		return
	end
	if action == "volume" then
		audio:cycleVolume(appScreen)
		return
	end
	if action == "pause" then
		gamePaused = true
		return
	end
	if action == "resume" then
		gamePaused = false
		return
	end
	if action == "title" then
		if not localMode then
			if localHost then
				save()
			end
			launchMode, exitRequested = "local", true
			return
		end
		appScreen = "title"
		view.titleMenu, view.titleOffset = "main", 0
		gamePaused = false
		save()
		audio:update(appScreen)
		return
	end
	if action == "save" then
		if localHost then
			save()
			message = "GAME SAVED"
		else
			rednet.send(hostId, {
				action = "save",
				round = snapshot and snapshot.round,
				campaignID = snapshot and snapshot.campaignID,
			}, PROTOCOL)
			message = "SAVE REQUESTED"
		end
		return
	end
	if action == "civ" and state.phase == "lobby" then
		if localHost then
			local actor = localMode and state.players[1].id or myId
			local ok, why =
				CampaignRules.selectCivilization(state, actor, params or {}, Systems.civs)
			if ok then
				save()
			else
				message = why
			end
		else
			rednet.send(hostId, {
				action = "civ",
				player = params.player,
				id = params.id,
				campaignID = snapshot and snapshot.campaignID,
				round = snapshot and snapshot.round,
			}, PROTOCOL)
		end
		return
	end
	if action == "toggleAI" and state.phase == "lobby" and localMode then
		local p = state.players[params and params.player or 1]
		if p then
			local humans = 0
			for _, q in ipairs(state.players) do
				if not q.ai then
					humans = humans + 1
				end
			end
			if p.ai or humans > 1 then
				p.ai = not p.ai
				save()
			else
				message = "KEEP AT LEAST ONE HUMAN PLAYER"
			end
		end
		return
	end
	if action == "reveal" then
		handoff = false
		return
	end
	if
		localMode
		and state.phase == "lobby"
		and (action == "addPlayer" or action == "removePlayer")
	then
		if action == "addPlayer" and #state.players < 4 then
			local i = #state.players + 1
			table.insert(
				state.players,
				{ id = myId * 16 + i, name = "PLAYER " .. i, ready = false }
			)
			message = "PLAYER " .. i .. " ADDED"
			save()
		elseif action == "removePlayer" and #state.players > 2 then
			table.remove(state.players)
			message = "PLAYER REMOVED"
			save()
		else
			message = "CHOOSE TWO TO FOUR PLAYERS"
		end
		return
	end
	local req = params or {}
	req.action = action
	if localHost then
		local id = activeID()
		local ok, reason = apply(id, req)
		message = ok and (reason or "ORDER ACCEPTED") or tostring(reason)
		audio:effect(
			not ok and "error"
				or action == "move" and "move"
				or action == "end" and "turn"
				or action == "queue" and "build"
				or action == "researchTech" and "research"
				or "click"
		)
		if ok then
			hasHumanSave = true
		end
		if localMode and ok and action == "end" then
			-- AI orders ran before the full-round check in apply().
			local previousIndex = state.activeIndex or 1
			local nextIndex = previousIndex % #state.players + 1
			for _ = 1, #state.players do
				if
					Scheduler.canAct(state, state.players[nextIndex].id)
					and not state.players[nextIndex].ai
				then
					break
				end
				nextIndex = nextIndex % #state.players + 1
			end
			-- AIs never own the screen even immediately after nextTurn clears ready.
			if state.players[nextIndex].ai then
				nextIndex = state.activeIndex or 1
			end
			state.activeIndex = nextIndex
			handoff = state.phase == "game"
				and nextIndex ~= previousIndex
				and not state.players[nextIndex].ai
			save()
		end
	else
		req.round = snapshot and snapshot.round
		req.campaignID = snapshot and snapshot.campaignID
		rednet.send(hostId, req, PROTOCOL)
	end
end
view = UI.new(display, function(action, params)
	if action == "audio" or action == "music" or action == "volume" then
		dispatch(action, params)
		return
	end
	if localHost then
		local accepted, reason = commandQueue:submit(function()
			dispatch(action, params)
		end, action ~= "eventHistory")
		if not accepted then
			message = reason
		end
	else
		dispatch(action, params)
	end
end)
if view.r and debugging then
	view.r.trace = trace
end
turnProgress = function(title, detail)
	if view.turnProgress then
		view:turnProgress(title, detail)
	end
end
if view.r then
	view.r.onActivate = function()
		audio:effect("click")
	end
end
-- Keep the same checkpoint before and after renderer creation/settings changes.
Systems.checkpoint, World.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint
if bootstrapWork.pendingEvents then
	view.r.pendingEvents = view.r.pendingEvents or {}
	for _, event in ipairs(bootstrapWork.pendingEvents) do
		if event[1] == "rednet_message" and os.queueEvent then
			-- The server listener starts after bootstrap; let it receive early network traffic.
			os.queueEvent(table.unpack(event, 1, event.n))
		else
			view.r.pendingEvents[#view.r.pendingEvents + 1] = event
		end
	end
	bootstrapWork.pendingEvents = nil
end

local sendSnapshot = Snapshots.sender(tostring(myId) .. ":" .. newCampaignID())
local receiveSnapshot = Snapshots.receiver()
local acknowledged = {}
local publishedRevision = -1
local function sendState(id)
	local cursor = acknowledged[id]
	if cursor and cursor.campaign ~= state.campaignID then
		cursor = nil
	end
	local projected = World.forPlayer(state, id, cursor and cursor.seq)
	if projected then
		if replayBaseline and replayBaseline.campaign == state.campaignID then
			projected.replayBaseline = {
				campaign = state.campaignID,
				observers = { [id] = replayBaseline.observers[id] or 0 },
			}
		end
		rednet.send(id, sendSnapshot(id, projected), PROTOCOL)
	end
end
local function publish()
	if not hasModem or commandQueue.busy or publishedRevision == stateRevision then
		return
	end
	commandQueue:submit(function()
		local revision = stateRevision
		for _, p in ipairs(state.players) do
			if p.id ~= myId and not p.ai then
				sendState(p.id)
			end
		end
		publishedRevision = revision
	end, false)
end
local function server()
	while true do
		local id, req = rednet.receive(PROTOCOL)
		if type(req) == "table" then
			local accepted, reason = commandQueue:submit(function()
				if req.action == "join" then
					local p = player(id)
					if not p and state.phase == "lobby" and #state.players < 4 then
						table.insert(state.players, {
							id = id,
							name = tostring(req.name or ("P" .. (#state.players + 1))):sub(1, 10),
							ready = false,
						})
						log("Player joined: " .. id)
					end
					acknowledged[id] = nil
					sendState(id)
				elseif player(id) and req.action == "ackEvents" then
					if req.campaign == state.campaignID then
						local stream = Events.forPlayer(state, id)
						local seq = math.min(
							stream.lastSeq,
							math.max(0, math.floor(tonumber(req.seq) or 0))
						)
						local previous = acknowledged[id]
						if
							not previous
							or previous.campaign ~= state.campaignID
							or seq > previous.seq
						then
							acknowledged[id] = { campaign = state.campaignID, seq = seq }
						end
					end
				elseif player(id) and req.action == "eventHistory" then
					local reply = Events.historyReply(state, id, req)
					if reply then
						rednet.send(id, reply, PROTOCOL)
					end
				elseif player(id) then
					local ok, why = apply(id, req)
					rednet.send(
						id,
						{ type = "result", ok = ok, message = why or (ok and "Order accepted") },
						PROTOCOL
					)
				end
			end, req.action ~= "ackEvents" and req.action ~= "eventHistory")
			if not accepted then
				rednet.send(id, { type = "result", ok = false, message = reason }, PROTOCOL)
			end
			if req.action ~= "ackEvents" and req.action ~= "eventHistory" then
				publish()
			end
		end
	end
end
local function clientListener()
	local ackCampaign, ackSeq
	while true do
		local id, packet = rednet.receive(PROTOCOL, not snapshot and 1 or nil)
		if id == nil and not snapshot then
			rednet.send(hostId, joinRequest, PROTOCOL)
		elseif id == hostId and type(packet) == "table" then
			local changed = false
			if packet.type == "state" then
				local accepted, cursor = receiveSnapshot:accept(packet, myId)
				if accepted then
					snapshot = accepted
					changed = true
					if
						cursor and (ackCampaign ~= accepted.campaignID or cursor > (ackSeq or -1))
					then
						rednet.send(
							hostId,
							{ action = "ackEvents", campaign = accepted.campaignID, seq = cursor },
							PROTOCOL
						)
						ackCampaign, ackSeq = accepted.campaignID, cursor
					end
				end
			elseif packet.type == "eventHistory" then
				changed = view:receiveHistory(packet.history, packet.requestID)
			elseif packet.type == "result" then
				message =
					tostring(packet.message or (packet.ok and "Order accepted" or "Order rejected"))
				changed = true
			end
			if changed then
				os.queueEvent("civcraft_state_changed")
			end
		end
	end
end
local function ui()
	local resizeTimer, frameTimer, animationTimer
	local displayTimer = os.startTimer and os.startTimer(0.25)
	draw()
	audio:update(appScreen)
	while not exitRequested do
		local e, a, b, c, d
		if view.r and view.r.pullEvent then
			e, a, b, c, d = view.r:pullEvent()
		else
			e, a, b, c, d = os.pullEvent()
		end
		if e ~= "timer" then
			trace("event", e)
		end
		if view.conversationEvent and view:conversationEvent(e, a, b) then
			draw()
		elseif e == "monitor_touch" and display ~= term.current() and a == displaySide then
			view:tap(b, c)
			draw()
		elseif e == "mouse_click" and (not d or d == displaySide) then
			view:pointerDown(b, c)
			if not view.pointerStart then
				draw()
			end
		elseif e == "mouse_drag" and (not d or d == displaySide) then
			view:drag(b, c)
			if not frameTimer then
				frameTimer = os.startTimer(0.03)
			end
		elseif e == "mouse_scroll" and (not d or d == displaySide) then
			view:scroll(a, b, c)
			draw()
		elseif e == "mouse_up" and (not d or d == displaySide) then
			view:pointerUp()
			frameTimer = nil
			draw()
		elseif e == "civcraft_state_changed" then
			draw()
		elseif e == "term_resize" or e == "monitor_resize" then
			view:resize()
			draw()
			resizeTimer = os.startTimer and os.startTimer(0.15)
		elseif e == "timer" and a == audio.timer then
			audio:update(appScreen)
		elseif e == "timer" and a == frameTimer then
			frameTimer = nil
			draw()
		elseif e == "timer" and a == animationTimer then
			animationTimer = nil
			draw()
		elseif e == "timer" and a == displayTimer then
			local width, height = display.getSize()
			if view.r and (width ~= view.r.cw or height ~= view.r.ch) then
				view:resize()
				draw()
			end
			displayTimer = os.startTimer(0.25)
		elseif e == "timer" and a == resizeTimer then
			resizeTimer = nil
			view:resize()
			draw()
		elseif e == "key" and keys and (a == keys.q or a == keys.escape) then
			if view.settingsOpen then
				view:back()
			elseif a ~= keys.escape or not view:back() then
				gamePaused = not gamePaused
			end
			draw()
		end
		if view:animating() and not animationTimer then
			animationTimer = os.startTimer(0.05)
		end
		if localHost and hasModem then
			publish()
		end
	end
end
local completed, failure = pcall(function()
	if localHost and hasModem then
		parallel.waitForAny(server, ui)
	elseif localHost then
		ui()
	else
		parallel.waitForAny(clientListener, ui)
	end
end)
if localHost and hasModem then
	pcall(rednet.unhost, PROTOCOL)
end
view:close()

if previousMonitorMouse ~= nil then
	pcall(config.set, "monitorsUseMouseEvents", previousMonitorMouse)
end

if not completed then
	trace("error", failure)
	error(failure, 0)
end
trace("session.end")

if launchMode then
	if launchHost then
		shell.run("/games/civcraft/game.lua", launchMode, tostring(launchHost), "--menu")
	else
		shell.run("/games/civcraft/game.lua", launchMode, launchMode ~= "local" and "--menu" or "")
	end
end
