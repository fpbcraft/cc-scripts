local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Stock = dofile("/games/civcraft/resource_stock.lua")
local Content = dofile("/games/civcraft/content.lua")
local player = {
	id = 1,
	name = "OWNER",
	civ = "forge",
	techs = {},
	gold = 100,
	stockpile = { coal = 1, copper = 1, zinc = 1 },
}
for id in pairs(Systems.techs) do
	player.techs[id] = true
end
local city = {
	id = 1,
	owner = 1,
	x = 4,
	y = 4,
	population = 3,
	buildings = {
		waterwheel = true,
		press = true,
		mixer = true,
		steamplant = true,
		workshop = true,
		library = true,
		market = true,
	},
	sites = { works = { id = 1, kind = "works", x = 5, y = 4 } },
}
local state = {
	phase = "game",
	round = 1,
	contentRules = "balance5",
	ruleset = "create",
	nextId = 3,
	specialtySchema = 1,
	nextSiteId = 3,
	players = { player, { id = 2, name = "RIVAL", civ = "forge", techs = {} } },
	cities = {
		city,
		{
			id = 2,
			owner = 2,
			x = 12,
			y = 8,
			population = 2,
			buildings = { mixer = true },
			sites = { works = { id = 2, kind = "works", x = 13, y = 8 } },
		},
	},
	units = {},
	world = { width = 16, height = 12, tiles = {}, resources = { ["4:4"] = "coal" } },
}
for y = 1, 12 do
	for x = 1, 16 do
		state.world.tiles[x .. ":" .. y] = "plains"
	end
end
Systems.migrate(state)
World.reveal(state, Hex, Systems)
assert(
	Actions.apply(
		state,
		1,
		{ action = "selectMachineRecipe", city = 1, building = "mixer", recipe = "brass" },
		Systems
	)
)
local before = assert(Stock.copy(player.stockpile))
local plan = assert(Systems.machinePlan(state, player, 1))
assert(plan.owner == 1 and plan.stock.brass == 2 and plan.stock.coal == 1)
assert(plan.extraction.rates.coal == 1 and plan.reservations.inputs.coal == 1)
assert(plan.rates.coal == 0 and plan.rates.brass == 2)
for id, value in pairs(before) do
	assert(player.stockpile[id] == value, "Plan mutated stock")
