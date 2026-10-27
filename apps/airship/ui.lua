-- FPBCRAFT Airship Navigation / Basalt 2.5 touchscreen.
-- UI owns no propulsion timers. Flight is controlled by autopilot.lua.
local UI = {}
local C = colors
local function short(s, n)
	s = tostring(s or "")
	if #s > n then
		return s:sub(1, math.max(1, n - 1)) .. "~"
	end
	return s
end
local function num(n, precision)
	if type(n) ~= "number" then
		return "--"
	end
	return string.format("%." .. (precision or 0) .. "f", n)
end
function UI.run(api)
	local basalt = require("basalt")
	local terminal = basalt.getMainFrame()
	local root = terminal
	terminal.background = C.black
	if api.monitor then
		root = basalt.createFrame(api.monitor, api.monitorName)
		root.background = C.black
		terminal:addLabel({
			x = 2,
			y = 2,
			text = "FPBCRAFT / AIRSHIP NAVIGATION",
			foreground = C.cyan,
		})
		terminal:addLabel({
			x = 2,
			y = 4,
			text = "Cockpit console on attached monitor",
			foreground = C.lightGray,
		})
	end
	local w, h = (api.monitor or term).getSize()
	if w < 32 or h < 16 then
		error("Airship UI needs at least 32x16 characters; use monitor scale 0.5")
	end
	local page = "FLIGHT"
	local panel = nil
	local selectedRoute = 1
	local selectedPreset = 1
	local routeScroll = 1
	local presetScroll = 1
	local message = ""
	local edit =
		{ kind = "direct", values = { "", "", "" }, field = 1, back = "FLIGHT", index = nil }
	local confirm = nil
	local keyPage = 1
	local render
	local keyboardPanel = nil
	local keyboardInputs = {}
	local monitorValueLabels = {}
	local editorSession = 0
	local keyboardSession = -1
	local function setEditValue(i, value)
		edit.values[i] = tostring(value or ""):sub(1, 80)
		if monitorValueLabels[i] then
			monitorValueLabels[i].text =
				short(edit.values[i], math.max(4, math.floor((w - 4) / 3) - 2))
		end
	end
	local function parseCoordinatePair(value)
		local normalized =
			tostring(value or ""):gsub("[Xx]%s*[:=]%s*", ""):gsub("[Zz]%s*[:=]%s*", " ")
		local x, z = normalized:match("^%s*([+-]?%d+%.?%d*)%s*[,;%s]+%s*([+-]?%d+%.?%d*)%s*$")
		if x and z and tonumber(x) and tonumber(z) then
			return x, z
		end
	end
	local function label(parent, x, y, s, color, width)
		if y < 1 or y > h - 2 or x > w then
			return
		end
		return parent:addLabel({
			x = x,
			y = y,
			width = math.max(1, math.min(width or w - x, w - x + 1)),
			text = short(s, math.max(1, math.min(width or w - x, w - x + 1))),
			foreground = color or C.white,
		})
	end
	local function btn(parent, x, y, bw, bh, text, action, color)
		if bw < 3 or x < 1 or y < 1 or x + bw - 1 > w or y + bh - 1 > h - 2 then
			return
		end
		local b = parent:addButton({
			x = x,
			y = y,
			width = bw,
			height = bh,
			text = short(text, bw - 1),
			background = color or C.blue,
			foreground = C.white,
		})
		b:onClick(function()
			local ok, err = pcall(action)
			if not ok then
				message = "UI ERROR: " .. tostring(err)
			end
			render()
		end)
		return b
	end
	local function action(func, ...)
		local ok, why = func(...)
		if ok == false then
			message = tostring(why or "Cannot complete action")
		end
		if type(ok) == "string" then
			message = ok
		end
		return ok ~= false
	end
	local function navigate(name)
		page = name
		render()
	end
	local function countRows()
		return math.max(2, math.floor((h - 12) / 2))
	end
	local function editor(kind, index, back)
		local p
		if kind == "routeEdit" then
			p = api.snapshot().route[index]
		elseif kind == "presetEdit" then
			p = api.snapshot().presets[index]
		end
		edit = {
			kind = kind,
			index = index,
			field = 1,
			back = back or page,
			values = { p and tostring(p.x) or "", p and tostring(p.z) or "", p and p.name or "" },
		}
		keyPage = 1
		editorSession = editorSession + 1
		page = "EDITOR"
		render()
	end
	local function submit()
		local x, z = tonumber(edit.values[1]), tonumber(edit.values[2])
		if not x or not z or math.abs(x) >= 30000000 or math.abs(z) >= 30000000 then
			message = "Enter valid X and Z coordinates"
			return
		end
		local name = edit.values[3] or ""
		local result, reason
		if edit.kind == "direct" then
			result, reason = api.fly(x, z, name)
		elseif edit.kind == "routeAdd" then
			result, reason = api.addRoute(x, z, name, selectedRoute)
		elseif edit.kind == "routeEdit" then
			result, reason = api.editRoute(edit.index, x, z, name)
		elseif edit.kind == "presetAdd" then
			result, reason = api.addPreset(x, z, name)
		elseif edit.kind == "presetEdit" then
			result, reason = api.editPreset(edit.index, x, z, name)
		end
		if result == false then
			message = tostring(reason)
			return
		end
		page = edit.kind == "direct" and "FLIGHT" or edit.back
		message = "Coordinates saved"
	end
	local function ask(title, callback)
		confirm = { title = title, callback = callback, back = page }
		page = "CONFIRM"
	end
	local function showFlight(s)
		local p = s.position
		local active = s.mode == "map"
			or s.mode == "direct"
			or s.mode == "route"
			or s.mode == "calibration"
		local modeTitle = s.mode:upper()
		if s.mode == "route" then
			modeTitle = modeTitle
				.. " "
				.. s.routeIndex
				.. "/"
				.. #s.route
				.. (s.routeLoop and " / LOOP" or "")
		end
		label(panel, 3, 4, "NAVIGATION / " .. modeTitle, active and C.lime or C.orange)
		local compact = h < 21
		if p then
			label(
				panel,
				3,
				compact and 5 or 6,
				"POSITION  X " .. num(p.x) .. "  Z " .. num(p.z),
				C.cyan
			)
			if not compact then
				label(panel, 3, 7, "WORLD Y   " .. num(p.y), C.lightGray)
			end
		else
			label(panel, 3, compact and 5 or 6, "POSITION  Waiting for Avionics...", C.orange)
		end
		local t = s.target
		local targetY = compact and 6 or 9
		label(panel, 3, targetY, "DEST  " .. short(s.label or "No destination", w - 12), C.yellow)
		if t then
			label(
				panel,
				3,
				targetY + 1,
				"X " .. num(t.x) .. "  Z " .. num(t.z) .. "  D " .. num(s.distance),
				C.white
			)
			label(
				panel,
				3,
				targetY + 2,
				"ERROR " .. num(s.error, 1) .. "  SPEED " .. num(s.speed, 1),
				C.white
			)
		else
			label(panel, 3, targetY + 1, "Choose coordinates, map or route", C.lightGray)
		end
		label(
			panel,
			3,
			h - 7,
			"THRUST F"
				.. (s.outputs.forward or 0)
				.. " B"
				.. (s.outputs.reverse or 0)
				.. "  STEER L"
				.. (s.outputs.left or 0)
				.. " R"
				.. (s.outputs.right or 0),
			C.cyan
		)
		local cell = math.floor((w - 6) / 2)
		btn(panel, 2, h - 6, cell, 2, "FLY TO X/Z", function()
			editor("direct", nil, "FLIGHT")
		end, C.blue)
		btn(panel, 3 + cell, h - 6, cell, 2, "MAP TARGET", function()
			action(api.flyMap)
		end, C.blue)
		btn(panel, 2, h - 3, cell, 1, "SAVED ROUTES", function()
			navigate("ROUTE")
		end, C.gray)
		btn(panel, 3 + cell, h - 3, cell, 1, "PRESETS", function()
			navigate("PRESETS")
		end, C.gray)
		btn(panel, w - 12, 3, 11, 1, "STOP NOW", function()
			action(api.stop)
		end, C.red)
	end
	local function showList(s, isRoute)
		local items = isRoute and s.route or s.presets
		local sel = isRoute and selectedRoute or selectedPreset
		local offset = isRoute and routeScroll or presetScroll
		local rows = countRows()
		offset = math.max(1, math.min(offset, math.max(1, #items - rows + 1)))
		if isRoute then
			routeScroll = offset
		else
			presetScroll = offset
		end
		label(
			panel,
			2,
			4,
			isRoute and ("ROUTE / NEXT " .. s.routeNext .. " OF " .. #items)
				or ("PRESETS / " .. #items .. " SAVED"),
			C.cyan
		)
		if #items == 0 then
			label(panel, 3, 6, "No waypoints yet. Use + ADD.", C.lightGray)
		end
		for row = 1, rows do
			local i = offset + row - 1
			local item = items[i]
			if not item then
				break
			end
			local y = 5 + (row - 1) * 2
			local mark = (isRoute and i == s.routeNext) and "*" or " "
			local caption = ("%s%02d %s [%.0f,%.0f]"):format(
				mark,
				i,
				item.name ~= "" and item.name or "Waypoint",
				item.x,
				item.z
			)
			btn(panel, 2, y, w - 12, 1, caption, function()
				if isRoute then
					selectedRoute = i
				else
					selectedPreset = i
				end
			end, sel == i and C.blue or C.gray)
		end
		btn(panel, w - 9, 5, 8, 2, "UP", function()
			if isRoute then
				selectedRoute = math.max(1, selectedRoute - 1)
				routeScroll = math.min(routeScroll, selectedRoute)
			else
				selectedPreset = math.max(1, selectedPreset - 1)
				presetScroll = math.min(presetScroll, selectedPreset)
			end
		end, C.gray)
		btn(panel, w - 9, 8, 8, 2, "DOWN", function()
			if isRoute then
				selectedRoute = math.min(#items, selectedRoute + 1)
				routeScroll = math.max(routeScroll, selectedRoute - rows + 1)
			else
				selectedPreset = math.min(#items, selectedPreset + 1)
				presetScroll = math.max(presetScroll, selectedPreset - rows + 1)
			end
		end, C.gray)
		local bw = math.floor((w - 6) / 3)
		btn(panel, 2, h - 6, bw, 1, "+ ADD", function()
			editor(isRoute and "routeAdd" or "presetAdd", nil, page)
		end, C.blue)
		btn(panel, 3 + bw, h - 6, bw, 1, "EDIT", function()
			if items[sel] then
				editor(isRoute and "routeEdit" or "presetEdit", sel, page)
			end
		end, C.gray)
		btn(panel, 4 + bw * 2, h - 6, bw, 1, "DELETE", function()
			if items[sel] then
				ask("Delete selected waypoint?", function()
					action(isRoute and api.removeRoute or api.removePreset, sel)
				end)
			end
		end, C.red)
		if isRoute then
			btn(
				panel,
				2,
				h - 3,
				w - 3,
				1,
				s.routeLoop and "LOOP ROUTE: ON - REPEAT FROM FIRST"
					or "LOOP ROUTE: OFF - STOP AT END",
				function()
					action(api.setRouteLoop, not s.routeLoop)
				end,
				s.routeLoop and C.lime or C.gray
			)
			btn(panel, 2, h - 4, bw, 1, "RESUME", function()
				if action(api.resumeRoute) then
					page = "FLIGHT"
				end
			end, C.lime)
			btn(panel, 3 + bw, h - 4, bw, 1, "FROM SELECT", function()
				if action(api.flyRouteFrom, selectedRoute) then
					page = "FLIGHT"
				end
			end, C.orange)
			btn(panel, 4 + bw * 2, h - 4, bw, 1, "REORDER", function()
				navigate("REORDER")
			end, C.gray)
		else
			btn(panel, 2, h - 4, bw, 1, "FLY HERE", function()
				if action(api.flyPreset, selectedPreset) then
					page = "FLIGHT"
				end
			end, C.lime)
			btn(panel, 3 + bw, h - 4, bw, 1, "TO ROUTE", function()
				action(api.presetToRoute, selectedPreset)
			end, C.orange)
			btn(panel, 4 + bw * 2, h - 4, bw, 1, "SAVE HERE", function()
				action(api.capturePreset)
			end, C.blue)
		end
	end
	local function showReorder(s)
		label(panel, 3, 4, "REORDER / SELECTED STOP " .. selectedRoute, C.cyan)
		local p = s.route[selectedRoute]
		label(
			panel,
			3,
			7,
			p and (p.name .. "  X" .. num(p.x) .. " Z" .. num(p.z)) or "Select a route stop",
			C.white
		)
		btn(panel, 3, 10, 13, 2, "MOVE UP", function()
			selectedRoute = api.moveRoute(selectedRoute, -1) or selectedRoute
		end, C.blue)
		btn(panel, 18, 10, 13, 2, "MOVE DOWN", function()
			selectedRoute = api.moveRoute(selectedRoute, 1) or selectedRoute
		end, C.blue)
		btn(panel, 3, 14, 18, 1, "BACK TO ROUTE", function()
			navigate("ROUTE")
		end, C.gray)
	end
	local function showEditor()
		label(panel, 2, 4, "DESTINATION / " .. edit.kind:upper() .. "  (TYPE ON COMPUTER)", C.cyan)
		local names = { "X COORD", "Z COORD", "NAME" }
		local bw = math.floor((w - 4) / 3)
		monitorValueLabels = {}
		for i = 1, 3 do
			btn(panel, 2 + (i - 1) * bw, 6, bw - 1, 1, names[i], function()
				edit.field = i
				keyPage = 1
				if keyboardInputs[i] then
					keyboardInputs[i]:focus()
				end
			end, edit.field == i and C.blue or C.gray)
			-- The physical keyboard is routed to the computer, not the monitor.
			-- On a computer-only setup, use native Input elements right here.
			if not api.monitor then
				local idx = i
				local input = panel:addInput({
					x = 2 + (i - 1) * bw,
					y = 7,
					width = bw - 1,
					text = edit.values[idx],
					maxLength = 80,
					background = C.lightGray,
					foreground = C.black,
				})
				keyboardInputs[idx] = input
				input:onChange(function(self)
					local raw = self.text
					local a, b
					if idx ~= 3 then
						a, b = parseCoordinatePair(raw)
					end
					if a and b then
						setEditValue(1, a)
						setEditValue(2, b)
						self.text = edit.values[idx]
						if keyboardInputs[3 - idx] then
							keyboardInputs[3 - idx].text = edit.values[3 - idx]
						end
					else
						setEditValue(idx, raw)
					end
				end)
				input:onEnter(function()
					if idx < 3 then
						keyboardInputs[idx + 1]:focus()
					else
						submit()
						render()
					end
				end)
			else
				monitorValueLabels[i] = label(
					panel,
					2 + (i - 1) * bw,
					7,
					short(edit.values[i], bw - 2),
					C.white,
					bw - 1
				)
			end
		end
		local characters = edit.field == 3 and "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_"
			or "7894561230-."
		local cols = edit.field == 3 and math.min(8, math.floor((w - 4) / 4)) or 4
		local cw = math.max(4, math.floor((w - 4) / cols))
		local keyRows = math.min(math.ceil(#characters / cols), math.max(1, h - 14))
		local perPage = cols * keyRows
		local pages = math.max(1, math.ceil(#characters / perPage))
		keyPage = math.min(keyPage, pages)
		for pos = 1, perPage do
			local i = (keyPage - 1) * perPage + pos
			if i > #characters then
				break
			end
			local x = 2 + ((pos - 1) % cols) * cw
			local y = 9 + math.floor((pos - 1) / cols)
			local ch = characters:sub(i, i)
			btn(panel, x, y, cw - 1, 1, ch == " " and "SPACE" or ch, function()
				if #edit.values[edit.field] < 80 then
					setEditValue(edit.field, edit.values[edit.field] .. ch)
				end
			end, C.gray)
		end
		if pages > 1 then
			if keyPage > 1 then
				btn(panel, 2, h - 5, 10, 1, "< KEYS", function()
					keyPage = keyPage - 1
				end)
			end
			if keyPage < pages then
				btn(panel, w - 12, h - 5, 10, 1, "KEYS >", function()
					keyPage = keyPage + 1
				end)
			end
		end
		local y = h - 4
		btn(panel, 2, y, math.max(7, math.floor((w - 6) / 3)), 1, "BACKSPACE", function()
			setEditValue(edit.field, edit.values[edit.field]:sub(1, -2))
		end, C.orange)
		btn(
			panel,
			3 + math.floor((w - 6) / 3),
			y,
			math.max(5, math.floor((w - 6) / 3)),
			1,
			"CLEAR",
			function()
				setEditValue(edit.field, "")
			end,
			C.red
		)
		btn(panel, 2, h - 3, math.floor((w - 4) / 2), 1, "CANCEL", function()
			navigate(edit.back)
		end, C.gray)
		btn(
			panel,
			3 + math.floor((w - 4) / 2),
			h - 3,
			math.floor((w - 4) / 2),
			1,
			"SAVE / FLY",
			function()
				submit()
			end,
			C.lime
		)
	end
	-- Basalt dispatches keyboard/paste events only to its main computer root.
	-- A monitor is touch-only, so create synchronized native Inputs on the
	-- computer while the monitor retains the large, touch-friendly keypad.
	local function updateKeyboardPanel()
		if not api.monitor then
			return
		end
		if page ~= "EDITOR" then
			if keyboardPanel then
				keyboardPanel:destroy()
				keyboardPanel = nil
			end
			keyboardInputs = {}
			keyboardSession = -1
			return
		end
		if keyboardPanel and keyboardSession == editorSession then
			for i = 1, 3 do
				if keyboardInputs[i] and keyboardInputs[i].text ~= edit.values[i] then
					keyboardInputs[i].text = edit.values[i]
				end
			end
			return
		end
		if keyboardPanel then
			keyboardPanel:destroy()
		end
		local tw, th = term.getSize()
		keyboardPanel =
			terminal:addFrame({ x = 1, y = 1, width = tw, height = th, background = C.black })
		keyboardSession = editorSession
		keyboardInputs = {}
		label(keyboardPanel, 2, 2, "SKYWAYS / KEYBOARD ENTRY", C.cyan, tw - 3)
		label(keyboardPanel, 2, 3, "Type or Ctrl+V paste values below.", C.lightGray, tw - 3)
		label(keyboardPanel, 2, 4, "You can paste 'X Z' together into X.", C.lightGray, tw - 3)
		local titles = { "X", "Z", "NAME" }
		for i = 1, 3 do
			local idx = i
			local y = 5 + (i - 1) * 3
			if y <= th - 2 then
				label(keyboardPanel, 2, y, titles[i], C.yellow, 8)
				local input = keyboardPanel:addInput({
					x = 10,
					y = y,
					width = math.max(8, tw - 12),
					text = edit.values[idx],
					maxLength = 80,
					background = C.lightGray,
					foreground = C.black,
				})
				keyboardInputs[idx] = input
				input:onChange(function(self)
					local raw = self.text
					local a, b
					if idx ~= 3 then
						a, b = parseCoordinatePair(raw)
					end
					if a and b then
						setEditValue(1, a)
						setEditValue(2, b)
						self.text = edit.values[idx]
						local other = 3 - idx
						if keyboardInputs[other] then
							keyboardInputs[other].text = edit.values[other]
						end
					else
						setEditValue(idx, raw)
					end
				end)
				input:onEnter(function()
					if idx < 3 and keyboardInputs[idx + 1] then
						edit.field = idx + 1
						keyboardInputs[idx + 1]:focus()
					else
						submit()
						render()
					end
				end)
			end
		end
		label(
			keyboardPanel,
			2,
			math.min(th - 2, 15),
			"Monitor: SAVE / FLY to confirm.",
			C.lightGray,
			tw - 3
		)
		if keyboardInputs[edit.field] then
			keyboardInputs[edit.field]:focus()
		end
	end

	local function showSettings(s)
		label(panel, 3, 4, "NAVIGATION SETTINGS", C.cyan)
		label(panel, 3, 6, "BOW OFFSET  " .. tostring(s.bowOffset or "NOT CALIBRATED"), C.yellow)
		label(panel, 3, 8, "STEERING    " .. (s.invertSteering and "INVERTED" or "NORMAL"))
		label(panel, 3, 10, "AUTO MAP    " .. (s.autoMap and "ENABLED" or "DISABLED"))
		label(panel, 3, 12, "ENGINE AUTO " .. (s.engineAuto and "ENABLED" or "DISABLED"))
		local bw = math.floor((w - 5) / 2)
		btn(panel, 2, 14, bw, 1, "BOW +90", function()
			action(api.setting, "bow90")
		end)
		btn(panel, 3 + bw, 14, bw, 1, "FLIP 180", function()
			action(api.setting, "bow180")
		end)
		if h >= 20 then
			btn(panel, 2, 16, bw, 1, "STEERING", function()
				action(api.setting, "invert")
			end)
			btn(panel, 3 + bw, 16, bw, 1, "AUTO MAP", function()
				action(api.setting, "autoMap")
			end)
			btn(panel, 2, 18, bw, 1, "ENGINE AUTO", function()
				action(api.setting, "engineAuto")
			end, C.orange)
			btn(panel, 3 + bw, 18, bw, 1, "CALIBRATE", function()
				if action(api.calibrate) then
					page = "FLIGHT"
				end
			end, C.red)
		else
			btn(panel, 2, h - 4, bw, 1, "MORE SETTINGS", function()
				navigate("SETTINGS 2")
			end)
		end
		label(panel, 3, h - 2, "Engine needs inverted LAC receiver", C.lightGray)
	end
	local function showSettings2()
		local bw = math.floor((w - 5) / 2)
		label(panel, 2, 5, "SECONDARY SETTINGS", C.cyan)
		btn(panel, 2, 7, bw, 1, "STEERING", function()
			action(api.setting, "invert")
		end)
		btn(panel, 3 + bw, 7, bw, 1, "AUTO MAP", function()
			action(api.setting, "autoMap")
		end)
		btn(panel, 2, 10, bw, 1, "ENGINE AUTO", function()
			action(api.setting, "engineAuto")
		end, C.orange)
		btn(panel, 3 + bw, 10, bw, 1, "CALIBRATE", function()
			if action(api.calibrate) then
				page = "FLIGHT"
			end
		end, C.red)
	end
	local function showDiag(s)
		label(panel, 3, 4, "FLIGHT SYSTEM / DIAGNOSTICS", C.cyan)
		label(panel, 3, 6, "Tick " .. s.tick .. "  Mode " .. s.mode)
		label(panel, 3, 7, "Last update " .. num(s.tickAge, 1) .. "s ago")
		label(panel, 3, 8, "Stage " .. tostring(s.stage), C.yellow)
		label(panel, 3, 9, "Flight time " .. num(s.tickDuration, 3) .. "s")
		label(panel, 3, 11, "Nav " .. s.navName, C.lightGray)
		label(panel, 3, 12, "Bridge " .. s.bridgeName, C.lightGray)
		label(panel, 3, 13, "Display Links " .. s.displayLinks, C.lightGray)
		if s.controlError then
			label(panel, 3, 15, "ERROR: " .. s.controlError, C.red)
		end
	end
	local function showConfirm()
		label(panel, 3, 6, confirm and confirm.title or "Confirm?", C.yellow)
		btn(panel, 3, 10, math.floor((w - 6) / 2), 2, "YES, CONTINUE", function()
			local callback = confirm.callback
			page = confirm.back
			confirm = nil
			callback()
		end, C.red)
		btn(panel, 4 + math.floor((w - 6) / 2), 10, math.floor((w - 6) / 2), 2, "CANCEL", function()
			page = confirm.back
			confirm = nil
		end, C.gray)
	end
	function render()
		local rw, rh = (api.monitor or term).getSize()
		if rw ~= w or rh ~= h then
			w, h = rw, rh
		end
		if panel then
			panel:destroy()
		end
		panel = root:addFrame({ x = 1, y = 1, width = w, height = h, background = C.black })
		if api.setPage then
			api.setPage(page)
		end
		local s = api.snapshot()
		label(panel, 2, 1, "FPBCRAFT  /  AERONAUTICS", C.cyan, w - 3)
		local nav = {
			{ "FLIGHT", "FLIGHT" },
			{ "ROUTE", "ROUTE" },
			{ "PRESETS", "PRESETS" },
			{ "SETUP", "SETTINGS" },
			{
				"INFO",
				"DIAGNOSTICS",
			},
		}
		local x = 2
		for _, entry in ipairs(nav) do
			local bw = math.max(5, math.floor((w - 4) / #nav))
			btn(panel, x, 2, bw - 1, 1, entry[1], function()
				navigate(entry[2])
			end, page == entry[2] and C.blue or C.gray)
			x = x + bw
		end
		if page == "FLIGHT" then
			showFlight(s)
		elseif page == "ROUTE" then
			showList(s, true)
		elseif page == "PRESETS" then
			showList(s, false)
		elseif page == "EDITOR" then
			showEditor()
		elseif page == "REORDER" then
			showReorder(s)
		elseif page == "SETTINGS" then
			showSettings(s)
		elseif page == "SETTINGS 2" then
			showSettings2()
		elseif page == "DIAGNOSTICS" then
			showDiag(s)
		elseif page == "CONFIRM" then
			showConfirm()
		end
		local line = message ~= "" and message or s.notice or "Select a destination to begin"
		label(panel, 2, h - 1, line, C.lightGray, w - 3)
		updateKeyboardPanel()
		if not api.monitor and page == "EDITOR" and keyboardInputs[edit.field] then
			keyboardInputs[edit.field]:focus()
		end
	end
	-- Non-blocking start animation: frame transitions are scheduled inside
	-- Basalt; the independent 10Hz navigation loop starts immediately.
	local splash = root:addFrame({ x = 1, y = 1, width = w, height = h, background = C.black })
	local art = {
		"          ______________          ",
		"     ___/              \\___     ",
		"    /    AERONAUTICS      \\    ",
		"    \\____________________/    ",
		"              ||                 ",
		"          ___/==\\___            ",
		"         |  GONDOLA  |           ",
		"          \\________/            ",
	}
	local sprite = {}
	local y0 = math.max(3, math.floor((h - 12) / 2))
	splash:addLabel({ x = 2, y = 2, text = "FPBCRAFT / SKYWAYS", foreground = C.cyan })
	for i, txt in ipairs(art) do
		sprite[i] = splash:addLabel({
			x = 1,
			y = y0 + i,
			text = txt,
			foreground = i < 5 and C.lightBlue or C.orange,
		})
	end
	local status = splash:addLabel({
		x = 2,
		y = math.min(h - 2, y0 + 10),
		text = "INITIALIZING FLIGHT SYSTEM",
		foreground = C.yellow,
	})
	basalt.schedule(function()
		for tick = 1, 9 do
			local shift = (tick - 1) % 4
			for i, txt in ipairs(art) do
				sprite[i].text = string.rep(" ", shift) .. txt
			end
			status.text = ("INITIALIZING FLIGHT SYSTEM%s"):format(string.rep(".", tick % 4))
			sleep(0.11)
		end
		splash:destroy()
		render()
	end)
	basalt.schedule(function()
		while true do
			sleep(0.75)
			if page ~= "EDITOR" and page ~= "CONFIRM" and panel then
				render()
			end
		end
	end)
	basalt.run()
end
return UI
