local Panels = dofile("/games/civcraft/panels.lua")
local Suggestions = dofile("/games/civcraft/settlement_suggestions.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Content = dofile("/games/civcraft/content.lua")
local DisplayGeometry = dofile("/games/civcraft/display_geometry.lua")
local V = {}
local LIMIT = 3

local function wrapRows(renderer, rows, width)
	local wrapped = {}
	for _, row in ipairs(rows) do
		if row.text then
			for _, line in ipairs(Panels.wrap(renderer, row.text, width)) do
				wrapped[#wrapped + 1] = { text = line, color = row.color }
			end
		else
			wrapped[#wrapped + 1] = row
		end
	end
	return wrapped
end

function V.current(ui, state, player)
	local selected = ui.selected
	local observer = player and player.id
	local settler
	if
		state
		and state.observerID == observer
		and selected
		and selected.kind == "unit"
		and selected.unitID
	then
		for _, unit in ipairs(state.units or {}) do
			if unit.id == selected.unitID and unit.owner == observer and unit.kind == "settler" then
				settler = unit
				break
			end
		end
	end
	if not settler then
		ui.settlementSuggestionCache = nil
		ui.settlementSuggestions = nil
		ui.settlementSuggestionTargets = {}
		ui.settlementSuggestionDetail = nil
		return nil
	end
	local cache = ui.settlementSuggestionCache
	if
		cache
		and cache.view == state
		and cache.observer == observer
		and cache.campaign == state.campaignID
		and cache.settlerID == settler.id
	then
		return cache.sites
	end
	if
		cache
		and (
			cache.observer ~= observer
			or cache.campaign ~= state.campaignID
			or cache.settlerID ~= settler.id
		)
	then
		ui.settlementSuggestionDetail = nil
		ui.settlementSuggestionTargets = {}
	end
	local systems = setmetatable({
		checkpoint = function()
			if ui.r.cooperate then
				ui.r:cooperate()
			end
		end,
	}, { __index = Systems })
	local sites = Suggestions.forSettler(state, observer, settler, systems, LIMIT)
	ui.settlementSuggestionCache = {
		view = state,
		observer = observer,
		campaign = state.campaignID,
		settlerID = settler.id,
		sites = sites,
	}
	ui.settlementSuggestions = sites
	return sites
end

function V.open(ui, site)
	if not site then
		return false
	end
	ui.settlementSuggestionDetail = { x = site.x, y = site.y }
	ui.settlementSuggestionOffset = 0
	ui.panel = "settlementSuggestions"
	return true
end

local function selectedSite(ui, sites)
	local location = ui.settlementSuggestionDetail
	if not location then
		return nil
	end
	for index, site in ipairs(sites or {}) do
		if site.x == location.x and site.y == location.y then
			return site, index
		end
	end
	ui.settlementSuggestionDetail = nil
	return nil
end

function V.drawDetails(ui, state, player, rect)
	local r = ui.r
	local sites = V.current(ui, state, player) or {}
	local site, selectedIndex = selectedSite(ui, sites)
	r:text(rect.x + 5, rect.y + 5, "SETTLEMENT SITES", 8, 1, rect.w - 54)
	r:button(rect.x + rect.w - 43, rect.y + 2, 40, 11, "CLOSE", function()
		ui.panel = "context"
		ui.settlementSuggestionDetail = nil
	end)
	local rows = {}
	if site then
		rows[#rows + 1] = { text = "SITE " .. selectedIndex .. " AT " .. site.x .. "," .. site.y }
		rows[#rows + 1] = { text = "FOOD " .. site.reasons[1]:match("Food yield: (.+)") }
		rows[#rows + 1] = { text = "INDUSTRY " .. site.reasons[2]:match("Industry yield: (.+)") }
		rows[#rows + 1] = { text = site.reasons[3] }
		if site.capacity.active then
			rows[#rows + 1] = {
				text = "BASE "
					.. site.capacity.base
					.. " / WATER "
					.. site.capacity.waterBonus
					.. " / INFRASTRUCTURE "
					.. site.capacity.infrastructure,
			}
			for _, source in ipairs(site.capacity.sources or {}) do
				rows[#rows + 1] = { text = source.id .. " CAPACITY +" .. source.amount }
			end
		end
		rows[#rows + 1] = { text = site.reasons[4] }
		for _, resource in ipairs(site.resources or {}) do
			rows[#rows + 1] = { text = "ADJACENT EXPLORED RESOURCE: " .. resource }
		end
		for _, specialty in ipairs(site.specialties or {}) do
			local tech = Content.techs[specialty.tech]
			rows[#rows + 1] = {
				text = "POSSIBLE LATER: "
					.. specialty.name
					.. " +"
					.. specialty.bonus
					.. " AT "
					.. specialty.x
					.. ","
					.. specialty.y
					.. " ("
					.. specialty.distance
					.. " HEXES); REQUIRES "
					.. (tech and tech.name or tostring(specialty.tech):upper()),
			}
			rows[#rows + 1] = { text = specialty.caveat }
		end
		rows[#rows + 1] = { text = site.knowledgeNote }
		rows[#rows + 1] = { text = "Advisory only; no movement or founding order is sent." }
		rows[#rows + 1] = {
			buttons = {
				{
					label = "SHOW ON MAP",
					run = function()
						local viewport = ui.mapViewport
						if viewport then
							local displayX = DisplayGeometry.nearestX(
								site.x,
								(ui.panX + viewport.w / 2) / viewport.tile
									+ 0.5
									- ((site.y - 1) % 2) * 0.5,
								state
							)
							local panX = (displayX - 0.5 + ((site.y - 1) % 2) * 0.5) * viewport.tile
								- viewport.w / 2
							ui.panX = viewport.wrapX
									and ((panX % viewport.periodX) + viewport.periodX) % viewport.periodX
								or math.max(0, math.min(viewport.maxX, panX))
							ui.panY = math.max(
								0,
								math.min(
									viewport.maxY,
									(site.y - 1) * viewport.tile * 0.75
										+ viewport.tile / 2
										- viewport.h / 2
								)
							)
						end
						ui.panel = "context"
						ui.settlementSuggestionDetail = nil
					end,
				},
			},
		}
		rows[#rows + 1] = {
			buttons = {
				{
					label = "BACK TO SITES",
					run = function()
						ui.settlementSuggestionDetail = nil
						ui.settlementSuggestionOffset = 0
					end,
				},
			},
		}
	else
		rows[#rows + 1] = { text = "RANKED SITES USE EXPLORED INFORMATION ONLY" }
		for index, candidate in ipairs(sites) do
			rows[#rows + 1] = {
				buttons = {
					{
						label = "SITE " .. index .. "  " .. candidate.x .. "," .. candidate.y,
						run = function()
							V.open(ui, candidate)
						end,
					},
				},
			}
		end
		if #sites == 0 then
			rows[#rows + 1] = { text = "NO KNOWN LEGAL SITE" }
		end
		rows[#rows + 1] = { text = "No site is founded or moved automatically." }
	end
	rows = wrapRows(r, rows, rect.w - 21)
	Panels.rows(
		r,
		{ x = rect.x + 5, y = rect.y + 18, w = rect.w - 10, h = rect.h - 24 },
		rows,
		ui,
		"settlementSuggestionOffset"
	)
end

function V.drawMarkers(ui, state, player, tiles, rect, size, renderer)
	local sites = ui.settlementSuggestions or {}
	local targets = {}
	ui.settlementSuggestionTargets = targets
	if
		#sites == 0
		or ui:animating()
		or ui.source
		or ui.placement
		or ui.pendingMove
		or ui.cityStrikeSource
	then
		return
	end
	local function overlaps(a, b)
		return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
	end
	local obstacles = {}
	for _, list in ipairs({
		renderer.buttons or {},
		ui.cityBannerTargets or {},
		ui.unitBadgeTargets or {},
		ui.unitIconTargets or {},
	}) do
		for _, item in ipairs(list) do
			obstacles[#obstacles + 1] = item
		end
	end
	local byKey = {}
	for index, site in ipairs(sites) do
		byKey[World.key(site.x, site.y)] = index
	end
	local markerSize = math.min(9, math.max(7, math.floor(size * 0.48)))
	for _, tile in ipairs(tiles) do
		local index = byKey[World.key(tile.x, tile.y)]
		if index and tile.visibility ~= "hidden" then
			local positions = {
				{ tile.px + size * 0.25, tile.py + size * 0.25 },
				{ tile.px + size * 0.75, tile.py + size * 0.25 },
				{ tile.px + size * 0.25, tile.py + size * 0.75 },
				{ tile.px + size * 0.75, tile.py + size * 0.75 },
				{ tile.px + size * 0.5, tile.py + size * 0.25 },
				{ tile.px + size * 0.5, tile.py + size * 0.75 },
			}
			for _, position in ipairs(positions) do
				local x = math.floor(position[1] - markerSize / 2)
				local y = math.floor(position[2] - markerSize / 2)
				local target = { x = x, y = y, w = markerSize, h = markerSize }
				local centerX, centerY =
					x + math.floor(markerSize / 2), y + math.floor(markerSize / 2)
				local visible = x >= rect.x
					and y >= rect.y
					and x + markerSize <= rect.x + rect.w
					and y + markerSize <= rect.y + rect.h
					and Hex.contains(tile.px, tile.py, size, centerX, centerY)
				for _, obstacle in ipairs(obstacles) do
					if overlaps(target, obstacle) then
						visible = false
						break
					end
				end
				if visible then
					renderer:fill(x, y, markerSize, markerSize, 0)
					renderer:outline(x, y, markerSize, markerSize, 18)
					renderer:text(x + 1, y + 1, tostring(index), 13, 1, markerSize - 2)
					target.site = sites[index]
					target.index = index
					target.settlerID = ui.selected.unitID
					targets[#targets + 1] = target
					obstacles[#obstacles + 1] = target
					break
				end
			end
		end
	end
end

return V
