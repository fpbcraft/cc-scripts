local native = dofile
dofile = function(path)
  return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
colors = {
  black = 32768,
  white = 1,
  gray = 128,
  lightGray = 256,
  orange = 2,
  lightBlue = 8,
  yellow = 16,
  green = 8192,
  blue = 2048,
  lime = 32,
  red = 16384,
  brown = 4096,
}
local UI = dofile("games/civcraft/ui.lua")
local S = dofile("games/civcraft/systems.lua")
local W = dofile("games/civcraft/world.lua")
local H = dofile("games/civcraft/hex.lua")
local Codex = dofile("games/civcraft/encyclopedia.lua")
local world = {
  width = 18,
  height = 12,
  seed = 42,
  tiles = {},
  resources = {},
  landmarks = { ["7:5"] = { kind = "amethyst", natural = true } },
  rails = {},
  contentVersion = 1,
}
for y = 1, 12 do
  for x = 1, 18 do
    world.tiles[W.key(x, y)] = "plains"
  end
end
local state = {
  ruleset = "create",
  version = 6,
  phase = "game",
  round = 80,
  nextId = 10,
  world = world,
  spawners = { { id = 1, x = 10, y = 6, kind = "spawner" } },
  players = {
    { id = 1, name = "ONE", techs = {}, civ = "iron", gold = 100, stockpile = { iron = 20 } },
    { id = 2, name = "TWO", techs = {}, civ = "verdant" },
  },
  cities = {
    { id = 1, owner = 1, x = 3, y = 4, population = 2, buildings = {} },
    { id = 2, owner = 2, x = 15, y = 9, population = 2, buildings = {} },
    {
      id = 3,
      owner = -1003,
      villageOwner = -1003,
      village = true,
      villageKind = "librarian",
      influence = { [1] = 40, [2] = 10 },
      x = 9,
      y = 5,
      name = "BELLBROOK",
      population = 2,
      buildings = { walls = true },
    },
  },
  units = {
    { id = 4, owner = 1, kind = "engineer", x = 4, y = 4, movesLeft = 3 },
    { id = 5, owner = -2147483647, kind = "zombie", x = 10, y = 6, movesLeft = 0 },
  },
}
for _, id in ipairs(S.techOrder) do
  state.players[1].techs[id] = true
end
S.migrate(state)
for y = 1, 12 do
  for x = 1, 18 do
    state.players[1].explored[W.key(x, y)] = true
    state.players[1].visible = state.players[1].visible or {}
    state.players[1].visible[W.key(x, y)] = true
  end
end
for _, graphics in ipairs({ false, true }) do
  for _, size in ipairs({ { 57, 38 }, { 100, 67 } }) do
    local cw, ch = size[1], size[2]
    local frames = {}
    local monitor = {
      getSize = function(mode)
        if mode == 2 then
          return cw * 6, ch * 9
        end
        return cw, ch
      end,
      getPaletteColor = function()
        return 0, 0, 0
      end,
      setPaletteColor = function() end,
    }
    if graphics then
      monitor.setGraphicsMode = function() end
      monitor.drawPixels = function(x, y, rows, w, h)
        frames.rows = rows
        frames.w = w
        frames.h = h
      end
    else
      monitor.setCursorPos = function() end
      monitor.setBackgroundColor = function() end
      monitor.setTextColor = function() end
      monitor.write = function() end
    end
    local calls = {}
    local ui = UI.new(monitor, function(action, params)
      calls[#calls + 1] = { action = action, params = params }
    end)
    local function draw()
      ui:draw(state, 1, { screen = "game" })
    end
    local function button(label)
      for _, b in ipairs(ui.r.buttons) do
        if b.label == label then
          return b
        end
      end
    end
    local function bounds()
      for _, b in ipairs(ui.r.buttons) do
        assert(
          b.x >= 0 and b.y >= 0 and b.x + b.w <= ui.r.w and b.y + b.h <= ui.r.h,
          "Expanded control offscreen: " .. tostring(b.label)
        )
      end
    end
    draw()
    ui:focus("city", state.cities[1])
    ui.cityPanel = "production"
    draw()
    for _ = 1, 20 do
      if button("WONDER") then
        break
      end
      ui.inspectorOffset = (ui.inspectorOffset or 0) + 1
      draw()
    end
    assert(button("WONDER"), "Wonder production category reachable")
    button("WONDER").fn()
    draw()
    bounds()
    ui:armPlacement("wonder", state.cities[1], "beacon")
    assert(#ui.reachable > 0)
    local target = ui.reachable[1]
    ui:tile(target.x, target.y)
    assert(ui.pendingMove and #calls == 0, "Placement is a preview")
    draw()
    bounds()
    ui:confirmMove()
    assert(
      calls[1].action == "queue" and calls[1].params.kind == "wonder" and calls[1].params.tileX == target.x,
      "Wonder uses confirmed city queue command"
    )
    ui:armPlacement("rail", state.units[1])
    assert(#ui.reachable > 0)
    target = ui.reachable[1]
    ui:tile(target.x, target.y)
    draw()
    ui:confirmMove()
    assert(calls[2].action == "buildRail" and calls[2].params.sx == 4, "Rail uses confirmed engineer command")
    ui:armPlacement("rail", state.units[1])
    assert(ui:back() and not ui.placement and #ui.reachable == 0)
    ui:tile(9, 5)
    draw()
    bounds()
    for _ = 1, 30 do
      if button("SEND ENVOY (25 GOLD)") then
        break
      end
      ui.inspectorOffset = (ui.inspectorOffset or 0) + 1
      draw()
    end
    assert(button("SEND ENVOY (25 GOLD)"), "Village diplomacy reachable")
    button("SEND ENVOY (25 GOLD)").fn()
    assert(calls[3].action == "envoy")
    ui.panel = "resources"
    draw()
    bounds()
    ui.panel = "encyclopedia"
    ui.codex = { category = "sites" }
    draw()
    bounds()
    for _, category in ipairs({ "wonders", "sites", "units", "buildings", "techs" }) do
      for _, entry in ipairs(Codex.entries(category)) do
        assert(#Codex.describe(category, entry, state.players[1]) > 0)
      end
    end
    ui.panel = "context"
    ui:armPlacement("rail", state.units[1])
    ui:draw(state, 2, { handoff = true })
    assert(not ui.placement and #ui.reachable == 0, "Handoff clears construction previews")
    if graphics and cw == 100 then
      _G.civcraftPreview = { rows = frames.rows, w = frames.w, h = frames.h, palette = ui.r.palette }
    end
  end
end
print("CIVCRAFT expansion UI: wonder/rail confirmation, village diplomacy, ledger, Codex and hotseat privacy passed.")
