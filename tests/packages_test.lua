local P = dofile("lib/fpb/packages.lua")
local seen = {}
for id, spec in pairs(P.packages) do
	assert(not seen[spec.root])
	seen[spec.root] = true
	for _, file in ipairs(spec.files) do
		local source = id == "node" and file == "auth.lua" and "apps/factory/auth.lua"
			or spec.source .. "/" .. file
		local f = assert(io.open(source, "r"), source)
		f:close()
	end
	for _, name in ipairs(spec.libraries) do
		assert(loadfile("lib/fpb/" .. name .. ".lua"))
	end
end
for _, id in ipairs({ "civcraft", "ironspire", "factory", "node" }) do
	dofile("tests/support/install_checks.lua")(id)
end
-- A node label must not be interpreted as a git revision when ref is main.
local disk = dofile("tests/support/craftos.lua").new()
disk.seed("/fpb-node/config.db", '{key="secret",name="Old"}')
disk.install("node", "main", "New node", "--no-startup")
local cfg = disk.env.textutils.unserialize(disk.files["/apps/node/config.db"])
assert(cfg.key == "secret" and cfg.name == "New node")
for _, url in ipairs(disk.requests) do
	assert(not url:find("cc-scripts/New node/", 1, true))
end
print("Manifest sources, unique roots and all package bootstraps passed")
