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
	if self.step == 1 then
		local target = (view.settlementSuggestionTargets or {})[1]
		if not target then
			local site =
				assert((view.settlementSuggestions or {})[1], "An explored recommendation exists")
			self.cameraAttempts = (self.cameraAttempts or 0) + 1
			assert(
				self.cameraAttempts <= 3,
				"Recommendation icon must render when its tile is centered"
			)
			-- Camera-only fixture navigation retains the real selected unit ID.
			view:focus("unit", { id = settler.id, x = site.x, y = site.y })
			os.queueEvent("term_resize")
			return true
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
			siteCount = self.siteCount,
			handoffVerified = self.handoffVerified == true,
		}
	return self.record
end
return Probe
