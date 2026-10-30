-- Extend the generated round-two native campaign through real program/UI/production/restart.
-- Controlled technology, population, basic infrastructure, terrain and one extra Settler
-- are fixture setup. No sites, project progress, production yields or actions are fabricated.
local host, resume = false, false
for _, arg in ipairs({ ... }) do
	host = host or arg == "--host"
	resume = resume or arg == "--resume"
end
local native = dofile
local queued = false
local await
local ownerId, primaryId, secondaryId
local seededFixture
local requests = {}
local completed = false
local redevelopmentPreviewVerified = false
local redevelopmentPreview = {}
local uiText = {}
local restoredCheckpoint
local phase = "start"
local lastView = {}
local drawnText = {}
local pageHistory = {}
local lastPageKey
local stopStep = 0
local function wake()
	os.queueEvent("term_resize")
end
local function queuePoint(view, x, y, label)
	if view.r.mode == "graphics" then
		x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
	else
		x, y = x / 2 + 1, y / 3 + 1
	end
	queued = true
	os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
	os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
	os.queueEvent("civcraft_specialty_input_complete")
	local f = assert(fs.open("/specialty-session-input.log", "a"))
	f.writeLine(textutils.serialize({ phase = phase, label = label, x = x, y = y }))
	f.close()
	return true
