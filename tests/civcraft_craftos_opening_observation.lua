-- Fixed native usability workflow, not a tournament or calibration policy.
local native = dofile
native("/games/civcraft/module_cache.lua").install(_ENV)
native = dofile
local started, stage = os.epoch("utc"), "lobby"
local queued, stopped, actor, authoritative = false, false, nil, nil
local pendingInput, lastDecision, lastMetadata
local milestones, failures = {}, {}
local viewportBefore
local function record(kind, fields)
	fields = fields or {}
	fields.kind, fields.stage = kind, stage
	fields.elapsedMillis = os.epoch("utc") - started
	local f = assert(fs.open("/opening-observation.jsonl", "a"))
	f.writeLine(textutils.serializeJSON(fields))
	f.close()
end
local function milestone(name, state, detail)
	if not milestones[name] then
		milestones[name] = { round = state.round, detail = detail }
		record("milestone", { name = name, round = state.round, detail = detail })
	end
end
local function wake()
	os.queueEvent("term_resize")
end
local function point(view, x, y)
	if view.r.mode == "graphics" then
		return math.floor(view.r.ox + x * view.r.sx), math.floor(view.r.oy + y * view.r.sy)
	end
	return math.floor(x / 2 + 1), math.floor(y / 3 + 1)
end
local function tap(view, label)
	for _, b in ipairs(view.r.buttons or {}) do
		if b.label == label then
			local x, y = point(view, b.x + b.w / 2, b.y + b.h / 2)
			queued = true
			pendingInput = { label = label, since = os.epoch("utc") }
			os.queueEvent("mouse_click", 1, x, y)
			os.queueEvent("mouse_up", 1, x, y)
			os.queueEvent("opening_input_complete")
			return true
		end
	end
	return false
end
local function order(view, action, params)
	params = params or {}
	params.confirmed = true
	view:command(action, params)
	wake()
end
local function ownPlayer(state)
	for _, p in ipairs(state.players or {}) do
		if p.id == actor then
			return p
		end
	end
