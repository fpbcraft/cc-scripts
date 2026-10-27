local H = dofile("tests/support/craftos.lua")
local disk = H.new()
disk.install("fpbstore", "main", "--no-startup")
disk.install("cogworks", "main", "--no-startup")
disk.install("railbreak", "main", "--no-startup")
disk.withoutRuntime()
local manager = disk.run("fpbstore", "--test-api")
local first = manager.get("cogworks")
local second = manager.get("railbreak")
for _, app in ipairs({ first, second }) do
	disk.seed(app.root .. "/probe.lua", 'return {name="' .. app.id .. '"}')
	disk.seed(app.root .. "/_lib/fpb/probe.lua", 'return "' .. app.id .. '-library"')
	disk.files[app.entry] = [[
 local probe=require('probe')
 assert(probe==require('probe'),'Module cached within program')
 local library=require('lib.fpb.probe')
 _G.gameGlobal=probe.name
 package.loaded.polluted=true
 local value=assert(load('return gameGlobal'))()
 return {name=probe.name,library=library,global=value}
 ]]
end
for _ = 1, 2 do
	for _, app in ipairs({ first, second }) do
		local result = manager.launch(app)
		assert(result.name == app.id and result.global == app.id)
		assert(result.library == app.id .. "-library", "Libraries pinned per app")
	end
end
assert(disk.env.gameGlobal == nil, "Game globals stay private")
assert(package.loaded.polluted == nil, "Host module cache stays untouched")
disk.files[first.entry] = 'error("crashed app")'
local ok, err = pcall(manager.launch, first)
assert(not ok and tostring(err):find("crashed app", 1, true))
assert(manager.launch(second).name == second.id, "Next app boots after crash")
-- Actual game API verification failures must restore every preexisting code file.
local original = disk.files[second.entry]
local get = disk.env.http.get
disk.env.http.get = function(url)
	if url:find("/games/railbreak/main.lua?", 1, true) then
		return {
			getResponseCode = function()
				return 200
			end,
			readAll = function()
				return 'error("broken release")'
			end,
			close = function() end,
		}
	end
	return get(url)
end
ok, err = pcall(disk.install, "railbreak", "main", "--no-startup")
assert(not ok and tostring(err):find("broken release", 1, true))
assert(disk.files[second.entry] == original, "Boot failure rolled back")
print(
	"Program caches, globals, dynamic chunks and bundled library versions are isolated; failed boot rolls back"
)
