local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local E = dofile("/games/civcraft/events.lua")
local W = dofile("/games/civcraft/world.lua")
local UI = dofile("/games/civcraft/ui.lua")
local state = {
	phase = "game",
	round = 1,
	campaignID = "archive",
	ruleset = "create",
	players = { { id = 0, name = "HOST", techs = {} }, { id = 2, name = "OTHER", techs = {} } },
	cities = {},
	units = {},
	world = { width = 12, height = 8, tiles = {}, rails = {}, resources = {}, landmarks = {} },
}
for y = 1, 8 do
	for x = 1, 12 do
		state.world.tiles[W.key(x, y)] = "plains"
	end
end
for index = 1, 350 do
	state.round = math.floor(index / 10) + 1
	E.notice(state, "order", nil, "KNOWN " .. index, 0)
	E.notice(state, "order", nil, "HIDDEN " .. index, 2)
end
state.round = 100
E.prune(state)
assert(#E.forPlayer(state, 0).entries == 0, "Replay retention remains bounded independently")
local page = E.history(state, 0)
assert(#page.entries == 20 and page.entries[1].seq == 350 and page.entries[20].seq == 331)
assert(
	page.entries[1].text:find("KNOWN 350", 1, true)
		and not page.entries[1].text:find("HIDDEN", 1, true)
)
local visited, count = {}, 0
while page do
	for _, entry in ipairs(page.entries) do
		assert(not visited[entry.seq] and not entry.text:find("HIDDEN", 1, true))
		visited[entry.seq], count = true, count + 1
		for field in pairs(entry) do
			assert(field == "seq" or field == "round" or field == "text")
		end
	end
	page = page.nextBefore and E.history(state, 0, page.nextBefore)
end
assert(
	count == 350 and visited[1] and visited[350],
	"All older known events remain pageable after pruning"
)
assert(not E.history(state, 99))
page = E.history(state, 2)
assert(page.entries[1].text:find("HIDDEN", 1, true) and page.lastSeq == 350)
local snapshot = W.forPlayer(state, 0)
assert(snapshot.eventHistory.observer == 0 and #snapshot.eventHistory.entries == 20)
assert(
	not snapshot.eventJournal and not snapshot.eventHistory.entries[1].text:find("HIDDEN", 1, true)
)
page = E.history(state, 0, nil, 100000)
assert(#page.entries == 50, "History network pages have a strict upper bound")
page.entries[1].text = "MODIFIED"
assert(not E.history(state, 0).entries[1].text:find("MODIFIED", 1, true))
local before = state.eventJournal.streams[0].seq
E.history(state, 0, 0 / 0)
assert(state.eventJournal.streams[0].seq == before, "Reading history is not an observed action")

for _, size in ipairs({ { 51, 19 }, { 57, 38 }, { 100, 67 } }) do
	for _, graphics in ipairs({ false, true }) do
		local monitor = {
			getSize = function(mode)
				if mode == 2 then
					return size[1] * 6, size[2] * 9
				end
				return size[1], size[2]
			end,
			setCursorPos = function() end,
			setTextColor = function() end,
			setBackgroundColor = function() end,
			write = function() end,
		}
		if graphics then
			monitor.setGraphicsMode = function() end
			monitor.drawPixels = function() end
			monitor.getPaletteColor = function()
				return 0, 0, 0
			end
			monitor.setPaletteColor = function() end
		end
		local ui
		ui = UI.new(monitor, function(action, request)
			assert(action == "eventHistory", "Event Log controls never issue gameplay orders")
			assert(ui:receiveHistory(E.history(state, 0, request.before), request.requestID))
		end)
		ui.animationPreferences.speed = "off"
		local function draw(observer)
			ui:draw(W.forPlayer(state, observer or 0), observer or 0, {})
		end
		local function press(label)
			for _ = 1, 50 do
				draw()
				for _, button in ipairs(ui.r.buttons) do
					if button.label == label then
						button.fn()
						return
					end
				end
				for _, button in ipairs(ui.r.buttons) do
					if button.label == "NEXT" then
						button.fn()
					end
				end
			end
			error("Missing Event Log control: " .. label)
		end
		draw()
		local top
		for _, button in ipairs(ui.r.buttons) do
			if button.label == "EVENT LOG" then
				top = button
			end
		end
		assert(top and top.y < 13, "Event Log belongs to the top-right bar")
		press("EVENT LOG")
		assert(ui.panel == "history" and ui.historyPage.entries[1].seq == 350)
		press("OLDER")
		assert(ui.historyPage.entries[1].seq == 330)
		press("NEWER")
		assert(ui.historyPage.entries[1].seq == 350)
		press("RECENT")
		assert(ui.historyPage.entries[1].seq == 350 and #ui.historyCursors == 0)
		local request = ui.historyRequestID
		assert(
			not ui:receiveHistory(E.history(state, 2), request),
			"Wrong-observer replies are rejected"
		)
		assert(
			not ui:receiveHistory(E.history(state, 0), request - 1),
			"Old request replies are rejected"
		)
		press("CLOSE")
		assert(not ui:receiveHistory(E.history(state, 0), request))
		press("EVENT LOG")
		assert(
			not ui:receiveHistory(E.history(state, 0, 100), request),
			"Reopening invalidates outstanding replies"
		)
		draw(2)
		assert(
			ui.panel == "context" and ui.historyPage == nil,
			"Hotseat clears the other observer's history page"
		)
		ui:close()
	end
end
-- Migrate only retained legacy observations, never invent the already-pruned past.
local legacy = {
	players = { { id = 0 } },
	round = 20,
	eventJournal = {
		version = 1,
		order = 50,
		streams = {
			[0] = {
				seq = 50,
				entries = { { seq = 50, round = 19, type = "order", content = "LEGACY" } },
			},
		},
	},
}
page = E.history(legacy, 0)
assert(page.entries[1].seq == 50 and page.missingEarlier)
E.notice(legacy, "order", nil, "NEW", 0)
assert(
	E.history(legacy, 0).entries[1].seq == 51
		and #legacy.eventJournal.streams[0].history.entries == 2
)
print(
	"CIVCRAFT: complete private event history, bounded reverse pages, legacy migration and compact top-bar controls passed."
)

local reply = E.historyReply(state, 0, { campaignID = "archive", requestID = 7, observer = 2 })
assert(
	reply.history.observer == 0 and reply.history.entries[1].text:find("KNOWN", 1, true),
	"Remote history always uses the authenticated sender, never a requested observer"
)
assert(not E.historyReply(state, 99, { campaignID = "archive", requestID = 7 }))
assert(not E.historyReply(state, 0, { campaignID = "another campaign", requestID = 7 }))
assert(not E.historyReply(state, 0, { campaignID = "archive", requestID = 0 / 0 }))
state.players[1].ready = true
assert(
	E.historyReply(state, 0, { campaignID = "archive", requestID = 8 }),
	"Read-only history is available after ending the turn"
)
print(
	"CIVCRAFT: remote history sender identity, campaign validation and read-only eligibility passed."
)

state.players[1].ready = false
state.units = { { id = 8, owner = 0, kind = "warrior", x = 3, y = 3, movesLeft = 2 } }
local otherCount = E.history(state, 2).lastSeq
assert(
	dofile("/games/civcraft/actions.lua").apply(
		state,
		0,
		{ action = "skipTurn", unitID = 8, x = 3, y = 3 },
		dofile("/games/civcraft/systems.lua")
	)
)
local text = E.history(state, 0).entries[1].text
assert(
	text:upper():find("STONE GUARD", 1, true) and text:find("3,3", 1, true),
	"Private unit orders retain readable unit and location context"
)
assert(
	E.history(state, 2).lastSeq == otherCount,
	"Context-rich private orders do not leak action counts"
)
