local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local S = dofile("/games/civcraft/systems.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local View = dofile("/games/civcraft/specialty_view.lua")
local W = dofile("/games/civcraft/world.lua")
local H = dofile("/games/civcraft/hex.lua")
local A = dofile("/games/civcraft/actions.lua")
local Codex = dofile("/games/civcraft/encyclopedia.lua")
local Research = dofile("/games/civcraft/research_details.lua")
local function fixture()
	local p = { id = 0, civ = "forge", name = "FORGE", techs = {}, gold = 100 }
	for id in pairs(S.techs) do
		p.techs[id] = true
	end
	local state = {
		version = 6,
		contentRules = "balance5",
		ruleset = "create",
		phase = "game",
		round = 1,
		turn = 1,
		nextId = 3,
		logs = {},
		players = { p, { id = 1, civ = "iron", name = "IRON", techs = {}, gold = 100 } },
		units = {},
		cities = {
			{ id = 1, owner = 0, x = 4, y = 4, population = 7, buildings = {}, worked = {} },
		},
		world = {
			width = 12,
			height = 10,
			tiles = {},
			resources = {},
			landmarks = {},
			rails = {},
			improvements = {},
		},
	}
	for y = 1, 10 do
		for x = 1, 12 do
			state.world.tiles[W.key(x, y)] = "plains"
		end
	end
	S.migrate(state)
	W.reveal(state, H, S)
	return state, p, state.cities[1]
end
local state, p, c = fixture()
local help = Codex.entries("mechanics", state)
local specialtyHelp
for _, entry in ipairs(help) do
	if entry.id == "specialties" then
		specialtyHelp = entry
	end
end
assert(specialtyHelp and specialtyHelp.text:find("No SU", 1, true))
assert(#Codex.entries("specialties", state) == 3)
local knowledge = Codex.entries("specialties", state)[1]
assert(#Codex.describe("specialties", knowledge, p, state) >= 4)
local astronomy = table.concat(Research.paragraphs(S, "astronomy", p), " ")
assert(astronomy:find("Nether Portal only", 1, true))
local original = fixture()
original.contentRules = "balance4"
local foundCurrent = false
for _, entry in ipairs(Codex.entries("mechanics", original)) do
	foundCurrent = foundCurrent or entry.id == "specialties"
end
assert(foundCurrent, "The current rules expose specialty help for migrated profile labels")
assert(View.symbols.works == "W" and View.symbols.knowledge == "K" and View.symbols.freight == "F")
local rows = {}
local texts = {}
local fake = { productionCategory = "site" }
View.rows(
	fake,
	W.forPlayer(state, 0),
	W.forPlayer(state, 0).players[1],
	W.forPlayer(state, 0).cities[1],
	rows,
	function(value)
		texts[#texts + 1] = value
	end
)
assert(table.concat(texts, " "):find("FOCUS 0/3", 1, true))
if term and fs and textutils then
	local UI = dofile("/games/civcraft/ui.lua")
	local last, accepted, rejections
	local actual
	actual = UI.new(term.current(), function(action, request)
		request.action = action
		last = request
		accepted = select(1, A.apply(state, 0, request, S))
		if not accepted then
			rejections = (rejections or 0) + 1
			actual:feedback("Host rejected stale site order")
		end
	end)
	local function draw()
		actual:draw(W.forPlayer(state, 0), 0, {})
		if actual.pendingMove and actual.pendingMove.sitePreview or actual.specialtyCancel then
			for i, a in ipairs(actual.r.buttons) do
				assert(
					a.x >= 0 and a.y >= 0 and a.x + a.w <= actual.r.w and a.y + a.h <= actual.r.h,
					"Specialty modal button outside compact screen"
				)
				for j = i + 1, #actual.r.buttons do
					local b = actual.r.buttons[j]
					assert(
						not (
								a.x < b.x + b.w
								and a.x + a.w > b.x
								and a.y < b.y + b.h
								and a.y + a.h > b.y
							),
						"Specialty pager and confirmation buttons overlap"
					)
				end
			end
		end
	end
	local function click(rect)
		local x, y = rect.x + rect.w / 2, rect.y + rect.h / 2
		if actual.r.mode == "graphics" then
			x, y = actual.r.ox + x * actual.r.sx, actual.r.oy + y * actual.r.sy
		else
			x, y = x / 2 + 1, y / 3 + 1
		end
		assert(actual:tap(math.floor(x), math.floor(y)))
	end
	local function button(prefix, paged)
		for offset = 0, paged and 180 or 0 do
			if paged then
				actual.inspectorOffset = offset
			end
			draw()
			for _, b in ipairs(actual.r.buttons) do
				if b.label and b.label:sub(1, #prefix) == prefix then
					click(b)
					return b
				end
			end
		end
		error(
			"Native button missing: "
				.. prefix
				.. " last="
				.. tostring(last and last.action)
				.. " invalid="
				.. tostring(actual.pendingMove and actual.pendingMove.invalid)
				.. " review="
				.. tostring(actual.pendingMove and actual.pendingMove.needsReview)
		)
	end
	local function cityMenu()
		actual:focus("city", c)
		actual.panel = "inspector"
		actual.cityPanel = "production"
		actual.inspectorOffset = 0
	end
	local function target()
		draw()
		for _, hex in ipairs(actual.hexTargets) do
			for _, choice in ipairs(actual.reachable) do
				if hex.tx == choice.x and hex.ty == choice.y then
					local v = actual.mapViewport
					local cx, cy = hex.x + hex.w / 2, hex.y + hex.w / 2
					if cx >= v.x and cx < v.x + v.w and cy >= v.y and cy < v.y + v.h then
						click({ x = hex.x, y = hex.y, w = hex.w, h = hex.w })
						assert(actual.pendingMove and actual.pendingMove.sitePreview)
						return choice
					end
				end
			end
		end
		error("Native map lacks a visible legal specialty hex " .. textutils.serializeJSON({
			v = actual.mapViewport,
			hex = actual.hexTargets,
			reachable = actual.reachable,
			panX = actual.panX,
			panY = actual.panY,
		}))
	end
	draw()
	cityMenu()
	button("SITES", true)
	button("PLACE: W", true)
	assert(actual.placement and actual.placement.kind == "specialty")
	local choice = target()
	assert(not c.project and not c.siteProjects and p.gold == 100)
	button("BACK")
	assert(not actual.pendingMove and actual.placement and not c.project)
	target()
	button("CONFIRM")
	assert(
		accepted
			and last.action == "placeSite"
			and c.project.kind == "site"
			and c.siteProjects[1].progress == 0
	)
	assert(p.gold == 100 and not state.world.improvements[W.key(choice.x, choice.y)])
	assert(Sites.advance(state, p, c, 30))
	c.buildings.workshop = true
	c.projectProgress["building:assembly"] = 7
	cityMenu()
	button("REDEVELOP W", true)
	button("REPLACE: K", true)
	target()
	assert(actual.pendingMove.sitePreview.cost == 45)
	assert(actual.pendingMove.sitePreview.lostBuildings[1] == "workshop")
	assert(actual.pendingMove.sitePreview.lostProgress[1].progress == 7)
	local textSeen = {}
	local originalText = actual.r.text
	actual.r.text = function(renderer, x, y, value, ...)
		textSeen[#textSeen + 1] = tostring(value)
		return originalText(renderer, x, y, value, ...)
	end
	for offset = 0, 40 do
		actual.specialtyOffset = offset
		draw()
	end
	actual.r.text = originalText
	assert(table.concat(textSeen, " "):find("LOSE", 1, true))
	-- A newly updated active family investment replaces stale saved progress in consent.
	local oldConfirm
	draw()
	for _, b in ipairs(actual.r.buttons) do
		if b.label == "CONFIRM" then
			oldConfirm = b
		end
	end
	assert(oldConfirm)
	local beforeLossUpdate = last
	assert(S.queue(p, c, "building", "press", state, H))
	c.project.progress = 23
	c.projectProgress["building:press"] = 3
	actual.state = W.forPlayer(state, 0)
	click(oldConfirm)
	assert(last == beforeLossUpdate and c.project.kind == "building" and c.project.progress == 23)
	local pressLoss
	for _, loss in ipairs(actual.pendingMove.sitePreview.lostProgress) do
		if loss.id == "press" then
			pressLoss = loss.progress
		end
	end
	assert(pressLoss == 23, "UI must review the current active investment exactly once")
	button("CONFIRM")
	assert(accepted and last.action == "redevelopSite" and c.sites.works and c.buildings.workshop)
	local Saves = dofile("/games/civcraft/saves.lua")
	Saves.root = "/specialty-ui-save"
	assert(Saves.writeFile(Saves.path(1), state))
	local loaded = S.migrate(assert(Saves.load(1)))
	assert(loaded.cities[1].project.id == 2 and loaded.cities[1].siteProjects[2].sourceSiteId == 1)
	cityMenu()
	button("CANCEL K", true)
	assert(actual.specialtyCancel and c.siteProjects[2])
	local beforeReview = last
	c.siteProjects[2].progress = 20
	c.project.progress = 20
	draw()
	assert(actual.specialtyCancel.progress == 20 and actual.specialtyCancel.needsReview)
	button("REVIEW AGAIN")
	assert(last == beforeReview and c.siteProjects[2].progress == 20)
	button("KEEP")
	assert(not actual.specialtyCancel and c.siteProjects[2])
	button("CANCEL K", true)
	button("CANCEL SITE")
	assert(
		accepted
			and last.action == "cancelSite"
			and not c.siteProjects[2]
			and c.sites.works
			and c.buildings.workshop
	)
	-- A stale preview cannot reserve an invalid tile or consume any resource.
	cityMenu()
	button("PLACE: K", true)
	local stale = target()
	state.world.improvements[W.key(stale.x, stale.y)] = { kind = "farm" }
	local id = state.nextSiteId
	local previous = last
	button("CLOSE")
	assert(last == previous and state.nextSiteId == id and p.gold == 100 and not c.siteProjects[id])
	-- Resume a retained project through the actual inspector button.
	state.world.improvements[W.key(stale.x, stale.y)] = nil
	W.reveal(state, H, S)
	cityMenu()
	button("PLACE: K", true)
	target()
	button("CONFIRM")
	assert(accepted)
	local pendingId = c.project.id
	assert(S.queue(p, c, "none", nil, state, H))
	cityMenu()
	button("RESUME K", true)
	assert(accepted and last.action == "resumeSite" and c.project.id == pendingId)
	cityMenu()
	button("CANCEL K", true)
	draw()
	local oldCancel
	for _, b in ipairs(actual.r.buttons) do
		if b.label == "CANCEL SITE" then
			oldCancel = b
		end
	end
	assert(oldCancel)
	local beforeStale = last
	c.siteProjects[pendingId].progress = 9
	c.project.progress = 9
	actual.state = W.forPlayer(state, 0)
	click(oldCancel)
	assert(
		last == beforeStale and c.siteProjects[pendingId].progress == 9,
		"Stale rendered consent must not discard newer investment"
	)
	button("KEEP")
	-- Ownership invalidation hides cached losses and cannot cancel another owner's project.
	cityMenu()
	button("CANCEL K", true)
	local beforeCapture = last
	c.owner = 1
	draw()
	assert(actual.specialtyCancel.invalid)
	button("CLOSE")
	assert(last == beforeCapture and c.siteProjects[pendingId].progress == 9)
	c.owner = 0
	-- Map symbols consume only projected visible/remembered site records and retain hex targets.
	local Map = dofile("/games/civcraft/map_view.lua")
	local symbolCount = 0
	local text = actual.r.text
	actual.r.text = function(renderer, x, y, value, ...)
		if value == "W" then
			symbolCount = symbolCount + 1
		end
		return text(renderer, x, y, value, ...)
	end
	local projected = W.forPlayer(state, 0)
	actual.r:begin()
	Map.draw(
		actual,
		projected,
		projected.players[1],
		{ x = 2, y = 2, w = actual.r.w - 4, h = actual.r.h - 4 }
	)
	actual.r:finish()
	assert(symbolCount > 0 and #actual.hexTargets > 0)
	actual.r.text = text
	-- Switching to an older campaign cannot retain an inaccessible SITES category.
	state.contentRules = "balance4"
	c.project = nil
	S.migrate(state)
	actual.productionCategory = "site"
	cityMenu()
	draw()
	assert(actual.productionCategory == "unit")
	for _, b in ipairs(actual.r.buttons) do
		assert(b.label ~= "SITES")
	end
	actual:close()
end
print(
	"PASS: specialty help, focus/role controls, native map previews and confirmation, cancellation, stale rejection, saved redevelopment and resume"
)
