-- A shell-less CraftOS process can install and boot the fallback Store.
local disk = dofile("tests/support/craftos.lua").new()
disk.withoutRuntime()
assert(disk.install("fpbstore", "main", "--no-startup"))
assert(disk.files["/apps/fpbstore/main.lua"])
assert(not disk.files["/apps/fpbstore/basalt.lua"])
local manager = disk.run("fpbstore", "--test-api")
assert(manager.get("cogworks"), "Store loads without shell or Basalt")
print("Store cold install without shell: terminal fallback is available")
