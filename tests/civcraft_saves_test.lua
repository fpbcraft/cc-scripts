local files, dirs = {}, {}
fs = {}
function fs.exists(p)
	return files[p] ~= nil or dirs[p]
end
function fs.makeDir(p)
	dirs[p] = true
end
function fs.open(p, mode)
	if mode == "r" then
		if not files[p] then
			return nil
		end
		return {
			readAll = function()
				return files[p]
			end,
			close = function() end,
		}
	end
	local body = ""
	return {
		write = function(v)
			body = body .. v
		end,
		close = function()
			files[p] = body
		end,
	}
end
function fs.move(a, b)
	assert(files[a])
	files[b] = files[a]
	files[a] = nil
end
function fs.delete(p)
	files[p] = nil
end
local native = dofile
dofile = function(p)
	return native(p:gsub("^/games/civcraft/", "games/civcraft/"))
end
textutils = {
	unserialize = function(encoded)
		local read = load("return " .. encoded, "campaign", "t", {})
		return read and read() or nil
	end,
}
local Save = assert(loadfile("games/civcraft/saves.lua"))()
assert(#Save.list() == 3 and not Save.list()[1].occupied)
local a = { name = "RED", round = 4, phase = "game", world = { seed = 101, size = "compact" } }
local b = { name = "BLUE", round = 12, phase = "game", world = { seed = 202, size = "large" } }
Save.save(1, a)
Save.save(2, b)
local wrapped = {
	name = "WRAPPED",
	round = 1,
	phase = "game",
	world = { width = 5, height = 4, seed = 77, wrapX = true },
}
Save.save(3, wrapped)
assert(Save.load(3).world.wrapX == true, "Serialized world topology survives save and load")
assert(Save.load(1).name == "RED" and Save.load(2).name == "BLUE")
Save.save(
	1,
	{ name = "GREEN", round = 5, phase = "game", world = { seed = 303, size = "standard" } }
)
assert(Save.load(1).name == "GREEN" and Save.load(2).name == "BLUE")
assert(files[Save.path(1) .. ".bak"], "Previous slot revision should be backed up")
Save.delete(2)
assert(Save.load(2) == nil and Save.load(1).name == "GREEN")
local legacy = '{name="RED",round=4,phase="game",world={seed=101,size="compact"}}'
files["/games/civcraft/data/local-save.dat"] = legacy
files["/games/civcraft/data/slots-migrated"] = nil
Save.delete(1)
assert(Save.load(1) == nil, "Confirmed deletion must not resurrect legacy save")
assert(files["/games/civcraft/data/local-save.dat"] == legacy, "Legacy backup itself is preserved")
files["/games/civcraft/data/slots-migrated"] = nil
assert(
	Save.load(1).name == a.name and Save.load(1).world.seed == a.world.seed,
	"Legacy save can be imported on fresh install"
)
assert(not pcall(Save.path, 4), "Out of bounds save slot")
print("CIVCRAFT: three independent saves, backup, deletion and legacy import passed.")

Save.save(1, a)
local original, backup = files[Save.path(1)], files[Save.path(1) .. ".bak"]
local cyclic = {}
cyclic.loop = cyclic
assert(not pcall(Save.save, 1, cyclic))
assert(
	files[Save.path(1)] == original
		and files[Save.path(1) .. ".bak"] == backup
		and not files[Save.path(1) .. ".tmp"],
	"Encoding failure preserves both committed saves"
)
local open, closed = fs.open, false
fs.open = function(p, mode)
	local handle = open(p, mode)
	if mode == "w" and p:match("%.tmp$") then
		return {
			write = function()
				error("Disk full")
			end,
			close = function()
				closed = true
				handle.close()
			end,
		}
	end
	return handle
end
assert(not pcall(Save.save, 1, b))
fs.open = open
assert(
	closed and files[Save.path(1)] == original and not files[Save.path(1) .. ".tmp"],
	"Write failure closes and removes the temporary file without replacing the campaign"
)
local move = fs.move
fs.move = function(from, to)
	if from:match("%.tmp$") then
		error("Rename failed")
	end
	return move(from, to)
end
assert(not pcall(Save.save, 1, b))
fs.move = move
assert(files[Save.path(1)] == original, "A failed commit restores the previous campaign")
Save.writeFile("/games/civcraft/data/save.dat", b)
assert(
	textutils.unserialize(files["/games/civcraft/data/save.dat"]).name == "BLUE",
	"Host saves use the same atomic writer"
)
print("CIVCRAFT: failed encoding/write/rename recovery and shared host save protection passed.")

files["/games/civcraft/data/slots-migrated"] = nil
files["/games/civcraft/data/local-save.dat"] = legacy
files[Save.path(1)] = "{broken campaign"
local corrupt, reason = Save.load(1)
assert(not corrupt and reason:find("Invalid campaign data", 1, true))
assert(files[Save.path(1)] == "{broken campaign", "Corrupt save is never silently removed")
assert(Save.list()[1].occupied and Save.list()[1].error, "Corrupt slot needs an explicit reset")
files[Save.path(1)] = "{world=7,name={},round={},phase={}}"
assert(Save.list()[1].occupied, "Malformed metadata cannot crash the reset picker")
print("CIVCRAFT: unreadable saves remain occupied and cannot resurrect legacy files")
