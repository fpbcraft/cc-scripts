-- Stable, type-tagged encoding for differential tests, not a save-file format.
local Canonical = {}
local function encode(value, active)
	local kind = type(value)
	if kind == "nil" then
		return "z"
	end
	if kind == "boolean" then
		return value and "b1" or "b0"
	end
	if kind == "number" then
		return "n" .. string.format("%.17g", value) .. ";"
	end
	if kind == "string" then
		return "s" .. #value .. ":" .. value
	end
	assert(kind == "table", "Unsupported canonical value: " .. kind)
	assert(not active[value], "Cycle in authoritative state")
	active[value] = true
	local keys = {}
	for key in pairs(value) do
		assert(type(key) == "number" or type(key) == "string", "Unsupported state key")
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then
			return type(a) < type(b)
		end
		return a < b
	end)
	local parts = { "t{" }
	for _, key in ipairs(keys) do
		parts[#parts + 1] = encode(key, active)
		parts[#parts + 1] = encode(value[key], active)
	end
	parts[#parts + 1] = "}"
	active[value] = nil
	return table.concat(parts)
end
function Canonical.encode(value)
	return encode(value, {})
end

function Canonical.decode(source)
	local cursor = 1
	local parse
	parse = function()
		local tag = source:sub(cursor, cursor)
		cursor = cursor + 1
		if tag == "z" then
			return nil
		end
		if tag == "b" then
			local flag = source:sub(cursor, cursor)
			assert(flag == "0" or flag == "1", "Invalid boolean")
			cursor = cursor + 1
			return flag == "1"
		end
		if tag == "n" or tag == "s" then
			local finish = assert(source:find(tag == "n" and ";" or ":", cursor, true))
			local text = source:sub(cursor, finish - 1)
			cursor = finish + 1
			if tag == "n" then
				if text == "inf" then
					return math.huge
				end
				if text == "-inf" then
					return -math.huge
				end
				return assert(tonumber(text), "Invalid checkpoint number")
			end
			local length = assert(tonumber(text), "Invalid checkpoint string length")
			assert(length >= 0 and length % 1 == 0 and cursor + length - 1 <= #source)
			local value = source:sub(cursor, cursor + length - 1)
			cursor = cursor + length
			return value
		end
		assert(tag == "t" and source:sub(cursor, cursor) == "{", "Invalid checkpoint table")
		cursor = cursor + 1
		local value = {}
		while source:sub(cursor, cursor) ~= "}" do
			assert(cursor <= #source, "Truncated checkpoint")
			local key = parse()
			assert(type(key) == "number" or type(key) == "string", "Invalid checkpoint key")
			value[key] = parse()
		end
		cursor = cursor + 1
		return value
	end
	local value = parse()
	assert(cursor == #source + 1, "Trailing checkpoint data")
	return value
end
return Canonical
