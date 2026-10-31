-- Exercise installed files through their private loader, without source-tree fallbacks.
local disk = dofile("tests/support/install_checks.lua")("civcraft")
disk.withoutRuntime()
local root = "/games/civcraft"
local Loader = disk.env.dofile(root .. "/_lib/fpb/loader.lua")
local env = Loader.environment(root, disk.env, "game.lua")
env.dofile(root .. "/module_cache.lua").install(env)
local Systems = env.dofile(root .. "/systems.lua")
local World = env.dofile(root .. "/world.lua")
local Diplomacy = env.dofile(root .. "/diplomacy.lua")
local Saves = env.dofile(root .. "/saves.lua")
local Hex = env.dofile(root .. "/hex.lua")
for _, name in ipairs({
	"ui",
	"civilization_picker",
	"tech_tree",
	"conversation_view",
	"council_view",
	"settings_view",
}) do
	assert(
		type(env.dofile(root .. "/" .. name .. ".lua")) == "table",
		"Installed dependency missing: " .. name
	)
end
local function fixture(version, ruleset, speed)
	local world = {
		width = 18,
		height = 12,
		size = "compact",
		seed = 717,
		tiles = {},
		resources = { ["5:4"] = "iron" },
		rails = { ["6:4"] = true },
		landmarks = {},
	}
	for y = 1, 12 do
		for x = 1, 18 do
			world.tiles[x .. ":" .. y] = "plains"
		end
	end
	world.tiles["1:1"] = "water"
	return {
		version = version,
		campaignID = "installed-migration-" .. version .. ruleset .. speed,
		phase = "game",
		round = 11,
		ruleset = ruleset,
		gameSpeed = speed,
		world = world,
		players = {
			{
				id = 1,
				civ = "scholar",
				gold = 42,
				food = 13,
				wood = 7,
				science = 29,
				techs = { agriculture = true, mining = true },
				researchTarget = "writing",
				researchProgress = { writing = 9 },
			},
			{ id = 2, civ = "iron", techs = {}, gold = 10 },
		},
		cities = {
			{
				id = 1,
				owner = 1,
				x = 4,
				y = 4,
				name = "ORIGINAL",
				population = 3,
				buildings = {},
				project = { kind = "building", id = "library", progress = 6 },
				projectProgress = { ["building:farm"] = 3 },
			},
		},
		units = {
			{
				id = 2,
				owner = 1,
				kind = "warrior",
				x = 5,
				y = 4,
				hp = 72,
				movesLeft = 0,
				moved = true,
			},
			{ id = 3, owner = 1, kind = "settler", x = 6, y = 4, hp = 90, movesLeft = 1 },
		},
	}
end
local cases = 0
for version = 3, 6 do
	for _, ruleset in ipairs({ "legacy", "create" }) do
		for _, speed in ipairs({ "quick", "standard", "epic" }) do
			local state = fixture(version, ruleset, speed)
			local tiles =
				disk.env.textutils.unserialize(disk.env.textutils.serialize(state.world.tiles))
			Systems.migrate(World.migrate(state))
			Diplomacy.migrate(state)
			World.reveal(state, Hex, Systems)
			assert(Saves.save(2, state))
			local restored = Saves.load(2)
			Systems.migrate(World.migrate(restored))
			Diplomacy.migrate(restored)
			assert(
				restored.version == 6
					and restored.campaignID == state.campaignID
					and restored.round == 11
			)
			assert(
				restored.world.width == 18
					and restored.world.height == 12
					and restored.world.seed == 717
			)
			for key, terrain in pairs(tiles) do
				assert(restored.world.tiles[key] == terrain, "Upgrade regenerated existing terrain")
			end
			for key in pairs(restored.world.tiles) do
				assert(tiles[key], "Upgrade added existing-world tiles")
			end
			assert(restored.world.resources["5:4"] == "iron" and restored.world.rails["6:4"])
			assert(restored.players[1].gold == 42 and restored.players[1].science == 29)
			assert(
				restored.players[1].researchProgress.writing == 9
					and restored.players[1].researchTarget == "writing"
			)
			assert(
				restored.cities[1].name == "ORIGINAL" and restored.cities[1].project.progress == 6
			)
			assert(restored.cities[1].projectProgress["building:farm"] == 3)
			assert(
				restored.units[1].movesLeft == 0
					and restored.units[1].moved
					and restored.units[1].hp == 72
			)
			assert(restored.units[2].movesLeft == 1, "Migration refilled a mid-turn allowance")
			assert(
				restored.gameSpeed == speed
					and restored.ruleset == "create"
					and restored.contentRules == "balance5"
			)
			cases = cases + 1
		end
	end
end
assert(cases == 24)
print(
	"CIVCRAFT: installed UI/rules dependencies and 24 legacy/current speed-ruleset save upgrades passed."
)
