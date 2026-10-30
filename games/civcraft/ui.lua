local Specialty = dofile("/games/civcraft/specialty_view.lua")
-- CIVCRAFT local/network UI built on the RAILBREAK pixel canvas.
-- Never mutate simulation here: all commands flow through dispatch().
local FactionColors = dofile("/games/civcraft/faction_colors.lua")
local Personalities = dofile("/games/civcraft/ai_personalities.lua")
local CivilizationPicker = dofile("/games/civcraft/civilization_picker.lua")
local CampaignOptions = dofile("/games/civcraft/campaign_options.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Combat = dofile("/games/civcraft/combat.lua")
local Conversation = dofile("/games/civcraft/conversation_view.lua")
local GameView = dofile("/games/civcraft/game_view.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local DisplayGeometry = dofile("/games/civcraft/display_geometry.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Playback = dofile("/games/civcraft/playback_ui.lua")
local Renderer = dofile("/games/civcraft/render.lua")
local Settings = dofile("/games/civcraft/settings_view.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local TurnTasks = dofile("/games/civcraft/turn_tasks.lua")
local Scheduler = dofile("/games/civcraft/turn_scheduler.lua")
local World = dofile("/games/civcraft/world.lua")
local QueuedRoutes = dofile("/games/civcraft/queued_routes.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local Stacks = dofile("/games/civcraft/unit_stacks.lua")
local Difficulty = dofile("/games/civcraft/ai_difficulty.lua")
local UI = {}
UI.__index = UI
local function mapLabel(state)
	local size = state.mapSize or "standard"
	local dims = state.world and { state.world.width, state.world.height }
		or World.dimensions(size, state)
	return size:upper() .. " " .. dims[1] .. "X" .. dims[2]
end
local P = FactionColors.players
local function clip(s, n)
	return tostring(s or ""):upper():sub(1, math.max(0, n))
end
local function where(list, x, y)
	for _, thing in ipairs(list or {}) do
		if thing.x == x and thing.y == y then
			return thing
		end
	end
end
function UI.new(m, dispatch, options)
	local self = setmetatable({
		dispatch = dispatch,
		mapMode = "terrain",
		panX = 0,
		panY = 0,
		selected = { x = 2, y = 2 },
		source = nil,
		mode = "map",
		frame = 0,
		notice = "",
		panel = "context",
		productionCategory = "unit",
		productionPage = 1,
		workCity = nil,
	}, UI)
	Playback.attach(self)
	self.r = Renderer.new(m, {
		forceText = self.animationPreferences.display == "text",
		layoutOnly = options and options.layoutOnly,
	})
	return self
end
function UI:message(s)
	if not self.localNotice then
		self.notice = tostring(s or "")
	end
end
function UI:feedback(s)
	self.notice = tostring(s or "")
	self.localNotice = true
end
function UI:turnProgress(title, detail)
	local r = self.r
	local w, h = r.w, r.h
	r:begin()
	self.hexTargets = {}
	self.unitBadgeTargets = {}
	self.mapViewport = nil
	self.inspectorBounds = nil
	self.modalBounds = nil
	self.inputMode = nil
	self.pointerStart = nil
	r:fill(0, 0, w, h, 0)
	local y = math.max(2, math.floor(h / 2) - 16)
	local function line(offset, text, color)
		local limit = math.max(1, math.floor((w - 8) / 4))
		r:center(y + offset, clip(text, limit), color)
	end
	line(0, title, 8)
	line(12, detail, 7)
	line(24, "PLEASE WAIT...", 5)
	r:finish()
end
function UI:command(action, params)
	if action == "civ" then
		self.lobbyPlayer = params and params.player or 1
		if not (params and params.id) then
			self.civDropdown, self.civOffset = self.lobbyPlayer, 0
			local visible = {}
			for _, button in ipairs(self.r.buttons) do
				if button.label == "CIV" then
					visible[#visible + 1] = button
				end
			end
			self.civAnchor = visible[self.lobbyPlayer] or visible[1]
			return true
		end
	end
	if Settings.command(self, action) then
		return
	end
	if Playback.command(self, action) then
		return
	end
	self.localNotice = nil
	self.notice = ""
	if action == "disband" and params and not params.confirmed then
		self.disbandConfirm = params
		return
	end
	if action == "queue" and params and not params.confirmed then
		local city = where(self.state.cities, params.cityX, params.cityY)
		local current = city and city.project
		if current and (current.kind ~= params.kind or current.id ~= params.id) then
			self.productionConfirm = {
				params = params,
				previous = current.kind == "site" and Specialty.projectName(city, current)
					or current.id,
				progress = current.progress or 0,
			}
			self.productionOffset = 0
			return
		end
	end
	if action == "end" and not (params and params.confirmed) then
		local warnings = self:endWarnings()
		if #warnings > 0 then
			self.endConfirm = warnings
			self.endOffset = 0
			return
		end
	end
	if action == "end" then
		Playback.endTurn(self)
		self.placement = nil
		self.pendingMove = nil
		self.cityStrikeSource = nil
		self.source = nil
		self.reachable = {}
		self.workCity = nil
	end
	if self.dispatch then
		self.dispatch(action, params or {})
	end
end
function UI:openHistory()
	self.panel = "history"
	self.historyRequestID, self.historyLoading = (self.historyRequestID or 0) + 1, false
	self.historyPage, self.historyCursors, self.historyOffset = self.state.eventHistory, {}, 0
	if not self.historyPage then
		self:requestHistory()
	end
end
function UI:requestHistory(before)
	self.historyRequestID = (self.historyRequestID or 0) + 1
	self.historyLoading = true
	self:command("eventHistory", { before = before, requestID = self.historyRequestID })
end
function UI:receiveHistory(page, requestID)
	if
		type(page) ~= "table"
		or not self.state
		or page.observer ~= self.playerID
		or page.campaign ~= (self.state.campaignID or "legacy")
		or requestID ~= self.historyRequestID
		or self.panel ~= "history"
	then
		return false
	end
	self.historyPage, self.historyOffset, self.historyLoading = page, 0, false
	return true
end
function UI:endWarnings()
	return TurnTasks.pending(self.state, self.playerID, Systems)
end
function UI:turnAction()
	local eligible = self.state and Scheduler.canAct(self.state, self.playerID)
	if not eligible then
		return "WAITING", "pause", "waiting"
	end
	local task = self:endWarnings()[1]
	if task then
		if task.kind == "unit" then
			return "UNIT ORDERS", "nextUnit", "unit"
		end
		if task.kind == "city" then
			return "PRODUCTION", "station", "city"
		end
		return "RESEARCH", "tree", "research"
	end
	return "END TURN", "endTurn", "end"
end
function UI:advanceTurn()
	local _, _, action = self:turnAction()
	if action == "waiting" then
		return false
	end
	if action == "unit" then
		self:nextIdle()
	elseif action == "city" then
		self:nextIdleCity()
	elseif action == "research" then
		self.panel = "quickResearch"
		self.techModel = self.techModel or {}
		self:feedback("CHOOSE A RESEARCH PROJECT")
	else
		self:command("end")
	end
	if
		(action == "unit" or action == "city")
		and self.inspectorBounds
		and self.inspectorBounds.h < 60
	then
		self.panel = "inspector"
	end
	return true
end
function UI:deselect()
	self.settlementSuggestionCache = nil
	self.settlementSuggestions = nil
	self.settlementSuggestionDetail = nil
	self.settlementSuggestionTargets = {}
	self.placement = nil
	self.cityStrikeSource = nil
	self.source = nil
	self.reachable = {}
	self.pendingMove = nil
	self.workCity = nil
	self.selected.empty = true
	self.localNotice = nil
	self.notice = ""
end
function UI:armPlacement(kind, item, id)
	self.source = nil
	self.workCity = nil
	self.cityStrikeSource = nil
	self.pendingMove = nil
	self.reachable = {}
	self.panel = "context"
	self.placement = { kind = kind, item = item, id = id }
	local p
	for _, player in ipairs(self.state.players) do
		if player.id == self.playerID then
			p = player
		end
	end
	if kind == "work" then
		local reserved = self.appendWork and item.workQueue and #item.workQueue.tasks or 0
		if (item.charges or 0) > reserved then
			for _, city in ipairs(self.state.cities or {}) do
				if city.owner == self.playerID then
					for _, tile in ipairs(Systems.workable(self.state, city)) do
						local preview =
							Works.preview(self.state, p, item, id, tile.x, tile.y, Systems)
						if preview then
							self.reachable[#self.reachable + 1] =
								{ x = tile.x, y = tile.y, cost = 1, preview = preview }
						end
					end
				end
			end
		end
		self.placement.append = self.appendWork == true
	elseif kind == "wonder" then
		local L = dofile("/games/civcraft/landmarks.lua")
		for _, tile in ipairs(Systems.workable(self.state, item)) do
			if L.canPlace(self.state, item, id, tile.x, tile.y, Systems) then
				self.reachable[#self.reachable + 1] = { x = tile.x, y = tile.y, cost = 0 }
			end
		end
	else
		local R = dofile("/games/civcraft/railways.lua")
		local tiles = Hex.neighbours(item.x, item.y, self.state)
		tiles[#tiles + 1] = { x = item.x, y = item.y }
		for _, tile in ipairs(tiles) do
			if R.canBuild(self.state, p, item, tile.x, tile.y, Systems) then
				self.reachable[#self.reachable + 1] = { x = tile.x, y = tile.y, cost = 2 }
			end
		end
	end
	self:feedback(
		#self.reachable > 0 and "CHOOSE A CYAN HEX; CONFIRM TO BUILD"
			or "NO ELIGIBLE HEXES / CHECK MATERIALS AND RESEARCH"
	)
end
function UI:armSpecialty(city, kind, sourceId)
	self.source = nil
	self.workCity = nil
	self.cityStrikeSource = nil
	self.pendingMove = nil
	self.panel = "context"
	self.specialtyOffset = 0
	self.placement = { kind = "specialty", item = city, id = kind, sourceSiteId = sourceId }
	local player
	for _, p in ipairs(self.state.players) do
		if p.id == self.playerID then
			player = p
		end
	end
	self.reachable = Specialty.targets(self.state, player, city, kind, sourceId)
	self:feedback(
		#self.reachable > 0 and "CHOOSE A CYAN HEX FOR THE SPECIALTY" or "NO ELIGIBLE OWNED HEX"
	)
end
function UI:tile(x, y)
	if self.placement and not self.pendingMove then
		for _, t in ipairs(self.reachable or {}) do
			if t.x == x and t.y == y then
				self.pendingMove = {
					placement = self.placement,
					workPreview = t.preview,
					sitePreview = t.sitePreview,
					siteRequest = t.request,
					signature = t.signature,
					siteCampaign = t.campaign,
					siteIndustry = t.industry,
					x = x,
					y = y,
					cost = t.cost,
					player = self.playerID,
				}
				if t.sitePreview then
					self.specialtyOffset = 0
					self:feedback("REVIEW COST, FOCUS AND LOSSES BEFORE CONFIRMING")
				elseif t.preview then
					t.preview.reservedCharges = self.placement.append
							and self.placement.item.workQueue
							and #self.placement.item.workQueue.tasks
						or 0
					local v = t.preview
					self:feedback(
						"FOOD "
							.. v.before.food
							.. " -> "
							.. v.after.food
							.. "; INDUSTRY "
							.. v.before.industry
							.. " -> "
							.. v.after.industry
							.. "; CHARGES "
							.. v.chargesBefore
							.. " -> "
							.. v.chargesAfter
							.. ". CONFIRM TO QUEUE"
					)
				elseif
					self.placement.kind == "wonder"
					and (self.state.world.improvements or {})[World.key(x, y)]
				then
					self:feedback(
						"WONDER COMPLETION REPLACES THIS TILE IMPROVEMENT; CONFIRM TO QUEUE"
					)
				else
					self:feedback("CLICK HEX AGAIN OR CONFIRM TO BUILD")
				end
				return
			end
		end
		self:feedback("CHOOSE A HIGHLIGHTED HEX; ESCAPE CANCELS")
		return
	end
	if self.cityStrikeSource and not self.pendingMove then
		for _, target in ipairs(self.reachable or {}) do
			if target.x == x and target.y == y then
				local city =
					where(self.state.cities, self.cityStrikeSource.x, self.cityStrikeSource.y)
				self.pendingMove = {
					city = true,
					sx = city.x,
					sy = city.y,
					x = x,
					y = y,
					cost = 0,
					attack = true,
					kind = "CITY STRIKE",
					player = self.playerID,
					path = { { x = city.x, y = city.y }, { x = x, y = y } },
				}
				self:feedback("CLICK TARGET AGAIN TO CONFIRM CITY STRIKE")
				return
			end
		end
	end
	if self.pendingMove and self.pendingMove.x == x and self.pendingMove.y == y then
		self:confirmMove()
		return
	end
	if self.workCity then
		local city = where(self.state.cities, self.workCity.x, self.workCity.y)
		for _, tile in ipairs(Systems.workable(self.state, city)) do
			if tile.x == x and tile.y == y then
				self:command("workTile", { cityX = city.x, cityY = city.y, x = x, y = y })
				return
			end
		end
		self.workCity = nil
		self.cityPanel = "overview"
	end
	if self.source and not (x == self.source.x and y == self.source.y) then
		for _, p in ipairs(not self.source.queue and self.reachable or {}) do
			if p.x == x and p.y == y then
				local unit =
					Stacks.at(self.state.units, self.source.x, self.source.y, self.source.unitID)
				self.pendingMove = {
					sx = self.source.x,
					sy = self.source.y,
					x = x,
					y = y,
					cost = p.cost,
					attack = p.attack,
					path = p.path,
					kind = unit and unit.kind,
					unitID = unit and unit.id,
					player = self.playerID,
				}
				local forecast
				if p.attack and unit then
					local awake = {}
					for k, v in pairs(unit) do
						awake[k] = v
					end
					awake.standby = false
					awake.healing = false
					forecast = Combat.predictOrder(self.state, awake, p, Systems)
				end
				self.pendingMove.forecast = forecast
				local risk = (self.destinationThreats or {})[World.key(x, y)]
				self.pendingMove.risk = risk
				local summary = "COST "
					.. p.cost
					.. (p.escortCost and " / ESCORT " .. p.escortCost or "")
					.. (p.zoneStop and " / ZONE OF CONTROL: STOP" or "")
				if forecast then
					summary = "HP "
						.. forecast.attackerHP
						.. " / TARGET "
						.. (forecast.defenderHP or forecast.cityHP)
						.. (forecast.wallHP and (" / WALL " .. forecast.wallHP) or "")
						.. ((forecast.captured or forecast.capturedSettler) and " CAPTURE" or "")
				end
				if risk then
					summary = summary .. " / THREAT ~" .. risk.damage
				end
				self.moveOffset = 0
				self.lastDrag = nil
				self:feedback(summary .. " - CONFIRM")
				return
			end
		end
		local unit = Stacks.at(self.state.units, self.source.x, self.source.y, self.source.unitID)
		if unit then
			local path, reason =
				QueuedRoutes.preview(self.state, unit, x, y, self.source.append, Systems)
			if path and #path > 1 then
				self.pendingMove = {
					queued = true,
					append = self.source.append,
					sx = unit.x,
					sy = unit.y,
					x = x,
					y = y,
					unitID = unit.id,
					player = self.playerID,
					path = path,
				}
				self:feedback(
					(self.source.append and "APPEND WAYPOINT" or "ASSIGN ROUTE") .. " - CONFIRM"
				)
			else
				self:feedback(reason or "Choose another route destination")
			end
			return
		end
	end
	self.source = nil
	self.reachable = {}
	self.pendingMove = nil
	self.inspectorOffset = 0
	self.unitDetails = false
	if self.selected.x == x and self.selected.y == y and not self.selected.empty then
		self:deselect()
		return
	end
	local unit = Stacks.at(self.state.units, x, y)
	self.selected = {
		x = x,
		y = y,
		kind = unit and unit.owner == self.playerID and "unit" or "city",
		unitID = unit and unit.id,
	}
	self.panel = "context"
	self.cityPanel = "overview"
	self.workCity = nil
	self.localNotice = nil
	self.notice = ""
end
function UI:draw(state, playerID, opts)
	local r = self.r
	local w, h = r.w, r.h
	opts = opts or {}
	local world = state and state.world
	self.worldKey = table.concat({
		state and state.name or "",
		world and world.width or 0,
		world and world.height or 0,
		world and world.mapType or "",
		world and world.wrapX == true and "wrapped" or "bounded",
	}, ":")
	if not state or state.phase ~= "game" then
		self.worldReady = false
		self.reportSeen = {}
	end
	-- Never carry a previous hotseat player's selection or movement overlay
	-- into the next player's screen (including the concealed handoff).
	if
		self.lastPlayer ~= nil and self.lastPlayer ~= playerID
		or self.lastCampaign ~= nil and self.lastCampaign ~= (state and state.campaignID)
	then
		self.source = nil
		self.reachable = {}
		self.pendingMove = nil
		self.cityStrikeSource = nil
		self.productionConfirm = nil
		self.specialtyCancel = nil
		self.siteSource = nil
		self.specialtyOffset = 0
		self.disbandConfirm = nil
		self.endConfirm = nil
		self.panel = "context"
		self.placement = nil
		self.actionPage = 1
		self.techModel = nil
		Conversation.close(self)
		self.unitDetails = false
		self.conversationTarget = nil
		self.conversationOffset = 0
		self.trade = nil
		self.factionOffset = 0
		self.councilModel = nil
		self.historyPage, self.historyCursors, self.historyLoading = nil, {}, false
		self.historyRequestID = (self.historyRequestID or 0) + 1
		self.workCity = nil
		self.settlementSuggestionCache = nil
		self.settlementSuggestions = nil
		self.settlementSuggestionDetail = nil
		self.settlementSuggestionTargets = {}
		self.worldReady = false
		self.panX = 0
		self.panY = 0
		self.zoomLevel = nil
		self.localNotice = nil
		self.notice = ""
		self.activeScroll = nil
		self.selected = { x = 2, y = 2, empty = true }
		for _, city in ipairs(state.cities or {}) do
			if city.owner == playerID then
				self.selected = { x = city.x, y = city.y }
				break
			end
		end
	end
	self.lastPlayer = playerID
	self.lastCampaign = state and state.campaignID
	if self.selected.kind == "unit" and self.selected.unitID then
		local selectedUnit
		local observer
		for _, candidate in ipairs(state.players or {}) do
			if candidate.id == playerID then
				observer = candidate
				break
			end
		end
		for _, u in ipairs(state.units or {}) do
			if
				u.id == self.selected.unitID
				and (
					u.owner == playerID
					or observer and (observer.visible or {})[World.key(u.x, u.y)]
				)
			then
				selectedUnit = u
				break
			end
		end
		if selectedUnit then
			self.selected.x = selectedUnit.x
			self.selected.y = selectedUnit.y
		else
			self.selected = { x = self.selected.x, y = self.selected.y, empty = true }
			self.queuedRouteCache = nil
		end
	end
	if
		opts.handoff
		or (
			self.state
			and self.source
			and not (function()
				for _, u in ipairs(state.units or {}) do
					if
						u.x == self.source.x
						and u.y == self.source.y
						and u.owner == playerID
						and (not self.source.unitID or u.id == self.source.unitID)
						and (self.source.queue or not u.moved)
					then
						return true
					end
				end
				return false
			end)()
		)
	then
		self.source = nil
		self.reachable = {}
		self.pendingMove = nil
	end
	if
		opts.handoff
		or opts.paused
		or opts.screen == "title"
		or not state
		or state.phase ~= "game"
	then
		self.settlementSuggestionCache = nil
		self.settlementSuggestions = nil
		self.settlementSuggestionDetail = nil
		self.settlementSuggestionTargets = {}
		self.placement = nil
		self.reachable = {}
		self.pendingMove = nil
		self.productionConfirm = nil
		self.specialtyCancel = nil
		self.siteSource = nil
		self.specialtyOffset = 0
		self.disbandConfirm = nil
		self.endConfirm = nil
		self.lastDrag = nil
	end
	Playback.update(self, state, playerID, opts)
	r:begin()
	self.hexTargets = {}
	self.unitBadgeTargets = {}
	self.mapViewport = nil
	self.inspectorBounds = nil
	self.inputMode = nil
	self.modalBounds = nil
	r:fill(0, 0, w, h, 0)
	self.state = state
	self.playerID = playerID
	local header = math.min(27, math.max(16, math.floor(h * 0.16)))
	local footer = math.max(22, math.floor(h * 0.20))
	r:fill(0, 0, w, header, 1)
	r:fill(0, header - 2, w, 2, 8)
	r:text(7, math.max(4, math.floor(header / 2) - 6), "CIVCRAFT", 8, 1, 40)
	local phase = state and state.phase or "lobby"
	r:text(
		math.max(50, w - 84),
		math.max(3, header - 10),
		phase == "game" and ("ROUND " .. state.round) or phase,
		6,
		1,
		80
	)
	if not state then
		r:center(math.floor(h / 2), "CONNECTING TO HOST...", 6)
		r:finish()
		return
	end
	if self.settingsOpen then
		Settings.draw(self, opts)
		r:finish()
		return
	end
	if opts.screen == "title" then
		r:fill(0, 0, w, h, 0)
		local menu = self.titleMenu or "main"
		local compact = h < 180 or w < 220
		r:center(compact and 3 or math.floor(h * 0.12), "CIVCRAFT", 8, compact and 1 or 3)
		local rows = {}
		local function button(label, run, selected)
			rows[#rows + 1] =
				{ buttons = { { label = label, run = run, style = { primary = selected } } } }
		end
		local function open(name)
			self.titleMenu, self.titleOffset = name, 0
		end
		if menu == "main" then
			button("NEW CAMPAIGN", function()
				open("new")
			end)
			button("LOAD CAMPAIGN", function()
				open("load")
			end)
			button("REMOTE MULTIPLAYER", function()
				open("remote")
			end)
			button("SETTINGS", function()
				self:command("settings")
			end)
			button("EXIT", function()
				self:command("exit")
			end)
		elseif menu == "remote" then
			button("HOST GAME", function()
				self:command("remoteHost")
			end)
			button("JOIN GAME", function()
				self:command("remoteJoin")
			end)
			if self.notice ~= "" then
				rows[#rows + 1] = { text = self.notice, color = 8 }
			end
		elseif menu == "overwrite" then
			rows[#rows + 1] =
				{ text = "REPLACE CAMPAIGN IN SLOT " .. tostring(opts.slot) .. "?", color = 8 }
			button("CONFIRM REPLACE", function()
				self:command("newGame", { confirmed = true })
			end)
		else
			rows[#rows + 1] = {
				text = menu == "new" and "CHOOSE A SLOT FOR NEW CAMPAIGN" or "CHOOSE A CAMPAIGN",
				color = 8,
			}
			for i, record in ipairs(opts.slots or {}) do
				local label = "SLOT "
					.. i
					.. (
						record.occupied
							and ((compact and "" or " " .. (record.name or "CAMPAIGN")) .. " R" .. (record.round or 1))
						or " EMPTY"
					)
				button(label, function()
					self:command("selectSlot", { slot = i })
				end, opts.slot == i)
			end
			button(menu == "new" and "CREATE CAMPAIGN" or "LOAD CAMPAIGN", function()
				self:command(menu == "new" and "newGame" or "continue")
			end)
			if menu == "load" then
				button(
					opts.deleteConfirm == opts.slot and "CONFIRM DELETE" or "DELETE SELECTED",
					function()
						self:command("deleteSlot")
					end
				)
			end
		end
		local bw = math.min(w - 12, math.max(100, math.floor(w * 0.72)))
		local by = compact and 12 or math.floor(h * 0.30)
		if menu == "main" then
			by = compact and 12 or by
			local step = math.min(24, math.floor((h - by - 4) / #rows))
			for i, row in ipairs(rows) do
				local action = row.buttons[1]
				r:button(
					math.floor((w - bw) / 2),
					by + (i - 1) * step,
					bw,
					math.max(8, step - 1),
					action.label,
					action.run
				)
			end
		else
			Panels.rows(r, {
				x = math.floor((w - bw) / 2),
				y = by,
				w = bw,
				h = h - by - 16,
			}, rows, self, "titleOffset")
		end
		if menu ~= "main" then
			r:button(math.floor((w - bw) / 2), h - 13, bw, 11, "BACK", function()
				open(menu == "overwrite" and "new" or "main")
			end)
		end
		r:finish()
		return
	end
	if opts.paused then
		r:fill(0, 0, w, h, 0)
		r:text(5, 3, "PAUSED", 8)
		local rows = {}
		for _, action in ipairs({
			{ "RESUME", "resume" },
			{ "SAVE", "save" },
			{ "SETTINGS", "settings" },
			{ "MAIN MENU", "title" },
			{ "EXIT", "exit" },
		}) do
			rows[#rows + 1] = {
				buttons = {
					{
						label = action[1],
						run = function()
							self:command(action[2])
						end,
					},
				},
			}
		end
		Panels.rows(r, { x = 4, y = 14, w = w - 8, h = h - 18 }, rows, self, "menuOffset")
		r:finish()
		return
	end
	if opts.handoff then
		r:fill(0, 0, w, h, 0)
		r:center(6, "PASS THE COMPUTER", 8)
		local active
		for _, p in ipairs(state.players) do
			if p.id == playerID then
				active = p
			end
		end
		r:center(18, clip(active and active.name or "NEXT PLAYER", 18) .. " - YOUR TURN", 7)
		r:center(29, "OTHER PLAYERS: LOOK AWAY", 5)
		r:button(math.max(4, math.floor(w / 2) - 44), h - 16, 88, 12, "READY TO PLAY", function()
			self:command("reveal")
		end, { primary = true })
		r:finish()
		return
	end
	if phase == "lobby" then
		if self.panel == "campaign" then
			CampaignOptions.draw(self, state)
			r:finish()
			return
		end
		if w < 220 or h < 140 then
			r:fill(0, 0, w, h, 0)
			r:text(4, 3, opts.localMode and "LOCAL LOBBY" or "NETWORK LOBBY", 8)
			r:button(w - 35, 1, 32, 11, "BACK", function()
				self:command("title")
			end)
			local rows = {}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "CAMPAIGN OPTIONS",
						run = function()
							self.panel = "campaign"
							self.campaignOffset = 0
						end,
					},
				},
			}
			for i, p in ipairs(state.players) do
				rows[#rows + 1] = { text = i .. ". " .. p.name .. " / " .. Systems.civ(p.civ).name }
				for _, line in
					ipairs(
						Panels.wrap(r, "BONUS: " .. Systems.civ(p.civ, self.state).bonus, w - 20)
					)
				do
					rows[#rows + 1] = { text = line, color = P[i] or 8 }
				end
				if p.ai then
					rows[#rows + 1] = {
						text = "AI " .. Difficulty.id(p):upper() .. " / " .. Personalities
							.forCivilization(p.civ).archetype
							:upper(),
					}
				end
				if opts.localMode or opts.host or p.id == playerID then
					rows[#rows + 1] = {
						buttons = {
							{
								label = p.ai and "AI" or "HUMAN",
								run = function()
									self:command("toggleAI", { player = i })
								end,
							},
							{
								label = "CIV",
								run = function()
									self:command("civ", { player = i })
								end,
							},
						},
					}
					if not opts.localMode then
						table.remove(rows[#rows].buttons, 1)
					end
				end
			end
			rows[#rows + 1] = {
				text = "MAP: "
					.. mapLabel(state)
					.. " / "
					.. (state.mapType or "continents")
					.. " / "
					.. (state.mapWrapX == true and "CYLINDER" or "BOUNDED"),
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "MAP SIZE",
						run = function()
							self:command("mapSize")
						end,
					},
					{
						label = "MAP TYPE",
						run = function()
							self:command("mapType")
						end,
					},
					{
						label = state.mapWrapX == true and "CYLINDER" or "BOUNDED",
						run = function()
							self:command("mapWrapX")
						end,
					},
				},
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "MOBS: " .. (state.hostileMode or "off"):upper(),
						run = function()
							self:command("hostileMode")
						end,
					},
				},
			}
			rows[#rows + 1] = {
				buttons = {
					{
						label = "REROLL SEED",
						run = function()
							self:command("mapSeed")
						end,
					},
				},
			}
			if opts.localMode then
				rows[#rows + 1] = {
					buttons = {
						{
							label = "- PLAYER",
							run = function()
								self:command("removePlayer")
							end,
						},
						{
							label = "+ PLAYER",
							run = function()
								self:command("addPlayer")
							end,
						},
					},
				}
			elseif opts.host then
				rows[#rows + 1] = {
					buttons = {
						{
							label = "+ AI",
							run = function()
								self:command("addAI")
							end,
						},
						{
							label = "- AI",
							run = function()
								self:command("removeAI")
							end,
						},
					},
				}
			end
			rows[#rows + 1] = {
				buttons = {
					{
						label = "START GAME",
						run = function()
							self:command("start")
						end,
						style = { primary = true },
					},
				},
			}
			Panels.rows(r, { x = 4, y = 14, w = w - 8, h = h - 18 }, rows, self, "lobbyOffset")
			if self.civDropdown then
				CivilizationPicker.draw(self, state)
			end
			r:finish()
			return
		end
		r:button(w - 36, 2, 32, 11, "BACK", function()
			self:command("title")
		end)
		r:fill(8, header + 5, w - 16, h - header - 15, 1)
		r:center(
			header + 9,
			"LOCAL HOTSEAT" == (opts.localMode and "LOCAL HOTSEAT" or "ONLINE") and "LOCAL HOTSEAT"
				or "NETWORK LOBBY",
			8
		)
		r:text(16, header + 24, "PLAYERS  " .. #state.players .. "/4", 7)
		for i, p in ipairs(state.players) do
			local row = header + 35 + (i - 1) * 13
			r:fill(16, row, math.min(w - 32, math.max(50, math.floor(w * 0.55))), 11, 2)
			r:fill(16, row, 3, 11, P[i] or 8)
			r:text(
				22,
				row + 2,
				(
					p.ai and "AI " .. Difficulty.id(p):upper() .. " " .. clip(p.name, 7)
					or i .. ". " .. clip(p.name, 9)
				)
					.. " "
					.. clip(Systems.civ(p.civ).name, p.ai and 9 or 17),
				7,
				1,
				122
			)
			if opts.localMode then
				r:button(math.min(w - 56, 150), row, 23, 11, p.ai and "AI" or "HUMAN", function()
					self:command("toggleAI", { player = i })
				end)
			end
			if opts.localMode or opts.host or p.id == playerID then
				r:button(math.min(w - 29, 179), row, 22, 11, "CIV", function()
					self:command("civ", { player = i })
				end)
			end
		end
		r:button(w - 101, header + 10, 85, 11, "CAMPAIGN OPTIONS", function()
			self.panel = "campaign"
			self.campaignOffset = 0
		end)
		r:button(
			w - 101,
			header + 24,
			85,
			11,
			"MOBS " .. (state.hostileMode or "off"):upper(),
			function()
				self:command("hostileMode")
			end
		)
		local y = h - 37
		r:text(
			13,
			y - 27,
			"MAP "
				.. mapLabel(state)
				.. " / "
				.. tostring(state.mapType or "continents"):upper()
				.. " / SEED "
				.. tostring(state.mapSeed or 12345)
				.. " / "
				.. (state.mapWrapX == true and "CYLINDER" or "BOUNDED"),
			8,
			1,
			w - 25
		)
		r:button(12, y - 15, 52, 12, "MAP SIZE", function()
			self:command("mapSize")
		end)
		r:button(68, y - 15, 58, 12, "MAP TYPE", function()
			self:command("mapType")
		end)
		r:button(128, y - 15, 58, 12, "REROLL SEED", function()
			self:command("mapSeed")
		end)
		if opts.localMode then
			r:button(12, y, 40, 15, "- PLAYER", function()
				self:command("removePlayer")
			end)
			r:button(56, y, 40, 15, "+ PLAYER", function()
				self:command("addPlayer")
			end)
		elseif opts.host then
			r:button(12, y, 40, 15, "+ AI", function()
				self:command("addAI")
			end)
			r:button(56, y, 40, 15, "- AI", function()
				self:command("removeAI")
			end)
		else
			r:text(13, y, "HOST ID: " .. tostring(opts.hostID or "?"), 5)
		end
		r:button(math.max(12, w - 90), y, 75, 15, "START GAME", function()
			self:command("start")
		end, { primary = true })
		local choosing = state.players[self.lobbyPlayer or 1] or state.players[1]
		if choosing then
			r:text(
				12,
				h - 15,
				"BONUS: " .. Systems.civ(choosing.civ, self.state).bonus,
				P[self.lobbyPlayer or 1] or 8,
				1,
				w - 24
			)
			r:text(
				12,
				h - 7,
				"AI PERSONALITY: " .. Personalities.forCivilization(choosing.civ).archetype:upper(),
				6,
				1,
				w - 24
			)
		end
		if self.civDropdown then
			CivilizationPicker.draw(self, state)
		end
		r:finish()
		return
	end
	if phase == "over" then
		if h < 180 or w < 220 then
			r:fill(0, 0, w, h, 0)
			r:center(7, "GAME COMPLETE", 8)
			r:center(20, "WINNER " .. clip(state.winner, 18), 7)
			r:center(30, state.victoryReason or "LEGACY VICTORY", 8)
			r:button(math.max(4, math.floor(w / 2) - 40), h - 16, 80, 12, "EXIT", function()
				self:command("exit")
			end)
			r:finish()
			return
		end
		r:center(header + 20, "GAME COMPLETE", 8, 2)
		r:center(header + 46, "WINNER  " .. clip(state.winner, 22), 7)
		r:button(math.max(12, math.floor(w / 2) - 40), h - 32, 80, 15, "EXIT", function()
			self:command("exit")
		end)
		r:finish()
		return
	end
	local mine
	for _, p in ipairs(state.players) do
		if p.id == playerID then
			mine = p
		end
	end
	if opts.report and not (mine and mine.ready) then
		local key = tostring(state.round) .. ":" .. tostring(playerID)
		if self.reportWorld ~= self.worldKey then
			self.reportSeen = {}
			self.reportWorld = self.worldKey
		end
		self.reportSeen = self.reportSeen or {}
		if not self.reportSeen[key] then
			self.reportSeen[key] = true
			self.panel = "report"
			self.reportOffset = 0
		end
	end
	GameView.draw(self, state, mine or { techs = {}, name = "OBSERVER" })

	r:finish()
end
function UI:focus(kind, item)
	self.settlementSuggestionCache = nil
	self.settlementSuggestions = nil
	self.settlementSuggestionDetail = nil
	self.settlementSuggestionTargets = {}
	self.lastUnitTap = nil
	self.unitDetails = false
	self.cityStrikeSource = nil
	self.source = nil
	self.reachable = {}
	self.pendingMove = nil
	self.workCity = nil
	self.panel = "context"
	self.cityPanel = "jobs"
	self.inspectorOffset = 0
	self.selected =
		{ x = item.x, y = item.y, kind = kind, unitID = kind == "unit" and item.id or nil }
	local v = self.mapViewport
	if v then
		local displayX = DisplayGeometry.nearestX(
			item.x,
			(self.panX + v.w / 2) / v.tile + 0.5 - ((item.y - 1) % 2) * 0.5,
			self.state
		)
		local panX = (displayX - 0.5 + ((item.y - 1) % 2) * 0.5) * v.tile - v.w / 2
		self.panX = v.wrapX and ((panX % v.periodX) + v.periodX) % v.periodX
			or math.max(0, math.min(v.maxX, panX))
		self.panY =
			math.max(0, math.min(v.maxY, (item.y - 1) * v.tile * 0.75 + v.tile / 2 - v.h / 2))
	end
	self:feedback(
		(kind == "unit" and item.kind:upper() or item.name or "CITY")
			.. " AT "
			.. item.x
			.. ","
			.. item.y
	)
end
function UI:nextIdle()
	local candidates = {}
	local current
	for _, unit in ipairs(self.state.units or {}) do
		if TurnTasks.idle(self.state, unit, self.playerID) then
			candidates[#candidates + 1] = unit
			if
				not self.selected.empty
				and self.selected.kind == "unit"
				and unit.x == self.selected.x
				and unit.y == self.selected.y
			then
				current = #candidates
			end
		end
	end
	if #candidates == 0 then
		self:feedback("NO AWAKE UNITS WITH MOVEMENT LEFT")
		return false
	end
	self:focus("unit", candidates[(current or 0) % #candidates + 1])
	return true
end
function UI:nextIdleCity()
	local candidates = {}
	local current
	for _, city in ipairs(self.state.cities or {}) do
		if city.owner == self.playerID and not city.project and not city.productionIdle then
			candidates[#candidates + 1] = city
			if
				not self.selected.empty
				and self.selected.kind == "city"
				and self.selected.x == city.x
				and self.selected.y == city.y
			then
				current = #candidates
			end
		end
	end
	if #candidates == 0 then
		self:feedback("ALL CITIES HAVE PRODUCTION")
		return false
	end
	self:focus("city", candidates[(current or 0) % #candidates + 1])
	self.cityPanel = "production"
	return true
end
function UI:openCodex(category, id)
	local entries = dofile("/games/civcraft/encyclopedia.lua").entries(category)
	for _, entry in ipairs(entries) do
		if entry.id == id then
			self.codex = { category = category, entry = entry, offset = 0 }
			self.panel = "encyclopedia"
			return true
		end
	end
	return false
end
function UI:armCityStrike(city)
	self.source = nil
	self.pendingMove = nil
	self.workCity = nil
	self.reachable = {}
	self.cityStrikeSource = { x = city.x, y = city.y }
	local player
	for _, p in ipairs(self.state.players) do
		if p.id == self.playerID then
			player = p
		end
	end
	for _, u in ipairs(self.state.units) do
		if
			u.owner ~= self.playerID
			and Diplomacy.canAttack(self.state, self.playerID, u.owner)
			and Hex.distance(city.x, city.y, u.x, u.y) <= 2
			and (player.visible or {})[u.x .. ":" .. u.y]
		then
			self.reachable[#self.reachable + 1] = { x = u.x, y = u.y, cost = 0, attack = true }
		end
	end
	self:feedback("CHOOSE A RED CROSS FOR CITY STRIKE")
end
function UI:confirmMove()
	local order = self.pendingMove
	if order and order.sitePreview and not Specialty.ready(self, order) then
		self:feedback("Site conditions changed. Review updated details before confirming.")
		return false
	end
	self.pendingMove = nil
	if order and order.placement and order.player == self.playerID then
		local placement = order.placement
		local item = placement.item
		if placement.kind == "specialty" then
			local request = order.siteRequest
			self:command(request.action, request)
			self.siteSource = nil
		elseif placement.kind == "work" then
			self:command("queueWork", {
				unitID = item.id,
				x = item.x,
				y = item.y,
				kind = placement.id,
				tileX = order.x,
				tileY = order.y,
				append = placement.append,
			})
		elseif placement.kind == "wonder" then
			self:command("queue", {
				kind = "wonder",
				id = placement.id,
				cityX = item.x,
				cityY = item.y,
				tileX = order.x,
				tileY = order.y,
			})
		else
			self:command(
				"buildRail",
				{ sx = item.x, sy = item.y, x = order.x, y = order.y, unitID = item.id }
			)
		end
		self.placement = nil
		self.reachable = {}
		return true
	end
	if order and order.city then
		self:command("cityStrike", { x = order.sx, y = order.sy, tx = order.x, ty = order.y })
		self.cityStrikeSource = nil
		self.reachable = {}
		return true
	end
	if not order or order.player ~= self.playerID then
		return false
	end
	local unit = Stacks.at(self.state.units, order.sx, order.sy, order.unitID)
	if unit and unit.owner == self.playerID and unit.id == order.unitID then
		if order.queued then
			self:command("queueMove", {
				sx = order.sx,
				sy = order.sy,
				x = order.x,
				y = order.y,
				unitID = order.unitID,
				append = order.append == true,
			})
			self.source, self.reachable = nil, {}
			return true
		end
		for _, destination in ipairs(Hex.reachable(self.state, unit, self.playerID, Systems)) do
			if destination.x == order.x and destination.y == order.y then
				local request = {
					sx = order.sx,
					sy = order.sy,
					x = order.x,
					y = order.y,
					unitID = order.unitID,
				}
				self:command("move", request)
				self.selected = { x = unit.x, y = unit.y, kind = "unit", unitID = unit.id }
				self.source = nil
				self.reachable = {}
				return true
			end
		end
	end
	self:feedback("Order changed. Select a valid destination again.")
	self.source = nil
	self.reachable = {}
	return false
end
function UI:back()
	if self.civDropdown then
		self.civDropdown = nil
		return true
	end
	if self.panel == "conversation" then
		return Conversation.back(self)
	end
	if self.settingsOpen then
		self.settingsOpen = false
		return true
	end
	if self.placement then
		self.placement = nil
		self.pendingMove = nil
		self.reachable = {}
		return true
	end
	if self.cityStrikeSource then
		self.cityStrikeSource = nil
		self.reachable = {}
		self.pendingMove = nil
		return true
	end
	if self.specialtyCancel then
		self.specialtyCancel = nil
		return true
	end
	if self.disbandConfirm then
		self.disbandConfirm = nil
		return true
	end
	if self.productionConfirm then
		self.productionConfirm = nil
		return true
	end
	if self.endConfirm then
		self.endConfirm = nil
		return true
	end
	if self.pendingMove then
		self.pendingMove = nil
		return true
	end
	if self.panel ~= "context" then
		self.panel = "context"
		self.pointerStart = nil
		self.techDrag = nil
		return true
	end
	if self.source or self.workCity then
		self.source = nil
		self.reachable = {}
		self.workCity = nil
		return true
	end
	if not self.selected.empty then
		self:deselect()
		return true
	end
	return false
end
function UI:zoom(delta)
	if
		self.panel ~= "context"
		or self.productionConfirm
		or self.specialtyCancel
		or self.disbandConfirm
		or self.endConfirm
	then
		return false
	end
	local v = self.mapViewport
	if not v then
		return false
	end
	local size = math.max(8, math.min(48, v.tile + delta * 4))
	local ratio = size / v.tile
	self.panX = ((self.panX or 0) + v.w / 2) * ratio - v.w / 2
	self.panY = ((self.panY or 0) + v.h / 2) * ratio - v.h / 2
	self.zoomLevel = size
	return true
end
function UI:pan(dx, dy)
	if
		self.panel ~= "context"
		or self.productionConfirm
		or self.specialtyCancel
		or self.disbandConfirm
		or self.endConfirm
		or self.inputMode ~= "map"
	then
		return false
	end
	local v = self.mapViewport
	if not v then
		return false
	end
	local panX = (self.panX or 0) + dx
	self.panX = v.wrapX and ((panX % v.periodX) + v.periodX) % v.periodX
		or math.max(0, math.min(v.maxX, panX))
	self.panY = math.max(0, math.min(v.maxY, (self.panY or 0) + dy))
	return true
end
function UI:pointerDown(x, y)
	if self.panel == "conversation" and self.conversationSurface then
		local px, py = self.r:touch(x, y)
		if px then
			self.conversationSurface:mouse("mouse_click", 1, px, py)
		end
		self.conversationPointer = true
		return true
	end
	local rx, ry = self.r:touch(x, y)
	local v = self.mapViewport
	self.pointerStart = nil
	self.pointerDragged = false
	self.blockDrag = true
	self.techDrag = nil
	local model = self.panel == "tech" and self.techModel
	local area = model and model.dragArea
	if
		rx
		and area
		and rx >= area.x
		and rx < area.x + area.w
		and ry >= area.y
		and ry < area.y + area.h
	then
		self.pointerStart = { x = x, y = y }
		self.blockDrag = false
		self.techDrag = {
			x = rx,
			y = ry,
			panX = model.panX or 0,
			panY = model.panY or 0,
			offset = model.offset or 0,
		}
		return true
	end
	if
		rx
		and v
		and self.panel == "context"
		and not self.productionConfirm
		and not self.specialtyCancel
		and not self.disbandConfirm
		and not self.endConfirm
		and rx >= v.x
		and rx < v.x + v.w
		and ry >= v.y
		and ry < v.y + v.h
	then
		self.pointerStart = { x = x, y = y }
		self.lastDrag = { x = rx, y = ry }
		self.blockDrag = false
		return true
	end
	return self:tap(x, y)
end
function UI:pointerUp()
	if self.conversationPointer then
		local s = self.conversationSurface
		if s and s.lastMouse then
			s:mouse("mouse_up", 1, s.lastMouse.x, s.lastMouse.y)
		end
		self.conversationPointer = nil
		return
	end
	local start = self.pointerStart
	if start and not self.pointerDragged then
		self:tap(start.x, start.y)
	end
	self.pointerStart = nil
	self.pointerDragged = false
	self.blockDrag = nil
	self.lastDrag = nil
	self.activeScroll = nil
	self.techDrag = nil
end
function UI:drag(x, y)
	if self.conversationPointer and self.conversationSurface then
		local px, py = self.r:touch(x, y)
		if px then
			self.conversationSurface:mouse("mouse_drag", 1, px, py)
		end
		return true
	end
	local px, py = self.r:touch(x, y)
	if px then
		for _, bar in ipairs(self.r.scrollbars or {}) do
			if
				(
					self.activeScroll
					and self.activeScroll.model == bar.model
					and self.activeScroll.key == bar.key
				)
				or (
					not self.techDrag
					and px >= bar.x
					and px < bar.x + bar.w
					and py >= bar.y
					and py < bar.y + bar.h
				)
			then
				bar.move(px, py)
				self.activeScroll = bar
				self.lastDrag = nil
				return true
			end
		end
	end
	if self.techDrag and self.panel == "tech" and px then
		local drag, model = self.techDrag, self.techModel
		local dx, dy = drag.x - px, drag.y - py
		if math.abs(dx) + math.abs(dy) >= 3 then
			self.pointerDragged = true
		end
		if self.pointerDragged then
			if model.dragMode == "graph" then
				model.panX = math.max(0, math.min(model.maxPanX, drag.panX + dx))
				model.panY = math.max(0, math.min(model.maxPanY, drag.panY + dy))
			else
				model.offset =
					math.max(0, math.min(model.maxPanY, drag.offset + math.floor(dy / 12)))
			end
		end
		return true
	end
	if
		self.blockDrag
		or self.panel ~= "context"
		or self.productionConfirm
		or self.specialtyCancel
		or self.disbandConfirm
		or self.endConfirm
	then
		self.lastDrag = nil
		return false
	end
	local rx, ry = self.r:touch(x, y)
	local v = self.mapViewport
	if not rx or not v or rx < v.x or rx >= v.x + v.w or ry < v.y or ry >= v.y + v.h then
		self.lastDrag = nil
		return false
	end
	if self.lastDrag then
		if rx ~= self.lastDrag.x or ry ~= self.lastDrag.y then
			self.pointerDragged = true
		end
		self:pan(self.lastDrag.x - rx, self.lastDrag.y - ry)
	end
	self.lastDrag = { x = rx, y = ry }
	return true
end
function UI:scroll(delta, x, y)
	if self.specialtyCancel or self.pendingMove and self.pendingMove.sitePreview then
		self.specialtyOffset = math.max(0, (self.specialtyOffset or 0) + delta)
		return true
	end
	if self.panel == "conversation" and self.conversationSurface then
		local px, py = self.r:touch(x, y)
		if px then
			self.conversationSurface:mouse("mouse_scroll", delta, px, py)
		end
		return true
	end
	local px, py = self.r:touch(x, y)
	for _, bar in ipairs(self.r.scrollbars or {}) do
		local area = bar.area
		if
			px
			and px >= area.x
			and px < area.x + area.w
			and py >= area.y
			and py < area.y + area.h
		then
			bar.model[bar.key] = math.max(0, math.min(bar.max, (bar.model[bar.key] or 0) + delta))
			return true
		end
	end
	if
		self.productionConfirm
		or self.specialtyCancel
		or self.pendingMove and self.pendingMove.sitePreview
		or self.disbandConfirm
		or self.endConfirm
		or self.panel ~= "context"
	then
		return false
	end
	local rx, ry = self.r:touch(x, y)
	local v = self.mapViewport
	local inspector = self.inspectorBounds
	if
		rx
		and inspector
		and rx >= inspector.x
		and rx < inspector.x + inspector.w
		and ry >= inspector.y
		and ry < inspector.y + inspector.h
	then
		self.inspectorOffset =
			math.max(0, math.min(self.pageMax or 0, (self.inspectorOffset or 0) + delta))
		return true
	end
	if not v or not rx or rx < v.x or rx >= v.x + v.w or ry < v.y or ry >= v.y + v.h then
		return false
	end
	return self:pan(0, delta * v.tile * 2)
end
function UI:tap(x, y)
	local rx, ry = self.r:touch(x, y)
	if not rx then
		return false
	end
	self.lastDrag = nil
	self.activeScroll = nil
	if self.civDropdown and self.modalBounds then
		local box = self.modalBounds
		if rx < box.x or rx >= box.x + box.w or ry < box.y or ry >= box.y + box.h then
			self.civDropdown = nil
			return true
		end
	end
	-- Modal screens own all input, even outside their visible panel.
	if
		self.modalBounds
		or self.panel ~= "context"
		or self.productionConfirm
		or self.specialtyCancel
		or self.disbandConfirm
		or self.endConfirm
	then
		return self.r:hit(rx, ry)
	end
	if self.r:hit(rx, ry) then
		return true
	end
	local v = self.mapViewport
	if not v or rx < v.x or rx >= v.x + v.w or ry < v.y or ry >= v.y + v.h then
		return false
	end
	if
		not self.source
		and not self.placement
		and not self.pendingMove
		and not self.cityStrikeSource
	then
		for _, target in ipairs(self.settlementSuggestionTargets or {}) do
			if
				self.selected.kind == "unit"
				and target.settlerID == self.selected.unitID
				and rx >= target.x
				and rx < target.x + target.w
				and ry >= target.y
				and ry < target.y + target.h
			then
				self.settlementSuggestionDetail = { x = target.site.x, y = target.site.y }
				self.settlementSuggestionOffset = 0
				self.panel = "settlementSuggestions"
				return true
			end
		end
		for _, badge in ipairs(self.unitBadgeTargets or {}) do
			if
				rx >= badge.x
				and rx < badge.x + badge.w
				and ry >= badge.y
				and ry < badge.y + badge.h
			then
				self:focus("unit", badge.unit)
				return true
			end
		end
		for _, banner in ipairs(self.cityBannerTargets or {}) do
			if
				rx >= banner.x
				and rx < banner.x + banner.w
				and ry >= banner.y
				and ry < banner.y + banner.h
			then
				self:focus("city", banner.city)
				return true
			end
		end
		-- The city banner wins inside its visible rectangle. Outside the
		-- banner, hit the actual rendered unit glyph (no extra bubble).
		-- This retains independent selection of civilian/military stacks and
		-- visible rival units, even when no circular callout is necessary.
		local iconMatches, matchedUnits = {}, {}
		for _, target in ipairs(self.unitIconTargets or {}) do
			if
				rx >= target.x
				and rx < target.x + target.w
				and ry >= target.y
				and ry < target.y + target.h
				and not matchedUnits[target.unit.id]
			then
				matchedUnits[target.unit.id] = true
				local cx = target.glyphX + target.glyphW / 2
				local cy = target.glyphY + target.glyphH / 2
				iconMatches[#iconMatches + 1] = {
					unit = target.unit,
					distance = (rx - cx) ^ 2 + (ry - cy) ^ 2,
				}
			end
		end
		if #iconMatches > 0 then
			-- Larger invisible text-mode touch targets can overlap. Prefer
			-- the closest actual glyph; an already-focused unit stays put on
			-- the first tap, then repeat taps cycle through the same stack.
			table.sort(iconMatches, function(a, b)
				if a.distance == b.distance then
					return a.unit.id < b.unit.id
				end
				return a.distance < b.distance
			end)
			local nextUnit = iconMatches[1].unit
			if #iconMatches > 1 and self.selected.kind == "unit" then
				for index, match in ipairs(iconMatches) do
					if match.unit.id == self.selected.unitID then
						if
							self.lastUnitTap
							and self.lastUnitTap.x == rx
							and self.lastUnitTap.y == ry
							and self.lastUnitTap.unitID == match.unit.id
						then
							nextUnit = iconMatches[index % #iconMatches + 1].unit
						else
							nextUnit = match.unit
						end
						break
					end
				end
			end
			self:focus("unit", nextUnit)
			self.lastUnitTap = { x = rx, y = ry, unitID = nextUnit.id }
			return true
		end
	end
	local best, distance
	for _, hex in ipairs(self.hexTargets or {}) do
		if Hex.contains(hex.x, hex.y, hex.w, rx, ry) then
			local d = (rx - hex.x - hex.w / 2) ^ 2 + (ry - hex.y - hex.h / 2) ^ 2
			if not distance or d < distance then
				best = hex
				distance = d
			end
		end
	end
	if best then
		self:tile(best.tx, best.ty)
		return true
	end
	return false
end
function UI:resize()
	self.r:resize()
end
function UI:animating()
	return self.playback
		and not self.playback.pausedAt
		and (self.playback.active ~= nil or #self.playback.pending > 0)
end
function UI:conversationEvent(event, a, b)
	if self.panel ~= "conversation" or not self.conversationSurface then
		return false
	end
	if event ~= "key" and event ~= "key_up" and event ~= "char" and event ~= "paste" then
		return false
	end
	if event == "key" and a == self.conversationSurface.keys.escape then
		Conversation.back(self)
	else
		self.conversationSurface:key(event, a, b)
	end
	return true
end
function UI:close()
	Conversation.close(self)
	self.r:close()
end
return UI
