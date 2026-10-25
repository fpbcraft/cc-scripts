package.path = "./apps/factory/?.lua;" .. package.path
if not bit32 then
  bit32 = {
    band = function(a, b)
      return a & b
    end,
    bor = function(a, b)
      return a | b
    end,
    bxor = function(a, b, c)
      return a ~ b ~ (c or 0)
    end,
    bnot = function(a)
      return ~a
    end,
    rshift = function(a, n)
      return (a & 0xffffffff) >> n
    end,
    rrotate = function(a, n)
      n = n % 32
      return ((a >> n) | (a << (32 - n))) & 0xffffffff
    end,
  }
end
local auth = require("auth")
assert(
  auth.hex(auth.sha256("abc")) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  "SHA-256 abc test vector failed"
)
local key = string.rep(string.char(0x0b), 20)
assert(
  auth.hmac(key, "Hi There") == "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
  "HMAC-SHA256 RFC 4231 test vector failed"
)
local frame = auth.frame("set", 1, 2, 9, "redstone_relay_0", "left", true, false, "")
assert(frame ~= auth.frame("set", 1, 2, 9, "redstone_relay_0", "left", false, false, ""))
assert(auth.equal(auth.mac(key, frame), auth.mac(key, frame)))
assert(not auth.equal(auth.mac(key, frame), auth.mac(key, frame .. "x")))
print("SHA256/HMAC authentication tests passed")
