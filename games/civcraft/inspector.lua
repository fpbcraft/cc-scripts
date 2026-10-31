local Specialty = dofile("/games/civcraft/specialty_view.lua")
local Sites = dofile("/games/civcraft/specialty_sites.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Biomes = dofile("/games/civcraft/biomes.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Landmarks = dofile("/games/civcraft/landmarks.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local UnitActions = dofile("/games/civcraft/unit_actions.lua")
local Villages = dofile("/games/civcraft/villages.lua")
local World = dofile("/games/civcraft/world.lua")
local MovementBudget = dofile("/games/civcraft/movement_budget.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local I = {}
local function at(list, x, y)
	for _, item in ipairs(list or {}) do
		if item.x == x and item.y == y then
			return item
		end
	end
end
function I.draw(ui, state, player, rect, modal)
	local r = ui.r
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	ui.inspectorBounds = rect
	r:fill(x, y, w, h, 1)
	r:outline(x, y, w, h, 3)
	local selectedCity = not ui.selected.empty
		and World.observedCity(state, player, ui.selected.x, ui.selected.y)
	r:text(
		x + 3,
		y + 3,
		selectedCity and ui.selected.kind ~= "unit" and selectedCity.name or "INSPECTOR",
		8,
		1,
		w - (modal and 40 or 6)
	)
	if modal then
		r:button(x + w - 36, y + 1, 34, 11, "CLOSE", function()
			ui.panel = "context"
		end)
	end
	local city = selectedCity
	local unit = not ui.selected.empty
		and Stacks.at(state.units, ui.selected.x, ui.selected.y, ui.selected.unitID)
	local rows = {}
	if not Sites.enabled(state) and ui.productionCategory == "site" then
		ui.productionCategory = "unit"
		ui.siteSource = nil
	end
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, w - 17)) do
			rows[#rows + 1] = { text = line, color = color }
		end
	end
	if not modal and h < 60 and (city or unit) then
		local description = city and ui.selected.kind ~= "unit" and city.name
			or unit and Systems.label("unit", unit.kind)
			or "SELECTED TILE"
		r:button(x + 2, y + (h < 30 and 2 or 14), w - 4, 11, "DETAILS", function()
			ui.panel = "inspector"
			ui.inspectorOffset = 0
		end)
		if h >= 40 then
			r:text(x + 3, y + 28, description, 7, 1, w - 6)
		end
		return
	end
	local cohabitant
	if unit and unit.owner == ui.playerID then
		for _, other in ipairs(state.units) do
			if
				other ~= unit
				and other.x == unit.x
				and other.y == unit.y
				and other.owner == unit.owner
			then
				cohabitant = other
			end
		end
	end
	local bodyY = y + 13
	local controlsY = y + 13
	local stacked = false
	if city and unit and city.owner == ui.playerID and unit.owner == ui.playerID then
		stacked = true
		if cohabitant then
			local nextKind, nextUnit, caption
			if ui.selected.kind == "city" then
				nextKind, nextUnit, caption =
					"unit", Stacks.at(state.units, city.x, city.y), "SELECT GUARD"
			elseif not Stacks.isCivilian(unit) then
				nextKind, nextUnit, caption =
					"unit",
					cohabitant,
					cohabitant.kind == "builder" and "SELECT BUILDER" or "SELECT SETTLER"
			else
				nextKind, nextUnit, caption = "city", city, "SELECT CITY"
			end
			r:button(x + 2, controlsY, w - 4, 11, caption, function()
				ui:focus(nextKind, nextUnit)
			end)
		else
			local width = math.floor((w - 6) / 2)
			for i, kind in ipairs({ "city", "unit" }) do
				r:button(
					x + 2 + (i - 1) * (width + 2),
					controlsY,
					width,
					11,
					kind:upper(),
					function()
						ui.selected.kind = kind
						ui.inspectorOffset = 0
						ui.source = nil
						ui.reachable = {}
						ui.workCity = nil
					end,
					{ selected = (ui.selected.kind or "unit") == kind }
				)
			end
		end
		controlsY = controlsY + 12
		bodyY = controlsY
		if (ui.selected.kind or "unit") == "unit" then
			city = nil
		else
			unit = nil
		end
	end
	if cohabitant and not stacked and (ui.selected.kind or "unit") == "unit" then
		r:button(
			x + 2,
			controlsY,
			w - 4,
			11,
			Stacks.isCivilian(cohabitant)
					and (cohabitant.kind == "builder" and "SELECT BUILDER" or "SELECT SETTLER")
				or "SELECT GUARD",
			function()
				ui.selected.unitID = cohabitant.id
				ui.inspectorOffset, ui.unitDetails = 0, false
				ui.source, ui.pendingMove, ui.reachable = nil, nil, {}
			end
		)
		controlsY, bodyY = controlsY + 12, controlsY + 12
	end
	if ui.selected.empty then
		text("NO SELECTION", 7)
		text("Click a hex to inspect it.")
	elseif city and city.owner == ui.playerID then
		local tabs = { "INFO", "JOBS", "TILES", "PROD" }
		local values = { "overview", "jobs", "tiles", "production" }
		local columns = w < 100 and 2 or 4
		local width = math.floor((w - 4 - (columns - 1) * 2) / columns)
		local tabButtons = {}
		for i, label in ipairs(tabs) do
			local mode = values[i]
			local function choose()
				ui.placement = nil
				ui.cityPanel = mode
				ui.inspectorOffset = 0
				ui.cityStrikeSource = nil
				ui.source = nil
				ui.reachable = {}
				ui.pendingMove = nil
				ui.workCity = mode == "tiles" and { x = city.x, y = city.y } or nil
				if mode == "tiles" and modal then
					ui.panel = "context"
				end
			end
			if stacked and h < 64 then
				tabButtons[#tabButtons + 1] = {
					label = label,
					run = choose,
					style = {
						selected = (ui.cityPanel or "overview") == mode,
					},
				}
			else
				r:button(
					x + 2 + ((i - 1) % columns) * (width + 2),
					controlsY + math.floor((i - 1) / columns) * 12,
					width,
					11,
					label,
					choose,
					{ selected = (ui.cityPanel or "overview") == mode }
				)
			end
		end
		if #tabButtons > 0 then
			rows[#rows + 1] = { buttons = tabButtons }
			bodyY = controlsY
		else
			bodyY = controlsY + math.ceil(#tabs / columns) * 12
		end
		Combat.city(city)
		local yields = Systems.yields(player, city, state, Hex)
		if (ui.cityPanel or "overview") == "overview" then
			text("POP " .. (city.population or 2) .. "  IDLE " .. Systems.idle(city), 7)
			rows[#rows + 1] = { yields = yields }
			local growth = Systems.growth(player, city, state, yields)
			if growth.capacity then
				text(
					"CAPACITY "
						.. growth.capacity
						.. " / GROWTH "
						.. (growth.growthFactor * 100)
						.. "%",
					13
				)
				local sources = growth.capacitySources
				text(
					"BASE "
						.. sources.base
						.. " + WATER "
						.. sources.water
						.. " + SERVICES "
						.. sources.infrastructure
				)
				text("GROWTH FOOD " .. growth.foodGain .. " / RAW SURPLUS " .. growth.surplus)
			end
			text(
				growth.status == "GROWING" and ("POP +1 IN " .. growth.turns .. "T")
					or growth.status == "STARVING" and (growth.canShrink and ("POP -1 IN " .. growth.turns .. "T") or "STARVING - MIN POP")
					or "POP STAGNANT",
				growth.status == "STARVING" and 31 or 13
			)
			text(
				"FOOD "
					.. math.floor(growth.stored)
					.. "/"
					.. growth.threshold
					.. " ("
					.. (growth.surplus >= 0 and "+" or "")
					.. growth.surplus
					.. ")"
			)
			text("CITY HP " .. city.hp .. "/200")
			if city.maxWalls > 0 then
				text("WALLS " .. city.wallHP .. "/" .. city.maxWalls, 13)
			end
			if city.wallHP > 0 and city.struckRound ~= state.round then
				rows[#rows + 1] = {
					buttons = {
						{
							label = "CITY STRIKE",
							run = function()
								ui:armCityStrike(city)
							end,
						},
					},
				}
			end
		elseif ui.cityPanel == "jobs" then
			text("POP " .. (city.population or 2) .. " / IDLE " .. Systems.idle(city), 7)
		end
		if ui.cityPanel == "production" then
			local project = city.project
			if ContentRules.hasDevelopment(state) then
				text("SETTLER: 1 CITIZEN; NEEDS POP 2", 13)
				if
					project
					and project.kind == "unit"
					and project.id == "settler"
					and (city.population or 2) < 2
				then
					text("SETTLER PAUSED: WAITING FOR POP 2", 31)
				end
			end
			text(
				project and ("MAKING " .. Specialty.projectName(city, project)) or "NO PRODUCTION",
				8
			)
			rows[#rows + 1] = {
				buttons = {
					{
						label = "UNITS",
						run = function()
							ui.productionCategory = "unit"
							ui.inspectorOffset = 0
						end,
						style = { selected = ui.productionCategory == "unit" },
					},
					{
						label = "BUILDS",
						run = function()
							ui.productionCategory = "building"
							ui.inspectorOffset = 0
						end,
						style = { selected = ui.productionCategory == "building" },
					},
					{
						label = "WONDER",
						run = function()
							ui.productionCategory = "wonder"
							ui.inspectorOffset = 0
						end,
						style = { selected = ui.productionCategory == "wonder" },
					},
				},
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "NO PRODUCTION",
						style = { selected = city.productionIdle == true },
						run = function()
							ui:command("queue", { cityX = city.x, cityY = city.y, kind = "none" })
						end,
					},
				},
			}
			if ContentRules.usesP1Economy(state) then
				rows[#rows + 1] = {
					buttons = {
						{
							label = "PROJECTS",
							style = { selected = ui.productionCategory == "project" },
							run = function()
								ui.productionCategory = "project"
								ui.inspectorOffset = 0
							end,
						},
					},
				}
			end
			if Sites.enabled(state) then
				rows[#rows + 1] = {
					buttons = {
						{
							label = "SITES",
							style = { selected = ui.productionCategory == "site" },
							run = function()
								ui.productionCategory = "site"
								ui.inspectorOffset = 0
							end,
						},
					},
				}
			end
			if Sites.enabled(state) and ui.productionCategory == "site" then
				Specialty.rows(ui, state, player, city, rows, text)
			else
				local kind = ui.productionCategory or "unit"
				local source = kind == "wonder" and Systems.wonders
					or kind == "project" and Systems.projects
					or kind == "building" and Systems.buildings
					or Systems.units
				local list = {}
				for id in pairs(source) do
					local allowed
					if kind == "wonder" then
						allowed = player.techs[source[id].tech] and Landmarks.available(state, id)
					elseif kind == "unit" then
						allowed = Systems.canRecruit(player, id, state, Hex, city)
					elseif kind == "project" then
						allowed = Systems.canProject(player, city, id)
					else
						allowed = Systems.canBuild(player, city, id, state)
					end
					if allowed then
						list[#list + 1] = { id = id, allowed = true }
					end
				end
				table.sort(list, function(a, b)
					if a.allowed ~= b.allowed then
						return a.allowed
					end
					return a.id < b.id
				end)
				for _, item in ipairs(list) do
					local id = item.id
					local allowed = item.allowed
					local active = city.project
						and city.project.kind == kind
						and city.project.id == id
					local progress = active and city.project.progress
						or (city.projectProgress or {})[kind .. ":" .. id]
						or 0
					local turns = math.max(
						1,
						math.ceil(
							(Systems.projectCost(kind, id, player, city) - progress)
								/ math.max(1, yields.industry)
						)
					)
					local label = Systems.label(kind, id) .. " " .. turns .. "T"
					if
						kind == "building"
						and ContentRules.hasDevelopment(state)
						and (source[id].capacity or 0) > 0
					then
						text(Systems.label(kind, id) .. ": CAPACITY +" .. source[id].capacity)
					end
					if kind == "project" then
						local output = Systems.projectPreview(player, city, id, state, yields)
						label = Systems.label(kind, id)
							.. (output.active and " / ROUND" or " PAUSED")
						text(source[id].description)
						local record = source[id]
						text(
							"NEXT ROUND +" .. output[record.output] .. " " .. record.output:upper()
						)
						text(
							"REMAINDER "
								.. ((city.projectRemainders or {})[id] or 0)
								.. "/"
								.. record.divisor
						)
						if not output.active then
							text("Select unfinished research to resume.")
						end
					end
					rows[#rows + 1] = {
						project = {
							label = label,
							selected = active,
							run = function()
								if kind == "wonder" then
									ui:armPlacement(kind, city, id)
								else
									ui:command(
										"queue",
										{ cityX = city.x, cityY = city.y, kind = kind, id = id }
									)
								end
							end,
							info = function()
								ui:openCodex(
									kind == "wonder" and "wonders"
										or kind == "project" and "projects"
										or kind == "unit" and "units"
										or "buildings",
									id
								)
							end,
							id = id,
						},
					}
				end
			end
		elseif ui.cityPanel == "tiles" then
			local count = 0
			for _ in pairs(city.worked or {}) do
				count = count + 1
			end
			text("WORKED " .. count .. "/" .. (city.population or 2), 8)
			text("TAP LAND HEXES")
			text("Tap a worked hex to free it.")
			rows[#rows + 1] = {
				buttons = {
					{
						label = "DONE WORK",
						run = function()
							ui.workCity = nil
							ui.cityPanel = "jobs"
							ui.inspectorOffset = 0
						end,
					},
				},
			}
		elseif ui.cityPanel == "jobs" then
			for _, job in ipairs(Systems.jobs) do
				rows[#rows + 1] = {
					adjust = {
						icon = job,
						label = tostring(city.jobs[job] or 0),
						minus = function()
							ui:command(
								"assign",
								{ x = city.x, y = city.y, from = job, to = "idle" }
							)
						end,
						plus = function()
							if Systems.idle(city) > 0 then
								ui:command(
									"assign",
									{ x = city.x, y = city.y, from = "idle", to = job }
								)
							else
								ui:feedback("No idle citizens. Use - to free one first.")
							end
						end,
					},
				}
			end
			text("- frees a citizen; + uses idle.")
		end
	elseif unit and unit.owner == ui.playerID then
		local stats = Systems.units[unit.kind] or Systems.units.warrior
		local partner = Stacks.partner(state, unit)
		local available = cohabitant and Stacks.canLink(state, unit, cohabitant, Systems)

		Combat.unit(unit)
		text(Systems.label("unit", unit.kind) .. " LV" .. unit.level, 7)
		if partner or available then
			rows[#rows + 1] = {
				buttons = {
					{
						label = partner and "DETACH ESCORT" or "ATTACH ESCORT",
						run = function()
							ui:command(partner and "detachEscort" or "attachEscort", {
								x = unit.x,
								y = unit.y,
								unitID = unit.id,
								partnerID = cohabitant and cohabitant.id,
							})
							ui.source, ui.pendingMove, ui.reachable = nil, nil, {}
						end,
					},
				},
			}
		end
		if partner then
			text("LINKED / OTHER MOVE " .. (partner.movesLeft or 0), 13)
		end
		local route = unit.moveQueue or partner and partner.moveQueue
		if route then
			text(route.paused and "ROUTE PAUSED" or "WAYPOINTS " .. #route.goals, 13)
		end
		text("HP " .. unit.hp .. "/100", unit.hp < 35 and 31 or 13)
		text(
			"ATK "
				.. Combat.power(unit, Systems, false, state)
				.. " DEF "
				.. Combat.power(unit, Systems, true, state)
		)
		text("XP " .. unit.xp .. "/" .. (unit.level * 10))
		local allowance = unit.movementAllowanceRound == state.round and unit.turnMovementAllowance
			or stats.move
		text("MOVE " .. (unit.movesLeft or 0) .. "/" .. allowance)
		text("UPKEEP " .. (stats.upkeep or 1) .. " GOLD")
		if not stats.naval and Hex.terrain(unit.x, unit.y, state) == "water" then
			text("EMBARKED", 13)
		end
		text(
			"RANGE "
				.. MovementBudget.attackRange(state, unit, stats, Hex)
				.. " VISION "
				.. stats.vision
		)
		if ui.source then
			text("CYAN RING: MOVE", 13)
			text("RED CROSS: ATTACK", 31)
			text("AMBER RING: CONTROL STOP", 8)
			text("AMBER !: VISIBLE THREAT", 18)
			text("Threat damage estimates the next enemy turn.")
		end
		for _, line in ipairs(Panels.wrap(r, ContentRules.ability(stats, state) or "", w - 10)) do
			text(line)
		end
		rows[#rows + 1] = {
			buttons = {
				{
					label = "MOVE / ATTACK",
					run = function()
						ui.placement = nil
						ui.cityStrikeSource = nil
						if ui.mapViewport and ui.mapViewport.tile < 16 then
							ui:zoom((16 - ui.mapViewport.tile) / 4)
						end
						ui.source = { x = unit.x, y = unit.y, unitID = unit.id }
						ui.reachable = Hex.reachable(state, unit, ui.playerID, Systems)
						ui.pendingMove = nil
						ui:feedback("CYAN MOVE / RED ATTACK / AMBER THREAT")
						if modal then
							ui.panel = "context"
						end
					end,
				},
			},
		}
		local queue = unit.moveQueue or partner and partner.moveQueue
		local routeButtons = {
			{
				label = queue and "ADD WAYPOINT" or "QUEUE MOVES",
				run = function()
					ui.placement, ui.cityStrikeSource, ui.pendingMove = nil, nil, nil
					ui.source = {
						x = unit.x,
						y = unit.y,
						unitID = unit.id,
						queue = true,
						append = queue ~= nil,
					}
					ui.reachable = {}
					ui:feedback(queue and "CHOOSE NEXT WAYPOINT" or "CHOOSE ROUTE DESTINATION")
					if modal then
						ui.panel = "context"
					end
				end,
			},
		}
		if queue then
			routeButtons[#routeButtons + 1] = {
				label = "CANCEL ROUTE",
				run = function()
					ui:command("cancelRoute", { x = unit.x, y = unit.y, unitID = unit.id })
					ui.source, ui.pendingMove, ui.reachable = nil, nil, {}
				end,
			}
		end
		rows[#rows + 1] = { buttons = routeButtons }
		rows[#rows + 1] = {
			buttons = {
				{
					label = "SKIP TURN",
					run = function()
						ui:command("skipTurn", { x = unit.x, y = unit.y, unitID = unit.id })
						ui.source, ui.pendingMove, ui.reachable = nil, nil, {}
						if modal then
							ui.panel = "context"
						end
					end,
				},
			},
		}
		rows[#rows + 1] = {
			buttons = {
				{
					label = unit.standby and "WAKE UNIT" or "SLEEP UNIT",
					run = function()
						ui.source = nil
						ui.reachable = {}
						ui.pendingMove = nil
						ui:command(
							"standby",
							{ x = unit.x, y = unit.y, unitID = unit.id, value = not unit.standby }
						)
					end,
				},
			},
		}
		rows[#rows + 1] = {
			buttons = {
				{
					label = "FORTIFY / HEAL",
					run = function()
						ui.source = nil
						ui.reachable = {}
						ui.pendingMove = nil
						ui:command("heal", { x = unit.x, y = unit.y, unitID = unit.id })
					end,
				},
			},
		}
		if ContentRules.isRedesign(state) then
			local recovery = Combat.restRecovery(state, unit, Systems)
			local amount = math.min(100 - (unit.hp or 100), recovery.total)
			local text = "REST FORECAST: +"
				.. amount
				.. " HP ("
				.. recovery.territory
				.. "). Acting prevents recovery."
			for _, line in ipairs(Panels.wrap(r, text, w - 10)) do
				rows[#rows + 1] = { text = line }
			end
		end
		if stats.builder then
			text("BUILDER CHARGES " .. (unit.charges or 0) .. " / 3", 13)
			if unit.autoWork then
				text(
					"AUTO WORK: "
						.. (unit.autoWorkPaused and "PAUSED / " .. unit.autoWorkPaused or "ACTIVE")
				)
			end
			local autoControls = {}
			if unit.autoWork then
				autoControls[#autoControls + 1] = {
					label = unit.autoWorkPaused and "RESUME AUTO WORK" or "PAUSE AUTO WORK",
					run = function()
						ui:command("autoWork", {
							unitID = unit.id,
							x = unit.x,
							y = unit.y,
							value = unit.autoWorkPaused and "resume" or "pause",
						})
					end,
				}
				autoControls[#autoControls + 1] = {
					label = "STOP AUTO WORK",
					run = function()
						ui:command("autoWork", {
							unitID = unit.id,
							x = unit.x,
							y = unit.y,
							value = "stop",
						})
					end,
				}
			else
				autoControls[1] = {
					label = "AUTO WORK",
					run = function()
						ui:command("autoWork", {
							unitID = unit.id,
							x = unit.x,
							y = unit.y,
							value = true,
						})
					end,
				}
			end
			rows[#rows + 1] = { buttons = autoControls }
			if at(state.cities, unit.x, unit.y) then
				text("CITY CENTER: move onto an owned land tile to improve it.", 8)
			end
			local queue = unit.workQueue
			if queue then
				text(
					"WORK TASKS "
						.. #queue.tasks
						.. (queue.paused and " / PAUSED: " .. queue.paused or " / ACTIVE")
				)
				for _, task in ipairs(queue.tasks) do
					text(
						(Works.definitions[task.kind] or {}).name
							.. " @ "
							.. task.x
							.. ","
							.. task.y
					)
				end
				rows[#rows + 1] = {
					buttons = {
						{
							label = "CANCEL WORK",
							run = function()
								ui:command(
									"cancelWork",
									{ unitID = unit.id, x = unit.x, y = unit.y }
								)
							end,
						},
					},
				}
				if queue.paused then
					rows[#rows + 1] = {
						buttons = {
							{
								label = "RESUME WORK",
								run = function()
									ui:command(
										"resumeWork",
										{ unitID = unit.id, x = unit.x, y = unit.y }
									)
								end,
							},
						},
					}
				end
			end
			rows[#rows + 1] = {
				buttons = {
					{
						label = ui.appendWork and "WORK MODE: APPEND" or "WORK MODE: REPLACE",
						run = function()
							ui.appendWork = not ui.appendWork
						end,
					},
				},
			}
			for _, kind in ipairs(Works.order) do
				local definition = Works.definitions[kind]
				if player.techs[definition.tech] then
					local here = Works.preview(state, player, unit, kind, unit.x, unit.y, Systems)
					if here then
						rows[#rows + 1] = {
							buttons = {
								{
									label = definition.name .. " HERE",
									run = function()
										ui:armPlacement("work", unit, kind)
										ui:tile(unit.x, unit.y)
									end,
								},
							},
						}
					end
					rows[#rows + 1] = {
						buttons = {
							{
								label = "PLAN " .. definition.name,
								run = function()
									ui:armPlacement("work", unit, kind)
								end,
							},
						},
					}
				end
			end
			local preview = ui.pendingMove and ui.pendingMove.workPreview
			if preview then
				text("WORK PREVIEW: " .. Works.definitions[preview.kind].name, 13)
				text("CHARGES " .. preview.chargesBefore .. " -> " .. preview.chargesAfter)
				text(
					"FOOD "
						.. preview.before.food
						.. " -> "
						.. preview.after.food
						.. " / INDUSTRY "
						.. preview.before.industry
						.. " -> "
						.. preview.after.industry
				)
				text(
					"Only worked tiles produce yields. Route pauses on visible threats. Confirm queues work."
				)
			end
		end
		if stats.engineer then
			rows[#rows + 1] = {
				buttons = {
					{
						label = "BUILD RAIL (2 IRON)",
						run = function()
							ui:armPlacement("rail", unit)
						end,
					},
				},
			}
		end
		if unit.kind == "scout" or unit.kind == "explorer" then
			rows[#rows + 1] = {
				buttons = {
					{
						label = unit.autoExplore and "STOP EXPLORING" or "AUTO EXPLORE",
						run = function()
							ui:command("autoExplore", {
								x = unit.x,
								y = unit.y,
								unitID = unit.id,
								value = not unit.autoExplore,
							})
						end,
					},
				},
			}
		end
		if ui.source then
			rows[#rows + 1] = {
				buttons = {
					{
						label = "CANCEL MOVE",
						run = function()
							ui.source = nil
							ui.reachable = {}
							ui.pendingMove = nil
						end,
					},
				},
			}
		end
		rows[#rows + 1] = {
			buttons = {
				{
					label = "DISBAND",
					run = function()
						ui:command("disband", { x = unit.x, y = unit.y, unitID = unit.id })
					end,
				},
			},
		}
		rows[#rows + 1] = {
			buttons = {
				{
					label = "DESELECT",
					run = function()
						ui:deselect()
					end,
				},
			},
		}

		if unit.kind == "settler" and not at(state.cities, unit.x, unit.y) then
			rows[#rows + 1] = {
				buttons = {
					{
						label = ContentRules.startsWithSettler(state)
								and not player.capitalFounded
								and "FOUND CAPITAL"
							or "FOUND CITY",
						run = function()
							ui:command("found", { x = unit.x, y = unit.y, unitID = unit.id })
						end,
					},
				},
			}
		end
	elseif city and city.remembered then
		text(city.name or "REMEMBERED CITY", 17)
		text("LAST SEEN ROUND " .. (city.lastSeenRound or "?"), 17)
		text("Scout again for current details.")
	elseif
		city
		and Villages.independent(city)
		and World.known(player, city.x, city.y) ~= "hidden"
	then
		text(city.name or "VILLAGER VILLAGE", 8)
		local kind = Villages.types[city.villageKind] or {}
		text(kind.name or "INDEPENDENT VILLAGE")
		local influence = (city.influence or {})[player.id] or 0
		text("INFLUENCE " .. influence .. " / ALLY AT 40")
		local ally = Villages.ally(city)
		text(
			ally == player.id and "ALLIED WITH YOU"
				or ally and "ALLIED WITH A RIVAL"
				or "NO ALLIANCE"
		)
		text(
			"Defeat mobs within 3 hexes: +10 influence. Envoy: +10 influence for 25 gold, once per 5 rounds."
		)
		for k, v in pairs(kind) do
			if type(v) == "number" then
				text("ALLIANCE: +" .. v .. " " .. k .. " in your oldest city")
			end
		end
		text(
			city.remoteVillage and "DEFENSE OUTSIDE CURRENT SIGHT"
				or ("HP " .. (city.hp or 200) .. "/200")
		)
		rows[#rows + 1] = {
			buttons = {
				{
					label = "SEND ENVOY (25 GOLD)",
					run = function()
						ui:command("envoy", { x = city.x, y = city.y })
					end,
				},
			},
		}
		text("20 influence enables village material trade from the resource ledger.")
	elseif (city or unit) and World.known(player, ui.selected.x, ui.selected.y) == "visible" then
		if city then
			Combat.city(city)
			text(city.name or "ENEMY CITY", 31)
			text("HP " .. city.hp .. "/200")
			text("WALLS " .. city.wallHP .. "/" .. city.maxWalls)
			text("DEF " .. Combat.cityPower(state, city, Systems))
		else
			Combat.unit(unit)
			text(Systems.label("unit", unit.kind) .. " LV" .. unit.level, 31)
			text("HP " .. unit.hp .. "/100")
			text("ATK " .. Combat.power(unit, Systems, false, state))
			text("DEF " .. Combat.power(unit, Systems, true, state))
		end
	else
		local known = World.known(player, ui.selected.x, ui.selected.y)
		text("HEX " .. ui.selected.x .. "," .. ui.selected.y, 7)
		text(
			known == "hidden" and "UNEXPLORED"
				or Biomes.label(Hex.tile(ui.selected.x, ui.selected.y, state))
		)
		if known ~= "hidden" then
			local yields = World.yields(state.world, ui.selected.x, ui.selected.y, state)
			rows[#rows + 1] = { yields = yields }
			text(World.deposit(state.world, ui.selected.x, ui.selected.y) or "NO DEPOSIT")
		end
	end
	if state.world and Sites.enabled(state) and not ui.selected.empty then
		local site = (state.world.specialtySites or {})[World.key(ui.selected.x, ui.selected.y)]
		if site then
			text(Sites.definitions[site.kind].name .. (site.inactive and " (INACTIVE)" or ""), 13)
			text("Assigned city #" .. site.city .. "; W Works / K Knowledge / F Freight")
			for _, owned in ipairs(state.cities) do
				if owned.id == site.city and owned.owner == ui.playerID then
					rows[#rows + 1] = {
						buttons = {
							{
								label = "MANAGE SITES",
								run = function()
									ui:focus("city", owned)
									ui.panel = "inspector"
									ui.cityPanel = "production"
									ui.productionCategory = "site"
									ui.inspectorOffset = 0
								end,
							},
						},
					}
				end
			end
		end
	end
	if not ui.selected.empty and World.known(player, ui.selected.x, ui.selected.y) ~= "hidden" then
		local landmark, rail = World.observedFeatures(state, player, ui.selected.x, ui.selected.y)
		if landmark then
			local record = (landmark.natural and Systems.naturalWonders or Systems.wonders)[landmark.kind]
			if record then
				text(record.name, 8)
				text(record.description)
				text(
					landmark.natural and "Work this tile for its benefits."
						or "Benefits follow ownership of this tile."
				)
			end
		end
		local improvement = (state.world.improvements or {})[World.key(ui.selected.x, ui.selected.y)]
		if improvement then
			text(
				"TILE WORK: "
					.. (Works.definitions[improvement.kind] or {}).name
					.. (improvement.damaged and " / DAMAGED" or ""),
				13
			)
		end
		if rail then
			text("RAILWAY: 1/4 move between owned rail hexes.", 13)
		end
		for _, spawner in ipairs(World.observedCamps(state, player)) do
			if spawner.x == ui.selected.x and spawner.y == ui.selected.y then
				text(
					spawner.cleared and "CLEARED SPAWNER"
						or (
							"HOSTILE "
							.. spawner.kind:upper()
							.. " - melee occupation clears it for 25 gold"
						),
					31
				)
			end
		end
	end
	if unit and unit.owner == ui.playerID then
		for _, row in ipairs(rows) do
			if row.buttons then
				row.unitActions = true
				for _, button in ipairs(row.buttons) do
					UnitActions.decorate(button)
				end
			end
		end
		local ordered = {}
		local used = {}
		for i, row in ipairs(rows) do
			if i == 1 or row.text and (row.text:match("^HP ") or row.text:match("^MOVE ")) then
				ordered[#ordered + 1] = row
				used[i] = true
			end
		end
		for i, row in ipairs(rows) do
			if row.buttons then
				ordered[#ordered + 1] = row
				used[i] = true
			end
		end
		for i, row in ipairs(rows) do
			if not used[i] then
				ordered[#ordered + 1] = row
			end
		end
		if h < 150 then
			local primary, details = {}, {}
			for _, row in ipairs(ordered) do
				if
					row.buttons
					or row == ordered[1]
					or row.text and (row.text:match("^HP ") or row.text:match("^MOVE "))
				then
					primary[#primary + 1] = row
				else
					details[#details + 1] = row
				end
			end
			if ui.unitDetails then
				rows = details
			else
				rows = primary
			end
			local toggle = {
				buttons = {
					{
						label = ui.unitDetails and "ACTIONS" or "UNIT DETAILS",
						run = function()
							ui.unitDetails = not ui.unitDetails
							ui.inspectorOffset = 0
						end,
					},
				},
			}
			table.insert(rows, 1, toggle)
		else
			rows = ordered
		end
	end
	Panels.rows(
		r,
		{ x = x + 3, y = bodyY, w = w - 6, h = y + h - bodyY - 2 },
		rows,
		ui,
		"inspectorOffset"
	)
end
return I
