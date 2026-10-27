-- Pure suggestion engine tests; no Minecraft/Basalt runtime needed.
package.path = "./apps/factory/?.lua;" .. package.path
local c = require("completions")
local core = {
	devices = {
		list = function()
			return {
				{
					name = "redstone_relay_0",
					alias = "Andesite Farm",
					online = true,
					type = "redstone_relay",
				},
				{
					name = "powergrid_voltage_gauge_0",
					alias = "Main Grid",
					online = true,
					type = "powergrid_voltage_gauge",
				},
				{
					name = "redstone_relay_1",
					alias = "Offline Relay",
					online = false,
					type = "redstone_relay",
				},
			}
		end,
	},
	snapshot = {
		stock = {
			{ name = "minecraft:andesite", displayName = "Andesite", count = 1200 },
			{ name = "minecraft:iron_nugget", displayName = "Iron Nugget", count = 5555 },
			{ name = "create:andesite_alloy", displayName = "Andesite Alloy", count = 70 },
		},
	},
	machines = { { id = "andesite" }, { id = "iron" } },
	orders = { { to = "Hub" }, { to = "Foundry" } },
	config = { hubAddress = "Hub" },
}
local function contains(list, value)
	for _, v in ipairs(list) do
		if v.value == value then
			return true
		end
	end
	return false
end
local devices = c.candidates("device", core)
assert(contains(devices, "computer"))
assert(contains(devices, "redstone_relay_0"))
assert(not contains(devices, "powergrid_voltage_gauge_0"))
assert(not contains(devices, "redstone_relay_1"))
-- Paired remote nodes may offer both their own redstone sides and relay faces.
core.remote = {
	paired = function(_, id)
		return id == 47
	end,
}
local entries = core.devices.list
core.devices.list = function()
	local found = entries()
	found[#found + 1] = {
		name = "remote:47:computer",
		type = "remote_computer",
		online = true,
		alias = "Ironworks",
	}
	found[#found + 1] = {
		name = "remote:47:redstone_relay_2",
		type = "redstone_relay",
		online = true,
		alias = "Remote Relay",
	}
	found[#found + 1] =
		{ name = "remote:48:computer", type = "remote_computer", online = true, alias = "Unpaired" }
	return found
end
local paired = c.candidates("device", core)
assert(contains(paired, "remote:47:computer"))
assert(contains(paired, "remote:47:redstone_relay_2"))
assert(not contains(paired, "remote:48:computer"))

local sides = c.suggest("side", "le", core, 5)
assert(#sides == 1 and sides[1].value == "left")
local items = c.suggest("item", "andesite", core, 5)
assert(contains(items, "minecraft:andesite"))
assert(contains(items, "create:andesite_alloy"))
local threshold = c.candidates("resumeBelow", core, { stopAt = 100 })
assert(contains(threshold, "64"))
assert(not contains(threshold, "128"))
local smoothing = c.candidates("rateWindowSeconds", core)
assert(contains(smoothing, "120") and contains(smoothing, "300"))
assert(not contains(smoothing, "8192"))
local hub = c.suggest("hubAddress", "found", core, 5)
assert(#hub == 1 and hub[1].value == "Foundry")
local queries = c.suggest("search", "iron", core, 5)
assert(contains(queries, "Iron Nugget"))
local result = c.suggest("device", "Andesite", core, 3)
assert(result[1] and result[1].value == "redstone_relay_0")
print("Context completion tests passed")
