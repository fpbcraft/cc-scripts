local Panels = dofile("/games/civcraft/panels.lua")
local Preferences = dofile("/games/civcraft/animation_preferences.lua")
local Renderer = dofile("/games/civcraft/render.lua")
local Settings = {}

function Settings.command(ui, action)
	if action == "settings" then
		ui.settingsOpen, ui.settingsOffset = true, 0
		return true
	end
	if action == "closeSettings" then
		ui.settingsOpen = false
		return true
	end
	if action == "displayMode" then
		local preferences = ui.animationPreferences
		preferences.display = preferences.display == "text" and "auto" or "text"
		Preferences.save(preferences)
		local previous = ui.r
		local display = previous.m
		previous:close()
		ui.r = Renderer.new(display, { forceText = preferences.display == "text" })
		for _, field in ipairs({ "onActivate", "trace", "pendingEvents", "pullEvent" }) do
			ui.r[field] = rawget(previous, field)
		end
		ui.worldReady = false
		return true
	end
	return false
end

function Settings.draw(ui, options)
	local r = ui.r
	r:fill(0, 0, r.w, r.h, 0)
	r:text(5, 4, "SETTINGS", 8)
	r:button(r.w - 44, 1, 40, 11, "CLOSE", function()
		ui:command("closeSettings")
	end)
	local preferences = ui.animationPreferences
	local volume = options.volume or 1
	local rows = {}
	for _, setting in ipairs({
		{
			"SOUND " .. (options.audio == false and "OFF" or "ON"),
			"audio",
			"Sound effects and master mute.",
		},
		{
			"MUSIC " .. (options.music == false and "OFF" or "ON"),
			"music",
			"Title-screen music; sound effects stay independent.",
		},
		{
			"VOLUME " .. (volume <= 0.5 and "LOW" or volume <= 0.85 and "MEDIUM" or "HIGH"),
			"volume",
			"Speaker volume for music and effects.",
		},
		{
			"ANIMATIONS " .. preferences.speed:upper(),
			"animationSpeed",
			"Normal, Fast or Off. Actions otherwise replay automatically.",
		},
		{
			"REDUCED MOTION " .. (preferences.reducedMotion and "ON" or "OFF"),
			"reducedMotion",
			"Show final positions and keep event summaries.",
		},
		{
			"DISPLAY " .. (preferences.display or "auto"):upper(),
			"displayMode",
			"Auto uses graphics when available. Text works on standard terminals.",
		},
	}) do
		rows[#rows + 1] = {
			buttons = {
				{
					label = setting[1],
					run = function()
						ui:command(setting[2])
					end,
				},
			},
		}
		for _, line in ipairs(Panels.wrap(r, setting[3], r.w - 20)) do
			rows[#rows + 1] = { text = line }
		end
	end
	Panels.rows(r, { x = 4, y = 15, w = r.w - 8, h = r.h - 19 }, rows, ui, "settingsOffset")
end

return Settings
