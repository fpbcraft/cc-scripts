package.path = "./?.lua;./?/init.lua;" .. package.path
local files, dirs = {}, {}
fs = {}
function fs.exists(p)
	return files[p] ~= nil or dirs[p] ~= nil
end
function fs.makeDir(p)
	dirs[p] = true
end
function fs.delete(p)
	files[p] = nil
	dirs[p] = nil
end
function fs.move(a, b)
	assert(files[a], "Missing file " .. a)
	files[b] = files[a]
	files[a] = nil
end
function fs.open(p, mode)
	if mode == "r" then
		if files[p] == nil then
			return nil
		end
		return {
			readAll = function()
				return files[p]
			end,
			close = function() end,
		}
	end
	assert(mode == "w")
	local body = ""
	return {
		write = function(s)
			body = body .. s
		end,
		close = function()
			files[p] = body
		end,
	}
end
local stored, n = {}, 0
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = copy(x)
	end
	return out
end
textutils = {
	serialize = function(v)
		n = n + 1
		stored[n] = copy(v)
		return tostring(n)
	end,
	unserialize = function(s)
		return stored[tonumber(s)] and copy(stored[tonumber(s)])
	end,
}
local S = require("games.cogworks.storage")
assert(not S.has(2), "Fresh slot 2 empty")
local old = {
	campaignVersion = 2,
	unlocked = 14,
	level = 7,
	best = { [7] = 12 },
	sessions = { [7] = { parts = { { kind = "I", x = 2, y = 3, r = 1 } } } },
	awards = { [7] = { sealed = true } },
}
files[S.LEGACY] = textutils.serialize(old)
local imported = S.load(1)
assert(imported and imported.unlocked == 14 and imported.level == 7)
assert(imported.awards[7].sealed, "Legacy trophies preserved")
assert(
	imported.sessions[7] and imported.best[7] == 12,
	"Version 2 upgrade does not erase existing solutions"
)
assert(type(imported.tutorials) == "table", "Older saves gain tutorial flags")
assert(S.save(1, imported), "Legacy save migrated to slot 1")
assert(files[S.LEGACY], "Legacy backup untouched")
local second = S.newProgress()
second.unlocked = 5
second.level = 4
second.tutorials.I = true
assert(S.save(2, second), "Second save")
assert(S.load(1).level == 7 and S.load(2).level == 4, "Slots independent")
assert(
	S.load(2).tutorials.I and not S.load(1).tutorials.I,
	"Ponder completion is per slot and survives reload"
)
local third = S.newProgress()
third.unlocked = 30
third.level = 30
assert(S.save(3, third), "Third save")
assert(S.load(3).unlocked == 30, "Third slot valid")
local settings = S.loadSettings()
assert(settings.animations and settings.showPorts, "Default settings enabled")
settings.animations = false
settings.showPorts = false
settings.lastSlot = 3
assert(S.saveSettings(settings), "Settings save")
local copySettings = S.loadSettings()
assert(
	not copySettings.animations and not copySettings.showPorts and copySettings.lastSlot == 3,
	"Settings persist"
)
-- A broken slot does not corrupt the other slots.
files[S.path(2)] = "invalid lua serialization"
assert(S.load(2) == nil and S.load(1).level == 7, "Corrupt slot isolated")
print("COGWORKS: three save slots, legacy import, settings and corruption isolation passed.")
