-- Small self-contained HMAC-SHA256 for authenticated factory control frames.
-- Uses CC:Tweaked's built-in bit32 library (Lua 5.2 compatible).
local M = {}
local b = bit32
assert(b and b.band and b.rrotate, "bit32 is required")
local band, bor, bxor, bnot, shr, ror = b.band, b.bor, b.bxor, b.bnot, b.rshift, b.rrotate
local K = {
	0x428a2f98,
	0x71374491,
	0xb5c0fbcf,
	0xe9b5dba5,
	0x3956c25b,
	0x59f111f1,
	0x923f82a4,
	0xab1c5ed5,
	0xd807aa98,
	0x12835b01,
	0x243185be,
	0x550c7dc3,
	0x72be5d74,
	0x80deb1fe,
	0x9bdc06a7,
	0xc19bf174,
	0xe49b69c1,
	0xefbe4786,
	0x0fc19dc6,
	0x240ca1cc,
	0x2de92c6f,
	0x4a7484aa,
	0x5cb0a9dc,
	0x76f988da,
	0x983e5152,
	0xa831c66d,
	0xb00327c8,
	0xbf597fc7,
	0xc6e00bf3,
	0xd5a79147,
	0x06ca6351,
	0x14292967,
	0x27b70a85,
	0x2e1b2138,
	0x4d2c6dfc,
	0x53380d13,
	0x650a7354,
	0x766a0abb,
	0x81c2c92e,
	0x92722c85,
	0xa2bfe8a1,
	0xa81a664b,
	0xc24b8b70,
	0xc76c51a3,
	0xd192e819,
	0xd6990624,
	0xf40e3585,
	0x106aa070,
	0x19a4c116,
	0x1e376c08,
	0x2748774c,
	0x34b0bcb5,
	0x391c0cb3,
	0x4ed8aa4a,
	0x5b9cca4f,
	0x682e6ff3,
	0x748f82ee,
	0x78a5636f,
	0x84c87814,
	0x8cc70208,
	0x90befffa,
	0xa4506ceb,
	0xbef9a3f7,
	0xc67178f2,
}
local function word(data, i)
	local a, c, d, e = data:byte(i, i + 3)
	return (a or 0) * 16777216 + (c or 0) * 65536 + (d or 0) * 256 + (e or 0)
end
local function bytes(w)
	return string.char(
		band(shr(w, 24), 255),
		band(shr(w, 16), 255),
		band(shr(w, 8), 255),
		band(w, 255)
	)
end
function M.sha256(data)
	local size = #data
	data = data .. "\128" .. string.rep("\0", (56 - ((size + 1) % 64)) % 64)
	local top = math.floor(size / 536870912)
	local bottom = (size * 8) % 4294967296
	data = data .. bytes(top) .. bytes(bottom)
	local H = {
		0x6a09e667,
		0xbb67ae85,
		0x3c6ef372,
		0xa54ff53a,
		0x510e527f,
		0x9b05688c,
		0x1f83d9ab,
		0x5be0cd19,
	}
	for offset = 1, #data, 64 do
		local W = {}
		for i = 1, 16 do
			W[i] = word(data, offset + 4 * (i - 1))
		end
		for i = 17, 64 do
			local x, y = W[i - 15], W[i - 2]
			local s0 = bxor(ror(x, 7), ror(x, 18), shr(x, 3))
			local s1 = bxor(ror(y, 17), ror(y, 19), shr(y, 10))
			W[i] = band(W[i - 16] + s0 + W[i - 7] + s1, 0xffffffff)
		end
		local a, c, d, e, f, g, h, j = (table.unpack or unpack)(H)
		for i = 1, 64 do
			local s1 = bxor(ror(f, 6), ror(f, 11), ror(f, 25))
			local ch = bxor(band(f, g), band(bnot(f), h))
			local t1 = band(j + s1 + ch + K[i] + W[i], 0xffffffff)
			local s0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
			local maj = bxor(band(a, c), band(a, d), band(c, d))
			local t2 = band(s0 + maj, 0xffffffff)
			j, h, g, f, e, d, c, a =
				h, g, f, band(e + t1, 0xffffffff), d, c, a, band(t1 + t2, 0xffffffff)
		end
		local vals = { a, c, d, e, f, g, h, j }
		for i = 1, 8 do
			H[i] = band(H[i] + vals[i], 0xffffffff)
		end
	end
	local out = ""
	for i = 1, 8 do
		out = out .. bytes(H[i])
	end
	return out
end
function M.hex(data)
	return (data:gsub(".", function(ch)
		return string.format("%02x", ch:byte())
	end))
end
function M.hmac(key, message)
	if #key > 64 then
		key = M.sha256(key)
	end
	key = key .. string.rep("\0", 64 - #key)
	local inner, outer = {}, {}
	for i = 1, 64 do
		local v = key:byte(i)
		inner[i] = string.char(bxor(v, 0x36))
		outer[i] = string.char(bxor(v, 0x5c))
	end
	return M.hex(M.sha256(table.concat(outer) .. M.sha256(table.concat(inner) .. message)))
end
function M.equal(a, b)
	if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
		return false
	end
	local diff = 0
	for i = 1, #a do
		diff = bor(diff, bxor(a:byte(i), b:byte(i)))
	end
	return diff == 0
end
-- Fixed-field canonical encoding: no transmitted Lua code, no ambiguity.
function M.frame(kind, hub, node, seq, target, side, on, polarity, session)
	return table.concat({
		tostring(kind),
		tostring(hub),
		tostring(node),
		tostring(seq),
		tostring(target or ""),
		tostring(side or ""),
		on and "1" or "0",
		polarity and "1" or "0",
		tostring(session or ""),
	}, "|")
end
function M.mac(key, frame)
	return M.hmac(key, frame)
end
return M
