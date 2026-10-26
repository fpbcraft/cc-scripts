local Contacts = dofile("/games/civcraft/contacts.lua")
local Colors = dofile("/games/civcraft/faction_colors.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local Factions = {}

function Factions.draw(ui, state, observer, rect)
	local r = ui.r
	r:text(rect.x + 4, rect.y + 4, "FACTIONS", 8, 1, rect.w - 48)
	r:button(rect.x + rect.w - 41, rect.y + 1, 38, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local rows = {}
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, rect.w - 20)) do
			rows[#rows + 1] = { text = line, color = color }
		end
	end
	for index, player in ipairs(state.players or {}) do
		local own = player.id == observer.id
		if Contacts.knows(state, observer.id, player.id) then
			local civilization = Systems.civ(player.civ)
			text(player.name .. (own and " (YOU)" or ""), Colors.players[index] or 8)
			text(civilization.name .. " / " .. (player.ai and "AI" or "HUMAN"))
			text("BONUS: " .. civilization.bonus)
			if state.diplomacy then
				text("REPUTATION: " .. ((state.diplomacy.reputation or {})[player.id] or 0))
				if not own then
					local pending = 0
					for _, offer in ipairs(state.diplomacy.offers or {}) do
						if
							offer.from == player.id
							and offer.to == observer.id
							and offer.status == "pending"
						then
							pending = pending + 1
						end
					end
					if pending > 0 then
						text("PENDING DIPLOMATIC CHOICES: " .. pending, 9)
					end
					rows[#rows + 1] = {
						buttons = {
							{
								label = "TALK " .. player.name,
								run = function()
									ui.conversationTarget, ui.conversationOffset, ui.panel =
										player.id, 0, "conversation"
								end,
							},
						},
					}
					local war = Diplomacy.war(state, observer.id, player.id)
					text(
						war
								and (war.active and "AT WAR" or "WAR STARTS ROUND " .. war.activatesRound)
							or "AT PEACE"
					)
					if not war and Scheduler.canAct(state, observer.id) then
						rows[#rows + 1] = {
							buttons = {
								{
									label = "ANNOUNCE WAR: " .. player.name,
									run = function()
										ui:command(
											"declareWar",
											{ target = player.id, kind = "normal" }
										)
									end,
								},
							},
						}
						text(
							"Normal war starts next round. Surprise War starts now: -50 reputation, -75 defender trust; all remaining actions before a response.",
							9
						)
						rows[#rows + 1] = {
							buttons = {
								{
									label = "SURPRISE WAR: " .. player.name,
									run = function()
										ui:command(
											"declareWar",
											{ target = player.id, kind = "surprise" }
										)
									end,
								},
							},
						}
					end
				end
			end
			if player.ai then
				text(
					"AI "
						.. Difficulty.id(player):upper()
						.. " / "
						.. Personalities.forCivilization(player.civ).archetype:upper()
				)
			end
			local age = own and Systems.age(player) or player.age
			text("AGE: " .. (age and Systems.ages[age] and Systems.ages[age].name or "UNKNOWN"))
			local cities, units = 0, 0
			for _, city in ipairs(state.cities or {}) do
				if
					city.owner == player.id
					and (own or World.known(observer, city.x, city.y) == "visible")
				then
					cities = cities + 1
				end
			end
			for _, unit in ipairs(state.units or {}) do
				if
					unit.owner == player.id
					and (own or World.known(observer, unit.x, unit.y) == "visible")
				then
					units = units + 1
				end
			end
			text(
				(own and "TOTAL" or "CURRENTLY VISIBLE")
					.. ": "
					.. cities
					.. " CITIES, "
					.. units
					.. " UNITS"
			)
		else
			text("UNDISCOVERED CIVILIZATION", 5)
			text("Explore until you encounter its units or a settlement to establish contact.")
		end
		rows[#rows + 1] = { text = "" }
	end
	local group = Scheduler.group(state, observer.id)
	if group then
		text("WAR GROUP ORDER:", 8)
		for _, id in ipairs(group.order) do
			for _, participant in ipairs(state.players) do
				if participant.id == id then
					text(
						participant.name
							.. (
								id == group.active and " / ACTIVE"
								or participant.ready and " / ENDED"
								or " / WAITING"
							)
					)
				end
			end
		end
	end
	Panels.rows(
		r,
		{ x = rect.x + 4, y = rect.y + 16, w = rect.w - 8, h = rect.h - 21 },
		rows,
		ui,
		"factionOffset"
	)
end

return Factions
