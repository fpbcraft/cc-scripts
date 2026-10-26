local screenFactory = dofile("tests/support/store_screen.lua")
local function scenario(w, h, events, check)
  local screen = screenFactory.new(w, h)
  local calls = { launch = 0, install = 0, remove = 0, refresh = 0 }
  local apps = {}
  for i = 1, 14 do
    apps[i] = {
      id = tostring(i),
      name = "APP " .. i,
      subtitle = "WORKSHOP " .. i,
      description = "A useful application",
      genre = "PUZZLE",
    }
  end
  local manager = { catalog = { apps = apps } }
  function manager.installed(app)
    return tonumber(app.id) % 2 == 0
  end
  function manager.status(app)
    return { installed = manager.installed(app), installedVersion = "1.0.0" }
  end
  function manager.storeStatus()
    return { installedVersion = "2.0.0" }
  end
  function manager.refreshVersions()
    calls.refresh = calls.refresh + 1
    return false, "offline"
  end
  function manager.launch(app)
    calls.launch = calls.launch + 1
    calls.lastLaunch = app.id
    screen.setGraphicsMode(2)
    screen.setPaletteColor(1, 1, 1, 1)
    if calls.throw then
      error(("application failure "):rep(30))
    end
  end
  function manager.installedSource()
    return { kind = "main", value = "main", label = "main" }
  end
  function manager.parseSource(value, mode)
    if mode == "pr" then
      assert(value:match("^%d+$"), "Invalid PR")
      return { kind = "pr", value = value, label = "PR #" .. value }
    elseif mode == "branch" then
      assert(value ~= "")
      return { kind = "branch", value = value, label = value }
    end
    return { kind = "main", value = "main", label = "main" }
  end
  function manager.install(app, source)
    calls.install = calls.install + 1
    calls.lastInstall = app.id
    calls.lastSource = source
  end
  function manager.remove(app, purge)
    assert(not purge)
    calls.remove = calls.remove + 1
    calls.lastRemove = app.id
  end
  local target = screen
  local env = setmetatable({
    colors = screen.colors,
    keys = screen.keys,
    term = {
      current = function()
        return target
      end,
      redirect = function(t)
        target = t
      end,
    },
    print = function() end,
  }, { __index = _G })
  local index = 0
  env.os = setmetatable({
    pullEvent = function()
      index = index + 1
      local event = assert(events[index], "Event loop did not exit")
      if type(event) == "function" then
        event = event(screen, calls)
      end
      screen.frames[#screen.frames + 1] = screen.text()
      return table.unpack(event)
    end,
  }, { __index = os })
  local ui = assert(loadfile("apps/fpbstore/launcher.lua", "t", env))()
  ui.run(manager)
  assert(target == screen and screen.mode == 0, "Display restored after launch/error")
  local r, g, b = screen.getPaletteColor(1)
  assert(r == 0.2 and g == 0.4 and b == 0.6, "Original palette restored")
  check(calls, screen)
  return screen
end
local K = screenFactory.new(1, 1).keys
-- Default Enter installs missing apps; installed Enter launches rather than reinstalls.
scenario(
  51,
  19,
  { { "key", K.down }, { "key", K.enter }, { "key", K.up }, { "key", K.enter }, { "char", "q" } },
  function(c)
    assert(c.launch == 1 and c.lastLaunch == "2")
    assert(c.install == 1 and c.lastInstall == "1")
  end
)
-- Installed filter, pagination and removal confirmation bind to the visible selection.
local frames = scenario(51, 19, {
  { "key", K.tab },
  { "key", K.pageDown },
  function(s)
    assert(s.text():find("> APP 14", 1, true), "Selection scrolls into view")
    return { "char", "d" }
  end,
  { "key", K.down },
  { "key", K.enter },
  { "char", "q" },
}, function(c)
  assert(c.remove == 1 and c.lastRemove == "14", "Confirmation cannot change app via navigation")
end)
-- Search consumes Q as text, supports paste/backspace, and has a safe empty state.
scenario(26, 12, {
  { "char", "/" },
  { "paste", "no results q" },
  { "key", K.backspace },
  { "key", K.enter },
  function(s)
    assert(s.text():find("No apps match", 1, true))
    return { "key", K.enter }
  end,
  { "char", "q" },
}, function(c)
  assert(c.install == 0 and c.launch == 0, "Empty results disable actions")
end)
-- Mouse wheel, resize and long errors do not overflow the physical terminal.
scenario(80, 30, {
  { "mouse_scroll", 7 },
  function(s, c)
    s.w = 30
    s.h = 14
    c.throw = true
    return { "key", K.enter }
  end,
  { "key", K.down },
  function(s)
    s.w = 26
    s.h = 12
    return { "term_resize" }
  end,
  { "key", K.enter },
  { "key", K.escape },
}, function(c)
  assert(c.launch == 1)
end)
-- Too-small terminals never execute an invisible action.
scenario(20, 8, { { "key", K.enter }, { "char", "i" }, { "char", "q" } }, function(c)
  assert(c.install == 0)
end)
-- Build picker supports entering PR numbers and pasting branch names.
scenario(51, 19, {
  { "char", "b" },
  { "key", K.tab },
  { "char", "5" },
  { "char", "2" },
  { "key", K.enter },
  { "char", "q" },
}, function(c)
  assert(c.install == 1 and c.lastInstall == "1")
  assert(c.lastSource and c.lastSource.kind == "pr" and c.lastSource.value == "52")
end)
scenario(51, 19, {
  { "char", "b" },
  { "key", K.tab },
  { "key", K.tab },
  { "paste", "feature/my-build" },
  { "key", K.enter },
  { "char", "q" },
}, function(c)
  assert(c.install == 1 and c.lastSource.kind == "branch" and c.lastSource.value == "feature/my-build")
end)
-- Screenshot artifact is generated from the real terminal draw calls.
local output = io.open("/tmp/cc-store-screen.txt", "w")
output:write(frames.frames[2])
output:close()
print("Store launcher: 14-app scrolling, filters, search, launch/install, confirmation, errors and resize passed")
