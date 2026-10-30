-- Actual map-icon input; recommendations never dispatch a gameplay action.
local Probe = {}
Probe.__index = Probe
function Probe.new()
	return setmetatable({ step = 0, active = false, verified = false }, Probe)
end
function Probe:attach() end
function Probe:dispatch()
	assert(not self.active, "Recommendation icon dispatched a game order")
end
function Probe:drive(view, state, queue)
	if self.verified then
		return false
	end
	local settler
	for _, unit in ipairs(state.units or {}) do
		if unit.owner == view.playerID and unit.kind == "settler" then
			settler = unit
			break
		end
	end
	assert(settler, "Native advice needs the real opening Settler")
	if self.step == 0 then
		if view:animating() then
			for _, button in ipairs(view.r.buttons) do
				if button.label == "SKIP" then
					local x, y = button.x + button.w / 2, button.y + button.h / 2
					if view.r.mode == "graphics" then
						x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
					else
						x, y = x / 2 + 1, y / 3 + 1
					end
					queue(math.floor(x), math.floor(y))
					break
				end
			end
			return true
		end
		self.owner = settler.owner
		self.unit = { id = settler.id, x = settler.x, y = settler.y, movesLeft = settler.movesLeft }
		self.active = true
		view:focus("unit", settler)
		self.step = 1
		os.queueEvent("term_resize")
		return true
	end
	if view:animating() then
		local active = self.active
		self.active = false
		view:command("skipPlayback")
		self.active = active
		os.queueEvent("term_resize")
		return true
	end
	assert(view.selected.unitID == self.unit.id, "Icons preserve selected Settler")
	assert(
		settler.x == self.unit.x
			and settler.y == self.unit.y
			and settler.movesLeft == self.unit.movesLeft,
		"Icons do not move or spend the Settler"
	)
	for _, button in ipairs(view.r.buttons) do
		assert(
			not (button.label or ""):find("SETTLEMENT SITES", 1, true),
			"No recommendation menu entry"
		)
	end
	if self.step == 11 then
		assert(
			view.settlementSuggestionCache.signature ~= self.previousSignature,
			"Real exploration changes recommendation inputs"
		)
		assert(
			view.settlementSuggestions ~= self.previousSites,
			"Real exploration recomputes recommendations"
		)
		self.explorationRefreshed = true
		self.step = 1
	end
	if self.step == 1 and not self.explorationChecked then
		self.explorationChecked = true
		local Hex = dofile("/games/civcraft/hex.lua")
		local World = dofile("/games/civcraft/world.lua")
		local Systems = dofile("/games/civcraft/systems.lua")
		local request, best = nil, 0
		for _, unit in ipairs(state.units) do
			if
				unit.owner == self.owner
				and unit.kind == "warrior"
				and (unit.movesLeft or 0) > 0
			then
				for _, choice in ipairs(Hex.reachable(state, unit, self.owner, Systems)) do
					if not choice.attack then
						local unknown = 0
						for _, point in
							ipairs(
								Hex.withinRadius(
									choice.x,
									choice.y,
									(Systems.units[unit.kind] or {}).vision or 2,
									state
								)
							)
						do
							if not state.world.tiles[World.key(point.x, point.y)] then
								unknown = unknown + 1
							end
						end
						if unknown > best then
							best = unknown
							request = {
								unitID = unit.id,
								sx = unit.x,
								sy = unit.y,
								x = choice.x,
								y = choice.y,
							}
						end
					end
				end
			end
		end
		assert(request, "Native exploration scenario needs an ordinary frontier move")
		self.previousSignature = view.settlementSuggestionCache.signature
		self.previousSites = view.settlementSuggestions
		-- This deliberate test move is separate from passive recommendation input.
		self.active = false
		local ok, why = pcall(view.command, view, "move", request)
		self.active = true
		assert(ok, why)
		self.step = 11
		os.queueEvent("term_resize")
		return true
	end
	if self.step == 1 then
		local target = (view.settlementSuggestionTargets or {})[1]
		if not target then
			if view.mapViewport and view.mapViewport.tile < 16 then
				view:zoom(math.ceil((16 - view.mapViewport.tile) / 4))
				os.queueEvent("term_resize")
				return true
			end
			local sites = view.settlementSuggestions or {}
			assert(#sites > 0, "An explored recommendation exists")
			local site = sites[((self.cameraAttempts or 0) % #sites) + 1]
			self.cameraAttempts = (self.cameraAttempts or 0) + 1
			assert(
				self.cameraAttempts <= math.max(3, #(view.settlementSuggestions or {}) * 2),
				"Recommendation icon must render when centered: "
					.. textutils.serialize({
						viewport = view.mapViewport,
						sites = view.settlementSuggestions,
						source = view.source ~= nil,
						pending = view.pendingMove ~= nil,
					})
			)
			-- Camera-only fixture navigation retains the real selected unit ID.
			view:focus("unit", { id = settler.id, kind = settler.kind, x = site.x, y = site.y })
			os.queueEvent("term_resize")
			return true
		end
		if view.r.mode == "graphics" and view.r.frameRows then
			local rows, palette = {}, {}
			for y = 1, view.r.h do
				rows[y] = table.concat(view.r.frameRows[y])
				if y % 32 == 0 then
					view.r:cooperate()
				end
			end
			for index = 0, 255 do
				palette[index + 1] = view.r.palette[index] or 0
			end
			local f = assert(fs.open("/settlement-icons-canvas.json", "w"))
			f.write(textutils.serializeJSON({
				rows = rows,
				palette = palette,
				width = view.r.w,
				height = view.r.h,
				marker = { x = target.x, y = target.y, w = target.w, h = target.h },
			}))
			f.close()
		end
		self.marker = { x = target.site.x, y = target.site.y }
		self.siteCount = #view.settlementSuggestions
		self.panel = view.panel
		local x, y = target.x + target.w / 2, target.y + target.h / 2
		if view.r.mode == "graphics" then
			x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
		else
			x, y = x / 2 + 1, y / 3 + 1
		end
		queue(math.floor(x), math.floor(y))
		self.step = 2
		return true
	end
	assert(
		view.panel == self.panel and view.panel ~= "settlementSuggestions",
		"Clicking a recommendation opens no menu"
	)
	self.active, self.verified = false, true
	return false
end
function Probe:observe(view, options)
	if self.verified and options.handoff then
		assert(
			view.settlementSuggestionCache == nil
				and view.settlementSuggestions == nil
				and #(view.settlementSuggestionTargets or {}) == 0,
			"Handoff clears private recommendations"
		)
		self.handoffVerified = true
		if self.record then
			self.record.handoffVerified = true
		end
	end
	if self.verified and view.playerID ~= self.owner and view.settlementSuggestionCache then
		assert(
			view.settlementSuggestionCache.observer == view.playerID,
			"Advice cache belongs to current observer"
		)
	end
end
function Probe:evidence()
	self.record = self.record
		or {
			verified = self.verified,
			marker = self.marker,
			settlerID = self.unit.id,
			sentGameOrders = 0,
			iconsOnly = true,
			explorationRefreshed = self.explorationRefreshed == true,
			manualExplorationOrders = 1,
			siteCount = self.siteCount,
			handoffVerified = self.handoffVerified == true,
		}
	return self.record
end
return Probe
