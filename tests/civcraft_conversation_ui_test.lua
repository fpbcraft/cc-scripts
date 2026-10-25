local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
local Actions = dofile("/games/civcraft/actions.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local UI = dofile("/games/civcraft/ui.lua")
local World = dofile("/games/civcraft/world.lua")
local Hex = dofile("/games/civcraft/hex.lua")
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 57, 38 }, { 120, 70 } }) do
		local state = {
			phase = "game",
			round = 1,
			ruleset = "create",
			diplomacy = Diplomacy.new(),
			scheduler = Scheduler.new(),
			players = {
				{ id = 1, name = "ONE", civ = "forge", techs = {} },
				{ id = 2, name = "TWO", civ = "iron", ai = true, ready = true, techs = {} },
			},
			cities = {
				{ id = 1, owner = 1, x = 3, y = 4, population = 2, buildings = {} },
				{ id = 2, owner = 2, x = 9, y = 6, population = 2, buildings = {} },
			},
			units = {},
			world = {
				width = 12,
				height = 10,
				tiles = {},
				resources = {},
				landmarks = {},
				rails = {},
			},
		}
		for y = 1, 10 do
			for x = 1, 12 do
				state.world.tiles[World.key(x, y)] = "plains"
			end
		end
		Systems.migrate(state)
		state.players[1].gold, state.players[2].gold = 100, 100
		World.reveal(state, Hex, Systems)
		local monitor = {
			getSize = function(mode)
				if mode == 2 then
					return size[1] * 6, size[2] * 9
				end
				return size[1], size[2]
			end,
			setCursorPos = function() end,
			setBackgroundColor = function() end,
			setTextColor = function() end,
			write = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.getPaletteColor = function()
				return 0, 0, 0
			end
			monitor.setPaletteColor = function() end
			monitor.drawPixels = function(x, y, _, w, h)
				assert(x >= 0 and y >= 0 and x + w <= size[1] * 6 and y + h <= size[2] * 9)
			end
		end
		local calls = {}
		local ui = UI.new(monitor, function(action, request)
			calls[#calls + 1] = action
			request.action = action
			assert(Actions.apply(state, 1, request, Systems))
			Systems.diplomaticResponses(state, state.players[2])
		end)
		local function draw()
			ui:draw(World.forPlayer(state, 1), 1, {})
		end
		local function scan(key)
			local found, offset = {}, 0
			repeat
				ui[key] = offset
				draw()
				for _, button in ipairs(ui.r.buttons) do
					assert(
						button.x >= 0
							and button.y >= 0
							and button.x + button.w <= ui.r.w
							and button.y + button.h <= ui.r.h,
						"Conversation controls remain on screen"
					)
					if button.label then
						found[button.label] = button
					end
				end
				if offset >= ui.pageMax then
					break
				end
				offset = math.min(ui.pageMax, offset + ui.pageCapacity)
			until false
			return found
		end
		draw()
		ui.panel = "factions"
		local factions = scan("factionOffset")
		assert(factions["TALK TWO"])
		factions["TALK TWO"].fn()
		assert(ui.panel == "conversation" and ui.conversationTarget == 2)
		local buttons = scan("conversationOffset")
		assert(
			buttons.GREET
				and buttons["OFFER COMMERCE"]
				and buttons["PROMISE TO WITHDRAW"]
				and buttons["SEND TRADE"]
		)
		buttons.GREET.fn()
		assert(calls[#calls] == "diplomaticTalk" and state.diplomacy.relations["2:1"].trust == 2)
		buttons["SEND TRADE"].fn()
		assert(
			state.diplomacy.offers[1].status == "accepted"
				and state.players[1].gold == 90
				and state.players[2].gold == 110,
			"Conversation terms flow through host validation and an explained AI response"
		)
		ui.trade = { gold = 777, askResource = "diamond", askAmount = 12 }
		ui:draw(World.forPlayer(state, 2), 2, { handoff = true })
		assert(
			ui.trade == nil and ui.conversationTarget == nil and ui.panel == "context",
			"Hotseat handoffs clear private negotiation drafts and targets"
		)
		state.campaignID = "A"
		ui:draw(World.forPlayer(state, 2), 2, {})
		ui.trade = { gold = 777 }
		state.campaignID = "B"
		ui:draw(World.forPlayer(state, 2), 2, {})
		assert(
			ui.trade == nil,
			"Switching campaigns clears negotiation drafts even for the same computer ID"
		)
		ui:close()
	end
end
print(
	"CIVCRAFT: six conversation layouts, faction navigation, authored topics, treaty choices and actual AI trade response passed."
)