end
local function workflow(view, state, observer, options)
	if queued then
		return
	end
	if options.screen == "title" then
		if not tap(view, view.titleMenu == "new" and "CREATE CAMPAIGN" or "NEW CAMPAIGN") then
			tap(view, "NEXT")
		end
		return
	end
	if options.handoff then
		tap(view, "READY TO PLAY")
		return
	end
	if state.phase == "lobby" then
		if #state.players < 2 then
			order(view, "addAI")
		else
			order(view, "start")
		end
		return
	end
	if options.paused then
		if not tap(view, "EXIT") then
			tap(view, "NEXT")
		end
		return
	end
	if state.phase ~= "game" then
		failures[#failures + 1] = "Campaign ended before workflow completion"
		order(view, "exit")
		return
	end
	actor = observer
	local Systems, Hex = dofile("/games/civcraft/systems.lua"), dofile("/games/civcraft/hex.lua")
	local player = ownPlayer(state)
	if not player or player.ai or player.ready then
		return
	end
	if view:animating() then
		order(view, "skipPlayback")
		return
	end
	if not lastMetadata then
		local world = authoritative and authoritative.world or state.world
		lastMetadata = true
		record("campaign_metadata", {
			sourceRevision = __openingSourceRevision,
			profile = state.contentRules,
			seed = world.seed,
			mapSize = world.size,
			width = state.world.width,
			height = state.world.height,
			wrapX = state.world.wrapX == true,
			players = #state.players,
			runtime = _HOST,
			lua = _VERSION,
			backend = view.r.mode,
			canvasWidth = view.r.w,
			canvasHeight = view.r.h,
		})
		stage = "viewport"
	end
	if stage == "viewport" and view.panel ~= "context" then
		if not tap(view, "CLOSE") then
			tap(view, "NEXT")
		end
		return
	end
	if stage == "viewport" and view.mapViewport then
		local v = view.mapViewport
		local x, y = point(view, v.x + v.w / 2, v.y + v.h / 2)
		viewportBefore =
			{ panX = view.panX, panY = view.panY, zoom = view.zoomLevel, since = os.epoch("utc") }
		queued = true
		os.queueEvent("mouse_scroll", 1, x, y)
		os.queueEvent("mouse_click", 2, x, y)
		os.queueEvent("mouse_drag", 2, x + 5, y + 2)
		os.queueEvent("mouse_up", 2, x + 5, y + 2)
		os.queueEvent("opening_input_complete")
		stage = "menu"
		return
	end
	if stage == "menu" then
		stage = "menu-open"
		queued = true
		pendingInput = { label = "pause-key", since = os.epoch("utc") }
		os.queueEvent("key", keys.q)
		os.queueEvent("opening_input_complete")
		return
	end
	if stage == "menu-open" then
		return
	end
	stage = "opening"
	local cities = {}
	for _, c in ipairs(state.cities or {}) do
		if c.owner == actor then
			cities[#cities + 1] = c
		end
	end
	if #cities > 1 then
		milestone("expansion", state, #cities)
	end
	if
		state.round > 40
		or milestones.firstBuild
			and milestones.firstResearch
			and milestones.expansion
			and milestones.civilianOutput
	then
		stopped = true
		order(view, "exit")
		return
	end
	for _, unit in ipairs(state.units or {}) do
		if unit.owner == actor and unit.kind == "settler" and (unit.movesLeft or 0) > 0 then
			local request =
				dofile("/games/civcraft/ai_settlement.lua").order(state, player, unit, Systems)
			if request then
				order(view, request.action, request)
				return
			end
		end
	end
	if not player.researchTarget or not Systems.canResearch(player, player.researchTarget) then
		for _, id in ipairs({
			"writing",
			"crafting",
			"agriculture",
			"mining",
			"bronze",
			"masonry",
			"currency",
			"engineering",
		}) do
			if Systems.canResearch(player, id) then
				order(view, "researchTech", { id = id })
				return
			end
		end
		for _, id in ipairs(Systems.techOrder) do
			if Systems.canResearch(player, id) then
				order(view, "researchTech", { id = id })
				return
			end
		end
	end
	local hasSettler = false
	for _, u in ipairs(state.units) do
		hasSettler = hasSettler or u.owner == actor and u.kind == "settler"
	end
	for _, c in ipairs(cities) do
		local kind, id
		if not c.project then
			if
				not (c.buildings or {}).furnace and Systems.canBuild(player, c, "furnace", state)
			then
				kind, id = "building", "furnace"
			elseif
				not (c.buildings or {}).library and Systems.canBuild(player, c, "library", state)
			then
				kind, id = "building", "library"
			elseif not milestones.civilianOutput and Systems.canProject(player, c, "ponder") then
				kind, id = "project", "ponder"
			elseif
				#cities < 2
				and not hasSettler
				and Systems.canRecruit(player, "settler", state, Hex, c)
			then
				kind, id = "unit", "settler"
			elseif Systems.canBuild(player, c, "housing", state) then
				kind, id = "building", "housing"
			elseif Systems.canProject(player, c, "ponder") then
				kind, id = "project", "ponder"
			else
				kind = "none"
			end
		elseif
			c.project.kind == "project"
			and milestones.civilianOutput
			and #cities < 2
			and not hasSettler
			and Systems.canRecruit(player, "settler", state, Hex, c)
		then
			kind, id = "unit", "settler"
		end
		if kind and (kind ~= "none" or not c.productionIdle) then
			order(view, "queue", { cityX = c.x, cityY = c.y, kind = kind, id = id })
			return
		end
	end
	local signature = tostring(actor)
		.. ":"
		.. tostring(state.round)
		.. ":"
		.. tostring(player.ready)
	if lastDecision ~= signature then
		lastDecision = signature
		record("end_turn_requested", { round = state.round, cities = #cities })
		order(view, "end")
	end
end

dofile = function(path)
	local module = native(path)
	if path == "/games/civcraft/match_lifecycle.lua" and not module.openingObserved then
		module.openingObserved = true
		local initialize = module.initialize
		module.initialize = function(state, ...)
			state.mapSeed, state.mapSize = 319497, "compact"
			assert(
				#state.players == 2 and not state.players[1].ai and state.players[2].ai,
				"Expected one human and one AI"
			)
			return initialize(state, ...)
		end
		local lobby = module.newLobby
		module.newLobby = function(...)
			local state = lobby(...)
			state.contentRules, state.mapSeed, state.mapSize, state.mapType, state.hostileMode =
				"balance5", 319497, "compact", "continents", "off"
			return state
		end
	elseif path == "/games/civcraft/world.lua" and not module.openingObserved then
		module.openingObserved = true
		local reveal = module.reveal
		module.reveal = function(state, ...)
			authoritative = state
			return reveal(state, ...)
		end
	elseif path == "/games/civcraft/civilian_projects.lua" and not module.openingObserved then
		module.openingObserved = true
		local commit = module.commit
		module.commit = function(city, output)
			local result = commit(city, output)
			if
				actor
				and city.owner == actor
				and output.active
				and ((output.science or 0) + (output.food or 0) + (output.gold or 0)) > 0
			then
				milestone("civilianOutput", authoritative, city.project.id)
			end
			return result
		end
	elseif path == "/games/civcraft/systems.lua" and not module.openingObserved then
		module.openingObserved = true
		local production = module.production
		module.production = function(state, ...)
			local p = ownPlayer(state)
			local techs, buildings = {}, {}
			for id in pairs(p and p.techs or {}) do
				techs[id] = true
			end
			for _, c in ipairs(state.cities) do
				if c.owner == actor then
					for id in pairs(c.buildings or {}) do
						buildings[c.id .. ":" .. id] = true
					end
				end
			end
			local result = production(state, ...)
			for id in pairs(p and p.techs or {}) do
				if not techs[id] then
					milestone("firstResearch", state, id)
				end
			end
			for _, c in ipairs(state.cities) do
				if c.owner == actor then
					for id in pairs(c.buildings or {}) do
						if not buildings[c.id .. ":" .. id] then
							milestone("firstBuild", state, id)
						end
					end
				end
			end
			return result
		end
	elseif path == "/games/civcraft/ui.lua" and not module.openingObserved then
		module.openingObserved = true
		local new = module.new
		module.new = function(display, dispatch)
			local view = new(display, function(action, params)
				local before = os.epoch("utc")
				local ok, why = dispatch(action, params)
				record("command_callback", {
					action = action,
					millis = os.epoch("utc") - before,
					note = "UI dispatch callback return; includes queue drain only when initially idle",
				})
				return ok, why
			end)
			local pull = view.r.pullEvent
			view.r.pullEvent = function(renderer)
				local event = table.pack(pull(renderer))
				if event[1] == "opening_input_complete" then
					queued = false
					wake()
				end
				return table.unpack(event, 1, event.n)
			end
			local draw = view.draw
			view.draw = function(self, state, observer, options)
				local before = os.epoch("utc")
				local result = draw(self, state, observer, options)
				record("frame", {
					millis = os.epoch("utc") - before,
					round = state.round,
					panel = self.panel,
					backend = self.r.mode,
				})
				if pendingInput then
					record("input_frame", {
						label = pendingInput.label,
						millis = os.epoch("utc") - pendingInput.since,
						note = "First subsequent rendered frame; individual event acceptance not inferred",
					})
					pendingInput = nil
				end
				if viewportBefore and not queued then
					record("viewport_result", {
						millis = os.epoch("utc") - viewportBefore.since,
						before = viewportBefore,
						panX = self.panX,
						panY = self.panY,
						zoom = self.zoomLevel,
					})
					viewportBefore = nil
				end
				if stage == "menu-open" and options.paused and not queued then
					if tap(self, "RESUME") then
						stage = "opening"
					else
						tap(self, "NEXT")
					end
				else
					workflow(self, state, observer, options)
				end
				return result
			end
			return view
		end
	end
	return module
end
record("begin", {
	sourceRevision = __openingSourceRevision,
	runtime = _HOST,
	seed = 319497,
	profile = "balance5",
	maxRounds = 40,
	network = "not measured in local baseline",
})
local deadline = os.startTimer(240)
local ok, why = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))("host", "--new", "--debug")
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == deadline then
				error("Opening observation timeout at " .. stage)
			end
		end
	end)
end)
dofile = native
local missing = {}
for _, name in ipairs({ "firstBuild", "firstResearch", "expansion", "civilianOutput" }) do
	if not milestones[name] then
		missing[#missing + 1] = name
	end
end
record("missing_milestones", { names = missing })
record("end", {
	success = ok,
	reason = ok and nil or tostring(why),
	milestones = milestones,
	stoppedAtBound = stopped,
	failures = failures,
})
assert(ok, why)
assert(stopped, "Opening workflow did not reach its explicit stopping bound")

assert(#missing == 0, "Opening milestones missing: " .. table.concat(missing, ", "))
