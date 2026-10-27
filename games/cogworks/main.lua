-- Installed programs own their globals and module cache.
local bootstrap = loadfile("/games/cogworks/_lib/fpb/loader.lua")
if bootstrap and _G.__fpbRoot ~= "/games/cogworks" then
	-- selene: allow(undefined_variable) -- Selene misidentifies chunk-level varargs.
	return bootstrap().run("/games/cogworks", "main.lua", _ENV, ...)
end
-- COGWORKS / kinetic workshop for CC:Tweaked Advanced Monitors.
-- Uses CC: Graphics when available, with a vanilla text-mode fallback.
package.path = "/?.lua;/?/init.lua;" .. package.path
local App = require("games.cogworks.app")
local Renderer = require("games.cogworks.render")
local E = require("games.cogworks.engine")
local Display = require("games.cogworks.display")
local Pointer = require("games.cogworks.pointer")
-- Translate a pointer press on the board, not on toolbar/menu controls.
-- CC mouse buttons are 1=left (remove), 2=right (build / drag).
-- Touch input has no mouse button and also supports the erase tool.
local function boardAction(button, selected, touch)
	-- Explicit mouse buttons take precedence over the selected inventory tool:
	-- right click NEVER removes, even when Erase is selected.
	if button == 1 then
		return "remove"
	end
	if button == 2 and selected == "erase" then
		return "inspect"
	end
	-- Buttonless monitor touches can still use the dedicated Erase tool.
	if selected == "erase" then
		return "remove"
	end
	return touch and "inspect" or "cell"
end
-- CraftOS-PC mobile synthesizes primary mouse clicks for finger taps.
-- Detect its mobile API so terminal taps use monitor-like selection rather
-- than the desktop left-click-to-delete shortcut.
local function terminalTouchMode(computerMode, override, mobileApi)
	return computerMode and (override == true or (override == nil and type(mobileApi) == "table"))
end
local args = { ... }
if args[1] == "--test-api" then
	return {
		app = App,
		engine = E,
		renderer = Renderer,
		boardAction = boardAction,
		pointer = Pointer,
		terminalTouchMode = terminalTouchMode,
	}
end
local dev = false
local debugInput = false
local touchOverride = nil
local preferredMonitor = nil
for _, arg in ipairs(args) do
	if arg == "--dev" then
		dev = true
	elseif arg == "--input-debug" then
		debugInput = true
	elseif arg == "--touch" then
		touchOverride = true
	elseif arg == "--mouse" then
		touchOverride = false
	elseif arg:sub(1, 2) == "--" then
		error("Unknown option: " .. arg)
	elseif not preferredMonitor then
		preferredMonitor = arg
	else
		error("Only one monitor can be selected")
	end
end
local function selectMonitor(preferred)
	if preferred then
		local m = peripheral.wrap(preferred)
		assert(
			m and peripheral.getType(preferred) == "monitor",
			"Unknown monitor: " .. tostring(preferred),
			0
		)
		return m, preferred
	end
	-- A program started via `monitor <side> fpbstore` inherits a redirected
	-- terminal. Prefer that monitor instead of silently choosing a different
	-- attached display, which may have different input/graphics capabilities.
	if peripheral.getName and term.current then
		local current = term.current()
		local ok, redirected = pcall(peripheral.getName, current)
		if ok and redirected and peripheral.getType(redirected) == "monitor" then
			return peripheral.wrap(redirected), redirected
		end
	end
	local chosen, name, largest = nil, nil, -1
	for _, side in ipairs(peripheral.getNames()) do
		if peripheral.getType(side) == "monitor" then
			local m = peripheral.wrap(side)
			local ok, w, h = pcall(m.getSize)
			if ok and w and h then
				-- Always use an attached monitor rather than CraftOS-PC's own screen.
				-- Prefer an Advanced (color) monitor, then the largest surface.
				-- Ordinary monitors remain a supported text-mode fallback.
				local colored = not m.isColor or m.isColor()
				local score = w * h + (colored and 1000000 or 0)
				if score > largest then
					chosen, name, largest = m, side, score
				end
			end
		end
	end
	return chosen, name
