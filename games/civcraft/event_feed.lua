local Panels = dofile("/games/civcraft/panels.lua")
local Playback = dofile("/games/civcraft/playback_ui.lua")
local Feed = {}

function Feed.draw(ui, rect)
	local r = ui.r
	r:text(rect.x + 4, rect.y + 4, "OBSERVED EVENTS", 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 42, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local events = ui.playback and ui.playback.feed or {}
	local rows = {
		{
			text = "Events retain what you could see at action time.",
		},
		{
			buttons = {
				{
					label = "PLAY ALL",
					run = function()
						Playback.watch(ui, events)
					end,
				},
				{
					label = "SKIP",
					run = function()
						ui:command("skipPlayback")
						ui.panel = "context"
					end,
				},
			},
		},
	}
	if #events == 0 then
		rows[#rows + 1] = { text = "No recent observed actions." }
	end
	for i = #events, 1, -1 do
		local event = events[i]
		for _, line in
			ipairs(
				Panels.wrap(r, "R" .. event.round .. " " .. Playback.summary(event), rect.w - 18)
			)
		do
			rows[#rows + 1] = { text = line }
		end
		rows[#rows + 1] = {
			buttons = {
				{
					label = "WATCH",
					run = function()
						Playback.watch(ui, { event }, true)
					end,
				},
			},
		}
	end
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 20 },
		rows,
		ui,
		"eventOffset"
	)
end

return Feed