end
assert(plan.effects[1].industry == 11, "Brass recipe cannot also grant Mixer industry")
local capacity = assert(Systems.machineCapacity(state, 1, 1))
assert(
	capacity.capacity == 12 and capacity.used == 5 and capacity.base == 4 and capacity.steamActive
)
capacity.capacity = 999
assert(Systems.machineCapacity(state, 1, 1).capacity == 12)
assert(not Systems.machineCapacity(state, 1, 2))
assert(not Systems.machinePlan(state, 99))
local preview = assert(Systems.previewMachine(state, 1, 1, "mixer", "industry"))
assert(preview.stock.brass == 0 and preview.stock.copper == before.copper)
assert(preview.effects[1].industry == plan.effects[1].industry + 2)
assert(city.machines.mixer.recipe == "brass", "Preview changed selected recipe")
assert(not Systems.previewMachine(state, 1, 1, "mixer", "unknown"))
assert(not Systems.previewMachine(state, 1, 2, "mixer", "industry"))
local forecast = assert(Systems.machineForecast(state, 1))
assert(forecast.economy.strategic.brass == 2 and forecast.economy.strategic.coal == 0)
local frozen = Systems.centerYields(player, city, state, plan)
city.buildings.library = false
assert(
	frozen.science - Systems.centerYields(player, city, state, plan).science
		== Content.buildings.library.effects.science,
	"Unpowered Library continues independently of machine capacity"
)
city.buildings.library = true
player.stockpile = plan.stock
assert(
	Systems.centerYields(player, city, state, plan).industry == frozen.industry,
	"Resolution must use its frozen plan after input debit"
)
assert(
	Systems.machinePlan(state, 1).effects[1].industry < plan.effects[1].industry,
	"A fresh next-round forecast may differ after inputs were consumed"
)
player.stockpile = before
local ownerView = World.forPlayer(state, 1)
local observed = assert(Systems.machinePlan(ownerView, 1))
assert(
	observed.stock.brass == plan.stock.brass
		and observed.effects[1].industry == plan.effects[1].industry
)
state.cities[2].machines.mixer.recipe = "private-invalid"
local private = assert(Systems.machinePlan(state, 1))
assert(private.stock.brass == 2 and #private.machines == #plan.machines)
for _, row in ipairs(private.machines) do
	assert(row.cityID == 1)
end

local Inspector = dofile("/games/civcraft/inspector.lua")
local function renderer()
	local r = { buttons = {}, texts = {} }
	function r:fill() end
	function r:outline() end
	function r:text(_, _, value, _, _, width)
		self.texts[#self.texts + 1] = { value = tostring(value), width = width }
	end
	function r:textWidth(value)
		return #tostring(value or "") * 4
	end
	function r:button(x, y, w, h, label, run)
		self.buttons[#self.buttons + 1] = { x = x, y = y, w = w, h = h, label = label, run = run }
	end
	return r
end
local cityUI = {
	playerID = 1,
	selected = { x = city.x, y = city.y, kind = "city" },
	cityPanel = "machinery",
	inspectorOffset = 0,
	commands = {},
}
function cityUI:command(action, params)
	self.commands[#self.commands + 1] = { action = action, params = params }
end
local function drawInspector(ui, width, height, observer)
	ui.r = renderer()
	Inspector.draw(ui, state, observer, { x = 0, y = 0, w = width, h = height }, false)
	return ui.r
end
local function clickPaged(ui, width, height, label)
	for _ = 1, 16 do
		local r = drawInspector(ui, width, height, player)
		for _, button in ipairs(r.buttons) do
			if button.label == label then
				assert(
					button.w >= 10 and r:textWidth(label) <= button.w - 6,
					"Compact control label is readable: " .. label
				)
				button.run()
				return
			end
		end
		local nextPage
		for _, button in ipairs(r.buttons) do
			if button.label == "NEXT" then
				nextPage = button
				break
			end
		end
		assert(nextPage, "Paged control is reachable: " .. label)
		nextPage.run()
	end
	error("Control not found: " .. label)
end

-- Reduce the owned test city to a single machine so each rendered control has
-- one unambiguous owner-city action target.
city.buildings = { mixer = true }
city.machines = { mixer = { recipe = "brass", priority = 3, enabled = true } }
local large = drawInspector(cityUI, 120, 300, player)
local largeLabels = {}
for _, button in ipairs(large.buttons) do
	largeLabels[button.label] = true
end
for _, label in ipairs({ "MACH", "BRASS", "NO RECIPE", "INDUSTRY", "P-", "P+", "PAUSE", "APPLY" }) do
	assert(largeLabels[label], "Large inspector renders " .. label)
end
assert(
	table
		.concat(
			(function()
				local lines = {}
				for _, item in ipairs(large.texts) do
					lines[#lines + 1] = item.value
				end
				return lines
			end)(),
			" "
		)
		:find("PAUSED: Insufficient local SU", 1, true),
	"Pause reason is rendered in full"
)
for _, label in ipairs({ "NO RECIPE", "BRASS" }) do
	clickPaged(cityUI, 60, 160, label)
	assert(#cityUI.commands == 0, "Recipe preview control does not issue an action")
end

-- At compact width every option and action remains available on a page and
-- each label fits its real button bounds.
cityUI.inspectorOffset = 0
local compactLabels = {}
for _ = 1, 16 do
	local r = drawInspector(cityUI, 60, 160, player)
	for _, button in ipairs(r.buttons) do
		if button.label then
			compactLabels[button.label] = true
		end
	end
	local nextPage
	for _, button in ipairs(r.buttons) do
		if button.label == "NEXT" then
			nextPage = button
			break
		end
	end
	if not nextPage then
		break
	end
	nextPage.run()
end
for _, label in ipairs({ "MACH", "BRASS", "NO RECIPE", "INDUSTRY", "P-", "P+", "PAUSE", "APPLY" }) do
	assert(compactLabels[label], "Compact inspector exposes readable " .. label)
end
clickPaged(cityUI, 60, 160, "MACH")

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end
local function equal(left, right)
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in pairs(left) do
		if not equal(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

cityUI.inspectorOffset = 0
cityUI.machinePreview = nil
local beforePreview = copy(state)
clickPaged(cityUI, 60, 160, "INDUSTRY")
assert(#cityUI.commands == 0, "Choosing a recipe previews without issuing an action")
drawInspector(cityUI, 60, 160, player)
assert(equal(state, beforePreview), "Rendered recipe preview leaves the complete state unchanged")
assert(city.machines.mixer.recipe == "brass", "Preview leaves the persisted recipe unchanged")
clickPaged(cityUI, 60, 160, "APPLY")
local recipeCommand = cityUI.commands[#cityUI.commands]
assert(recipeCommand.action == "selectMachineRecipe")
assert(recipeCommand.params.city == city.id and recipeCommand.params.building == "mixer")
assert(
	recipeCommand.params.recipe == "industry",
	"Apply sends only the explicitly previewed recipe"
)
local recipeFields = 0
for _ in pairs(recipeCommand.params) do
	recipeFields = recipeFields + 1
end
assert(recipeFields == 3, "Recipe action contains only stable identity and selected recipe")

cityUI.inspectorOffset = 0
clickPaged(cityUI, 60, 160, "P-")
assert(cityUI.commands[#cityUI.commands].params.priority == 2)
cityUI.inspectorOffset = 0
clickPaged(cityUI, 60, 160, "P+")
assert(cityUI.commands[#cityUI.commands].params.priority == 4)
assert(
	cityUI.selected.x == city.x and cityUI.selected.y == city.y,
	"Rejected command retains city selection"
)
cityUI.inspectorOffset = 0
clickPaged(cityUI, 60, 160, "P+")
assert(
	cityUI.commands[#cityUI.commands].params.priority == 4,
	"Repeated control after rejection uses the unchanged authoritative priority"
)
assert(cityUI.selected.x == city.x and cityUI.selected.y == city.y)
city.machines.mixer.priority = 2 -- Simulate an authoritative refreshed snapshot after rejection.
cityUI.inspectorOffset = 0
clickPaged(cityUI, 60, 160, "P+")
assert(
	cityUI.commands[#cityUI.commands].params.priority == 3,
	"Priority control uses refreshed state"
)
clickPaged(cityUI, 60, 160, "PAUSE")
assert(cityUI.commands[#cityUI.commands].params.enabled == false)
assert(cityUI.selected.x == city.x and cityUI.selected.y == city.y)
city.machines.mixer.enabled = false -- Re-render the authoritative disabled snapshot.
cityUI.inspectorOffset = 0
clickPaged(cityUI, 60, 160, "ENABLE")
assert(cityUI.commands[#cityUI.commands].params.enabled == true)

local rivalCity = state.cities[2]
player.visible = player.visible or {}
player.visible[rivalCity.x .. ":" .. rivalCity.y] = true
assert(World.observedCity(state, player, rivalCity.x, rivalCity.y) == rivalCity)
local rivalUi = {
	playerID = 1,
	selected = { x = rivalCity.x, y = rivalCity.y, kind = "city" },
	cityPanel = "machinery",
	inspectorOffset = 0,
}
local rivalRender = drawInspector(rivalUi, 120, 300, player)
for _, button in ipairs(rivalRender.buttons) do
	assert(
		button.label ~= "MACH"
			and button.label ~= "BRASS"
			and button.label ~= "NO RECIPE"
			and button.label ~= "INDUSTRY"
			and button.label ~= "P-"
			and button.label ~= "P+"
			and button.label ~= "PAUSE"
			and button.label ~= "ENABLE"
			and button.label ~= "APPLY",
		"Rival city hides machinery controls"
	)
end
for _, item in ipairs(rivalRender.texts) do
	assert(not item.value:find("PLANNED OPERATION", 1, true), "Rival city hides forecasts")
end
local spectatorUi = {
	playerID = nil,
	selected = { x = city.x, y = city.y, kind = "city" },
	cityPanel = "machinery",
	inspectorOffset = 0,
}
local spectator = { id = 0, visible = { [city.x .. ":" .. city.y] = true } }
local spectatorRender = drawInspector(spectatorUi, 120, 300, spectator)
for _, button in ipairs(spectatorRender.buttons) do
	assert(button.label ~= "MACH" and button.label ~= "BRASS", "Spectator hides machinery controls")
end
for _, item in ipairs(spectatorRender.texts) do
	assert(not item.value:find("PLANNED OPERATION", 1, true), "Spectator hides machinery forecast")
end
print("CIVCRAFT: machine forecasts, persistent controls, privacy and preview UI passed")
