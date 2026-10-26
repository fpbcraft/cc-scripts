-- Linear, chunked Lua-table encoding compatible with existing textutils.unserialize saves.
local Writer = { chunkSize = 8192 }
function Writer.write(handle, value, checkpoint)
	local parts, bytes, operations, tracking = {}, 0, 0, {}
	local function flush()
		if bytes > 0 then
			handle.write(table.concat(parts))
			parts, bytes = {}, 0
		end
		if checkpoint then
			checkpoint()
		end
	end
	local function emit(text)
		if bytes + #text > Writer.chunkSize then
			flush()
		end
		if #text > Writer.chunkSize then
			for start = 1, #text, Writer.chunkSize do
				handle.write(text:sub(start, start + Writer.chunkSize - 1))
				if checkpoint then
					checkpoint()
				end
			end
		else
			parts[#parts + 1], bytes = text, bytes + #text
			if bytes >= Writer.chunkSize then
				flush()
			end
		end
	end
	local function encode(item)
		operations = operations + 1
		if operations % 128 == 0 and checkpoint then
			checkpoint()
		end
		local kind = type(item)
		if kind == "table" then
			assert(not tracking[item], "Cannot save a recursive table")
			tracking[item] = true
			emit("{")
			for key, entry in pairs(item) do
				emit("[")
				encode(key)
				emit("]=")
				encode(entry)
				emit(",")
			end
			emit("}")
			tracking[item] = nil
		elseif kind == "string" then
			emit(string.format("%q", item))
		elseif kind == "number" then
			emit(
				item ~= item and "0/0"
					or item == math.huge and "1/0"
					or item == -math.huge and "-1/0"
					or tostring(item)
			)
		elseif kind == "boolean" or kind == "nil" then
			emit(tostring(item))
		else
			error("Cannot save " .. kind, 0)
		end
	end
	encode(value)
	flush()
end
return Writer
