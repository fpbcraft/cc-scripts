-- One-command installer. Shared engine and all files use the same revision.
local args = { ... }
local ref = "main"
local positional = 0
for _, a in ipairs(args) do
	if a:sub(1, 2) ~= "--" then
		positional = positional + 1
		if positional == 1 then
			ref = a
		else
			args.label = a
		end
	end
end
assert(ref:match("^[%w._/-]+$") and not ref:find("..", 1, true), "Invalid git ref")
assert(http and http.get, "Enable HTTP in CraftOS settings")
if ref == "main" and textutils and textutils.unserializeJSON then
	local ok, sha = pcall(function()
		local h = assert(
			http.get(
				"https://api.github.com/repos/fpbcraft/cc-scripts/commits/main",
				{ ["Accept"] = "application/vnd.github+json", ["User-Agent"] = "FPBInstaller" },
				true
			)
		)
		local body = h.readAll()
		h.close()
		local value = textutils.unserializeJSON(body)
		assert(
			type(value) == "table"
				and type(value.sha) == "string"
				and #value.sha == 40
				and value.sha:match("^[a-f0-9]+$")
		)
		return value.sha
	end)
	if ok then
		ref = sha
	end
end
local nonce = os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
local url = "https://raw.githubusercontent.com/fpbcraft/cc-scripts/"
	.. ref
	.. "/lib/fpb/installer.lua?fpb_cb="
	.. nonce
local h, err = http.get(url, nil, true)
assert(h, err or "Installer engine download failed")
local status = h.getResponseCode and h.getResponseCode() or 200
local body = h.readAll()
h.close()
assert(status == 200 and type(body) == "string", "Installer engine download failed: " .. status)
local engine, why = load(body, "@fpb-installer", "t", _ENV)
assert(engine, why)
return engine().install("railbreak", ref, args)
