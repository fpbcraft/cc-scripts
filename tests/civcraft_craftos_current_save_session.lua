-- Run only in an isolated CraftOS-PC profile: exercises the real game loader and UI.
local nativeLoadfile = loadfile
local function write(path, value)
	local file = assert(fs.open(path, "w"))
	file.write(value)
	file.close()
end
local function read(path)
	local file = assert(fs.open(path, "r"))
	local value = file.readAll()
	file.close()
	return value
end
local function fixture()
	local tiles = {}
	for y = 1, 10 do
		for x = 1, 12 do
			tiles[x .. ":" .. y] = "plains"
		end
	end
	return {
		version = 3,
		ruleset = "legacy",
		contentRules = "p1",
		phase = "game",
		round = 9,
		nextId = 3,
		campaignID = "migration-native",
		world = { width = 12, height = 10, tiles = tiles, resources = {} },
		players = {
			{ id = 0, name = "HUMAN", civ = "forge", techs = {}, stockpile = { iron = 12 } },
		},
		cities = {
			{ id = 1, owner = 0, capitalOf = 0, x = 4, y = 4, population = 3, buildings = {} },
		},
		units = { { id = 2, owner = 0, kind = "warrior", x = 5, y = 4, hp = 70, movesLeft = 1 } },
	}
end
local function launch(mode, valid)
	local drawn = false
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.loadfile = function(path, kind, scope)
		return nativeLoadfile(path, kind or "t", scope or env)
	end
	env.dofile = function(path)
		local module = assert(env.loadfile(path))()
		if path == "/games/civcraft/ui.lua" then
			local construct = module.new
			module.new = function(display, dispatch)
				local view = construct(display, dispatch)
				local draw = view.draw
				view.draw = function(self, state, player, options)
					assert(valid, "Invalid save reached rendering")
					assert(state.contentRules == "balance5" and state.ruleset == "create")
					assert(state.resourceSchema == 1 and state.round == 9)
					assert(state.players[1].gold == 0 and state.players[1].stockpile.iron == 12)
					assert(state.players[1].stockpile.coal == 0)
					assert(state.units[1].hp == 70 and state.units[1].movesLeft == 1)
					drawn = true
					return draw(self, state, player, options)
				end
				view.r.pullEvent = function()
					dispatch("save")
					dispatch("exit")
					return "term_resize"
				end
				return view
			end
		end
		return module
	end
	local ok, reason = pcall(assert(env.loadfile("/games/civcraft/game.lua")), mode, "--menu")
	if valid then
		assert(ok, reason)
		assert(drawn, "Loaded campaign did not render")
	else
		assert(not ok and not drawn)
		assert(tostring(reason):lower():find("delete/reset", 1, true), tostring(reason))
	end
end
for _, mode in ipairs({ "local", "host" }) do
	local path = "/games/civcraft/data/" .. (mode == "local" and "slot-1.dat" or "save.dat")
	write(path, textutils.serialize(fixture()))
	write(path .. ".bak", "preserve backup")
	write("/games/civcraft/data/unknown-user-file", "preserve user file")
	launch(mode, true)
	local saved = assert(textutils.unserialize(read(path)))
	assert(saved.version == 6 and saved.contentRules == "balance5" and saved.resourceSchema == 1)
	assert(saved.campaignID == "migration-native" and saved.world.width == 12)
	launch(mode, true)
	for _, payload in ipairs({
		"not a save",
		textutils.serialize({ version = 999, phase = "game" }),
	}) do
		write(path, payload)
		local backup = read(path .. ".bak")
		launch(mode, false)
		assert(read(path) == payload and read(path .. ".bak") == backup)
		assert(read("/games/civcraft/data/unknown-user-file") == "preserve user file")
	end
end
print("CIVCRAFT: native current-save load, render, save, restart and safe rejection passed")
