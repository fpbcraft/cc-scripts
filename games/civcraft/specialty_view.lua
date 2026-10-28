local Sites = dofile("/games/civcraft/specialty_sites.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local View = {}
View.symbols = { works = "W", knowledge = "K", freight = "F" }
View.bonuses = {
	works = "Hill here OR revealed iron/copper/zinc beside it: +1 industry.",
	knowledge = "Mountain beside it OR revealed redstone/diamond here: +1 science.",
	freight = "Water beside it OR a known road/rail here: +1 gold.",
}
local function signature(value)
	if type(value) ~= "table" then
		return type(value) .. ":" .. tostring(value)
	end
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local result = { "{" }
	for _, key in ipairs(keys) do
		result[#result + 1] = signature(key) .. "=" .. signature(value[key])
	end
	return table.concat(result, "|") .. "}"
end
local function placementKey(state, city, request, preview)
	local source
	for _, site in pairs(city.sites or {}) do
		if site.id == request.siteId then
			source = site
		end
	end
	return signature({
		campaign = state.campaignID,
		city = city.id,
		owner = city.owner,
		request = request,
		preview = preview,
		source = source,
	})
end
local function cancelKey(state, city, project)
	return signature({
		campaign = state.campaignID,
		city = city.id,
		owner = city.owner,
		project = project,
	})
end
function View.refresh(ui, holder, cancel)
	local state = ui.state
	local request = not cancel and holder.siteRequest
	local cityId = cancel and holder.city or request and request.city
	local city, player
	for _, c in ipairs(state.cities or {}) do
		if c.id == cityId then
			city = c
		end
	end
	for _, p in ipairs(state.players or {}) do
		if p.id == ui.playerID then
			player = p
		end
	end
	local campaign = cancel and holder.campaign or holder.siteCampaign
	if
		not Sites.enabled(state)
		or campaign ~= state.campaignID
		or not city
		or city.owner ~= ui.playerID
		or not player
	then
		holder.invalid = true
		return false
	end
	local key
	if cancel then
		local project = (city.siteProjects or {})[holder.projectId]
		if not project or project.kind ~= holder.kind then
			holder.invalid = true
			return false
		end
		key = cancelKey(state, city, project)
		holder.progress = project.progress
	else
		local preview = Sites.preview(state, player, city, request)
		if not preview then
			holder.invalid = true
			return false
		end
		key = placementKey(state, city, request, preview)
		holder.sitePreview = preview
		holder.siteIndustry = Systems.yields(player, city, state, Hex, nil, true).industry
	end
	if holder.invalid or key ~= holder.signature then
		holder.needsReview = true
		ui.specialtyOffset = 0
	end
	holder.invalid = false
	holder.signature = key
	return true
end
function View.ready(ui, pending)
	return View.refresh(ui, pending, false) and not pending.needsReview
end
function View.projectName(city, project)
	if project.kind == "site" then
		local retained = (city.siteProjects or {})[project.id]
		return retained and Sites.definitions[retained.kind].name or "SPECIALTY"
	end
	return Systems.label(project.kind, project.id)
end
function View.targets(state, player, city, kind, sourceId)
	local result = {}
	if not Sites.enabled(state) then
		return result
	end
	for y = math.max(1, city.y - 3), math.min(state.world.height, city.y + 3) do
		for x = math.max(1, city.x - 3), math.min(state.world.width, city.x + 3) do
			if Hex.distance(city.x, city.y, x, y) <= 3 then
				local request = {
					action = sourceId and "redevelopSite" or "placeSite",
					city = city.id,
					siteId = sourceId,
					kind = kind,
					x = x,
					y = y,
				}
				local preview = Sites.preview(state, player, city, request)
				if preview then
					result[#result + 1] = {
						x = x,
						y = y,
						cost = preview.cost,
						sitePreview = preview,
						signature = placementKey(state, city, request, preview),
						campaign = state.campaignID,
						industry = Systems.yields(player, city, state, Hex, nil, true).industry,
						request = request,
					}
				end
			end
		end
	end
	return result
end
function View.rows(ui, state, player, city, rows, text)
	local details = Sites.owned(state, player, city)
	local focus = details.focus
	text("FOCUS " .. focus.used .. "/" .. focus.allowed, 8)
	text("One slot per placed or reserved site. Basics use none.")
	rows[#rows + 1] = {
		buttons = {
			{
				label = "SITE HELP",
				run = function()
					ui:openCodex("mechanics", "specialties")
				end,
			},
		},
	}
	if focus.overage > 0 then
		text("POP LOSS: existing sites stay active; grow before adding a slot.", 13)
	end
	local sourceId = ui.siteSource
	if sourceId then
		local found
		for _, site in pairs(city.sites or {}) do
			if site.id == sourceId then
				found = site
			end
		end
		if not found then
			ui.siteSource = nil
			sourceId = nil
		else
			text("REDEVELOP " .. Sites.definitions[found.kind].name, 13)
			text("Choose replacement role, then a hex. Moving the same role keeps its buildings.")
			rows[#rows + 1] = {
				buttons = {
					{
						label = "KEEP SITE",
						run = function()
							ui.siteSource = nil
							ui.inspectorOffset = 0
						end,
					},
				},
			}
		end
	end
	for _, kind in ipairs(Sites.order) do
		local definition = Sites.definitions[kind]
		local site = (city.sites or {})[kind]
		local status = details.familyAvailability[kind]
		text(definition.name .. (site and " HEX " .. site.x .. "," .. site.y or ""), 8)
		text("Base +1 " .. definition.output .. "; local bonus capped +1.")
		text(View.bonuses[kind])
		if site and not status.available then
			text("INACTIVE: " .. status.reason, 31)
		end
		if sourceId or not site then
			local targets = View.targets(state, player, city, kind, sourceId)
			local price = Sites.cost(player, { sourceSiteId = sourceId })
			if #targets > 0 then
				rows[#rows + 1] = {
					buttons = {
						{
							label = (sourceId and "REPLACE: " or "PLACE: ")
								.. View.symbols[kind]
								.. " ("
								.. price
								.. ")",
							run = function()
								ui:armSpecialty(city, kind, sourceId)
							end,
						},
					},
				}
			else
				local reason = not (player.techs or {})[definition.tech]
						and "Research " .. definition.tech
					or not sourceId and focus.used >= focus.allowed and "No free focus slot"
					or "No eligible owned hex; range 1-3, no improvement/wonder/site"
				text(reason, 13)
			end
		elseif site then
			local redeveloping = false
			for _, project in pairs(city.siteProjects or {}) do
				if project.sourceSiteId == site.id then
					redeveloping = true
				end
			end
			if redeveloping then
				text("Redevelopment already saved; resume/cancel below.", 13)
			else
				rows[#rows + 1] = {
					buttons = {
						{
							label = "REDEVELOP " .. View.symbols[kind],
							run = function()
								ui.siteSource = site.id
								ui.inspectorOffset = 0
							end,
						},
					},
				}
			end
		end
	end
	local projects = {}
	for id in pairs(city.siteProjects or {}) do
		projects[#projects + 1] = id
	end
	table.sort(projects)
	for _, id in ipairs(projects) do
		local project = city.siteProjects[id]
		local status = details.siteProjectStatus[id]
		text(Sites.definitions[project.kind].name .. " HEX " .. project.x .. "," .. project.y, 8)
		text(
			"SAVED "
				.. project.progress
				.. "/"
				.. status.cost
				.. (status.selected and " SELECTED" or " PAUSED")
		)
		if status.paused then
			text(status.reason, 31)
		end
		rows[#rows + 1] = {
			buttons = {
				{
					label = "RESUME " .. View.symbols[project.kind],
					run = function()
						ui:command("resumeSite", { city = city.id, projectId = id })
					end,
				},
			},
		}
		rows[#rows + 1] = {
			buttons = {
				{
					label = "CANCEL " .. View.symbols[project.kind],
					run = function()
						ui.specialtyCancel = {
							city = city.id,
							campaign = state.campaignID,
							signature = cancelKey(state, city, project),
							projectId = id,
							kind = project.kind,
							progress = project.progress,
						}
						ui.specialtyOffset = 0
					end,
				},
			},
		}
	end
	text("Ponder / Tend / Trade remain in PROJECTS without a site.")
	text("End Staging needs Nether Portal, not a Knowledge site.")
end
function View.confirmation(ui, state, player, rect)
	local r = ui.r
	local w, h = r.w, r.h
	local rows = {}
	local function text(value, color)
		for _, line in ipairs(Panels.wrap(r, value, w - 25)) do
			rows[#rows + 1] = { text = line, color = color }
		end
	end
	local cancel = ui.specialtyCancel
	local pending = ui.pendingMove
	local holder = cancel or pending
	local valid = View.refresh(ui, holder, cancel ~= nil)
	local preview = pending and pending.sitePreview
	r:text(8, 6, cancel and "CANCEL SITE PROJECT?" or "CONFIRM SPECIALTY", 8, 1, w - 16)
	if not valid then
		text("Order no longer available. Reselect an owned city/project.", 31)
		text("Nothing will be sent. Cached private details have been cleared.")
	elseif cancel then
		text(Sites.definitions[cancel.kind].name, 8)
		text("Forfeit " .. cancel.progress .. " invested industry. No refund.", 31)
		text("The reservation is released. A redevelopment source and its buildings remain.")
	else
		local request = pending.siteRequest
		text(Sites.definitions[preview.kind].name .. " HEX " .. preview.x .. "," .. preview.y, 8)
		text(
			"COST "
				.. preview.cost
				.. " INDUSTRY / "
				.. math.max(1, math.ceil(preview.cost / math.max(1, pending.siteIndustry)))
				.. " TURNS",
			13
		)
		text(
			"FOCUS "
				.. preview.focusBefore
				.. " > "
				.. preview.focusAfter
				.. " / "
				.. preview.allowance
		)
		if request.siteId then
			text(
				"LOSE "
					.. #preview.lostBuildings
					.. " BUILDS / "
					.. #preview.lostProgress
					.. " SAVED TARGETS",
				31
			)
			if #preview.lostBuildings == 0 and #preview.lostProgress == 0 then
				text("No family buildings/progress lost. Same-role moves retain them.")
			end
			for _, id in ipairs(preview.lostBuildings) do
				text("LOSE: " .. Systems.label("building", id), 31)
			end
			for _, record in ipairs(preview.lostProgress) do
				text(
					"LOSE SAVED: "
						.. Systems.label("building", record.id)
						.. " "
						.. record.progress
						.. " industry",
					31
				)
			end
			text("No salvage/refund. End flags and civilian remainders stay.")
			text("Price includes the redevelopment surcharge. Source operates until completion.")
		end
		text(
			"CITY +"
				.. preview.base
				.. " BASE +"
				.. preview.bonus
				.. " LOCAL "
				.. Sites.definitions[preview.kind].output:upper()
		)
		text(View.bonuses[preview.kind])
		local yields = preview.tileYields or {}
		text(
			"Tile stays workable: food "
				.. (yields.food or 0)
				.. ", industry "
				.. (yields.industry or 0)
				.. ", science "
				.. (yields.science or 0)
				.. ". No Builder improvement may share it."
		)
	end
	if h < 85 then
		local summary = not valid and "RESELECT REQUIRED"
			or cancel and ("FORFEIT " .. cancel.progress .. "I / NO REFUND")
			or (
				preview.cost
				.. "I F"
				.. preview.focusBefore
				.. ">"
				.. preview.focusAfter
				.. "/"
				.. preview.allowance
				.. " L"
				.. #preview.lostBuildings
				.. "+"
				.. #preview.lostProgress
			)
		r:text(7, 14, summary, cancel and 31 or 13, 1, w - 14)
		local capacity = math.max(1, math.floor((h - 49) / 8))
		ui.specialtyOffset =
			math.max(0, math.min(ui.specialtyOffset or 0, math.max(0, #rows - capacity)))
		for i = 1, capacity do
			local row = rows[ui.specialtyOffset + i]
			if row then
				r:text(7, 23 + (i - 1) * 8, row.text, row.color or 6, 1, w - 14)
			end
		end
		local navWidth = math.floor((w - 18) / 2)
		r:button(7, h - 26, navWidth, 9, "PREV", function()
			ui.specialtyOffset = math.max(0, ui.specialtyOffset - capacity)
		end)
		r:button(math.floor(w / 2) + 2, h - 26, navWidth, 9, "NEXT", function()
			ui.specialtyOffset =
				math.min(math.max(0, #rows - capacity), ui.specialtyOffset + capacity)
		end)
	else
		Panels.rows(r, { x = 8, y = 18, w = w - 16, h = h - 47 }, rows, ui, "specialtyOffset")
	end
	local width = math.floor((w - 18) / 2)
	r:button(7, h - 15, width, 11, cancel and "KEEP" or "BACK", function()
		ui.specialtyCancel = nil
		if not cancel then
			ui.pendingMove = nil
		end
	end)
	r:button(
		math.floor(w / 2) + 2,
		h - 15,
		width,
		11,
		not valid and "CLOSE"
			or holder.needsReview and "REVIEW AGAIN"
			or cancel and "CANCEL SITE"
			or "CONFIRM",
		function()
			if not View.refresh(ui, holder, cancel ~= nil) then
				ui.specialtyCancel = nil
				ui.pendingMove = nil
				ui.placement = nil
				ui.reachable = {}
				ui:feedback("Order changed. Select an owned city/project again.")
				return
			end
			if holder.needsReview then
				holder.needsReview = false
				ui.specialtyOffset = 0
				ui:feedback("Updated costs/losses shown. Confirm again to proceed.")
				return
			end
			if cancel then
				ui.specialtyCancel = nil
				ui:command("cancelSite", { city = cancel.city, projectId = cancel.projectId })
			else
				ui:confirmMove()
			end
		end,
		{ primary = true }
	)
end
return View
