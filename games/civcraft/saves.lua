local Sites = dofile("/games/civcraft/specialty_sites.lua")
-- Three independent local campaigns; legacy save is copied on first use.
local Writer = dofile("/games/civcraft/state_writer.lua")
local S = { count = 3, root = "/games/civcraft/data" }
local function path(slot)
	slot = tonumber(slot)
	assert(slot and slot == math.floor(slot) and slot >= 1 and slot <= S.count, "Invalid save slot")
	return S.root .. "/slot-" .. slot .. ".dat"
end
S.path = path
local migrationMarker = S.root .. "/slots-migrated"
local function read(p)
	if not fs.exists(p) then
		return nil
	end
	local h = fs.open(p, "r")
	if not h then
		return nil, "Cannot read campaign " .. p
	end
	local ok, raw = pcall(h.readAll)
	h.close()
	if not ok or not raw then
		return nil, "Cannot read campaign " .. p
	end
	local success, value = pcall(textutils.unserialize, raw)
	if success and type(value) == "table" then
		return value
	end
	return nil, "Invalid campaign data in " .. p
end
S.readFile = read
function S.load(slot)
	local destination = path(slot)
	if fs.exists(destination) then
		return read(destination)
	end
	if tonumber(slot) == 1 and not fs.exists(migrationMarker) then
		return read(S.root .. "/local-save.dat")
	end
end
function S.list()
	local out = {}
	for slot = 1, S.count do
		local game, reason = S.load(slot)
		if game then
			local world = type(game.world) == "table" and game.world or {}
			out[slot] = {
				occupied = true,
				name = type(game.name) == "string" and game.name or ("CAMPAIGN " .. slot),
				seed = type(world.seed) == "number" and world.seed or 0,
				size = type(world.size) == "string" and world.size or "unknown",
				round = type(game.round) == "number" and game.round or 1,
				phase = type(game.phase) == "string" and game.phase or "unknown",
			}
		elseif reason then
			out[slot] = { occupied = true, name = "RESET REQUIRED", error = reason }
		else
			out[slot] = { occupied = false, name = "EMPTY SLOT " .. slot }
		end
	end
	return out
end
function S.writeFile(dest, state)
	Sites.validate(state)
	local folder = dest:match("^(.*)/[^/]+$") or "/"
	if not fs.exists(folder) then
		fs.makeDir(folder)
	end
	local tmp = dest .. ".tmp"
	local out = assert(fs.open(tmp, "w"), "Cannot write campaign")
	local encoded, problem = pcall(Writer.write, out, state, S.checkpoint)
	out.close()
	if not encoded then
		if fs.exists(tmp) then
			fs.delete(tmp)
		end
		error("Campaign encoding failed: " .. tostring(problem), 0)
	end
	-- Copy previous contents before replacing, so partial writes don't destroy a save.
	local backup = dest .. ".bak"
	if fs.exists(dest) then
		if fs.exists(backup) then
			fs.delete(backup)
		end
		fs.move(dest, backup)
	end
	local ok, why = pcall(fs.move, tmp, dest)
	if not ok then
		if fs.exists(backup) then
			fs.move(backup, dest)
		end
		error("Save not committed: " .. tostring(why))
	end
	return true
end
function S.save(slot, state)
	S.writeFile(path(slot), state)
	if not fs.exists(migrationMarker) then
		local marker = fs.open(migrationMarker, "w")
		if marker then
			marker.write("v3")
			marker.close()
		end
	end
	return true
end
function S.delete(slot)
	local dest = path(slot)
	if tonumber(slot) == 1 and not fs.exists(migrationMarker) then
		if not fs.exists(S.root) then
			fs.makeDir(S.root)
		end
		local marker = fs.open(migrationMarker, "w")
		if marker then
			marker.write("v3")
			marker.close()
		end
	end
	if fs.exists(dest) then
		fs.delete(dest)
	end
	if fs.exists(dest .. ".bak") then
		fs.delete(dest .. ".bak")
	end
	return true
end
return S
