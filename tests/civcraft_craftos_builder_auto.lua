-- Native Builder auto-work flow. The saved campaign fixture supplies a generated
-- balance5 map, research, a city, and one charged Builder; no work is completed here.
local monitor = false
for _, argument in ipairs({ ... }) do
	monitor = monitor or argument == "--monitor"
end
if monitor then
	assert(_G.periphemu.create("top", "monitor"))
end
local native = dofile
native("/games/civcraft/module_cache.lua").install(_ENV)
native = dofile
local function progress(value)
	local file = assert(fs.open("/builder-auto-progress.log", "a"))
	file.writeLine(value)
	file.close()
end
progress("begin")
local resume = ({ ... })[1] == "--resume"
local queued, step, completed = false, 0, false
local ownerID, builderID, campaignID
local requestLog = {}
local saved = false
local resumeVerified = false
local function wake()
	os.queueEvent("term_resize")
end
local function tap(view, label)
	for _, button in ipairs(view.r.buttons or {}) do
		if button.label == label then
			local x, y = button.x + button.w / 2, button.y + button.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			queued = true
			if monitor then
				os.queueEvent("monitor_touch", "top", math.floor(x), math.floor(y))
			else
				os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
				os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
			end
			os.queueEvent("builder_auto_input_complete")
			return true
		end
	end
	return false
end
local function unitByID(state)
	for _, unit in ipairs(state.units or {}) do
		if unit.id == builderID then
			return unit
		end
	end
end

