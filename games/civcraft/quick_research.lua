-- Available projects share the full tree's authoritative eligibility and costs.
local Q = {}
function Q.options(systems, player, science)
	local options = {}
	science = science or 0
	for _, id in ipairs(systems.techOrder) do
		if systems.canResearch(player, id) then
			local cost = systems.techCost(id, player)
			local progress = (player.researchProgress or {})[id] or 0
			options[#options + 1] = {
				id = id,
				name = systems.techs[id].name,
				cost = cost,
				progress = progress,
				turns = science > 0 and math.max(1, math.ceil((cost - progress) / science)) or nil,
				current = player.researchTarget == id,
			}
		end
	end
	return options
end
function Q.draw(ui, player, rect, systems)
	local r = ui.r
	local options =
		Q.options(systems, player, (ui.economy or {}).science or player.scienceRate or 0)
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	r:text(x + 3, y + 3, "CHOOSE RESEARCH", 8, 1, w - 41)
	r:button(x + w - 36, y + 1, 34, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	r:button(x + 3, y + 14, w - 6, 11, "TECH TREE", function()
		ui.panel = "tech"
		ui.techModel = ui.techModel or {}
	end)
	local capacity = math.max(1, math.floor((h - 40) / 20))
	local maximum = math.max(0, #options - capacity)
	ui.quickResearchOffset = math.max(0, math.min(ui.quickResearchOffset or 0, maximum))
	ui.quickResearchOptions = options
	if #options == 0 then
		local complete = true
		for _, id in ipairs(systems.techOrder) do
			if not (player.techs or {})[id] then
				complete = false
				break
			end
		end
		r:text(
			x + 3,
			y + 28,
			complete and "RESEARCH COMPLETE" or "NO AVAILABLE RESEARCH",
			7,
			1,
			w - 6
		)
	end
	for n = 1, capacity do
		local option = options[ui.quickResearchOffset + n]
		if option then
			local top = y + 27 + (n - 1) * 20
			r:button(x + 3, top, w - 6, 10, option.name, function()
				-- Revalidate the newest snapshot; commands remain the authoritative gate.
				local observer
				for _, candidate in ipairs(ui.state.players or {}) do
					if candidate.id == ui.playerID then
						observer = candidate
						break
					end
				end
				if observer and systems.canResearch(observer, option.id) then
					ui:command("researchTech", { id = option.id })
				end
			end, { selected = option.current })
			r.buttons[#r.buttons].label = "RESEARCH " .. option.id
			r:text(
				x + 4,
				top + 12,
				(option.current and "NOW " or "")
					.. option.progress
					.. "/"
					.. option.cost
					.. " S "
					.. (option.turns and option.turns .. "T" or "NO SCIENCE"),
				6,
				1,
				w - 8
			)
		end
	end
	if maximum > 0 then
		local width = math.floor((w - 8) / 2)
		r:button(x + 3, y + h - 12, width, 11, "PREV", function()
			ui.quickResearchOffset = math.max(0, ui.quickResearchOffset - capacity)
		end)
		r:button(x + 5 + width, y + h - 12, width, 11, "NEXT", function()
			ui.quickResearchOffset = math.min(maximum, ui.quickResearchOffset + capacity)
		end)
	end
end
return Q
