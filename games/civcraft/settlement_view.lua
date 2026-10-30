local Suggestions = dofile("/games/civcraft/settlement_suggestions.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local World = dofile("/games/civcraft/world.lua")
local Icons = dofile("/games/civcraft/icons.lua")
local V = {}
local LIMIT = 12

function V.current(ui, state, player)
	local observer = player and player.id
	local selected = ui.selected
	local settler
	if state and state.observerID == observer and selected and selected.kind == "unit" then
		for _, unit in ipairs(state.units or {}) do
			if unit.id == selected.unitID and unit.owner == observer and unit.kind == "settler" then
				settler = unit
				break
			end
		end
	end
	if not settler then
		ui.settlementSuggestionCache, ui.settlementSuggestions = nil, nil
		ui.settlementSuggestionTargets = {}
		return nil
	end
	local systems = setmetatable({
		checkpoint = function()
			if ui.r.cooperate then
				ui.r:cooperate()
			end
		end,
	}, { __index = Systems })
	local signature = Suggestions.observationSignature(state, observer, settler, systems)
	local cache = ui.settlementSuggestionCache
	if
		cache
		and cache.signature == signature
		and cache.observer == observer
		and cache.campaign == state.campaignID
		and cache.settlerID == settler.id
	then
		ui.settlementSuggestions = cache.sites
		return cache.sites
	end
	local sites = Suggestions.forSettler(state, observer, settler, systems, LIMIT)
	ui.settlementSuggestionCache = {
		signature = signature,
		observer = observer,
		campaign = state.campaignID,
		settlerID = settler.id,
		sites = sites,
	}
	ui.settlementSuggestions = sites
	return sites
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
	local markerSize = math.min(14, math.max(7, math.floor(size * 0.48)))
	for _, tile in ipairs(tiles) do
		local index = byKey[World.key(tile.x, tile.y)]
		if index and tile.visibility ~= "hidden" then
			local positions = {
				{ tile.px + size * 0.5, tile.py + size * 0.5 },
				{ tile.px + size * 0.25, tile.py + size * 0.5 },
				{ tile.px + size * 0.75, tile.py + size * 0.5 },
				{ tile.px + size * 0.25, tile.py + size * 0.25 },
				{ tile.px + size * 0.75, tile.py + size * 0.25 },
				{ tile.px + size * 0.25, tile.py + size * 0.75 },
				{ tile.px + size * 0.75, tile.py + size * 0.75 },
				{ tile.px + size * 0.5, tile.py + size * 0.25 },
				{ tile.px + size * 0.5, tile.py + size * 0.75 },
				{ tile.px + size * 0.5, tile.py + 1 },
				{ tile.px + size * 0.5, tile.py + size - 1 },
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
					Icons.draw(renderer, "settlement", x, y, markerSize, 13)
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
