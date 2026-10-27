-- Run only on an isolated computer with copied campaigns: this rewrites the copies.
local env =
	dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
env.dofile("/games/civcraft/module_cache.lua").install(env)
local World = env.dofile("/games/civcraft/world.lua")
local Hex = env.dofile("/games/civcraft/hex.lua")
local Systems = env.dofile("/games/civcraft/systems.lua")
local Saves = env.dofile("/games/civcraft/saves.lua")
local Cooperative = env.dofile("/games/civcraft/cooperative.lua")
local work, checks = {}, 0
local function checkpoint()
	checks = checks + 1
	Cooperative.checkpoint(work, false, true)
end
World.checkpoint, Systems.checkpoint, Saves.checkpoint = checkpoint, checkpoint, checkpoint
local function equal(before, after)
	assert(type(before) == type(after), "Save changed a value type")
	if type(before) ~= "table" then
		assert(before == after or before ~= before and after ~= after, "Save changed a value")
		return
	end
	for key, value in pairs(before) do
		equal(value, after[key])
	end
	for key in pairs(after) do
		assert(before[key] ~= nil, "Save added a field")
	end
end
local report = { host = _G._HOST, cycles = {} }
for pass = 1, 4 do
	for slot = 1, Saves.count do
		local start = os.epoch("utc")
		local state = Saves.load(slot)
		if state then
			Systems.migrate(World.migrate(state))
			World.reveal(state, Hex, Systems)
			Saves.save(slot, state)
			equal(state, assert(Saves.load(slot)))
			report.cycles[#report.cycles + 1] = {
				pass = pass,
				slot = slot,
				bytes = fs.getSize(Saves.path(slot)),
				elapsed = os.epoch("utc") - start,
			}
		end
	end
end
assert(#report.cycles > 0, "Copy at least one existing campaign into this isolated computer")
report.checkpoints, report.yields = checks, work.yieldToken or 0
local file = assert(fs.open("/civcraft-save-stress.txt", "w"))
file.write(textutils.serialize(report))
file.close()
print("CIVCRAFT: all copied campaigns passed repeated load/save/reload equality checks.")
