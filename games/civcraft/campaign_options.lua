local Panels = dofile("/games/civcraft/panels.lua")
local Rules = dofile("/games/civcraft/campaign_rules.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Options = {}
local names = {
	diplomatic = "DIPLOMATIC",
	conquest = "CONQUEST",
	industrial = "INDUSTRIAL",
	expedition = "END EXPEDITION",
	score = "SCORE",
}

function Options.draw(ui, state)
	local r = ui.r
	r:fill(0, 0, r.w, r.h, 1)
	r:text(4, 4, "CAMPAIGN", 8, 1, r.w - 48)
	r:button(r.w - 42, 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local speed = state.gameSpeed or "standard"
	local rows = {
		{
			buttons = {
				{
					label = "LENGTH " .. speed:upper(),
					run = function()
						ui:command("gameSpeed")
					end,
				},
			},
		},
		{ text = (state.roundLimit or 180) .. " ROUND LIMIT" },
		{
			buttons = {
				{
					label = state.contentRules == "p1" and "ECONOMY P1" or "ECONOMY ORIGINAL",
					run = function()
						ui:command("contentRules")
					end,
				},
			},
		},
	}
	for _, line in
		ipairs(
			Panels.wrap(
				r,
				"Quick speeds up research, production and growth. Epic slows them down. Movement and combat budgets stay the same each round.",
				r.w - 20
			)
		)
	do
		rows[#rows + 1] = { text = line }
	end
	for _, player in ipairs(state.players) do
		if player.ai then
			rows[#rows + 1] = {
				buttons = {
					{
						label = player.name .. " " .. Difficulty.id(player):upper(),
						run = function()
							ui:command("aiDifficulty", { playerID = player.id })
						end,
					},
				},
			}
			for _, line in
				ipairs(
					Panels.wrap(
						r,
						Difficulty.profile(player).description
							.. " No resource, vision or action bonuses.",
						r.w - 20
					)
				)
			do
				rows[#rows + 1] = { text = line }
			end
		end
	end
	for _, victory in ipairs(Rules.victories) do
		rows[#rows + 1] = {
			buttons = {
				{
					label = names[victory]
						.. " "
						.. (Rules.enabled(state, victory) and "ON" or "OFF"),
					run = function()
						ui:command("toggleVictory", { victory = victory })
					end,
				},
			},
		}
	end
	for _, line in
		ipairs(
			Panels.wrap(
				r,
				"At the round limit, Score chooses the highest-scoring civilization. If Score is disabled and no enabled victory has been won, the game ends in a draw. Keep at least one victory enabled.",
				r.w - 20
			)
		)
	do
		rows[#rows + 1] = { text = line }
	end
	if ui.notice and ui.notice ~= "" then
		for _, line in ipairs(Panels.wrap(r, ui.notice, r.w - 20)) do
			rows[#rows + 1] = { text = line }
		end
	end
	Panels.rows(r, { x = 4, y = 15, w = r.w - 8, h = r.h - 19 }, rows, ui, "campaignOffset")
end

return Options
