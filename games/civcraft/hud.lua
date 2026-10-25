local Systems = dofile("/games/civcraft/systems.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local H = {}
local function compact(value)
	value = math.floor(value or 0)
	if math.abs(value) >= 1000 then
		return (value < 0 and "-" or "") .. math.floor(math.abs(value) / 1000) .. "K"
	end
	return tostring(value)
end
local function rate(value)
	value = value or 0
	return (value > 0 and "+" or "") .. compact(value)
end
local function stock(value, change)
	return compact(value) .. ((change or 0) ~= 0 and rate(change) or "")
end
local function unlocked(player, kind)
	local technology = (Systems.resources[kind] or {}).tech
	return not technology or (player.techs or {})[technology] == true
end
function H.resources(ui, state, player)
	local r = ui.r
	local economy = Systems.economy(player, state)
	ui.economy = economy
	local x = 4
	r:withClip({ x = 4, y = 14, w = r.w - 8, h = 7 }, function()
		for _, entry in ipairs({
			{ "gold", stock(player.gold or 20, economy.net) },
			{ "science", rate(economy.science) },
			{ "food", rate(economy.food) },
			{ "wood", rate(economy.industry) },
		}) do
			local width = Icons.yieldValue(r, entry[1], entry[2], x, 15)
			x = x + width + 3
		end
		for _, kind in ipairs(Systems.resourceOrder) do
			if unlocked(player, kind) then
				Icons.resource(r, kind, x, 15)
				local value = stock((player.stockpile or {})[kind], economy.strategic[kind])
				r:text(x + 6, 15, value, 7)
				x = x + 7 + r:textWidth(value) + 3
			end
		end
	end)
	r.buttons[#r.buttons + 1] = {
		x = 4,
		y = 14,
		w = r.w - 8,
		h = 7,
		label = "RESOURCE LEDGER",
		fn = function()
			ui.panel = "resources"
			ui.resourceOffset = 0
		end,
	}
end
function H.ledger(ui, rect, player)
	local r = ui.r
	local e = Systems.economy(player, ui.state)
	r:fill(rect.x, rect.y, rect.w, rect.h, 1)
	r:outline(rect.x, rect.y, rect.w, rect.h, 8)
	r:text(rect.x + 4, rect.y + 4, "EMPIRE RESOURCES", 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local rows = {}
	for _, entry in ipairs({
		{
			"GOLD",
			compact(player.gold or 20) .. (e.net ~= 0 and " (" .. rate(e.net) .. "/TURN)" or ""),
		},
		{ "SCIENCE", rate(e.science) .. "/TURN" },
		{ "FOOD", rate(e.food) .. "/TURN" },
		{ "INDUSTRY", rate(e.industry) .. "/TURN" },
		{ "GOLD INCOME", rate(e.income) .. "/TURN" },
		{ "UNIT UPKEEP", rate(-e.upkeep) .. "/TURN" },
	}) do
		for _, line in ipairs(Panels.wrap(r, entry[1] .. " " .. entry[2], rect.w - 20)) do
			rows[#rows + 1] = { text = line }
		end
	end
	for _, kind in ipairs(Systems.resourceOrder) do
		if unlocked(player, kind) then
			local change = e.strategic[kind] or 0
			rows[#rows + 1] = {
				text = kind:upper()
					.. " "
					.. ((player.stockpile or {})[kind] or 0)
					.. (change ~= 0 and " (" .. rate(change) .. "/TURN)" or ""),
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "TRADE 20 GOLD FOR 1 " .. kind:upper(),
						run = function()
							ui:command("exchange", { resource = kind })
						end,
					},
				},
			}
		end
	end
	rows[#rows + 1] = { text = "AGE: " .. Systems.ages[Systems.age(player)].name }
	local victory = dofile("/games/civcraft/victory.lua").status(ui.state, player)
	rows[#rows + 1] = {
		text = "INDUSTRIAL: "
			.. victory.industryTurns
			.. "/10 ROUNDS; "
			.. victory.connected
			.. " LINKED CITIES",
	}
	rows[#rows + 1] = { text = "END EXPEDITION: " .. (player.endStage or 0) .. "/3 PROJECTS" }
	rows[#rows + 1] =
		{ text = "SCORE " .. victory.score .. " / DEADLINE ROUND " .. (ui.state.roundLimit or 90) }
	for _, rival in ipairs(ui.state.players) do
		if rival.id ~= player.id then
			rows[#rows + 1] = {
				text = rival.name
					.. ": AGE "
					.. (rival.age or Systems.age(rival))
					.. ", INDUSTRY "
					.. (rival.industryTurns or 0)
					.. "/10, END "
					.. (rival.endStage or 0)
					.. "/3",
			}
		end
	end
	rows[#rows + 1] = { text = "Gold pays unit upkeep each round." }
	rows[#rows + 1] = { text = "Unpaid units are disbanded." }
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 21 },
		rows,
		ui,
		"resourceOffset"
	)
end
return H
