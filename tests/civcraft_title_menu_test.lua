local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local UI = dofile("/games/civcraft/ui.lua")
local Playback = dofile("/games/civcraft/playback_ui.lua")
local state = { phase = "lobby", round = 1, players = {}, cities = {}, units = {} }
local options = {
	screen = "title",
	localMode = true,
	slot = 1,
	slots = {
		{ occupied = true, name = "ALPHA", round = 4 },
		{},
		{ occupied = true, name = "BETA", round = 9 },
	},
}
for _, graphics in ipairs({ false, true }) do
	for _, size in ipairs({ { 51, 19 }, { 80, 45 }, { 120, 60 } }) do
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
			setCursorPos = function() end,
			setBackgroundColor = function() end,
			setTextColor = function() end,
			write = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.drawPixels = function() end
		end
		local calls = {}
		local ui = UI.new(monitor, function(action, params)
			calls[#calls + 1] = { action = action, params = params }
		end)
		local function draw()
			ui:draw(state, 0, options)
			for i, b in ipairs(ui.r.buttons) do
				assert(
					b.x >= 0 and b.y >= 0 and b.x + b.w <= ui.r.w and b.y + b.h <= ui.r.h,
					b.label
				)
				for j = 1, i - 1 do
					local a = ui.r.buttons[j]
					assert(
						b.x >= a.x + a.w or a.x >= b.x + b.w or b.y >= a.y + a.h or a.y >= b.y + b.h,
						"Overlapping menu controls"
					)
				end
			end
		end
		local function find(label)
			for _, b in ipairs(ui.r.buttons) do
				if b.label == label then
					return b
				end
			end
		end
		local function click(label)
			for _ = 1, 12 do
				draw()
				local b = find(label)
				if b then
					b.fn()
					return
				end
				assert(find("NEXT"), "Unreachable menu option " .. label).fn()
			end
			error("Cannot reach " .. label)
		end
		draw()
		for _, label in ipairs({
			"NEW CAMPAIGN",
			"LOAD CAMPAIGN",
			"REMOTE MULTIPLAYER",
			"SETTINGS",
			"EXIT",
		}) do
			assert(find(label), "Main menu must show every action")
		end
		click("NEW CAMPAIGN")
		click("CREATE CAMPAIGN")
		assert(calls[#calls].action == "newGame")
		click("BACK")
		click("LOAD CAMPAIGN")
		click("DELETE SELECTED")
		assert(calls[#calls].action == "deleteSlot")
		click("BACK")
		click("REMOTE MULTIPLAYER")
		click("HOST GAME")
		assert(calls[#calls].action == "remoteHost")
		click("JOIN GAME")
		assert(calls[#calls].action == "remoteJoin")
		click("BACK")
		ui.titleMenu, ui.titleOffset = "overwrite", 0
		click("BACK")
		assert(ui.titleMenu == "new", "Cancel replacement returns to slot selection")
		ui.titleMenu, ui.titleOffset = "overwrite", 0
		click("CONFIRM REPLACE")
		assert(calls[#calls].action == "newGame" and calls[#calls].params.confirmed)
		ui:close()
	end
end
local ui = { panel = "context", feedback = function() end }
Playback.attach(ui)
local stream = {
	campaign = "saved",
	observer = 1,
	lastSeq = 2,
	entries = {
		{ seq = 1, round = 1, type = "research", name = "OLD" },
		{ seq = 2, round = 1, type = "research", name = "OLD TWO" },
	},
}
local snapshot = { phase = "game", round = 1, eventStream = stream }
local opts = {
	localMode = true,
	screen = "title",
	replayBaseline = { campaign = "saved", observers = { [1] = 2, [2] = 4 } },
}
Playback.update(ui, snapshot, 1, opts)
opts.screen = "game"
Playback.update(ui, snapshot, 1, opts)
assert(#ui.playback.pending == 0 and not ui.playback.active, "Loaded history must not replay")
assert(#ui.playback.feed == 2, "Loaded history stays readable")
opts.screen = "title"
stream.observer, stream.lastSeq = 2, 4
stream.entries = { { seq = 4, round = 1, type = "research" } }
Playback.update(ui, snapshot, 2, opts)
opts.screen = "game"
Playback.update(ui, snapshot, 2, opts)
assert(
	#ui.playback.pending == 0 and not ui.playback.active,
	"Other hotseat players also skip saved history"
)
stream.lastSeq = 5
stream.entries[#stream.entries + 1] = { seq = 5, round = 1, type = "research" }
Playback.update(ui, snapshot, 2, opts)
assert(ui.playback.active or #ui.playback.pending > 0, "New events still animate")
print(
	"CIVCRAFT: title-menu parity, focused navigation and per-observer load replay baselines passed."
)
