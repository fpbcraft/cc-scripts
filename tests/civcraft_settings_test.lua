local nativeOs = os
os = {}
for key, value in pairs(nativeOs) do
	os[key] = value
end
local timer = 0
os.startTimer = function()
	timer = timer + 1
	return timer
end
dofile = function(path)
	return assert(loadfile(path:gsub("^/games/civcraft/", "games/civcraft/"), "t", _ENV))()
end
local Audio = dofile("/games/civcraft/audio.lua")
local UI = dofile("/games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local files, encoded, notes = {}, {}, {}
fs = {
	exists = function(path)
		return files[path] ~= nil
	end,
	makeDir = function(path)
		files[path] = true
	end,
}
function fs.open(path, mode)
	if mode == "r" then
		return {
			readAll = function()
				return files[path]
			end,
			close = function() end,
		}
	end
	return {
		write = function(value)
			files[path] = value
		end,
		close = function() end,
	}
end
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
textutils = {
	serialize = function(value)
		encoded[#encoded + 1] = copy(value)
		return tostring(#encoded)
	end,
	unserialize = function(value)
		return copy(encoded[tonumber(value)])
	end,
}
local speaker = {
	playNote = function(_, volume)
		notes[#notes + 1] = volume
	end,
}
peripheral = {
	getNames = function()
		return { "speaker" }
	end,
	getType = function()
		return "speaker"
	end,
	wrap = function()
		return speaker
	end,
}

for _, graphics in ipairs({ false, true }) do
	files, encoded, notes = {}, {}, {}
	local audio = Audio.new()
	local monitor = {
		getSize = function(mode)
			if mode == 2 then
				return 402, 252
			end
			return 67, 28
		end,
		getPaletteColor = function()
			return 0, 0, 0
		end,
		setPaletteColor = function() end,
		setCursorPos = function() end,
		setBackgroundColor = function() end,
		setTextColor = function() end,
		write = function() end,
	}
	if graphics then
		monitor.setGraphicsMode = function() end
		monitor.drawPixels = function() end
	end
	local ui = UI.new(monitor, function(action)
		if action == "audio" then
			audio:toggle("title")
		elseif action == "music" then
			audio:toggleMusic("title")
		elseif action == "volume" then
			audio:cycleVolume("title")
		else
			error("Settings must not dispatch gameplay: " .. action)
		end
	end)
	local state = { phase = "lobby", round = 1, players = {}, units = {}, cities = {} }
	local function draw(paused)
		ui:draw(state, 1, {
			screen = paused and "game" or "title",
			paused = paused,
			audio = audio.enabled,
			music = audio.music,
			volume = audio.volume,
		})
	end
	local function click(label, paused)
		for _ = 1, 100 do
			draw(paused)
			for _, button in ipairs(ui.r.buttons) do
				if button.label == label then
					button.fn()
					return true
				end
			end
			if ui.settingsOpen then
				ui.settingsOffset = (ui.settingsOffset or 0) + 1
			else
				ui.menuOffset = (ui.menuOffset or 0) + 1
			end
		end
		return false
	end
	assert(click("SETTINGS") and ui.settingsOpen)
	assert(click("SOUND ON") and not audio.enabled)
	assert(click("MUSIC ON") and not audio.music)
	assert(click("VOLUME HIGH") and audio.volume == 0.35)
	assert(click("ANIMATIONS NORMAL") and ui.animationPreferences.speed == "fast")
	assert(click("REDUCED MOTION OFF") and ui.animationPreferences.reducedMotion)
	local pending = { { "buffered_input", 17 } }
	ui.r.pendingEvents = pending
	assert(click("DISPLAY AUTO") and ui.r.mode == "text")
	assert(ui.r.pendingEvents == pending, "Changing display mode preserves buffered input")
	assert(click("CLOSE") and not ui.settingsOpen)
	ui:close()
	local restored = UI.new(monitor, function() end)
	assert(
		restored.animationPreferences.speed == "fast"
			and restored.animationPreferences.reducedMotion
	)
	assert(restored.r.mode == "text" and restored.animationPreferences.display == "text")
	local saved = Audio.new()
	assert(not saved.enabled and not saved.music and saved.volume == 0.35)
	-- Muting music does not mute effects; volume applies to both note paths.
	saved.enabled = true
	saved:update("title")
	assert(not saved.timer)
	saved:effect("click")
	assert(math.abs(notes[#notes] - 0.45 * 0.35) < 0.00001)
	ui = restored
	assert(click("SETTINGS", true) and ui.settingsOpen)
	assert(ui:back() and not ui.settingsOpen, "Back returns to the existing pause/title screen")
	ui:close()
end
os = nativeOs
print(
	"CIVCRAFT: title/pause settings, persistent sound/music/volume, animation/accessibility, display fallback and buffered input passed."
)
