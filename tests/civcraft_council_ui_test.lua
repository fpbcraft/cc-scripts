local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
colors = colors
	or {
		black = 32768,
		white = 1,
		gray = 128,
		lightGray = 256,
		orange = 2,
		lightBlue = 8,
		yellow = 16,
		green = 8192,
		blue = 2048,
		lime = 32,
		red = 16384,
		brown = 4096,
	}
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local UI = dofile("/games/civcraft/ui.lua")
dofile("tests/helpers/civcraft_layout_only.lua")(UI)
local Council = dofile("/games/civcraft/council.lua")
local World = dofile("/games/civcraft/world.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 57, 26 }, { 80, 45 } }) do
		local state = {
			phase = "game",
			round = 1,
			campaignID = "council-ui",
			ruleset = "create",
			victoryRulesVersion = 2,
			players = {},
			cities = {},
			units = {},
			world = {
				width = 20,
				height = 14,
				tiles = {},
				rails = {},
				resources = {},
				landmarks = {},
			},
			diplomacy = Diplomacy.new(),
		}
		for y = 1, 14 do
			for x = 1, 20 do
				state.world.tiles[World.key(x, y)] = "plains"
			end
		end
		for id = 1, 3 do
			state.players[id] = {
				id = id,
				name = "SECRET NAME " .. id,
				civ = "iron",
				techs = { currency = true },
				contacts = {},
			}
			state.cities[id] =
				{ id = id, owner = id, x = id * 5, y = 6, population = 2, buildings = {} }
		end
		Systems.migrate(state)
		World.reveal(state, Hex, Systems)
		state.players[1].contacts = {}
		Council.advance(state)
		local monitor = {
			getSize = function(mode)
				if mode == 2 then
					return size[1] * 6, size[2] * 9
				end
				return size[1], size[2]
			end,
			getPaletteColor = function()
				return 0, 0, 0
			end,
			setPaletteColor = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.drawPixels = function() end
		else
			monitor.setCursorPos = function() end
			monitor.setBackgroundColor = function() end
			monitor.setTextColor = function() end
			monitor.write = function() end
		end
		local calls = 0
		local ui = UI.new(monitor, function(action, request)
			calls = calls + 1
			request.action = action
			assert(Actions.apply(state, 1, request, Systems))
		end)
		local function draw()
			if os and os.queueEvent and os.pullEvent then
				os.queueEvent("council_test_yield")
				os.pullEvent("council_test_yield")
			end
			ui:draw(World.forPlayer(state, 1), 1, { screen = "game" })
			for _, button in ipairs(ui.r.buttons) do
				if ui.panel == "council" or button.label == "COUNCIL" then
					assert(
						button.x >= 0
							and button.y >= 0
							and button.x + button.w <= ui.r.w
							and button.y + button.h <= ui.r.h,
						"Every control fits the viewport: " .. tostring(button.label)
					)
				end
			end
		end
		local function tap(label)
			while ui.councilModel and (ui.councilModel.offset or 0) > 0 do
				draw()
				local previous
				for _, button in ipairs(ui.r.buttons) do
					if button.label == "PREV" then
						previous = button
					end
				end
				assert(previous, "A scrolled Council page must have a Previous control")
				previous.fn()
			end
			for attempt = 1, 30 do
				draw()
				for _, button in ipairs(ui.r.buttons) do
					if button.label == label then
						local x = graphics
								and math.floor(ui.r.ox + (button.x + button.w / 2) * ui.r.sx)
							or math.floor((button.x + button.w / 2) / 2) + 1
						local y = graphics
								and math.floor(ui.r.oy + (button.y + button.h / 2) * ui.r.sy)
							or math.floor((button.y + button.h / 2) / 3) + 1
						assert(ui:tap(x, y), label)
						return
					end
				end
				local nextButton
				for _, button in ipairs(ui.r.buttons) do
					if button.label == "NEXT" then
						nextButton = button
					end
				end
				assert(nextButton, "Missing Council control: " .. label)
				nextButton.fn()
			end
			error("Unreachable Council control: " .. label)
		end
		tap("COUNCIL")
		tap("ELECTION")
		tap("VOTE UNMET CIV 2")
		assert(state.council.session.election[1].candidate == 2)
		tap("ABSTAIN")
		assert(state.council.session.election[1].candidate == false)
		tap("AGENDA")
		tap("TRADE FACILITATION")
		tap("VOTE YES")
		assert(state.council.session.agenda[1].votes[1].support)
		tap("BACK")
		tap("PROPOSE RESOLUTION")
		tap("TRADE EMBARGO")
		tap("UNMET CIV 2")
		tap("SUBMIT PROPOSAL")
		assert(state.council.session.agenda[2].target == 2)
		tap("STATUS")
		tap("COUNCIL HALL CODEX")
		assert(ui.panel == "encyclopedia" and ui.codex.entry.id == "councilhall")
		ui.panel = "council"
		state.round = state.council.session.closesRound
		Council.advance(state)
		tap("STATUS")
		tap("RECENT RESULTS")
		draw()
		assert(ui.councilModel.tab == "RESULTS" and calls == 4)
		tap("CLOSE")
		assert(ui.panel == "context")
		ui.councilModel = { key = "private", draft = { target = 2 } }
		ui:draw(World.forPlayer(state, 2), 2, { screen = "game" })
		assert(ui.councilModel == nil, "Hotseat handoff clears Council drafts")
	end
end
print(
	"CIVCRAFT: Six text/graphics Council layouts, actual ballot/proposal clicks, Codex and private handoffs passed."
)
