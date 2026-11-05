local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Encyclopedia = dofile("/games/civcraft/encyclopedia.lua")
local Research = dofile("/games/civcraft/research_details.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local player = { id = 1, civ = "iron", contentRules = "balance5", techs = {} }
local state = { contentRules = "balance5" }
local function contains(text, fragment)
	assert(text:find(fragment, 1, true), "Missing player guidance: " .. fragment)
end
local function building(id)
	return table.concat(
		Encyclopedia.describe("buildings", {
			id = id,
			record = Systems.buildings[id],
			name = Systems.buildings[id].name,
		}, player, state),
		" "
	)
end
local mixer = building("mixer")
contains(mixer, "Impact 3 SU")
contains(mixer, "Starts with no recipe")
contains(mixer, "1 copper and 1 zinc for 2 brass")
contains(mixer, "no industry bonus")
contains(mixer, "Industry gives +2 industry")
contains(mixer, "Complete output room is required before inputs are spent")
contains(mixer, "current city production remains under INFO")
contains(building("steamplant"), "Adds 8 local SU")
contains(building("steamplant"), "Steam reserves 1 coal only")
contains(building("waterwheel"), "Adds 4 local SU")
contains(building("windmill"), "Adds 3 local SU")
contains(building("workshop"), "Unpowered basic")
contains(building("redstoneworkshop"), "Unpowered basic")
assert(
	not building("library"):find("Impact", 1, true),
	"Ordinary buildings are not powered machines"
)
local research = table.concat(Research.paragraphs(Systems, "heatedmixing", player), " ")
contains(research, "HEATED MIXER: Impact 3 SU")
contains(research, "HEATED MIXER: Starts with no recipe")
local overview
for _, entry in ipairs(Encyclopedia.entries("mechanics", state)) do
	if entry.id == "machinery" then
		overview = table.concat(Encyclopedia.describe("mechanics", entry, player, state), " ")
	end
end
assert(overview, "Machinery help is reachable from the Codex")
contains(overview, "rails do not transfer SU")
contains(overview, "previewing spends nothing")
contains(overview, "PAUSE/ENABLE and priority choices persist")
print(
	"CIVCRAFT: machinery Codex and research explain forecasts, fuel, recipes and unpowered basics"
)
