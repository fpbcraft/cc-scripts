local Audio = assert(loadfile("games/civcraft/audio.lua"))()
local files, notes = {}, {}
fs = {
	exists = function(path)
		return files[path] ~= nil
	end,
	makeDir = function(path)
		files[path] = "DIR"
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
textutils = {
	serialize = function(value)
		return value.enabled and "on" or "off"
	end,
	unserialize = function(value)
		return { enabled = value == "on" }
	end,
}
local speaker = {
	playNote = function(instrument, volume, pitch)
		assert(
			(instrument == "harp" or instrument == "bass")
				and volume > 0
				and volume <= 3
				and pitch >= 0
				and pitch <= 24
		)
		notes[#notes + 1] = { instrument, volume, pitch }
	end,
}
peripheral = {
	getNames = function()
		return { "right" }
	end,
	getType = function()
		return "speaker"
	end,
	wrap = function()
		return speaker
	end,
}
local timers = 0
os.startTimer = function(delay)
	assert(delay > 0)
	timers = timers + 1
	return timers
end
local audio = Audio.new()
audio:update("title")
assert(audio.timer and #notes == 2, "Main menu schedules original music without blocking")
local count = #notes
audio:update("game")
assert(not audio.timer and #notes == count, "Music stops outside the title screen")
for _, kind in ipairs({ "click", "move", "build", "research", "turn", "error" }) do
	audio:effect(kind)
end
assert(#notes > count, "Gameplay effects use the speaker")
audio:toggle("title")
count = #notes
audio:effect("move")
assert(#notes == count and not audio.timer, "Mute suppresses effects and music")
assert(not Audio.new().enabled, "Audio preference persists across launches")
peripheral.getNames = function()
	return {}
end
local silent = Audio.new()
silent.enabled = true
silent:effect("move")
silent:update("title")
assert(not silent.timer, "No speaker degrades to silent play")
print(
	"CIVCRAFT: speaker effects, nonblocking menu music, persistent mute and silent fallback passed."
)
