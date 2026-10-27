-- Simulate Basalt 2.5 controls to test both touch and keyboard navigation.
local K = { enter = 28, escape = 1, tab = 15, space = 57 }
local C = dofile("tests/support/store_screen.lua").new(51, 19).colors
local old = { term = term, colors = colors, keys = keys, periphemu = periphemu, sleep = sleep }
local function scenario(w, h, actions)
	local screen = { mode = 0 }
	function screen.getSize()
		return w, h
	end
	function screen.setCursorPos() end
	function screen.setTextColor() end
	function screen.setBackgroundColor() end
	function screen.clear() end
	function screen.write() end
	function screen.setGraphicsMode(mode)
		screen.mode = mode
	end
	function screen.setPaletteColor() end
	function screen.getPaletteColor()
		return 0.2, 0.3, 0.4
	end
	local target = screen
	term = {
		current = function()
			return target
		end,
		redirect = function(device)
			target = device
		end,
	}
	colors, keys = C, K
	sleep = nil
	local created, launched, installed = 0, 0, false
	local monitor = {}
	function monitor.setTextScale() end
	function monitor.setGraphicsMode() end
	function monitor.getSize()
		return 80, 30
	end
	local prefs = {
		display = "term",
		launchTargets = {},
		opusShortcuts = {},
		opusStore = true,
		opusApps = true,
	}
	local app = {
		id = "alpha",
		name = "ALPHA",
		category = "Games",
		subtitle = "KINETIC",
		version = "1.0",
		genre = "PUZZLE",
		description = "Build gears and mechanisms",
		root = "/games/alpha",
	}
	local calls = {}
	local manager = { catalog = { apps = { app } } }
	function manager.preferences()
		return prefs
	end
	function manager.savePreferences(p)
		prefs = p
	end
	function manager.syncOpus() end
	function manager.storeStatus()
		return { installedVersion = "2.2.0" }
	end
	function manager.refreshVersions()
		return true
	end
	function manager.installed()
		return installed
	end
	function manager.status()
		return {
			installed = installed,
			root = app.root,
			source = { kind = "main", value = "main", label = "main" },
		}
	end
	function manager.disks()
		return {
			{ name = "Computer", root = app.root },
			{ name = "/disk", root = "/disk/games/alpha" },
		}
	end
	function manager.installRoot()
		return app.root
	end
	function manager.installedSource()
		return { kind = "main", value = "main", label = "main" }
	end
	function manager.parseSource(input, mode)
		assert(mode == "main" or input ~= "")
		return { kind = mode, value = input, label = input }
	end
	function manager.install(_, src, root)
		installed = true
		calls.source, calls.root = src, root
	end
	function manager.launch()
		launched = launched + 1
		calls.launchTarget = target
	end
	function manager.remove()
		installed = false
	end
	function manager.monitors()
		return created > 0 and { { name = "fpbstore_monitor", screen = monitor } } or {}
	end
	function manager.ensureMonitor()
		created = created + 1
		return { name = "fpbstore_monitor", screen = monitor }, true
	end
	periphemu = {
		create = function()
			return true
		end,
	}

	local root = { children = {} }
	local function add(parent, kind, props)
		local element = { kind = kind, parent = parent, children = {}, callbacks = {} }
		for key, value in pairs(props or {}) do
			element[key] = value
		end
		function element:onClick(fn)
			self.callbacks.click = fn
			return self
		end
		function element:onChange(fn)
			self.callbacks.change = fn
			return self
		end
		function element:onEnter(fn)
			self.callbacks.enter = fn
			return self
		end
		function element:onSelect(fn)
			self.callbacks.select = fn
			return self
		end
		function element:onKey(fn)
			self.callbacks.key = self.callbacks.key or {}
			self.callbacks.key[#self.callbacks.key + 1] = fn
			return self
		end
		function element:focus()
			calls.focus = self
			return self
		end
		function element:destroy()
			self.destroyed = true
		end
		function element:setItems(items)
			self.items = items
		end
		function element:selectItem(index)
			self.index = index
		end
		for _, method in ipairs({ "Frame", "Button", "Label", "Input", "List" }) do
			element["add" .. method] = function(self, p)
				return add(self, method, p)
			end
		end
		parent.children[#parent.children + 1] = element
		if kind == "Button" then
			assert(
				element.x + element.width - 1 <= w,
				"Button extends past screen: " .. element.text
			)
			assert(element.y <= h, "Button extends past screen vertically")
		end
		return element
	end
	for _, method in ipairs({ "Frame", "Button", "Label", "Input", "List" }) do
		root["add" .. method] = function(self, p)
			return add(self, method, p)
		end
	end
	local basalt = {
		getMainFrame = function()
			return root
		end,
		createFrame = function()
			return root
		end,
		stop = function()
			calls.stopped = true
		end,
	}
	local function find(kind, text)
		local result
		local function visit(node)
			if node.destroyed then
				return
			end
			if node.kind == kind and (not text or node.text == text) then
				result = node
			end
			for _, child in ipairs(node.children) do
				visit(child)
			end
		end
		visit(root)
		assert(result, "Missing " .. kind .. ": " .. tostring(text))
		return result
	end
	function basalt.run()
		for _, action in ipairs(actions) do
			if type(action) == "function" then
				action(find, calls, prefs)
			else
				find("Button", action).callbacks.click()
			end
		end
	end
	local ui = assert(loadfile("apps/fpbstore/basalt_ui.lua"))()
	local result = ui.run(manager, basalt)
	assert(target == screen and screen.mode == 0, "Original terminal restored")
	return result, calls, prefs, created, launched
end

local _, calls, prefs, count, launched = scenario(51, 19, {
	"DETAILS",
	"BUILD",
	"PR",
	function(find)
		local edit = find("Input")
		edit.text = "55"
		edit.callbacks.change(edit)
	end,
	"USE SOURCE",
	"DISK >",
	"OPUS SHORTCUT +",
	"MONITOR",
	"INSTALL NOW",
	"LAUNCH",
})
assert(calls.source.kind == "pr" and calls.source.value == "55")
assert(calls.root == "/disk/games/alpha" and prefs.opusShortcuts.alpha == false)
assert(prefs.launchTargets.alpha == "monitor")
assert(count == 1 and launched == 1 and calls.launchTarget ~= nil, "Launch auto-provisions monitor")

local _, _, smallPrefs = scenario(26, 12, {
	"MENU",
	"SETTINGS",
	"OPUS",
	"STORE ON",
	"BACK",
	"BACK",
	"BACK",
	"DETAILS",
	"MANAGE",
	"ABOUT",
	"DOWN",
	"BACK",
	"MON",
})
assert(smallPrefs.opusStore == false and smallPrefs.launchTargets.alpha == "monitor")
local _, _, searchPrefs = scenario(26, 12, {
	"KEYS",
	"NEXT",
	"A",
	"DONE",
	"DETAILS",
	"MANAGE",
	"MON",
})
assert(searchPrefs.launchTargets.alpha == "monitor", "Onscreen keyboard accepts touch-only search")

-- Keyboard focus starts in the native Basalt List and Tab moves to a button.
local keyboardResult, keyboardCalls = scenario(51, 19, {
	function(find, calls)
		assert(calls.focus == find("List"), "Keyboard starts on app list")
		assert(calls.focus.callbacks.key, "List handles keyboard shortcuts")
		calls.focus.callbacks.key[1](calls.focus, K.tab)
		assert(calls.focus.kind == "Button", "Tab focuses an actionable Basalt button")
		for _, handler in ipairs(calls.focus.callbacks.key) do
			handler(calls.focus, K.enter)
		end
		assert(find("List"), "Enter activates the focused tab and redraws the list")
		calls.focus.callbacks.key[1](calls.focus, K.escape)
	end,
})
assert(keyboardResult == "exit", "Escape exits the Store on keyboard only")
assert(keyboardCalls.stopped, "Basalt event loop stopped cleanly")

local _, compactLaunchCalls, _, createdCompact, launchedCompact = scenario(26, 12, {
	"DETAILS",
	"INSTALL",
	"INSTALL NOW",
	"LAUNCH",
	"MONITOR",
})
assert(
	createdCompact == 1 and launchedCompact == 1 and compactLaunchCalls.launchTarget,
	"Touch-only monitor selection provisions CraftOS screen even on 26x12"
)

term, colors, keys, periphemu, sleep = old.term, old.colors, old.keys, old.periphemu, old.sleep
print("Store Basalt: touch flows, PRs, disk, Opus, compact menus and virtual monitors passed")
