-- CraftOS-PC only: create a virtual monitor when no physical monitor exists.
local oldPeripheral, oldEmulation = peripheral, periphemu
local created, connect, scale, calls = nil, false, nil, 0
local monitor = {
	getSize = function()
		return 51, 19
	end,
	setTextScale = function(value)
		scale = value
	end,
}
peripheral = {
	getNames = function()
		return connect and { "fpbstore_monitor" } or {}
	end,
	getType = function()
		return "monitor"
	end,
	wrap = function()
		return monitor
	end,
	isPresent = function()
		return connect
	end,
}
periphemu = {
	create = function(side, kind)
		assert(kind == "monitor", "Can only request a monitor")
		created, connect = side, true
		calls = calls + 1
		return true
	end,
}
local M = dofile("apps/fpbstore/monitor.lua")
local entry, new = M.ensure()
assert(entry and entry.screen == monitor and new, "CraftOS created and discovered monitor")
assert(created == "fpbstore_monitor" and scale == 0.5, "Uses unique side and appropriate scale")
local again, second = M.ensure()
assert(again == entry or again.screen == monitor)
assert(not second and calls == 1, "Never creates over an attached monitor")

connect = false
periphemu = nil
local missing, _, reason = M.ensure()
assert(not missing and reason:find("unavailable"), "Plain CC:Tweaked cannot create a monitor")
peripheral, periphemu = oldPeripheral, oldEmulation
print("Store virtual monitor: only-on-demand CraftOS attach; no replacement or CC:T attach passed")
