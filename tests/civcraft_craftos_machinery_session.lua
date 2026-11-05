-- Native UI fixture: completed infrastructure/resources are setup, not production evidence.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Saves = dofile("/games/civcraft/saves.lua")
local UI = dofile("/games/civcraft/ui.lua")
local monitor = (...) == "--monitor"
local display = term.current()
local previousScale
if monitor then
	assert(_G.periphemu.create("top", "monitor"))
	display = assert(peripheral.wrap("top"))
	previousScale = display.getTextScale()
	display.setTextScale(0.5)
end
local owner = {
	id = 1,
	name = "OWNER",
	civ = "iron",
	techs = {},
	gold = 100,
	stockpile = { coal = 3, copper = 1, zinc = 1 },
}
for id in pairs(Systems.techs) do
	owner.techs[id] = true
end
local city = {
	id = 1,
	owner = 1,
	x = 4,
	y = 4,
	population = 3,
	buildings = { mixer = true },
	sites = { works = { id = 1, kind = "works", x = 5, y = 4 } },
}
local state = {
	phase = "game",
	round = 1,
	ruleset = "create",
	contentRules = "balance5",
	nextId = 3,
	nextSiteId = 2,
	specialtySchema = 1,
	players = { owner },
	cities = { city },
	units = {},
	world = { width = 12, height = 10, tiles = {}, resources = {} },
}
for y = 1, 10 do
	for x = 1, 12 do
		state.world.tiles[x .. ":" .. y] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)
local requests, rejected = {}, false
local ui = UI.new(display, function(action, data)
	if action == "setMachinePriority" and not rejected then
		rejected = true
		requests[#requests + 1] = { action = action, accepted = false }
		return false, "Fixture: rejected stale command"
	end
	local request = {}
	for key, value in pairs(data or {}) do
		request[key] = value
	end
	request.action = action
	local ok, why = Actions.apply(state, 1, request, Systems)
	requests[#requests + 1] =
		{ action = action, accepted = ok, city = request.city, building = request.building }
	assert(ok, why)
	return ok, why
end)
ui:focus("city", city)
ui.panel, ui.cityPanel = "inspector", "machinery"
local pages = {}
local function draw()
	ui:draw(World.forPlayer(state, 1), 1, { localMode = true, screen = "game" })
	local buttons = {}
	for _, button in ipairs(ui.r.buttons) do
		buttons[#buttons + 1] = {
			label = button.label,
			x = button.x,
			y = button.y,
			width = button.w,
			height = button.h,
		}
	end
	pages[#pages + 1] = { offset = ui.inspectorOffset, panel = ui.cityPanel, buttons = buttons }
	if #pages > 100 then
		table.remove(pages, 1)
	end
	local log = assert(fs.open("/machinery-pages.json", "w"))
	log.write(textutils.serializeJSON(pages))
	log.close()
end
local function click(button)
	local x, y = button.x + button.w / 2, button.y + button.h / 2
	if ui.r.mode == "graphics" then
		x, y = ui.r.ox + x * ui.r.sx, ui.r.oy + y * ui.r.sy
	else
		x, y = x / 2 + 1, y / 3 + 1
	end
	if monitor then
		os.queueEvent("monitor_touch", "top", math.floor(x), math.floor(y))
	else
		os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
		os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
	end
	local released = false
	while not released do
		local event, side, ex, ey = ui.r:pullEvent()
		if event == "monitor_touch" and side == "top" then
			ui:tap(ex, ey)
			released = true
		elseif event == "mouse_click" then
			ui:pointerDown(ex, ey)
		elseif event == "mouse_up" then
			ui:pointerUp()
			released = true
		end
	end
	draw()
end
local function tap(label)
	local direction = "NEXT"
	for _ = 1, 100 do
		for _, button in ipairs(ui.r.buttons) do
			if button.label == label then
				click(button)
				return
			end
		end
		local page
		for _, button in ipairs(ui.r.buttons) do
			if button.label == direction then
				page = button
			end
		end
		assert(page, "Unreachable native control: " .. label)
		local before = ui.inspectorOffset
		click(page)
		if ui.inspectorOffset == before then
			direction = direction == "NEXT" and "PREV" or "NEXT"
		end
	end
	error("Native control never became visible: " .. label)
end

draw()
local before = textutils.serialize(state)
tap("BRASS")
assert(
	textutils.serialize(state) == before and #requests == 0,
	"Preview must not change authoritative state"
)
tap("APPLY")
assert(city.machines.mixer.recipe == "brass", "Explicit APPLY saves selected recipe")
assert(owner.stockpile.copper == 1 and owner.stockpile.zinc == 1, "Controls do not spend materials")
tap("P+")
assert(
	rejected and city.machines.mixer.priority == 3,
	"Rejected command retains authoritative priority"
)
tap("P+")
assert(city.machines.mixer.priority == 4, "Fresh control uses authoritative priority")
tap("PAUSE")
assert(city.machines.mixer.enabled == false)
tap("ENABLE")
assert(city.machines.mixer.enabled == true)
assert(
	ui.selected.x == city.x and ui.selected.y == city.y and ui.cityPanel == "machinery",
	"Commands retain city selection"
)
assert(Saves.save(1, state))
local restored = assert(Saves.load(1))
Systems.migrate(restored)
assert(
	restored.cities[1].machines.mixer.recipe == "brass"
		and restored.cities[1].machines.mixer.priority == 4
)
assert(restored.players[1].stockpile.copper == 1, "Native save preserves stock and choices")
local f = assert(fs.open("/machinery-results.json", "w"))
f.write(textutils.serializeJSON({
	host = _G._HOST,
	mode = ui.r.mode,
	monitor = monitor,
	requests = requests,
	previewReadOnly = true,
	selectionRetained = true,
	rejectedThenRecovered = true,
	savedChoices = true,
}))
f.close()
ui:close()
if monitor then
	display.setTextScale(previousScale)
	_G.periphemu.remove("top")
end
