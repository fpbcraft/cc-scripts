package.path = "./apps/factory/?.lua;" .. package.path
local Remote = require("remote")
local current = 100000
os.epoch = function()
	return current
end
local remote = Remote.new()
assert(remote.PROTOCOL == "fpb.factory.node.v1")
assert(not remote:ingest(15, { kind = "other", version = 1, peripherals = {} }))
local packet = {
	kind = "snapshot",
	version = 1,
	name = "Andesite Outpost",
	peripherals = {
		{
			name = "Create_Stressometer_0",
			type = "Create_Stressometer",
			methods = { "getStress", "getStressCapacity", "setOutput" },
			values = { getStress = 450, getStressCapacity = 2000, setOutput = false },
		},
		{
			name = "powergrid_voltage_gauge_0",
			type = "powergrid_voltage_gauge",
			methods = { "voltage" },
			values = { voltage = 24 },
		},
	},
}
assert(remote:ingest(15, packet))
local all = remote:list()
assert(#all == 2)
local sensor = remote:find("remote:15:Create_Stressometer_0")
assert(sensor and sensor.values.getStress == 450)
assert(sensor.values.getStressCapacity == 2000)
assert(remote:find("remote:15:missing") == nil)
-- Remote announces from the same computer replace earlier inventory.
local revised = {
	kind = "snapshot",
	version = 1,
	name = "Updated",
	peripherals = {
		{
			name = "new_sensor",
			type = "custom_sensor",
			methods = { "getValue" },
			values = { getValue = 12 },
		},
	},
}
assert(remote:ingest(15, revised))
assert(remote:find("remote:15:new_sensor").values.getValue == 12)
assert(remote:find("remote:15:Create_Stressometer_0") == nil)
current = current + 23000
assert(#remote:list() == 0, "Offline nodes must expire")
print("Remote node cache and expiry tests passed")
