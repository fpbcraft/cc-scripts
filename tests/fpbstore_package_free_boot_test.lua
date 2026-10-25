-- Execute the real installed loader, entrypoint, manager and catalog.
local disk = dofile("tests/support/craftos.lua").new()
disk.install("fpbstore", "main", "--no-startup")
disk.withoutRuntime()
local api = disk.run("fpbstore", "--test-api")
assert(type(api) == "table" and type(api.status) == "function")
assert(#api.catalog.apps == 5)
assert(disk.env.package == nil and disk.env.require == nil, "Host globals are unchanged")
print("Installed Store boots without package, require or shell")
