-- Exercise the genuine character-cell UI without graphics mode or Basalt.
local screenFactory = dofile("tests/support/store_screen.lua")
local K = screenFactory.new(1, 1).keys

local function scenario(width, height, events, verify)
  local screen = screenFactory.new(width, height)
  local current = screen
  local calls = { launches = 0, installs = 0, removes = 0, refreshes = 0 }
  local apps = {}
  for i = 1, 14 do
    apps[i] = {
      id = tostring(i),
      name = "APP " .. i,
      subtitle = "WORKSHOP " .. i,
      description = "An industrial workshop with a variety of puzzles and challenges.",
      category = "Games",
      genre = "PUZZLE",
      root = "/games/" .. i,
      version = "1.0.0",
    }
  end
  local manager = { catalog = { apps = apps } }
  function manager.installed(app)
    return tonumber(app.id) % 2 == 0
  end
  function manager.status(app)
    return {
      installed = manager.installed(app),
      installedVersion = "1.0.0",
      latestVersion = "1.0.0",
      root = app.root,
      source = { kind = "main", value = "main", label = "main" },
    }
  end
  function manager.storeStatus()
    return { installedVersion = "2.1.0" }
  end
  function manager.refreshVersions()
    calls.refreshes = calls.refreshes + 1
    return false, "offline"
  end
  function manager.installedSource()
    return { kind = "main", value = "main", label = "main" }
  end
  function manager.parseSource(value, mode)
    if mode == "pr" then
      assert(value:match("^%d+$"))
      return { kind = "pr", value = value, label = "PR #" .. value }
    elseif mode == "branch" then
      assert(value ~= "")
      return { kind = "branch", value = value, label = value }
    end
    return { kind = "main", value = "main", label = "main" }
  end
  function manager.install(app, source, root)
    calls.installs = calls.installs + 1
    calls.installedId = app.id
    calls.source = source
    calls.root = root
  end
  function manager.launch(app)
    calls.launches = calls.launches + 1
    calls.launchedId = app.id
    screen.setGraphicsMode(2)
    screen.setPaletteColor(1, 1, 1, 1)
    if calls.throw then
      error("Broken application: long failure message", 0)
    end
  end
  function manager.remove(app, purge)
    assert(not purge)
    calls.removes = calls.removes + 1
    calls.removedId = app.id
  end
  local env = setmetatable({
    colors = screen.colors,
    keys = screen.keys,
    term = {
      current = function()
        return current
      end,
      redirect = function(destination)
        current = destination
      end,
    },
  }, { __index = _G })
  local index = 0
  env.os = setmetatable({
    pullEvent = function()
      index = index + 1
      local event = assert(events[index], "Event loop failed to exit")
      if type(event) == "function" then
        event = event(screen, calls)
      end
      screen.frames[#screen.frames + 1] = screen.text()
      return table.unpack(event)
    end,
  }, { __index = os })

  local UI = assert(loadfile("apps/fpbstore/launcher.lua", "t", env))()
  UI.run(manager)
  assert(current == screen and screen.mode == 0, "Terminal must be restored after exit")
  local r, g, b = screen.getPaletteColor(1)
  assert(r == 0.2 and g == 0.4 and b == 0.6, "Original palette must be restored")
  verify(calls, screen)
end

-- Browse -> details -> install. Newly requested locations are passed to the manager.
scenario(51, 19, {
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.escape },
  { "char", "q" },
}, function(c)
  assert(c.installs == 1 and c.installedId == "1" and c.root == "/games/1")
end)

-- Installed programs use the launch-target picker and restore graphics/palette.
scenario(51, 19, {
  { "key", K.down },
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.escape },
  { "char", "q" },
}, function(c)
  assert(c.launches == 1 and c.launchedId == "2")
end)

-- Source selection retains PR number and requires explicit install confirmation.
scenario(51, 19, {
  { "key", K.enter },
  { "char", "b" },
  { "key", K.tab },
  { "char", "5" },
  { "char", "2" },
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.escape },
  { "char", "q" },
}, function(c)
  assert(c.installs == 1 and c.source and c.source.kind == "pr" and c.source.value == "52")
end)

-- Search, empty results and constrained 26x12 screen do not cause overflow.
scenario(26, 12, {
  { "char", "/" },
  { "paste", "not an app q" },
  { "key", K.enter },
  function(s)
    assert(s.text():find("No apps match", 1, true))
    return { "key", K.enter }
  end,
  { "char", "q" },
}, function(c)
  assert(c.installs == 0 and c.launches == 0)
end)

-- A tiny terminal never activates actions it cannot display.
scenario(20, 8, { { "key", K.enter }, { "char", "q" } }, function(c)
  assert(c.installs == 0 and c.launches == 0)
end)

-- Failures return to a responsive, scrollable diagnostic screen.
scenario(80, 30, {
  { "key", K.down },
  { "key", K.enter },
  function(_, c)
    c.throw = true
    return { "key", K.enter }
  end,
  { "key", K.enter },
  { "key", K.enter },
  { "key", K.escape },
  { "char", "q" },
}, function(c)
  assert(c.launches == 1)
end)

print("Store launcher: details, installs, PR selection, target picker, search, small terminal and recovery passed")
