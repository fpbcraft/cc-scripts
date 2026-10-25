package.path = "./?.lua;./?/init.lua;" .. package.path
local E = require("games.cogworks.engine")
local R = require("games.cogworks.render")
local B = require("games.cogworks.briefing")
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
local game = E.new(#E.levels, true)
local progress = { awards = {}, unlocked = #E.levels }
local model = {
  scene = "title",
  game = game,
  result = E.evaluate(game),
  progress = progress,
  slot = 1,
  selected = "I",
  message = "",
  settings = {
    animations = true,
    showPorts = true,
  },
  slots = { { number = 1, empty = true }, { number = 2, empty = true }, { number = 3, empty = true } },
}
local gfx = { mode = 0, clears = 0, pixels = 0, flushes = 0, palette = {}, batches = 0, width = 400, height = 260 }
function gfx.getSize(mode)
  if mode == 2 then
    return gfx.width, gfx.height
  end
  return 70, 40
end
function gfx.setGraphicsMode(mode)
  gfx.mode = mode
end
function gfx.getPaletteColor()
  return 0, 0, 0
end
function gfx.setPaletteColor(index, color)
  gfx.palette[index] = color
end
function gfx.setFrozen(value)
  if not value then
    gfx.flushes = gfx.flushes + 1
  end
end
function gfx.drawPixels(x, y, fill, w, h)
  assert(x >= 0 and y >= 0 and x + w <= gfx.width and y + h <= gfx.height, "Pixel out of bounds")
  assert(w > 0 and h > 0, "Invalid pixel rectangle")
  if type(fill) == "table" then
    assert(#fill == h, "One bitmap row per pixel row")
    for _, row in ipairs(fill) do
      assert(type(row) == "string" and #row == w, "Bitmap row must cover its declared width")
    end
    gfx.batches = gfx.batches + 1
  else
    assert(fill >= 0 and fill < 16, "Invalid palette index")
    if x == 0 and y == 0 and w == gfx.width and h == gfx.height then
      assert(fill == 0, "Full-screen clear uses blueprint background ink")
      gfx.clears = gfx.clears + 1
    end
  end
  gfx.pixels = gfx.pixels + 1
end
local r = R.new(gfx)
assert(r.mode == "graphics" and gfx.mode == 2)
assert(math.abs(r.scale - 2) < 0.001, "Graphics virtual dimensions")
assert(gfx.palette[0] == 0x07192D and gfx.palette[11] == 0x64D3F2, "Blueprint ink palette installed")
assert(
  gfx.palette[14] == 0xF4A25E and gfx.palette[11] ~= gfx.palette[14],
  "Rotation direction colors use distinct cyan and amber"
)
local wheel = E.sandbox()
assert(E.place(wheel, 2, 3, "O", 1))
assert(E.place(wheel, 2, 4, "G", 1))
local wheelInfo = E.evaluate(wheel)
local cog = E.get(wheel, 2, 4)
r.frame = 0
r.buffer = {}
r:piece(20, 20, 13, cog, wheelInfo.lights[cog.id])
assert(r.buffer[27] and r.buffer[27][30] == 15, "Small pinion highlights its first gear tooth at frame zero")
r.frame = 1
r.buffer = {}
r:piece(20, 20, 13, cog, wheelInfo.lights[cog.id])
assert(r.buffer[27][30] ~= 15, "Highlighted tooth must move to a new location on the next frame")
local pixels = 0
for _, row in pairs(r.buffer) do
  for _, ink in pairs(row) do
    if ink == 14 then
      pixels = pixels + 1
    end
  end
end
assert(pixels > 0, "Rotation marker remains visible after stepping to next frame")
-- Pixel geometry matches the approved 200x120 HTML prototype:
-- radius 3/4, eight protruding 2x2 teeth, and a blue/orange steel spoke.
local function gearFrame(large, spin, frame)
  r.frame = frame
  r.buffer = {}
  r:cog(35, 35, large, spin)
  return r.buffer
end
local function pixel(frame, x, y)
  return frame[y + 1] and frame[y + 1][x + 1] or 0
end
local small = gearFrame(false, { rate = 1, sign = 1 }, 0)
local large = gearFrame(true, { rate = 1, sign = 1 }, 0)
assert(pixel(small, 38, 35) == 15, "Small pinion highlighted tooth lies three pixels from its center")
assert(pixel(large, 40, 35) == 15, "Large wheel highlighted tooth lies five pixels from its center")
assert(pixel(small, 40, 35) == 0 and pixel(large, 40, 35) == 15, "Large cog extends two pixels beyond the pinion")
assert(pixel(small, 34, 34) == 6 and pixel(large, 34, 34) == 13, "Small solid face and large steel hub are distinct")
local forward = gearFrame(false, { rate = 1, sign = 1 }, 1)
local reverse = gearFrame(false, { rate = 1, sign = -1 }, 1)
assert(pixel(forward, 38, 35) ~= 15, "At 1X the highlighted tooth travels between successive frames")
assert(pixel(forward, 38, 36) == 15, "CW tooth travels down from the rightmost starting position")
assert(pixel(reverse, 38, 34) == 15, "CCW tooth travels up from the rightmost starting position")
local slow = gearFrame(false, { rate = 0.5, sign = 1 }, 1)
local fast = gearFrame(false, { rate = 2, sign = 1 }, 1)
assert(pixel(slow, 38, 36) == 15, "Half-speed cog advances a shorter angle per frame")
assert(pixel(fast, 37, 37) == 15, "Double-speed cog advances a longer angle per frame")
r.frame = 0
r.buffer = {}
r:toolIcon(10, 10, "G")
local smallIcon = r.buffer
r.buffer = {}
r:toolIcon(10, 10, "O")
local largeIcon = r.buffer
assert(pixel(smallIcon, 10, 10) == 0, "Small pinion palette icon has exposed corners")
assert(pixel(largeIcon, 10, 13) == 6, "Large palette cog has an outer cardinal tooth")
r.buffer = {}
local function click(action, arg)
  for _, v in ipairs(r.targets) do
    if v.action == action and (arg == nil or v.arg == arg) then
      local x = r.ox + r.scale * (v.x + v.w / 2)
      local y = r.oy + r.scale * (v.y + v.h / 2)
      local a, b, c = r:hit(x, y)
      assert(a == action and (arg == nil or b == arg), "Hitbox mismatch for " .. action)
      local d, e = r:hitNormalized(x / r.pw, y / r.ph)
      assert(d == action and (arg == nil or e == arg), "Normalized hitbox mismatch for " .. action)
      return v
    end
  end
  error("Missing touch button " .. action .. " / " .. tostring(arg))
end
r:draw(model)
assert(gfx.batches == 1, "Title screen uploads one batched bitmap to the monitor")
assert(gfx.clears == 1, "Graphics startup clears the complete physical monitor surface")
click("slots")
click("settings")
click("exit")
-- monitor_touch delivers 1-based character cells, whereas hit() receives
-- actual pixels. Exercise multiple title actions after real character mapping.
local function monitorHit(action)
  for _, item in ipairs(r.targets) do
    if item.action == action then
      local px = r.ox + r.scale * (item.x + item.w / 2)
      local py = r.oy + r.scale * (item.y + item.h / 2)
      local cw, ch = gfx.getSize()
      local col = math.floor(px / r.pw * cw) + 1
      local line = math.floor(py / r.ph * ch) + 1
      local found = r:hitTouch(col, line)
      assert(found == action, "Character monitor_touch should hit " .. action)
      return
    end
  end
  error("Missing monitor action: " .. action)
end
monitorHit("slots")
monitorHit("settings")
monitorHit("exit")
assert(r:hitTouch(0, 2) == nil and r:hitTouch(71, 20) == nil, "Reject out of bounds touches")
model.scene = "slots"
r:draw(model)
click("slot", 1)
click("slot", 2)
model.scene = "game"
r:draw(model)
assert(#r.targets >= game.width * game.height + 12, "Game includes all variable-size board cells")
-- Selecting a board piece draws a complete outline with small action glyphs
-- and keeps rotate/remove hitboxes above the underlying grid hit target.
local campaignGame, campaignResult = model.game, model.result
model.game = E.sandbox(5, 5)
assert(E.place(model.game, 3, 3, "G", 1))
model.result = E.evaluate(model.game)
model.inspected = { x = 3, y = 3 }
r:draw(model)
click("rotate", 3)
click("remove", 3)
local selectedPx = r.boardX + (model.inspected.x - 1) * r.cell
local selectedPy = r.boardY + (model.inspected.y - 1) * r.cell
assert(r.buffer[selectedPy + 1][selectedPx + 1] == 11, "Selected part shows cyan outline around its cell")
model.inspected = nil
model.selected = "G"
r:draw(model)
local foundActive = false
for _, target in ipairs(r.targets) do
  if target.action == "tool" and target.arg == "G" then
    assert(r.buffer[target.y + 1][target.x + 1] == 6, "Selected palette part has bright border")
    foundActive = true
  end
end
assert(foundActive, "Selected gear appears in palette")
model.game, model.result = campaignGame, campaignResult
model.selected = "I"
r:draw(model)
click("cell", 1)
click("pause")
click("save")
click("tool", "D")
click("tool", "R")
click("tool", "B")
click("tool", "erase")
for _, target in ipairs(r.targets) do
  assert(target.arg ~= "L" and target.arg ~= "T", "Fictitious controls removed")
end
assert(gfx.pixels >= 3 and gfx.pixels < 50, "One batched upload per screen instead of thousands of pixel calls")
model.scene = "pause"
r:draw(model)
click("resume")
click("levels")
click("settings")
click("title")
model.scene = "levels"
r:draw(model)
click("level", 1)
click("level", #E.levels)
click("back")
model.scene = "settings"
r:draw(model)
click("toggleAnimations")
click("togglePorts")
click("back")
model.scene = "help"
r:draw(model)
click("back")
model.scene = "confirm"
model.pending = "newGame"
r:draw(model)
click("confirm")
click("cancel")
-- Draw the belt between parallel pulleys on the new stage eleven.
local spanCount = 0
local originalSpan = r.drawSpan
function r:drawSpan(...)
  spanCount = spanCount + 1
  return originalSpan(self, ...)
end
model.game = E.new(11, true)
model.result = E.evaluate(model.game)
model.scene = "game"
r:draw(model)
assert(spanCount > 0, "Clear-span belt links must be rendered")
model.scene = "tutorial"
model.tutorial = {
  steps = { { key = "V", title = "BELT TRANSMISSION", lines = { "PAIR TWO BELTS", "POWER TRAVELS ACROSS GAPS" } } },
  index = 1,
}
r:draw(model)
click("tutorialNext")
click("tutorialSkip")
for _, target in ipairs(r.targets) do
  assert(target.action ~= "cell", "Ponder must block board interaction")
end
local uploadsBefore = gfx.batches
r:draw(model)
assert(gfx.batches <= uploadsBefore + 1, "Each redraw uploads no more than one bitmap")
-- Briefing is modal, has animated reveals, and respects disabled animation.
local largeTitles = 0
local large = r.fontLarge
function r:fontLarge(...)
  largeTitles = largeTitles + 1
  return large(self, ...)
end
model.scene = "briefing"
model.briefing = B.forLevel(11)
model.settings.animations = true
r:draw(model)
assert(largeTitles == 0, "Briefing title animates into view")
for i = 1, 8 do
  r:draw(model)
end
assert(largeTitles > 0, "Briefing title reveals during animation")
click("beginLevel")
for _, target in ipairs(r.targets) do
  assert(target.action ~= "cell", "Intro blocks interaction with the level grid")
end
model.briefing = B.forLevel(#E.levels)
model.settings.animations = false
local count = largeTitles
r:draw(model)
assert(largeTitles == count + 1, "Disabled animation reveals everything immediately")
-- Every authored mission tip must fit completely in the enlarged hero panel.
-- The compact pixel font takes 4px per character; <=42 fits x=15..183.
for index, level in ipairs(E.levels) do
  local lines = r:wrapBriefingTip(level.tip)
  assert(#lines >= 1 and #lines <= 2, "Description needs at most two lines: " .. index)
  assert(table.concat(lines, " ") == level.tip, "Description wording is preserved: " .. index)
  for _, line in ipairs(lines) do
    assert(#line <= 42, "Description will not be clipped: " .. index)
  end
  model.briefing = B.forLevel(index)
  model.settings.animations = false
  r:draw(model)
end
-- Sandbox includes two dedicated redstone palette components.
model.game = E.sandbox()
model.result = E.evaluate(model.game)
model.progress = { awards = {}, unlocked = 1 }
model.scene = "game"
r:draw(model)
click("tool", "R")
click("tool", "B")
click("toggleAnimations")
local running = E.sandbox(5, 5)
assert(E.place(running, 2, 3, "I", 1))
assert(E.place(running, 3, 3, "G", 1))
model.game = running
model.result = E.evaluate(running)
model.selected = "G"
model.settings.animations = true
r:draw(model)
local beforeAnimated = gfx.batches
r:draw(model)
assert(gfx.batches == beforeAnimated + 1, "Two consecutive animated frames upload distinct cog pixels")
model.scene = "title"
model.dev = true
r:draw(model)
click("devLevels")
model.scene = "levels"
model.game = nil
model.devSession = true
r:draw(model)
click("level", #E.levels)
local long = r:wrapBriefingTip("BUILD EVERY CONNECTION; UNUSED PORTS LEAK POWER.")
assert(#long == 2, "Long instruction must wrap instead of truncating")
model.settings.animations = true
assert(
  r:hitNormalized(-0.1, 0.5) == nil and r:hitNormalized(1, 0.5) == nil,
  "Out-of-range normalized monitor clicks rejected"
)
r:resize()
model.scene = "title"
r:draw(model)
local firstFullDraws = gfx.clears
-- A monitor_resize must fully clear old pixels/letterbox areas before drawing.
gfx.width, gfx.height = 440, 240
r:resize()
r:draw(model)
assert(gfx.clears == firstFullDraws + 1, "Resize clears old pixels, text and white letterbox strips")
monitorHit("slots")
local afterFullDraw = gfx.pixels
r:draw(model)
assert(gfx.pixels == afterFullDraw, "No-op draw must not send redundant monitor pixels")
r:close()
assert(gfx.mode == 0, "Graphics mode restored")
local txt = { w = 70, h = 40, writes = 0 }
function txt.getSize()
  return txt.w, txt.h
end
function txt.setBackgroundColor() end
function txt.setTextColor() end
function txt.clear() end
function txt.setCursorPos(x, y)
  assert(x >= 1 and y >= 1 and x <= txt.w and y <= txt.h, "Text cursor out of bounds")
end
function txt.write(str)
  txt.writes = txt.writes + #str
end
model.game = E.new(11, true)
model.result = E.evaluate(model.game)
model.progress = { awards = {}, unlocked = #E.levels }
model.devSession = false
local plain = R.new(txt)
assert(plain.mode == "text")
for _, scene in ipairs({
  "title",
  "slots",
  "game",
  "briefing",
  "tutorial",
  "pause",
  "settings",
  "levels",
  "help",
  "confirm",
}) do
  model.scene = scene
  plain:draw(model)
  assert(#plain.targets > 0, "Text fallback has buttons on " .. scene)
end
plain:close()
assert(txt.writes > 0, "Vanilla renderer should draw text")
print("COGWORKS: pixel-diff monitor, animated cogs, flexible grid, belts and touch controls passed.")