end
local function tap(view, label, prefix)
	for _, b in ipairs(view.r.buttons) do
		if b.label and (b.label == label or prefix and b.label:sub(1, #label) == label) then
			return queuePoint(view, b.x + b.w / 2, b.y + b.h / 2, b.label)
		end
	end
	return false
end
local function setup(state, systems)
	if state.contentRules ~= "balance5" or state.phase ~= "game" then
		return
	end
	local World = dofile("/games/civcraft/world.lua")
	local Hex = dofile("/games/civcraft/hex.lua")
	ownerId = state.players[1].id
	state.nativeSpecialtyFixture = state.nativeSpecialtyFixture
		or { startRound = state.round, requests = {} }
	local fixture = state.nativeSpecialtyFixture
	seededFixture = fixture
	for _, player in ipairs(state.players) do
		player.gameSpeed = "standard"
		for _, id in ipairs({
			"crafting",
			"agriculture",
			"mining",
			"bronze",
			"metallurgy",
			"writing",
			"currency",
			"engineering",
			"masonry",
		}) do
			player.techs[id] = true
		end
	end
	for _, city in ipairs(state.cities) do
		if city.owner >= 0 and not city.village then
			city.population = 3
			city.foodStore = 100
		end
		if city.owner >= 0 and not city.village and not city.nativeSpecialtyPrepared then
			city.nativeSpecialtyPrepared = true
			for _, id in ipairs({
				"craftinghall",
				"furnace",
				"smithy",
				"library",
				"market",
				"pens",
				"housing",
				"well",
			}) do
				city.buildings[id] = true
			end
			for key in pairs(city.claimed or {}) do
				local x, y = key:match("^(%d+):(%d+)$")
				x, y = tonumber(x), tonumber(y)
				if x ~= city.x or y ~= city.y then
					state.world.tiles[key] = "hills"
				end
			end
			city.worked = nil
			systems.ensureWorkers(state, city)
		end
	end
	if not fixture.primaryCity then
		for _, city in ipairs(state.cities) do
			if city.owner == ownerId then
				fixture.primaryCity = city.id
				break
			end
		end
		assert(
			fixture.primaryCity,
			"Fixture requires the generated and player-founded first capital"
		)
	end
	if not fixture.settlerId then
		local capital
		for _, city in ipairs(state.cities) do
			if city.id == fixture.primaryCity then
				capital = city
			end
		end
		local target
		for distance = 3, 9 do
			for y = 2, state.world.height - 1 do
				for x = 2, state.world.width - 1 do
					if Hex.distance(capital.x, capital.y, x, y) == distance and not target then
						local legal = not World.territoryCity(state, Hex, x, y)
							and not (state.world.landmarks or {})[World.key(x, y)]
						for _, city in ipairs(state.cities) do
							if Hex.distance(city.x, city.y, x, y) < 3 then
								legal = false
							end
						end
						for _, unit in ipairs(state.units) do
							if unit.x == x and unit.y == y then
								legal = false
							end
						end
						for _, camp in ipairs(state.spawners or {}) do
							if not camp.cleared and camp.x == x and camp.y == y then
								legal = false
							end
						end
						if legal then
							target = { x = x, y = y }
						end
					end
				end
			end
			if target then
				break
			end
		end
		assert(target, "Controlled second-city fixture needs a legal distant hex")
		state.world.tiles[World.key(target.x, target.y)] = "plains"
		fixture.settlerId = state.nextId
		state.nextId = state.nextId + 1
		state.units[#state.units + 1] = {
			id = fixture.settlerId,
			kind = "settler",
			owner = ownerId,
			x = target.x,
			y = target.y,
			movesLeft = 2,
			moved = false,
		}
	end
	primaryId = fixture.primaryCity
	for _, city in ipairs(state.cities) do
		if city.owner == ownerId and city.id ~= primaryId then
			secondaryId = city.id
			break
		end
	end
	World.reveal(state, Hex, systems)
end
local function finishTurn(view)
	if view.endConfirm then
		return tap(view, "END ANYWAY")
	end
	if view.productionConfirm then
		return tap(view, "CHANGE")
	end
	if view.panel == "report" or view.panel == "recap" then
		return tap(view, view.panel == "report" and "CLOSE" or "SKIP")
	end
	if view.panel == "inspector" then
		if view.selected.kind == "unit" then
			return tap(view, "SKIP TURN") or tap(view, "NEXT")
		end
		for _, city in ipairs(view.state.cities) do
			if
				city.x == view.selected.x
				and city.y == view.selected.y
				and (city.project or city.productionIdle)
			then
				return tap(view, "CLOSE")
			end
		end
		return tap(view, "NO PRODUCTION") or tap(view, "NEXT")
	end
	if view.panel == "tech" then
		return tap(view, "CLOSE")
	end
	local label = view:turnAction()
	return tap(view, label)
end
local function menu(view, city)
	if
		view.panel ~= "inspector"
		or view.selected.kind ~= "city"
		or view.selected.x ~= city.x
		or view.selected.y ~= city.y
		or view.cityPanel ~= "production"
	then
		view:focus("city", city)
		view.panel = "inspector"
		view.cityPanel = "production"
		wake()
		return false
	end
	if view.productionCategory ~= "site" then
		if not tap(view, "SITES") then
			tap(view, "NEXT")
		end
		return false
	end
	return true
end
local function siteOrder(view, city, kind, sourceId)
	if view.pendingMove and view.pendingMove.sitePreview then
		if sourceId then
			local preview = view.pendingMove.sitePreview
			assert(
				preview.cost == 45,
				"Native redevelopment preview uses full 30+15 industry price"
			)
			assert(
				preview.focusBefore == 1 and preview.focusAfter == 1 and preview.allowance == 1,
				"Redevelopment replaces the sole occupied focus slot: "
					.. textutils.serialize({
						before = preview.focusBefore,
						after = preview.focusAfter,
						allowance = preview.allowance,
						population = city.population,
					})
			)
			assert(view.pendingMove.siteRequest.siteId == sourceId)
			redevelopmentPreviewVerified = true
			redevelopmentPreview = {
				cost = preview.cost,
				focusBefore = preview.focusBefore,
				focusAfter = preview.focusAfter,
				allowance = preview.allowance,
			}
		end
		local label = view.pendingMove.needsReview and "REVIEW AGAIN" or "CONFIRM"
		if label == "CONFIRM" then
			await = { city = city.id, kind = kind, sourceId = sourceId }
		end
		return tap(view, label)
	end
	if view.placement and view.placement.kind == "specialty" then
		for _, hex in ipairs(view.hexTargets) do
			for _, choice in ipairs(view.reachable) do
				if choice.x == hex.tx and choice.y == hex.ty then
					local x, y = hex.x + hex.w / 2, hex.y + hex.h / 2
					local v = view.mapViewport
					if x >= v.x and x < v.x + v.w and y >= v.y and y < v.y + v.h then
						return queuePoint(view, x, y, "SITE HEX")
					end
				end
			end
		end
		local target = view.reachable[1]
		assert(target, "Specialty placement requires an eligible owned hex")
		local v = view.mapViewport
		local px = (target.x - 0.5 + ((target.y - 1) % 2) * 0.5) * v.tile - v.w / 2
		local py = (target.y - 1) * v.tile * 0.75 + v.tile / 2 - v.h / 2
		assert(view:pan(px - view.panX, py - view.panY), "Fixture can pan the normal placement map")
		wake()
		return true
	end
	if not menu(view, city) then
		return true
	end
	local symbol = ({ works = "W", knowledge = "K", freight = "F" })[kind]
	if sourceId and view.siteSource ~= sourceId then
		return tap(view, "REDEVELOP W") or tap(view, "NEXT")
	end
	return tap(view, (sourceId and "REPLACE: " or "PLACE: ") .. symbol, true) or tap(view, "NEXT")
end
local function drive(view, state, observer, options)
	if queued then
		return
	end
	if options.handoff then
		tap(view, "READY TO PLAY")
		return
	end
	if options.screen == "title" then
		if view.titleMenu == "load" then
			tap(view, "LOAD CAMPAIGN")
		else
			tap(view, "LOAD CAMPAIGN")
		end
		return
	end
	if options.paused then
		if stopStep == 1 then
			if tap(view, "SAVE") then
				stopStep = 2
			else
				tap(view, "NEXT")
			end
		elseif stopStep == 2 then
			if tap(view, "EXIT") then
				stopStep = 3
			else
				tap(view, "NEXT")
			end
		end
		return
	end
	if state.phase ~= "game" then
		error("Specialty session unexpectedly left live play")
	end
	if view.panel == "recap" or view.panel == "report" then
		finishTurn(view)
		return
	end
	local me
	for _, p in ipairs(state.players) do
		if p.id == observer then
			me = p
		end
	end
	local scheduler = dofile("/games/civcraft/turn_scheduler.lua")
	local cities = {}
	for _, city in ipairs(state.cities) do
		if city.owner == ownerId then
			cities[city.id] = city
		end
	end
	local first, second = cities[primaryId], cities[secondaryId]
	if not secondaryId then
		for _, city in ipairs(state.cities) do
			if city.owner == ownerId and city.id ~= primaryId then
				secondaryId = city.id
				second = city
				break
			end
		end
	end
	if await then
		local city = cities[await.city]
		for _, pr in pairs(city and city.siteProjects or {}) do
			if pr.kind == await.kind and pr.sourceSiteId == await.sourceId then
				await = nil
				break
			end
		end
		if await then
			return
		end
	end
	if observer == ownerId and me and not me.ready and scheduler.canAct(state, ownerId) then
		if not second then
			phase = "found second city"
			local extra
			for _, unit in ipairs(state.units) do
				if unit.id == seededFixture.settlerId then
					extra = unit
				end
			end
			assert(extra, "The fixture Settler must persist until real founding")
			if view.panel ~= "inspector" or view.selected.unitID ~= extra.id then
				view:focus("unit", extra)
				view.panel = "inspector"
				wake()
				return
			end
			if not tap(view, "FOUND CITY") then
				tap(view, "NEXT")
			end
			return
		end
		local works = (first.sites or {}).works
		local knowledge = (second.sites or {}).knowledge
		local freight = (first.sites or {}).freight
		local primaryProject, secondaryProject
		for _, pr in pairs(first.siteProjects or {}) do
			primaryProject = pr
		end
		for _, pr in pairs(second.siteProjects or {}) do
			secondaryProject = pr
		end
		if not works and not freight and not primaryProject then
			phase = "place Works"
			siteOrder(view, first, "works")
			return
		end
		if not knowledge and not secondaryProject then
			phase = "place Knowledge"
			siteOrder(view, second, "knowledge")
			return
		end
		if works and knowledge and not primaryProject then
			phase = "redevelop Works to Freight"
			siteOrder(view, first, "freight", works.id)
			return
		end
		if
			not resume
			and primaryProject
			and primaryProject.sourceSiteId
			and primaryProject.progress > 0
		then
			phase = "save partial redevelopment"
			if view.panel ~= "context" then
				if not tap(view, "CLOSE") then
					tap(view, "BACK")
				end
				return
			end
			if tap(view, "PAUSE") then
				stopStep = 1
			else
				local labels = {}
				for _, b in ipairs(view.r.buttons) do
					labels[#labels + 1] = b.label
				end
				error("Pause unavailable at " .. phase .. " " .. textutils.serialize({
					labels = labels,
					panel = view.panel,
					placement = view.placement,
					pending = view.pendingMove,
					endConfirm = view.endConfirm,
				}))
			end
			return
		end
		if resume and freight and knowledge then
			completed = true
			phase = "save completed distinct cities"
			if view.panel ~= "context" then
				if not tap(view, "CLOSE") then
					tap(view, "BACK")
				end
				return
			end
			if tap(view, "PAUSE") then
				stopStep = 1
			else
				local labels = {}
				for _, b in ipairs(view.r.buttons) do
					labels[#labels + 1] = b.label
				end
				error("Pause unavailable at " .. phase .. " " .. textutils.serialize({
					labels = labels,
					panel = view.panel,
					placement = view.placement,
					pending = view.pendingMove,
					endConfirm = view.endConfirm,
				}))
			end
			return
		end
	end
	phase = "advance normal production"
	if view.panel ~= "context" and view.panel ~= "inspector" and view.panel ~= "tech" then
		view:back()
		wake()
		return
	end
	finishTurn(view)
end
dofile = function(path)
	local module = native(path)
	if path == "/games/civcraft/systems.lua" then
		local migrate, production = module.migrate, module.production
		module.migrate = function(state)
			local result = migrate(state)
			if resume and not restoredCheckpoint and state.phase == "game" then
				local f = assert(fs.open("/specialty-session-pending.json", "r"))
				local pending = textutils.unserializeJSON(f.readAll())
				f.close()
				redevelopmentPreviewVerified = pending.redevelopmentPreview.verified
				redevelopmentPreview = pending.redevelopmentPreview
				uiText.CONFIRM = pending.redevelopmentPreview.confirmButtonRendered
				assert(
					state.campaignID == pending.campaign,
					"Fresh program must reopen the exact saved campaign"
				)
				local primary, secondary
				for _, city in ipairs(state.cities) do
					if city.id == pending.primary.city then
						primary = city
					elseif city.id == pending.secondary.city then
						secondary = city
					end
				end
				assert(primary and secondary)
				local expected, actual
				for _, pr in pairs(pending.primary.projects) do
					if type(pr) == "table" then
						expected = pr
					end
				end
				for _, pr in pairs(primary.siteProjects or {}) do
					actual = pr
				end
				assert(
					expected
						and actual
						and actual.id == expected.id
						and actual.sourceSiteId == expected.sourceSiteId
						and actual.progress == expected.progress,
					"Fresh program must retain exact pending identity and invested industry"
				)
				assert(
					primary.sites.works.id == pending.primary.sites.works.id
						and secondary.sites.knowledge.id == pending.secondary.sites.knowledge.id,
					"Fresh program must retain both completed city roles"
				)
				restoredCheckpoint = {
					projectId = actual.id,
					sourceSiteId = actual.sourceSiteId,
					progress = actual.progress,
					round = state.round,
				}
			end
			setup(state, module)
			return result
		end
		module.production = function(state, hex)
			setup(state, module)
			return production(state, hex)
		end
	elseif path == "/games/civcraft/actions.lua" then
		local apply = module.apply
		module.apply = function(state, id, request, systems)
			local ok, why = apply(state, id, request, systems)
			if
				request.action == "placeSite"
				or request.action == "redevelopSite"
				or request.action == "resumeSite"
				or request.action == "cancelSite"
			then
				requests[#requests + 1] = {
					round = state.round,
					actor = id,
					action = request.action,
					city = request.city,
					kind = request.kind,
					sourceSiteId = request.siteId,
					x = request.x,
					y = request.y,
					ok = ok,
					message = why,
				}
			end
			return ok, why
		end
	elseif path == "/games/civcraft/ui.lua" then
		local new = module.new
		module.new = function(display, dispatch)
			local view = new(display, dispatch)
			local draw, pull = view.draw, view.r.pullEvent
			local nativeText = view.r.text
			view.r.text = function(canvas, x, y, value, ...)
				drawnText[#drawnText + 1] = value
				return nativeText(canvas, x, y, value, ...)
			end
			view.r.pullEvent = function(canvas)
				local event = table.pack(pull(canvas))
				if event[1] == "civcraft_specialty_input_complete" then
					queued = false
					wake()
				end
				return (table.unpack or unpack)(event, 1, event.n)
			end
			view.draw = function(self, state, observer, options)
				if state.contentRules == "balance5" then
					-- Pin only this fixture's prepared cities for the one-slot UI check.
					for _, city in ipairs(state.cities or {}) do
						if city.nativeSpecialtyPrepared then
							city.population = 3
							city.foodStore = 100
						end
					end
				end
				drawnText = {}
				draw(self, state, observer, options)
				if self.pendingMove and self.pendingMove.sitePreview then
					for _, button in ipairs(self.r.buttons or {}) do
						if button.label then
							uiText[button.label] = true
						end
					end
				end
				lastView = {
					panel = self.panel,
					cityPanel = self.cityPanel,
					category = self.productionCategory,
					source = self.siteSource,
					buttons = {},
					text = drawnText,
					offset = self.inspectorOffset,
				}
				for _, button in ipairs(self.r.buttons or {}) do
					lastView.buttons[#lastView.buttons + 1] = button.label
				end
				local pageKey = table.concat({
					phase,
					tostring(self.inspectorOffset),
					tostring(self.siteSource),
					tostring(self.productionCategory),
				}, ":")
				if pageKey ~= lastPageKey then
					pageHistory[#pageHistory + 1] = lastView
					if #pageHistory > 40 then
						table.remove(pageHistory, 1)
					end
					lastPageKey = pageKey
				end
				drive(self, state, observer, options)
			end
			return view
		end
	end
	return module
end
-- Compact text layouts expose one production row per page. Keep the full
-- placement/redevelopment/restart sequence bounded without expiring mid-page.
local timeout = os.startTimer(180)
local returned = false
local ok, why = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))(
			host and "host" or "local",
			"--menu",
			"--debug"
		)
		returned = true
	end, function()
		while true do
			local event, id = os.pullEvent()
			if event == "timer" and id == timeout then
				local file = assert(fs.open("/specialty-session-pages.json", "w"))
				file.write(textutils.serializeJSON(pageHistory))
				file.close()
				error(
					"Specialty native session timed out: "
						.. phase
						.. " "
						.. textutils.serialize(lastView)
				)
			end
		end
	end)
end)
dofile = native
assert(ok, why)
assert(returned and stopStep == 3, "Normal program must save and exit")
local saved
if host then
	local f = assert(fs.open("/games/civcraft/data/save.dat", "r"))
	saved = textutils.unserialize(f.readAll())
	f.close()
else
	saved = native("/games/civcraft/saves.lua").load(1)
end
local first, second
for _, city in ipairs(saved.cities) do
	if city.id == primaryId then
		first = city
	elseif city.id == secondaryId then
		second = city
	end
end
assert(
	first and second and (second.sites or {}).knowledge,
	"Distinct Knowledge city must be completed by normal production"
)
assert(
	redevelopmentPreviewVerified,
	"Human inspected and confirmed the 45-industry single-slot redevelopment"
)
assert(uiText.CONFIRM, "Native renderer exposed the normal confirmation button")
local project
for _, pr in pairs(first.siteProjects or {}) do
	project = pr
end
if resume then
	assert(
		completed and (first.sites or {}).freight and not project and not first.sites.works,
		"Restarted production must finish the paid role change"
	)
else
	assert(
		project and project.sourceSiteId and project.progress > 0 and first.sites.works,
		"Save must retain invested redevelopment and source site"
	)
end
for _, request in ipairs(requests) do
	assert(request.ok, "Native UI site command rejected: " .. tostring(request.message))
end
local acceptedAIWorks = false
local aiPlayers = {}
for _, player in ipairs(saved.players or {}) do
	aiPlayers[player.id] = player.ai == true
end
for _, request in ipairs(requests) do
	if
		request.ok
		and request.actor ~= ownerId
		and aiPlayers[request.actor]
		and request.action == "placeSite"
		and request.kind == "works"
	then
		acceptedAIWorks = true
	end
end
local Sites = native("/games/civcraft/specialty_sites.lua")
local firstFocus = Sites.allowance(saved, first)
local secondFocus = Sites.allowance(saved, second)
assert(
	firstFocus.used == 1 and secondFocus.used == 1,
	"Saved focus accounting mismatch: "
		.. textutils.serialize({
			primary = firstFocus,
			secondary = secondFocus,
			primaryPopulation = first.population,
			secondaryPopulation = second.population,
		})
)
local firstEffects, secondEffects = Sites.effects(saved, first), Sites.effects(saved, second)
assert(
	secondEffects.science > 0
		and (resume and firstEffects.gold > 0 or not resume and firstEffects.industry > 0),
	"Distinct completed roles must supply authoritative useful output"
)
if resume then
	assert(
		restoredCheckpoint,
		"A fresh normal program must verify the partial checkpoint before continuing"
	)
else
	assert(
		project.progress < Sites.cost(saved.players[1], project),
		"Checkpoint must precede redevelopment completion"
	)
end
local result = {
	restoredCheckpoint = restoredCheckpoint,
	effects = { primary = firstEffects, secondary = secondEffects },
	host = _G._HOST,
	mode = host and "host" or "hotseat",
	resumed = resume,
	round = saved.round,
	campaign = saved.campaignID,
	fixture = "Generated campaign; seeded technologies, basic infrastructure, owned hills and one extra Settler. Prepared cities are pinned at population 3 for specialty UI/preview frames; ordinary growth resumes between frames and later saved allowance is reported as saved. No site/progress/yield/action bypass.",
	primary = { city = first.id, sites = first.sites, projects = first.siteProjects },
	secondary = { city = second.id, sites = second.sites },
	focus = { primary = firstFocus, secondary = secondFocus },
	requests = requests,
	acceptedAIWorks = acceptedAIWorks,
	redevelopmentPreview = {
		verified = redevelopmentPreviewVerified,
		confirmButtonRendered = uiText.CONFIRM == true,
		cost = redevelopmentPreview.cost,
		focusBefore = redevelopmentPreview.focusBefore,
		focusAfter = redevelopmentPreview.focusAfter,
		allowance = redevelopmentPreview.allowance,
	},
}
local f = assert(
	fs.open(resume and "/specialty-session-resumed.json" or "/specialty-session-pending.json", "w")
)
f.write(textutils.serializeJSON(result))
f.close()
print(
	"PASS: normal-program specialty "
		.. (resume and "restart completion" or "construction, redevelopment and pending save")
)
