-- 64-stage, 8-chapter kinetic campaign. Authoring templates are derived
-- from the mechanically verified v0.3 puzzles; each variant is rotated or
-- mirrored, repositioned and supplied with an individual objective layout.
-- All data is regular Lua tables, compatible with future compiled level packs.
local seed = require("games.cogworks.levels_seed")
local chapters = require("games.cogworks.chapters").chapters
local levels = {}
local chapterSeeds = {
  { 1, 1, 1, 1, 1, 1, 1, 1 },
  { 2, 2, 3, 2, 3, 3, 5, 5 },
  { 4, 4, 4, 13, 4, 13, 15, 15 },
  { 9, 10, 9, 10, 9, 10, 14, 14 },
  { 6, 6, 6, 12, 6, 12, 12, 12 },
  { 11, 11, 11, 11, 14, 14, 14, 14 },
  { 7, 8, 7, 8, 7, 8, 16, 16 },
  { 12, 14, 15, 16, 12, 14, 15, 16 },
}
local function clone(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, child in pairs(value) do
    result[key] = clone(child)
  end
  return result
end
local function part(kind, x, y, r)
  return { kind = kind, x = x, y = y, r = r or 0 }
end
local function shaftLesson(step)
  local width = math.max(5, step + 2)
  local height = math.max(5, math.min(10, step + 2))
  local built, fixtures, stock = {}, {}, { I = step }
  for x = 2, step + 1 do
    local p = part("I", x, 3, 1)
    if step >= 4 and x == math.floor((step + 3) / 2) then
      fixtures[#fixtures + 1] = p
      stock.I = stock.I - 1
    else
      built[#built + 1] = p
    end
  end
  local name = step == 8 and "LONG RUN / SHAFT TEST" or ("SHAFT RUN " .. step)
  return {
    name = name,
    tip = step == 8 and "FINISH THE LONG SHAFT LINE WITH A FIXED COUPLING."
      or "EXTEND THE AXIAL SHAFT LINE TO THE PRESS.",
    width = width,
    height = height,
    source = part("S", 1, 3, 1),
    goals = { { kind = "M", x = step + 2, y = 3, r = 3, speed = 1, sign = 1 } },
    build = built,
    fixtures = fixtures,
    blocks = {},
    stock = stock,
    redstone = {},
    removeRedstone = {},
    toggles = {},
  }
end
local function fromSeed(chapter, step)
  local template = seed[chapterSeeds[chapter][step]]
  local width = math.max(5 + chapter - 1 + (step >= 6 and 1 or 0), template.width)
  local height = math.max(5 + chapter - 1 + (step >= 6 and 1 or 0), template.height)
  width, height = math.min(10, width), math.min(10, height)
  local flipX = step % 4 == 2 or step % 4 == 0
  local flipY = step % 4 == 3 or step % 4 == 0
  local offsetX = math.floor((width - template.width) / 2)
  local offsetY = math.floor((height - template.height) / 2)
  local function coords(x, y)
    return offsetX + (flipX and template.width + 1 - x or x), offsetY + (flipY and template.height + 1 - y or y)
  end
  local function relocate(p)
    local t = clone(p)
    t.x, t.y = coords(p.x, p.y)
    if flipX then
      t.r = ({ [0] = 0, [1] = 3, [2] = 2, [3] = 1 })[t.r or 0]
    end
    if flipY then
      t.r = ({ [0] = 2, [1] = 1, [2] = 0, [3] = 3 })[t.r or 0]
    end
    return t
  end
  local function relocateAll(values)
    local list = {}
    for _, value in ipairs(values or {}) do
      list[#list + 1] = relocate(value)
    end
    return list
  end
  local data = {
    name = step == 8 and chapters[chapter].test or template.name,
    tip = template.tip,
    width = width,
    height = height,
    source = relocate(template.source),
    goals = relocateAll(template.goals),
    fixtures = relocateAll(template.fixtures),
    build = relocateAll(template.build),
    redstone = relocateAll(template.redstone),
    stock = clone(template.stock),
    removeRedstone = {},
    blocks = {},
    toggles = {},
  }
  -- Early hints become increasingly constrained; later stages can start
  -- with pre-installed, immovable mechanical components.
  if step == 4 or step == 6 or step == 8 then
    local fixedCount = step == 8 and 2 or 1
    for _ = 1, math.min(fixedCount, math.max(0, #data.build - 1)) do
      local fixture = table.remove(data.build, 1)
      fixture.fixed = nil
      data.fixtures[#data.fixtures + 1] = fixture
      data.stock[fixture.kind] = data.stock[fixture.kind] - 1
    end
  end
  for _, pos in ipairs(template.removeRedstone or {}) do
    local x, y = coords(pos[1], pos[2])
    data.removeRedstone[#data.removeRedstone + 1] = { x, y }
  end
  for _, pos in ipairs(template.blocks or {}) do
    local x, y = coords(pos[1], pos[2])
    data.blocks[#data.blocks + 1] = { x, y }
  end
  -- A few fixed stone borders create useful placement restrictions without
  -- interfering with any reference power path.
  if step >= 5 then
    local occupied = {}
    for _, p in ipairs({ data.source }) do
      occupied[p.y * 20 + p.x] = true
    end
    for _, list in ipairs({ data.goals, data.build, data.fixtures, data.redstone }) do
      for _, p in ipairs(list) do
        occupied[p.y * 20 + p.x] = true
      end
    end
    for _, pos in ipairs(data.blocks) do
      occupied[pos[2] * 20 + pos[1]] = true
    end
    local corners = { { 1, 1 }, { width, height } }
    for k = 1, step >= 7 and 2 or 1 do
      local p = corners[k]
      if not occupied[p[2] * 20 + p[1]] then
        data.blocks[#data.blocks + 1] = p
      end
    end
  end
  return data
end
for chapter = 1, 8 do
  for step = 1, 8 do
    local stage = chapter == 1 and shaftLesson(step) or fromSeed(chapter, step)
    stage.chapter, stage.stage = chapter, step
    stage.finale = step == 8
    stage.title = chapter .. "-" .. step .. " " .. stage.name
    levels[#levels + 1] = stage
  end
end
return levels