end
local function start()
	local monitor, name = selectMonitor(preferredMonitor)
	local native = not monitor and term.current() or nil
	local physicalDisplay = monitor or native
	-- Match CivCraft: select 0.5 scale BEFORE creating the display wrapper or
	-- measuring pixel dimensions. Native terminals have no scale method on
	-- standard CC:Tweaked; only apply this when the emulator exposes one.
	local previous
	if physicalDisplay and physicalDisplay.setTextScale then
		if physicalDisplay.getTextScale then
			local ok, value = pcall(physicalDisplay.getTextScale)
			if ok then
				previous = value
			end
		end
		pcall(physicalDisplay.setTextScale, 0.5)
	end
	-- CivCraft uses mouse-style events in CraftOS monitor windows, allowing
	-- exact pointer input and drag on the iPad instead of cell-quantized taps.
	local previousMonitorMouse
	if name and config and config.get and config.set then
		local ok, value = pcall(config.get, "monitorsUseMouseEvents")
		if ok then
			previousMonitorMouse = value
			pcall(config.set, "monitorsUseMouseEvents", true)
		end
	end
	local mode
	monitor, mode = Display.select(monitor, native, require("games.cogworks.terminal_view"), 70, 40)
	local computerMode = Display.isComputer(mode)
	local touchComputer = terminalTouchMode(computerMode, touchOverride, rawget(_G, "mobile"))
	local inputLog = debugInput and fs.open("/games/cogworks/input-debug.log", "w") or nil
	local function trace(message)
		if inputLog then
			inputLog.write(tostring(message) .. "\n")
		end
	end
	trace(
		"COGWORKS MONITOR="
			.. tostring(name)
			.. " MODE="
			.. tostring(mode)
			.. " TOUCH="
			.. tostring(touchComputer)
	)
	local renderer, app
	local ok, reason = xpcall(function()
		renderer = Renderer.new(monitor)
		if mode == "native-pixels" and renderer.mode == "text" then
			-- Some CraftOS backends expose pixel methods but cannot enter mode 2.
			-- Retain the computer viewport rather than drawing a full board into
			-- a small native text terminal with overlapping controls.
			renderer:close()
			monitor = require("games.cogworks.terminal_view").new(native, 70, 40)
			mode = "virtual-text"
			renderer = Renderer.new(monitor)
			trace("PIXEL MODE UNAVAILABLE: USING VIRTUAL TEXT VIEWPORT")
		end
		app = App.new({ dev = dev })
		local drag = nil
		local function redraw()
			renderer:draw(app:model())
			Display.present(monitor, mode)
		end
		local function redrawPointer()
			-- Recompose only the ghost and its old footprint while dragging.
			-- Full-screen redraws here stall queued pointer events on CraftOS.
			renderer:drawDragPreview(app:model())
			Display.present(monitor, mode)
		end
		local function act(action, x, y)
			if not action then
				return true
			end
			local response = app:act(action, x, y)
			if response == "exit" then
				return false
			end
			if app.scene ~= "game" and app.scene ~= "editor" then
				drag, app.drag = nil, nil
			end
			redraw()
			return true
		end
		redraw()
		-- Smooth native CraftOS animation (~20fps); peripheral monitors are
		-- capped lower to avoid flooding remote monitor update packets.
		local frameInterval = renderer.mode == "graphics" and (computerMode and 0.05 or 0.13) or 0.2
		local timer = os.startTimer(frameInterval)
		local function cancelDrag()
			drag, app.drag = nil, nil
		end
		local function finishPointer(mx, my)
			local pointer = drag
			if not pointer then
				return true
			end
			Pointer.update(pointer, app.game, renderer, mx, my)
			if pointer.moved then
				app.drag = pointer
				app:dropDrag(pointer.targetX, pointer.targetY)
				drag = nil
				redraw()
				return true
			end
			cancelDrag()
			if pointer.origin ~= "inventory" then
				-- Every mouse_click/mouse_up is button-aware, even on a monitor.
				-- Only the monitor_touch event uses touch-style inspection.
				local action = pointer.touch and boardAction(nil, app.selected, true)
					or boardAction(pointer.button, app.selected, false)
				return act(action, pointer.fromX, pointer.fromY)
			end
			redraw()
			return true
		end
		local function pressPointer(button, mx, my)
			local touch = touchComputer and button == 1
			if drag and drag.origin == "paint" and not drag.moved then
				if not act("cell", drag.fromX, drag.fromY) then
					return false
				end
			end
			cancelDrag()
			local action, x, y = renderer:hit(mx, my)
			local gameScene = app.scene == "game" or app.scene == "editor"
			-- Inspect mode draws small rotate/remove overlays over selected cells.
			-- They are touch controls, not right-click actions: right-clicking
			-- either overlay must still operate on the underlying board cell.
			if
				gameScene
				and button == 2
				and (action == "rotate" or action == "remove" or action == "moveStart")
			then
				action = "cell"
			end
			-- Armed Move consumes a destination click, not a new drag or delete.
			if gameScene and app.moving and action == "cell" then
				return act("moveTo", x, y)
			end
			if gameScene and action == "cell" and button == 1 and not touch then
				return act("remove", x, y)
			end
			if gameScene and (action == "cell" or action == "tool") then
				if action == "tool" and not act(action, x, y) then
					return false
				end
				drag = Pointer.begin(
					app.game,
					renderer,
					button,
					action,
					x,
					y,
					mx,
					my,
					app.selected,
					touch
				)
				if drag then
					app.drag = drag
					if drag.origin ~= "inventory" then
						drag.timer = os.startTimer(0.12)
					end
					return true
				end
				if action == "tool" then
					return true
				end
			end
			if action == "cell" then
				action = touch and boardAction(nil, app.selected, true)
					or boardAction(button, app.selected, false)
			end
			return act(action, x, y)
		end
		local function mousePosition(event, a, b, c, d)
			local button, mx, my = a, b, c
			if event:sub(1, 8) == "monitor_" then
				button, mx, my = d ~= nil and b or 2, d ~= nil and c or b, d ~= nil and d or c
			end
			mx, my = Display.click(monitor, mode, mx, my)
			return button, mx, my
		end
		while true do
			local event, a, b, c, d = os.pullEventRaw()
			if
				event == "monitor_touch"
				or event == "monitor_left_click"
				or event == "monitor_mouse_click"
				or event == "monitor_resize"
				or event == "mouse_click"
			then
				trace(
					tostring(event)
						.. " side="
						.. tostring(a)
						.. " x="
						.. tostring(b)
						.. " y="
						.. tostring(c)
						.. " extra="
						.. tostring(d)
						.. " graphics="
						.. tostring(renderer.mode)
				)
			end
			if event == "terminate" then
				if app then
					app:save()
				end
				break
			elseif event == "monitor_touch" and a == name then
				local action, x, y = renderer:hitTouch(b, c)
				-- CC:Tweaked reports character-cell coordinates. Other monitor
				-- implementations may report graphics pixels; try those only if
				-- character-cell hit testing did not find a control.
				if not action and renderer.mode == "graphics" then
					action, x, y = renderer:hit(b, c)
				end
				if action == "cell" then
					action = boardAction(nil, app.selected, true)
				end
				trace(
					"MONITOR HIT="
						.. tostring(action)
						.. " part="
						.. tostring(x)
						.. ","
						.. tostring(y)
				)
				if not act(action, x, y) then
					break
				end
			elseif event == "_CCPC_finger_touch" and computerMode and touchOverride == nil then
				-- Some CraftOS-PC mobile versions expose finger events but not the
				-- mobile API. The paired mouse events still perform the actual action.
				touchComputer = true
			elseif event == "monitor_left_click" and a == name then
				local action, x, y = renderer:hitNormalized(b, c)
				app.hasLeftInput = true
				if action == "cell" then
					action = boardAction(1, app.selected, true)
				end
				cancelDrag()
				if not act(action, x, y) then
					break
				end
			elseif event == "mouse_click" or (event == "monitor_mouse_click" and a == name) then
				local button, mx, my = mousePosition(event, a, b, c, d)
				if mx and not pressPointer(button, mx, my) then
					break
				end
			elseif
				(event == "mouse_drag" or (event == "monitor_mouse_drag" and a == name)) and drag
			then
				local button, mx, my = mousePosition(event, a, b, c, d)
				if mx and button == drag.button then
					Pointer.update(drag, app.game, renderer, mx, my)
					if drag.moved then
						app.inspected = nil
					end
					if drag.moved then
						redrawPointer()
					end
				end
			elseif event == "mouse_move" and drag then
				local mx, my = Display.click(monitor, mode, a, b)
				if mx then
					Pointer.update(drag, app.game, renderer, mx, my)
					if drag.moved then
						app.inspected = nil
						redrawPointer()
					end
				end
			elseif
				(event == "mouse_up" or (event == "monitor_mouse_up" and a == name)) and drag
			then
				local button, mx, my = mousePosition(event, a, b, c, d)
				if mx and button == drag.button and not finishPointer(mx, my) then
					break
				end
			elseif event == "timer" and drag and a == drag.timer and not drag.moved then
				if drag.origin == "paint" then
					local x, y = drag.fromX, drag.fromY
					cancelDrag()
					if not act("cell", x, y) then
						break
					end
				elseif drag.origin == "board" then
					-- Click-only touch selects without mutating the piece. Retaining
					-- the gesture also permits a long hold before a desktop drag.
					if not act("inspect", drag.fromX, drag.fromY) then
						break
					end
				end
			elseif mode == "virtual-text" and event == "mouse_scroll" then
				monitor.pan(0, a * 3)
			elseif computerMode and event == "term_resize" then
				cancelDrag()
				renderer:resize()
				redraw()
			elseif event == "monitor_resize" and a == name then
				cancelDrag()
				renderer:resize()
				redraw()
			elseif event == "timer" and a == timer then
				if
					renderer.mode == "graphics"
					and (app.settings.animations or (drag and drag.moved))
					and (
						app.scene == "game"
						or app.scene == "editor"
						or app.scene == "briefing"
						or app.scene == "tutorial"
					)
				then
					if drag and drag.moved then
						redrawPointer()
					else
						redraw()
					end
				end
				-- Peripheral monitor graphics need fewer pushes than native CraftOS-PC.
				timer = os.startTimer(app.scene == "briefing" and 0.12 or frameInterval)
			elseif event == "char" then
				cancelDrag()
				local char = tostring(a):lower()
				local n = tonumber(char)
				if n and n >= 1 and n <= 9 then
					if not act("tool", E.order[n]) then
						break
					end
				elseif char == "0" then
					act("tool", E.order[10])
				elseif char == "x" then
					act("tool", "erase")
				elseif char == "t" then
					act("tool", "R")
				elseif char == "s" then
					act("save")
				elseif char == "n" then
					act(app.scene == "briefing" and "beginLevel" or "next")
				elseif char == " " and app.scene == "briefing" then
					act("beginLevel")
				elseif char == "p" or char == "q" then
					if app.scene == "game" then
						act("pause")
					elseif app.scene == "pause" then
						act("resume")
					elseif app.scene == "title" and char == "q" then
						if not act("exit") then
							break
						end
					end
				elseif char == "b" then
					act("back")
				end
			elseif event == "key" and keys then
				if drag and a == keys.escape then
					cancelDrag()
					redraw()
				elseif
					mode == "virtual-text"
					and (a == keys.up or a == keys.down or a == keys.left or a == keys.right)
				then
					local dx = a == keys.left and -8 or (a == keys.right and 8 or 0)
					local dy = a == keys.up and -5 or (a == keys.down and 5 or 0)
					monitor.pan(dx, dy)
				elseif
					(a == keys.enter or a == keys.numPadEnter or a == keys.space)
					and app.scene == "briefing"
				then
					act("beginLevel")
				elseif a == keys.escape or a == keys.backspace then
					local state = app.scene
					if state == "game" then
						act("pause")
					elseif state == "pause" then
						act("resume")
					else
						act("back")
					end
				elseif a == keys.left and app.scene == "game" then
					act("prev")
				elseif a == keys.right and app.scene == "game" then
					act("next")
				end
			end
		end
	end, function(e)
		return tostring(e) .. (debug and debug.traceback and "\n" .. debug.traceback() or "")
	end)
	if renderer then
		renderer:close()
	end
	if inputLog then
		inputLog.close()
	end
	Display.close(monitor, mode)
	if physicalDisplay and physicalDisplay.setTextScale and previous ~= nil then
		pcall(physicalDisplay.setTextScale, previous)
	end
	if previousMonitorMouse ~= nil and config and config.set then
		pcall(config.set, "monitorsUseMouseEvents", previousMonitorMouse)
	end
	if not ok then
		error(reason, 0)
	end
end
start()
