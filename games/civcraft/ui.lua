-- CIVCRAFT local/network UI built on the RAILBREAK pixel canvas.
-- Never mutate simulation here: all commands flow through dispatch().
local Combat = dofile("/games/civcraft/combat.lua")
local GameView = dofile("/games/civcraft/game_view.lua")
local Hex = dofile("/games/civcraft/hex.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local Renderer = dofile("/games/civcraft/render.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local World = dofile("/games/civcraft/world.lua")
local UI = {}
UI.__index = UI
local function mapLabel(state)
	local size = state.mapSize or "standard"
	local dims = World.sizes[size] or World.sizes.standard
	return size:upper() .. " " .. dims[1] .. "X" .. dims[2]
end
local P = { 8, 13, 11, 21 }
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
function UI.new(m, dispatch)
	local self = setmetatable({
		r = Renderer.new(m),
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
			self.productionConfirm =
				{ params = params, previous = current.id, progress = current.progress or 0 }
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
function UI:endWarnings()
	local warnings = {}
	local state = self.state
	if not state then
		return warnings
	end
	for _, u in ipairs(state.units or {}) do
		if
			u.owner == self.playerID
			and not u.standby
			and not u.autoExplore
			and (u.movesLeft or (u.moved and 0 or 1)) > 0
		then
			warnings[#warnings + 1] = {
				text = u.kind .. " at " .. u.x .. "," .. u.y .. " has moves left.",
				kind = "unit",
				item = u,
			}
		end
	end
	for _, c in ipairs(state.cities or {}) do
		if c.owner == self.playerID and not c.project and not c.productionIdle then
			warnings[#warnings + 1] = {
				text = (c.name or ("City " .. c.x .. "," .. c.y)) .. " has no production.",
				kind = "city",
				item = c,
			}
		end
	end
	for _, p in ipairs(state.players or {}) do
		if p.id == self.playerID and not p.researchTarget then
			for id in pairs(Systems.techs) do
				if Systems.canResearch(p, id) then
					warnings[#warnings + 1] = { text = "No research selected.", kind = "research" }
					break
				end
			end
		end
	end
	return warnings
end
function UI:deselect()
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
	if kind == "wonder" then
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
function UI:tile(x, y)
	if self.placement and not self.pendingMove then
		for _, t in ipairs(self.reachable or {}) do
			if t.x == x and t.y == y then
				self.pendingMove = {
					placement = self.placement,
					x = x,
					y = y,
					cost = t.cost,
					player = self.playerID,
				}
				self:feedback("CLICK HEX AGAIN OR CONFIRM TO BUILD")
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
		self.cityPanel = "jobs"
	end
	if self.source and not (x == self.source.x and y == self.source.y) then
		for _, p in ipairs(self.reachable or {}) do
			if p.x == x and p.y == y then
				local unit = where(self.state.units, self.source.x, self.source.y)
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
				local summary = "COST " .. p.cost
				if forecast then
					summary = "HP "
						.. forecast.attackerHP
						.. " / TARGET "
						.. (forecast.defenderHP or forecast.cityHP)
						.. (forecast.wallHP and (" / WALL " .. forecast.wallHP) or "")
						.. (forecast.captured and " CAPTURE" or "")
				end
				self.moveOffset = 0
				self.lastDrag = nil
				self:feedback(summary .. " - CONFIRM")
				return
			end
		end
	end
	self.source = nil
	self.reachable = {}
	self.pendingMove = nil
	self.inspectorOffset = 0
	if self.selected.x == x and self.selected.y == y and not self.selected.empty then
		self:deselect()
		return
	end
	local unit = where(self.state.units, x, y)
	self.selected = {
		x = x,
		y = y,
		kind = unit and unit.owner == self.playerID and "unit" or "city",
		unitID = unit and unit.id,
	}
	self.panel = "context"
	self.cityPanel = "jobs"
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
	}, ":")
	if not state or state.phase ~= "game" then
		self.worldReady = false
		self.reportSeen = {}
	end
	-- Never carry a previous hotseat player's selection or movement overlay
	-- into the next player's screen (including the concealed handoff).
	if self.lastPlayer ~= nil and self.lastPlayer ~= playerID then
		self.source = nil
		self.reachable = {}
		self.pendingMove = nil
		self.cityStrikeSource = nil
		self.productionConfirm = nil
		self.disbandConfirm = nil
		self.endConfirm = nil
		self.panel = "context"
		self.placement = nil
		self.actionPage = 1
		self.techModel = nil
		self.workCity = nil
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
	if self.selected.kind == "unit" and self.selected.unitID then
		for _, u in ipairs(state.units or {}) do
			if u.id == self.selected.unitID and u.owner == playerID then
				self.selected.x = u.x
				self.selected.y = u.y
				break
			end
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
						and not u.moved
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
		self.placement = nil
		self.reachable = {}
		self.pendingMove = nil
		self.productionConfirm = nil
		self.disbandConfirm = nil
		self.endConfirm = nil
		self.lastDrag = nil
	end
	r:begin()
	self.hexTargets = {}
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
	if opts.screen == "title" then
		r:fill(0, 0, w, h, 0)
		if h < 180 or w < 220 then
			r:center(3, "CIVCRAFT", 8, 1)
			r:center(11, "SELECT A SAVE SLOT", 6)
			if opts.slots then
				local size = math.floor((w - 8) / 3)
				for i, record in ipairs(opts.slots) do
					local label = "SLOT "
						.. i
						.. (record.occupied and " R" .. (record.round or 1) or " FREE")
					r:button(3 + (i - 1) * size, 16, size - 2, 10, label, function()
						self:command("selectSlot", { slot = i })
					end, { primary = opts.slot == i })
				end
			end
			local by = math.max(26, h - 31)
			local bx, bw = math.max(4, math.floor(w * 0.12)), math.max(33, math.floor(w * 0.76))
			r:button(bx, by, bw, 10, "NEW CAMPAIGN", function()
				self:command("newGame")
			end, { primary = true })
			r:button(bx, by + 10, bw, 10, "CONTINUE", function()
				self:command("continue")
			end)
			r:button(bx, by + 20, bw, 10, "EXIT", function()
				self:command("exit")
			end)
			r:finish()
			return
		end
		r:center(math.floor(h * 0.10), "CIVCRAFT", 8, w >= 155 and 3 or 2)
		r:center(math.floor(h * 0.23), "HEX EMPIRES / EXPLORE / CONQUER", 7)
		local bw = math.min(w - 20, math.max(100, math.floor(w * 0.72)))
		local bx = math.floor((w - bw) / 2)
		if opts.slots then
			local sy = math.floor(h * 0.32)
			for i, record in ipairs(opts.slots) do
				local active = i == opts.slot
				local title = record.occupied
						and ("SLOT " .. i .. "  " .. (record.name or "CAMPAIGN") .. "  R" .. (record.round or 1))
					or ("SLOT " .. i .. "  EMPTY")
				r:button(bx, sy + (i - 1) * 21, bw - 35, 17, title, function()
					self:command("selectSlot", { slot = i })
				end, { primary = active })
			end
			r:button(
				bx + bw - 31,
				sy,
				31,
				17,
				opts.deleteConfirm == opts.slot and "SURE?" or "DELETE",
				function()
					self:command("deleteSlot")
				end
			)
		end
		local by = math.min(h - 53, math.max(math.floor(h * 0.55), math.floor(h * 0.32) + 65))
		r:button(bx, by, bw, 16, "NEW CAMPAIGN", function()
			self:command("newGame")
		end, { primary = true })
		r:button(
			bx,
			by + 19,
			bw,
			16,
			opts.hasSave and "CONTINUE CAMPAIGN" or "NO SAVED CAMPAIGN",
			function()
				self:command("continue")
			end
		)
		r:button(bx, by + 38, bw, 14, "EXIT", function()
			self:command("exit")
		end)
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
			{ opts.audio == false and "AUDIO OFF" or "AUDIO ON", "audio" },
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
		if w < 220 or h < 140 then
			r:fill(0, 0, w, h, 0)
			r:text(4, 3, opts.localMode and "LOCAL LOBBY" or "NETWORK LOBBY", 8)
			local rows = {}
			for i, p in ipairs(state.players) do
				rows[#rows + 1] = { text = i .. ". " .. p.name .. " / " .. Systems.civ(p.civ).name }
				if opts.localMode then
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
				end
			end
			rows[#rows + 1] =
				{ text = "MAP: " .. mapLabel(state) .. " / " .. (state.mapType or "continents") }
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
			r:finish()
			return
		end
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
				i .. ". " .. clip(p.name, 9) .. " " .. clip(Systems.civ(p.civ).name, 17),
				7
			)
			if opts.localMode then
				r:button(math.min(w - 56, 150), row, 23, 11, p.ai and "AI" or "HUMAN", function()
					self:command("toggleAI", { player = i })
				end)
				r:button(math.min(w - 29, 179), row, 22, 11, "CIV", function()
					self:command("civ", { player = i })
				end)
			end
		end
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
				.. tostring(state.mapSeed or 12345),
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
		else
			r:text(13, y, "HOST ID: " .. tostring(opts.hostID or "?"), 5)
		end
		r:button(math.max(12, w - 90), y, 75, 15, "START GAME", function()
			self:command("start")
		end, { primary = true })
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
		self.panX = math.max(
			0,
			math.min(v.maxX, (item.x - 0.5 + ((item.y - 1) % 2) * 0.5) * v.tile - v.w / 2)
		)
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
		if
			unit.owner == self.playerID
			and not unit.standby
			and (unit.movesLeft or (unit.moved and 0 or 1)) > 0
		then
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
	self.pendingMove = nil
	if order and order.placement and order.player == self.playerID then
		local placement = order.placement
		local item = placement.item
		if placement.kind == "wonder" then
			self:command("queue", {
				kind = "wonder",
				id = placement.id,
				cityX = item.x,
				cityY = item.y,
				tileX = order.x,
				tileY = order.y,
			})
		else
			self:command("buildRail", { sx = item.x, sy = item.y, x = order.x, y = order.y })
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
	local unit = where(self.state.units, order.sx, order.sy)
	if unit and unit.owner == self.playerID and unit.id == order.unitID then
		for _, destination in ipairs(Hex.reachable(self.state, unit, self.playerID, Systems)) do
			if destination.x == order.x and destination.y == order.y then
				self:command("move", { sx = order.sx, sy = order.sy, x = order.x, y = order.y })
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
	self.panX = math.max(0, math.min(v.maxX, (self.panX or 0) + dx))
	self.panY = math.max(0, math.min(v.maxY, (self.panY or 0) + dy))
	return true
end
function UI:pointerDown(x, y)
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
	-- Modal screens own all input, even outside their visible panel.
	if
		self.modalBounds
		or self.panel ~= "context"
		or self.productionConfirm
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
function UI:close()
	self.r:close()
end
return UI
