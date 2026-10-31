-- Normal-program advisory input scenario; never bypasses a gameplay action.
local Probe = {}
Probe.__index = Probe
function Probe.new()
	return setmetatable(
		{ step = 0, active = false, verified = false, lines = {}, lastLine = 0 },
		Probe
	)
end
local function tap(view, prefix)
	for _, button in ipairs(view.r.buttons or {}) do
		if
			button.label
			and (
				button.label == prefix
				or prefix ~= "SKIP" and button.label:sub(1, #prefix) == prefix
			)
		then
			local x, y = button.x + button.w / 2, button.y + button.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			return math.floor(x), math.floor(y)
		end
	end
end
function Probe:attach(view)
	if self.renderer == view.r then
		return
	end
	self.renderer = view.r
	local original = view.r.text
	view.r.text = function(canvas, x, y, value, ...)
		local rect = view.modalBounds
		self.textCalls = (self.textCalls or 0) + 1
		if self.active then
			self.lastText = {
				value = tostring(value),
				y = y,
				panel = view.panel,
				rectY = rect and rect.y,
				detail = view.settlementSuggestionDetail,
			}
		end
		if
			self.active
			and view.panel == "settlementSuggestions"
			and view.settlementSuggestionDetail
			and rect
			and y >= rect.y + 18
			and value ~= "PREV"
			and value ~= "NEXT"
			and value ~= "SHOW ON MAP"
			and value ~= "BACK TO SITES"
		then
			local index = (view.settlementSuggestionOffset or 0)
				+ math.floor((y - rect.y - 18) / 12)
				+ 1
			self.lines[index] = tostring(value)
			self.lastLine = math.max(self.lastLine, index)
		end
		return original(canvas, x, y, value, ...)
	end
end
function Probe:dispatch()
	assert(not self.active, "Settlement advice dispatched a game order")
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
	assert(settler, "Native advice scenario needs the real opening Settler")
	local traceKey = table.concat(
		{ self.step, view.panel, view.settlementSuggestionOffset or 0, self.lastLine },
		":"
	)
	if traceKey ~= self.traceKey then
		self.traceKey = traceKey
		local labels = {}
		for _, button in ipairs(view.r.buttons or {}) do
			labels[#labels + 1] = button.label
		end
		local file = assert(fs.open("/settlement-advice-progress.log", "a"))
		file.writeLine(textutils.serialize({
			step = self.step,
			panel = view.panel,
			offset = view.settlementSuggestionOffset,
			lines = self.lines,
			lastLine = self.lastLine,
			textCalls = self.textCalls,
			lastText = self.lastText,
			buttons = labels,
		}))
		file.close()
	end
	local function click(prefix)
		local x, y = tap(view, prefix)
		if x then
			queue(x, y)
			return true
		end
		return false
	end
	if self.step == 0 then
		if view:animating() then
			if not click("SKIP") then
				click("CLOSE")
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
	assert(
		settler.id == self.unit.id
			and settler.x == self.unit.x
			and settler.y == self.unit.y
			and settler.movesLeft == self.unit.movesLeft,
		"Advisory input changed the selected Settler"
	)
	assert(
		view.selected.kind == "unit" and view.selected.unitID == settler.id,
		"Advisory input lost Settler selection"
	)
	if self.step == 1 then
		if view.mapViewport.h < 16 and view.mapViewport.tile > 8 then
			if view.panel == "mapTools" then
				if not click("ZOOM OUT") then
					click("NEXT")
				end
			else
				click("MAP TOOLS")
			end
		elseif click("SETTLEMENT SITES ") then
			self.step = 2
		elseif view.panel ~= "inspector" and click("DETAILS") then
			return true
		else
			click("NEXT")
		end
	elseif self.step == 2 then
		assert(
			view.panel == "settlementSuggestions",
			"Advice inspector entry did not open the list"
		)
		self.site =
			assert(view.settlementSuggestions[1], "Opening has no explored legal suggestion")
		if click("SITE 1 ") then
			self.step = 3
		else
			click("NEXT")
		end
	elseif self.step == 3 then
		assert(
			view.settlementSuggestionDetail
				and view.settlementSuggestionDetail.x == self.site.x
				and view.settlementSuggestionDetail.y == self.site.y,
			"Advice detail lost canonical site coordinates"
		)
		local text = {}
		for index = 1, self.lastLine do
			text[#text + 1] = self.lines[index] or ""
		end
		local content = table.concat(text, " "):lower():gsub("%s+", "")
		local function seen(value)
			return content:find(value:lower():gsub("%s+", ""), 1, true) ~= nil
		end
		local complete = seen("food")
			and seen("industry")
			and seen(self.site.reasons[4])
			and seen(self.site.knowledgeNote)
			and seen("Advisory only")
		if self.site.capacity.active then
			complete = complete and seen("BASE") and seen("WATER")
		end
		if #self.site.resources > 0 then
			complete = complete and seen("ADJACENT EXPLORED RESOURCE")
		end
		if #self.site.specialties > 0 then
			complete = complete and seen("POSSIBLE LATER") and seen(self.site.specialties[1].caveat)
		end
		if complete and click("SHOW ON MAP") then
			self.step = 4
		else
			click("NEXT")
		end
	elseif self.step == 4 then
		if self.retrySite then
			if view.panel == "context" then
				if not click("SETTLEMENT SITES ") and not click("DETAILS") then
					click("NEXT")
				end
			elseif view.panel == "inspector" then
				if not click("SETTLEMENT SITES ") then
					click("NEXT")
				end
			elseif view.panel == "settlementSuggestions" then
				if not view.settlementSuggestionDetail then
					if not click("SITE " .. self.retrySite .. " ") then
						click("NEXT")
					end
				elseif click("SHOW ON MAP") then
					self.retrySite = nil
				else
					click("NEXT")
				end
			end
			return true
		end
		assert(view.panel == "context", "Show on Map did not return to map input")
		local target = view.settlementSuggestionTargets and view.settlementSuggestionTargets[1]
		if target then
			self.marker = { x = target.site.x, y = target.site.y }
			local x, y = target.x + target.w / 2, target.y + target.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			queue(math.floor(x), math.floor(y))
			self.step = 5
		else
			self.shownSite = (self.shownSite or 1) + 1
			assert(
				self.shownSite <= #view.settlementSuggestions,
				"No actual native suggestion marker after viewing every ranked site"
			)
			self.retrySite = self.shownSite
			click("DETAILS")
		end
	elseif self.step == 5 then
		assert(
			view.panel == "settlementSuggestions"
				and view.settlementSuggestionDetail
				and view.settlementSuggestionDetail.x == self.marker.x
				and view.settlementSuggestionDetail.y == self.marker.y,
			"Native marker did not open its canonical explanation"
		)
		if click("CLOSE") then
			self.step = 6
		end
	elseif self.step == 6 then
		assert(view.panel == "context")
		self.active, self.verified = false, true
		return false
	end
	return true
end
function Probe:observe(view, options)
	if self.verified and options.handoff then
		assert(
			view.settlementSuggestionCache == nil
				and view.settlementSuggestions == nil
				and view.settlementSuggestionDetail == nil
				and #(view.settlementSuggestionTargets or {}) == 0,
			"Hotseat handoff retained private founding advice"
		)
		self.handoffVerified = true
		if self.record then
			self.record.handoffVerified = true
		end
	end
	if self.verified and view.playerID ~= self.owner and view.settlementSuggestionCache then
		assert(
			view.settlementSuggestionCache.observer == view.playerID,
			"Another observer retained the first player's advice cache"
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
			explanationRows = self.lastLine,
			handoffVerified = self.handoffVerified == true,
		}
	return self.record
end
return Probe
