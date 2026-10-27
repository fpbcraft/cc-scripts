package.path = "./apps/factory/?.lua;" .. package.path
-- Run with: lua tests/core_test.lua
-- This test uses fake Create/CC peripherals without loading Minecraft.
local function serialize(v)
	if type(v) == "table" then
		local out = {}
		for k, x in pairs(v) do
			out[#out + 1] = "[" .. serialize(k) .. "]=" .. serialize(x)
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end
local data = {}
textutils = {
	serialize = serialize,
	unserialize = function(s)
		local fn, err = load("return " .. s)
		if not fn then
			error(err)
		end
		return fn()
	end,
}
fs = {
	combine = function(a, b)
		return a .. "/" .. b
	end,
	exists = function(p)
		return data[p] ~= nil
	end,
	makeDir = function() end,
	delete = function(p)
		data[p] = nil
	end,
	move = function(a, b)
		data[b] = data[a]
		data[a] = nil
	end,
	open = function(path, mode)
		if mode == "r" then
			if not data[path] then
				return nil
			end
			return {
				readAll = function()
					return data[path]
				end,
				close = function() end,
			}
		end
		return {
			write = function(v)
				data[path] = v
			end,
			close = function() end,
		}
	end,
}
local clock = 1000000
os.epoch = function()
	return clock
end
local active = {}
redstone = {
	setOutput = function(side, value)
		active["computer:" .. side] = value
	end,
	getOutput = function(side)
		return active["computer:" .. side] or false
	end,
}
local count = 30
local ticker = {
	stock = function()
		return {
			[1] = { name = "minecraft:iron_nugget", displayName = "Iron Nugget", count = count },
		}
	end,
	requestFiltered = function(addr, filter)
		assert(addr == "Hub" and filter.name == "minecraft:iron_nugget")
		assert(filter._requestCount > 0)
		return math.min(filter._requestCount, count)
	end,
}
local relay = {
	setOutput = function(side, value)
		active["relay:" .. side] = value
	end,
	getOutput = function(side)
		return active["relay:" .. side] or false
	end,
}
local devices = {
	create_stock_ticker_0 = { kind = "Create_StockTicker", dev = ticker },
	redstone_relay_0 = { kind = "redstone_relay", dev = relay },
	create_stressometer_0 = {
		kind = "Create_Stressometer",
		dev = {
			getStress = function()
				return 500
			end,
			getStressCapacity = function()
				return 1000
			end,
		},
	},
	create_speedometer_0 = {
		kind = "Create_Speedometer",
		dev = {
			getSpeed = function()
				return 128
			end,
		},
	},
	powergrid_voltage_gauge_0 = {
		kind = "powergrid_voltage_gauge",
		dev = {
			voltage = function()
				return 24
			end,
		},
	},
}
peripheral = {
	getNames = function()
		return {
			"create_stock_ticker_0",
			"redstone_relay_0",
			"create_stressometer_0",
			"create_speedometer_0",
			"powergrid_voltage_gauge_0",
		}
	end,
	getType = function(name)
		return devices[name] and devices[name].kind
	end,
	hasType = function(name, kind)
		return devices[name] and devices[name].kind == kind
	end,
	isPresent = function(name)
		return devices[name] ~= nil
	end,
	wrap = function(name)
		return devices[name] and devices[name].dev
	end,
}
local core = dofile("apps/factory/core.lua").new("tmp")
assert(core.config.hubAddress == "Hub")
assert(core:register({
	id = "iron",
	name = "Iron Farm",
	device = "redstone_relay_0",
	side = "front",
	product = "minecraft:iron_nugget",
	item = "minecraft:iron_nugget",
	stopAt = 20,
	resumeBelow = 10,
	mode = "auto",
	onSignal = true,
	rateWindowSeconds = 120,
}))
local m = core.machines[1]
assert(core:register({
	id = "fast",
	name = "Fast Averaging",
	device = "computer",
	side = "left",
	product = "minecraft:iron_nugget",
	rateWindowSeconds = 30,
}))
local fast = core.machines[2]
core:scan()
local available, label, status = core:stockFor("minecraft:iron_nugget")
assert(available == 30 and label == "Iron Nugget" and status == nil)
local empty = core:stockFor("minecraft:andesite")
assert(empty == 0, "Known available inventory with no matching items must show 0")
local unset, _, missing = core:stockFor("")
assert(unset == nil and missing == "unconfigured")
core.snapshot.stockError = "Disconnected"
local unavailable, _, why = core:stockFor("minecraft:iron_nugget")
assert(unavailable == nil and why == "unavailable")
core.snapshot.stockError = nil
assert(core.rates.iron == 0 and core.rates.fast == 0)
assert(m.enabled == false)
assert(core.snapshot.stress[1].used == 500)
assert(core.snapshot.speed[1].rpm == 128)
assert(core.snapshot.power[1].value == 24)
clock = clock + 5000
count = 5
core:scan()
assert(
	m.enabled == true and active["relay:front"] == true,
	"Auto rule should resume below lower threshold"
)
clock = clock + 5000
count = 15
core:scan()
assert(core.rates.iron > 0 and core.rates.iron < 120, "Smoothing should suppress per-sample spikes")
assert(core.rates.fast > core.rates.iron, "A shorter averaging period should be more responsive")
local prevSlow = core.rates.iron
clock = clock + 5000
core:scan()
assert(core.rates.iron < prevSlow, "Rate must decay smoothly when idle")
assert(m.enabled == true, "Hysteresis must not toggle in the middle band")
clock = clock + 5000
count = 30
core:scan()
assert(
	m.enabled == false and active["relay:front"] == false,
	"Auto rule should stop at upper threshold"
)
local ok, err = core:toggle(m)
assert(not ok and err == "Set Manual mode first")
assert(core:setMode(m, "manual"))
assert(core:toggle(m))
assert(active["relay:front"] == true)
local requested, qty = core:request(core.snapshot.stock[1], 16)
assert(requested and qty == 16)
assert(#core.orders == 1 and core.orders[1].to == "Hub")
local invalid, message = core:register({
	id = "invalid",
	name = "Invalid",
	device = "computer",
	side = "left",
	stopAt = 20,
	resumeBelow = 21,
})
assert(not invalid and message:find("threshold"))
local rejected, why = core:register({
	id = "remote",
	name = "Remote Motor",
	device = "remote:13:redstone_relay_0",
	side = "left",
	rateWindowSeconds = 120,
})
assert(not rejected and (why:find("available") or why:find("Pair")))

local badWindow, reason = core:register({
	id = "bad",
	name = "Bad averaging window",
	device = "computer",
	side = "left",
	rateWindowSeconds = 1,
})
assert(not badWindow and reason:find("averaging"))
assert(core:setRateWindow(m, 300))
assert(m.rateWindowSeconds == 300 and core.rates[m.id] == 0)
assert(core.rateState[m.id] == nil)
local invalid, reason = core:setRateWindow(m, 12)
assert(not invalid and reason:find("15%-900"))
assert(m.rateWindowSeconds == 300)
assert(core:setRateWindow(m, 60))
assert(m.rateWindowSeconds == 60)
print("Core tests passed")
