-- Store disk installations and optional Opus Overview integration.
package.path = "./?.lua;./?/init.lua;" .. package.path
local disk = dofile("tests/support/craftos.lua").new()
disk.seed("/disk/.ready", "mounted")
disk.seed("/sys/apps/Overview.lua", "-- mock Opus")
local connected = true
disk.env.peripheral = {
  getNames = function()
    return connected and { "drive_0" } or {}
  end,
  getType = function(side)
    return side == "drive_0" and "drive" or nil
  end,
  call = function(_, method)
    assert(method == "getMountPath")
    return "disk"
  end,
}
disk.install("fpbstore", "main", "--no-startup")
disk.withoutRuntime()
local manager = disk.run("fpbstore", "--test-api")
local cog = assert(manager.get("cogworks"))

local disks = manager.disks(cog)
assert(#disks == 2 and disks[2].root == "/disk/games/cogworks", "Mounted disk destination is offered")
assert(not pcall(manager.install, cog, nil, "/somewhere/else"), "Unknown install destination is rejected")
assert(manager.install(cog, nil, disks[2].root), "Installation to the disk succeeds")
assert(manager.installed(cog), "Installed entry found at the disk root")
assert(manager.installRoot(cog) == "/disk/games/cogworks")
assert(manager.status(cog).root == disks[2].root)

-- Opus integration never mutates its built-in app database.
assert(disk.files["/usr/.registry/fpbstore-store"], "Store shortcut was registered")
assert(disk.files["/usr/.registry/fpbstore-cogworks"], "Game shortcut was registered")
assert(disk.files["/apps/fpbstore/shortcuts/cogworks.lua"], "Launch shim was generated")
assert(not disk.files["/sys/etc/apps.db"], "Opus database left untouched")

manager.setLaunchTarget(cog, "monitor")
assert(manager.preferences().launchTargets.cogworks == "monitor")
local prefs = manager.preferences()
prefs.opusShortcuts.cogworks = false
manager.savePreferences(prefs)
assert(not disk.files["/usr/.registry/fpbstore-cogworks"], "Per-game Opus opt-out honored")
prefs.opusShortcuts.cogworks = true
manager.savePreferences(prefs)
assert(disk.files["/usr/.registry/fpbstore-cogworks"])

local saved = "/disk/games/cogworks/save.dat"
local personal = "/disk/games/cogworks/user.txt"
disk.seed(saved, "keep me")
disk.seed(personal, "keep personal")
assert(manager.remove(cog, false) >= 1)
assert(disk.files[saved] == "keep me" and disk.files[personal] == "keep personal")
assert(not disk.files["/usr/.registry/fpbstore-cogworks"], "Opus entry removed on uninstall")

connected = false
assert(#manager.disks(cog) == 1, "Detached drive is no longer an install choice")
assert(not pcall(manager.install, cog, nil, "/disk/games/cogworks"), "Unavailable mount is rejected")
print("Store external disk and Opus integration: targets, shortcuts and data safety passed")
