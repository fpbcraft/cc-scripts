-- Prevent keyboard-repeat events from triggering expensive graphics-mode clears.
-- Rendering belongs to the fixed-rate timer loop, not to individual key events.
local file = assert(io.open("games/wormfront/main.lua", "r"))
local script = file:read("*a")
file:close()
local keyboard = assert(script:match('elseif event == "key" and keys then(.-)elseif event == "key_up"'))
local release = assert(script:match('elseif event == "key_up" and keys then(.-)elseif event == "char"'))
local character = assert(script:match('elseif event == "char" then(.-)elseif event == "rednet_message"'))
local network = assert(script:match('elseif event == "rednet_message" then(.-)elseif event == "monitor_resize"'))
for _, section in ipairs({ keyboard, release, character, network }) do
  assert(not section:find("redraw(", 1, true), "Input or rednet events must not trigger immediate frames")
end
assert(script:find("if current - lastDraw >= 0.16 then", 1, true))
assert(script:find("local timer = os.startTimer(0.1)", 1, true))
assert(script:find("keys.r or key == keys.t", 1, true))
assert(not keyboard:find('kind = "select"', 1, true), "Keyboard must not switch active worms")
print("WORMFRONT: redraw batching, keyboard ownership and rope bindings passed")
