-- Real native renderer and queued input; run only in an isolated CraftOS profile.
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local UI = dofile("/games/civcraft/ui.lua")
local state = Lifecycle.newLobby("native-coal-ledger")
state.mapSize, state.mapSeed, state.hostileMode = "compact", 319497, "off"
state.players =
	{ { id = 0, name = "HOST", civ = "forge" }, { id = 1, name = "OTHER", civ = "scholar" } }
Lifecycle.initialize(state)
local settler
for _, unit in ipairs(state.units) do
	if unit.owner == 0 and unit.kind == "settler" then
		settler = unit
	end
end
assert(
	Actions.apply(
		state,
		0,
		{ action = "found", unitID = settler.id, x = settler.x, y = settler.y },
		Systems
	)
)
local city
for _, candidate in ipairs(state.cities) do
	if candidate.owner == 0 then
		city = candidate
	end
end
local player = state.players[1]
player.techs.steampower, player.stockpile.coal = true, 10
state.world.resources[World.key(city.x, city.y)] = "coal"
World.reveal(state, Hex, Systems)
local ui = UI.new(term.current(), function()
	error("Ledger paging must not issue gameplay commands")
end)
local shown, seen = {}, false
local drawText = ui.r.text
ui.r.text = function(renderer, x, y, text, ...)
	shown[#shown + 1] = tostring(text)
	return drawText(renderer, x, y, text, ...)
end
local function draw()
	ui:draw(World.forPlayer(state, 0), 0, { screen = "game", localMode = true, report = false })
end
local function click(target)
	local r = ui.r
	local x, y = target.x + target.w / 2, target.y + target.h / 2
	if r.mode == "graphics" then
		x, y = r.ox + x * r.sx, r.oy + y * r.sy
	else
		x, y = x / 2 + 1, y / 3 + 1
	end
	os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
	local _, _, px, py = os.pullEvent("mouse_click")
	ui:pointerDown(px, py)
	ui:pointerUp(px, py)
end
local function button(label)
	for _, target in ipairs(ui.r.buttons) do
		if target.label == label then
			return target
		end
	end
end
local ok, why = pcall(function()
	draw()
	click(assert(button("RESOURCE LEDGER")))
	assert(ui.panel == "resources")
	for _ = 1, 40 do
		draw()
		local text = table.concat(shown, " ")
		if text:find("COAL 10/10", 1, true) and text:find("COAL LOST/TURN", 1, true) then
			seen = true
			break
		end
		click(assert(button("NEXT"), "Coal ledger row must be reachable by paging"))
	end
	assert(seen, "Real renderer must draw coal stock/cap and extraction overflow")
	assert(player.stockpile.coal == 10, "Read-only ledger must preserve stock")
end)
ui:close()
assert(ok, why)
print("CIVCRAFT: native coal ledger rendering, queued input, paging and stock conservation passed")
