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
local game = E.new(30, true)
local progress = { awards = {}, unlocked = 30 }
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
local gfx = { mode = 0, clears = 0, pixels = 0, flushes = 0 }
function gfx.getSize(mode)
  if mode == 2 then
    return 400, 260
  end
  return 70, 40
end
function gfx.setGraphicsMode(mode)
  gfx.mode = mode
end
function gfx.getPaletteColor()
  return 0, 0, 0
end
function gfx.setPaletteColor() end
function gfx.setFrozen(value)
  if not value then
    gfx.flushes = gfx.flushes + 1
  end
end
function gfx.drawPixels(x, y, color, w, h)
  assert(x >= 0 and y >= 0 and x + w <= 400 and y + h <= 260, "Pixel out of bounds")
  assert(w > 0 and h > 0 and color >= 0 and color < 16, "Invalid pixel rectangle")
  if x == 0 and y == 0 and w == 400 and h == 260 and color == 0 then
    gfx.clears = gfx.clears + 1
  end
  gfx.pixels = gfx.pixels + 1
end
local r = R.new(gfx)
assert(r.mode == "graphics" and gfx.mode == 2)
assert(math.abs(r.scale - 2) < 0.001, "Graphics virtual dimensions")
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
assert(gfx.clears == 1, "Title screen must clear whole monitor")
click("slots")
click("settings")
click("exit")
model.scene = "slots"
r:draw(model)
click("slot", 1)
click("slot", 2)
model.scene = "game"
r:draw(model)
assert(#r.targets >= E.WIDTH * E.HEIGHT + 12, "Game includes parts and board hitboxes")
click("cell", 1)
click("pause")
click("save")
click("tool", "D")
click("tool", "erase")
for _, target in ipairs(r.targets) do
  assert(target.arg ~= "C" and target.arg ~= "switch", "Clutch control removed")
end
assert(gfx.pixels > 500, "Graphics rendering should draw components")
model.scene = "pause"
r:draw(model)
click("resume")
click("levels")
click("settings")
click("title")
model.scene = "levels"
r:draw(model)
click("level", 1)
click("level", 30)
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
-- Draw the level-six belt: its physical span should cross the stone gap.
local spanCount = 0
local originalSpan = r.drawSpan
function r:drawSpan(...)
  spanCount = spanCount + 1
  return originalSpan(self, ...)
end
model.game = E.new(6, true)
model.result = E.evaluate(model.game)
model.scene = "game"
r:draw(model)
assert(spanCount > 0, "Gap-spanning belts must be rendered")
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
assert(gfx.clears == 10, "Every scene including Ponder clears the framebuffer")
-- Briefing is modal, has animated reveals, and respects disabled animation.
local largeTitles = 0
local large = r.fontLarge
function r:fontLarge(...)
  largeTitles = largeTitles + 1
  return large(self, ...)
end
model.scene = "briefing"
model.briefing = B.forLevel(6)
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
model.briefing = B.forLevel(23)
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
local long = r:wrapBriefingTip("BUILD EVERY CONNECTION; UNUSED PORTS LEAK POWER.")
assert(#long == 2, "Long instruction must wrap instead of truncating")
model.settings.animations = true
assert(
  r:hitNormalized(-0.1, 0.5) == nil and r:hitNormalized(1, 0.5) == nil,
  "Out-of-range normalized monitor clicks rejected"
)
r:resize()
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
local plain = R.new(txt)
assert(plain.mode == "text")
for _, scene in ipairs({ "title", "slots", "game", "briefing", "tutorial", "pause", "settings", "levels", "help", "confirm" }) do
  model.scene = scene
  plain:draw(model)
  assert(#plain.targets > 0, "Text fallback has buttons on " .. scene)
end
plain:close()
assert(txt.writes > 0, "Vanilla renderer should draw text")
print("COGWORKS: animated briefing, belt spans, Ponder and touch targets passed.")