if not resume then
	local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
	local Systems = dofile("/games/civcraft/systems.lua")
	local Saves = dofile("/games/civcraft/saves.lua")
	local Works = dofile("/games/civcraft/tile_improvements.lua")
	local state = Lifecycle.newLobby("native-builder-auto", "balance5")
	state.mapSeed, state.mapSize, state.mapType, state.hostileMode =
		20261030, "compact", "pangaea", "off"
	ownerID = (os.getComputerID and os.getComputerID() or 0) * 16 + 1
	state.players = {
		{ id = ownerID, name = "BUILDER TEST", civ = "forge" },
		{ id = ownerID + 1, name = "TEST AI", civ = "scholar", ai = true },
	}
	local Cooperative = dofile("/games/civcraft/cooperative.lua")
	local World = dofile("/games/civcraft/world.lua")
	local checkpointWork = {}
	local function checkpoint()
		Cooperative.checkpoint(checkpointWork, true, true)
	end
	World.checkpoint, Systems.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint
	local initialized = false
	local setupTimer = os.startTimer(120)
	parallel.waitForAny(function()
		progress("initialize")
		Lifecycle.initialize(state)
		initialized = true
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == setupTimer then
				error("Builder fixture generation timed out")
			end
		end
	end)
	assert(initialized, "Generated Builder fixture did not initialize")
	progress("found capitals")
	local Actions = dofile("/games/civcraft/actions.lua")
	local settlers = {}
	for _, unit in ipairs(state.units) do
		if unit.kind == "settler" then
			settlers[#settlers + 1] = unit
		end
	end
	for _, unit in ipairs(settlers) do
		assert(
			Actions.apply(state, unit.owner, {
				action = "found",
				unitID = unit.id,
				x = unit.x,
				y = unit.y,
			}, Systems),
			"Fixture capitals use ordinary founding validation"
		)
	end
	local player, capital, builder
	for _, p in ipairs(state.players) do
		for _, tech in ipairs({
			"agriculture",
			"mining",
			"crafting",
			"bronze",
			"writing",
			"currency",
		}) do
			p.techs[tech] = true
		end
		p.researchTarget = "masonry"
	end
	for _, city in ipairs(state.cities) do
		city.productionIdle = true
		if city.owner == ownerID then
			capital = city
		end
	end
	for _, unit in ipairs(state.units) do
		if unit.owner == ownerID and unit.kind == "warrior" then
			builder = unit
			break
		end
	end
	assert(capital and builder, "Generated fixture needs a capital and starting Warrior")
	builder.kind, builder.charges = "builder", 2
	builder.movesLeft, builder.moved = 0, true
	builderID = builder.id
	-- Controlled fixture prep: make one generated owned tile open plains so the
	-- actual planner has a clear farm target beside the Builder.
	local candidateX, candidateY = capital.x + 1, capital.y
	if candidateX > state.world.width then
		candidateX = capital.x - 1
	end
	state.world.tiles[candidateX .. ":" .. candidateY] = "plains"
	state.world.geography[candidateX .. ":" .. candidateY] = {
		biome = "plains",
		elevation = "flat",
		feature = "none",
	}
	World.reveal(state, dofile("/games/civcraft/hex.lua"), Systems)
	assert(Works.canPlace(state, state.players[1], "farm", candidateX, candidateY, Systems))
	state.nativeBuilderAuto = { ownerID = ownerID, builderID = builderID }
	progress("save fixture")
	assert(Saves.save(1, state), "Could not save generated Builder fixture")
	print("Prepared generated campaign fixture with a real capital and charged Builder")
else
	local Saves = dofile("/games/civcraft/saves.lua")
	local prior = assert(Saves.load(1), "Builder restart fixture save is missing")
	assert(prior.nativeBuilderAuto, "Restart fixture marker is missing")
	ownerID, builderID, campaignID =
		prior.nativeBuilderAuto.ownerID, prior.nativeBuilderAuto.builderID, prior.campaignID
end

dofile = function(path)
	local module = native(path)
	if path == "/games/civcraft/ui.lua" then
		local new = module.new
		module.new = function(display, dispatch, options)
			local currentState
			local function tracked(action, params)
				if currentState and not resume then
					currentState.nativeBuilderAuto = {
						ownerID = ownerID,
						builderID = builderID,
						campaignID = currentState.campaignID,
					}
				end
				local ok, message = dispatch(action, params)
				requestLog[#requestLog + 1] = { action = action, ok = ok, message = message }
				return ok, message
			end
			local view = new(display, tracked, options)
			local pull = view.r.pullEvent
			view.r.pullEvent = function(canvas)
				local event = table.pack(pull(canvas))
				if event[1] == "builder_auto_input_complete" then
					queued = false
					wake()
				end
				return (table.unpack or unpack)(event, 1, event.n)
			end
			local draw = view.draw
			view.draw = function(self, state, observer, opts)
				currentState = state
				draw(self, state, observer, opts)
				if queued then
					return
				end
				local status = tostring(step)
					.. ":"
					.. tostring(opts.screen)
					.. ":"
					.. tostring(self.panel)
					.. ":"
					.. tostring(opts.paused)
				if self.nativeBuilderStatus ~= status then
					self.nativeBuilderStatus = status
					progress(status)
				end
				if opts.screen == "title" then
					tap(self, "LOAD CAMPAIGN")
					return
				end
				if opts.handoff then
					tap(self, "READY TO PLAY")
					return
				end
				local unit = unitByID(state)
				if not unit then
					return
				end
				if
					step < 3
					and not (self.selected.kind == "unit" and self.selected.unitID == unit.id)
				then
					self:focus("unit", unit)
					wake()
					return
				end
				local wanted = step == 0 and "AUTO WORK"
					or step == 1 and "PAUSE AUTO WORK"
					or "RESUME AUTO WORK"
				local inlineControl = false
				for _, button in ipairs(self.r.buttons or {}) do
					inlineControl = inlineControl or button.label == wanted
				end
				if step < 3 and self.panel ~= "inspector" and not inlineControl and not resume then
					if not tap(self, "DETAILS") then
						tap(self, "NEXT")
					end
					return
				end
				if resume and not resumeVerified then
					assert(state.campaignID == campaignID, "Restart must reopen the same campaign")
					assert(unit.autoWork, "Auto-work intent must survive restart")
					assert(unit.kind == "builder", "Saved Builder identity must survive restart")
					resumeVerified = true
					step = 7
				elseif step == 0 then
					if tap(self, "AUTO WORK") then
						step = 1
					else
						tap(self, "NEXT")
					end
				elseif step == 1 and unit.autoWork then
					assert(
						unit.workQueue and unit.workQueue.auto,
						"Auto mode must create a provenance-marked queue"
					)
					if tap(self, "PAUSE AUTO WORK") then
						step = 2
					else
						tap(self, "NEXT")
					end
				elseif step == 2 and unit.autoWork and unit.autoWorkPaused then
					if tap(self, "RESUME AUTO WORK") then
						step = 3
					else
						tap(self, "NEXT")
					end
				elseif step == 7 then
					if (unit.charges or 0) < 2 and next(state.world.improvements or {}) then
						completed = true
						progress("automatic improvement consumed charge")
						step = 3
					else
						assert(state.round < 6, "Auto work must complete within bounded real turns")
						if
							not tap(self, "END TURN")
							and not tap(self, "CLOSE")
							and not tap(self, "CONTINUE")
						then
							tap(self, "NEXT")
						end
					end
				elseif step == 3 then
					queued = true
					os.queueEvent("key", keys.q)
					os.queueEvent("builder_auto_input_complete")
					step = 4
				elseif step == 4 and opts.paused then
					if tap(self, "SAVE") then
						step = 5
					else
						tap(self, "NEXT")
					end
				elseif step == 5 and opts.paused then
					if tap(self, "EXIT") then
						step = 6
					else
						tap(self, "NEXT")
					end
				end
			end
			return view
		end
	elseif path == "/games/civcraft/systems.lua" and resume then
		local migrate = module.migrate
		module.migrate = function(state)
			local result = migrate(state)
			if state.phase == "game" then
				local marker = state.nativeBuilderAuto
				assert(marker, "Restarted campaign marker missing")
				ownerID, builderID, campaignID = marker.ownerID, marker.builderID, state.campaignID
			end
			return result
		end
	end
	return module
end

local function markSaved(state)
	local unit = unitByID(state)
	assert(unit, "Fixture Builder vanished")
	state.nativeBuilderAuto = {
		ownerID = ownerID,
		builderID = builderID,
		campaignID = state.campaignID,
	}
end
progress("run app")
local timeout = os.startTimer(150)
local ok, why = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))("local", "--menu")
	end, function()
		while true do
			local event, id = os.pullEvent()
			if event == "timer" and id == timeout then
				error("Builder auto-work native UI timed out at step " .. step)
			end
		end
	end)
end)
dofile = native
assert(ok, why)
if resume then
	assert(
		completed and step == 6,
		"Restart UI must inspect saved auto-work state and exit cleanly"
	)
else
	assert(step == 6, "Native UI must enable, pause, resume, save, and exit")
	local Saves = native("/games/civcraft/saves.lua")
	local state = assert(Saves.load(1))
	markSaved(state)
	assert(Saves.save(1, state), "Could not save Builder auto-work restart fixture")
	local unit = unitByID(state)
	assert(unit.autoWork and unit.workQueue and unit.workQueue.auto)
	local marked = assert(Saves.load(1))
	assert(marked.nativeBuilderAuto, "Restart marker must persist")
end
if monitor then
	_G.periphemu.remove("top")
end
print("PASS: native Builder auto-work UI and saved intent")
