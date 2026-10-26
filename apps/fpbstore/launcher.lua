-- FPB Store: responsive ComputerCraft terminal storefront.
-- No Basalt, graphics mode or external UI libraries are required.
local UI = {}

function UI.run(manager)
  local native = term.current()
  local prefs = manager.preferences and manager.preferences()
    or { display = "term", opusStore = true, opusApps = true, launchTargets = {}, opusShortcuts = {} }
  prefs.launchTargets = prefs.launchTargets or {}
  prefs.opusShortcuts = prefs.opusShortcuts or {}

  local monitors = manager.monitors and manager.monitors() or {}
  local function monitor()
    monitors = manager.monitors and manager.monitors() or {}
    return monitors[1] and monitors[1].screen or nil
  end

  local host = native
  if prefs.display == "auto" or prefs.display == "monitor" then
    host = monitor() or native
  end
  if host ~= native and host.setTextScale then
    pcall(host.setTextScale, 0.5)
  end
  if term.redirect then
    term.redirect(host)
  end

  local palettes = {}
  local function capture(screen)
    if not screen or palettes[screen] then
      return
    end
    local palette = {}
    if screen.getPaletteColor then
      for i = 0, 15 do
        local color = 2 ^ i
        palette[color] = { screen.getPaletteColor(color) }
      end
    end
    palettes[screen] = palette
  end
  capture(native)
  capture(host)
  local function reset(screen)
    if screen.setGraphicsMode then
      pcall(screen.setGraphicsMode, 0)
    end
    if screen.setPaletteColor then
      for color, rgb in pairs(palettes[screen] or {}) do
        pcall(screen.setPaletteColor, color, table.unpack(rgb))
      end
    end
    if screen.setCursorBlink then
      screen.setCursorBlink(false)
    end
    screen.setBackgroundColor(colors.black)
    screen.setTextColor(colors.white)
  end
  local function restore()
    if term.redirect then
      term.redirect(native)
    end
    reset(host)
    if host ~= native then
      reset(native)
    end
  end

  local page, tab = "browse", "GAMES"
  local selected, offset = 1, 0
  local query, typing = "", false
  local source, sourceMode, sourceInput, sourceReturn = nil, "main", "", "detail"
  local installRoot, installIndex, installOpus, installTarget = nil, 1, true, "ask"
  local message, errLines, errorTop = "Catalog ready. Select a title.", nil, 1
  local hits, confirmApp, pendingLaunch = {}, nil, nil
  local w, h = host.getSize()

  local function put(x, y, value, fg, bg, width)
    if x > w or y > h or x < 1 or y < 1 then
      return
    end
    local maxWidth = math.min(width or (w - x + 1), w - x + 1)
    if maxWidth <= 0 then
      return
    end
    host.setCursorPos(x, y)
    host.setTextColor(fg or colors.white)
    host.setBackgroundColor(bg or colors.black)
    host.write((tostring(value or "") .. (" "):rep(maxWidth)):sub(1, maxWidth))
  end
  local function hit(x, y, width, action, value)
    if x < w and width > 0 then
      hits[#hits + 1] = { x = x, y = y, width = width, action = action, value = value }
    end
  end
  local function button(x, y, label, action, value, active, enabled)
    local content = "[" .. label .. "]"
    if x + #content - 1 > w then
      return x
    end
    local bg = enabled == false and colors.black or (active and colors.orange or colors.blue)
    local fg = enabled == false and colors.gray or (active and colors.black or colors.white)
    put(x, y, content, fg, bg, #content)
    if enabled ~= false then
      hit(x, y, #content, action, value)
    end
    return x + #content + 1
  end
  local function right(y, value, fg, margin)
    local text = tostring(value or "")
    local x = math.max(1, w - #text - (margin or 1) + 1)
    put(x, y, text, fg, nil, #text)
  end
  local function brief(text, count)
    text = tostring(text or "")
    if #text > count then
      return text:sub(1, math.max(0, count - 2)) .. ".."
    end
    return text
  end
  local function wrap(text, width)
    local lines, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      if #line > 0 and #line + #word + 1 > width then
        lines[#lines + 1], line = line, ""
      end
      line = line .. (line == "" and "" or " ") .. word
    end
    if line ~= "" then
      lines[#lines + 1] = line
    end
    return lines
  end
  local function currentList()
    local list = {}
    for _, app in ipairs(manager.catalog.apps) do
      local status = manager.status(app)
      local matched = tab == "GAMES" and (app.category == "Games" or not app.category)
        or tab == "APPS" and app.category == "Apps"
        or tab == "INSTALLED" and status.installed
        or tab == "UPDATES" and status.installed and status.updateAvailable
      local haystack = (app.name .. " " .. (app.subtitle or "") .. " " .. (app.genre or "") .. " " .. (app.description or "")):lower()
      if matched and haystack:find(query:lower(), 1, true) then
        list[#list + 1] = app
      end
    end
    selected = math.max(1, math.min(selected, math.max(1, #list)))
    return list
  end
  local function current()
    return currentList()[selected]
  end
  local function statusTag(app)
    local s = manager.status(app)
    if not s.installed then
      return s.managed and "MISSING" or "GET", colors.lightBlue
    end
    if s.updateAvailable then
      return "UPDATE", colors.orange
    end
    local sourceValue = s.source
    if sourceValue and sourceValue.kind == "pr" then
      return "PR #" .. sourceValue.value, colors.cyan
    elseif sourceValue and sourceValue.kind == "branch" then
      return "BRANCH", colors.cyan
    end
    return "READY", colors.lime
  end
  local function top()
    put(1, 1, "", colors.white, colors.gray, w)
    put(2, 1, "FPB STORE", colors.orange, colors.gray, 9)
    put(12, 1, (manager.storeStatus().installedVersion or "2.1"), colors.white, colors.gray, 7)
    local mode = prefs.display == "auto" and "AUTO" or (prefs.display == "monitor" and "MON" or "TERM")
    right(1, mode .. " SETUP", colors.white, 1)
    hit(w - #mode - 5, 1, #mode + 5, "settings")
    put(1, 2, "", colors.white, colors.blue, w)
    local x = 2
    for _, name in ipairs({ "GAMES", "APPS", "INSTALLED", "UPDATES" }) do
      if x + #name + 2 < w then
        put(x, 2, " " .. name .. " ", tab == name and colors.black or colors.white, tab == name and colors.orange or colors.blue, #name + 2)
        hit(x, 2, #name + 2, "tab", name)
        x = x + #name + 3
      end
    end
    if page == "browse" then
      local search = typing and "/ SEARCH> " or "/ SEARCH  "
      put(2, 3, search .. brief(query == "" and "(all titles)" or query, math.max(3, w - 29)), typing and colors.yellow or colors.lightGray, nil, w - 13)
      hit(2, 3, w - 16, "search")
      right(3, #currentList() .. " ITEMS", colors.cyan)
    else
      put(2, 3, brief(tab .. " / " .. page:upper(), w - 4), colors.lightGray)
    end
  end
  local function bottom(help)
    put(1, h - 1, " " .. brief(message, w - 2), colors.white, colors.gray, w)
    put(1, h, " " .. brief(help, w - 2), colors.lightGray, colors.black, w)
  end

  local function header(y, title)
    put(2, y, brief(title, w - 4), colors.yellow)
  end
  local function printDescription(app, x, y, width, limit)
    local lines = wrap(app.description or "No description provided.", width)
    for i = 1, math.min(limit, #lines) do
      put(x, y + i - 1, brief(lines[i], width), colors.white)
    end
  end
  local function browse()
    local list = currentList()
    local wide = w >= 72
    local listWidth = wide and math.floor(w * 0.48) or w - 2
    header(4, tab == "GAMES" and "GAME LIBRARY" or tab == "APPS" and "APPLICATIONS" or tab == "INSTALLED" and "YOUR LIBRARY" or "AVAILABLE UPDATES")
    local startY = 5
    local step = h >= 17 and 2 or 1
    local capacity = math.max(1, math.floor((h - startY - 3) / step))
    offset = math.max(0, math.min(offset, math.max(0, #list - capacity)))
    if selected <= offset then
      offset = selected - 1
    elseif selected > offset + capacity then
      offset = selected - capacity
    end
    if #list == 0 then
      put(3, 7, "No apps match", colors.yellow)
    end
    for i = 1, capacity do
      local app = list[offset + i]
      if app then
        local y = startY + (i - 1) * step
        local active = selected == offset + i
        local tag, fg = statusTag(app)
        local nameWidth = math.max(8, listWidth - #tag - 7)
        if active then
          put(2, y, "", colors.white, colors.blue, listWidth)
        end
        put(3, y, (active and ">" or " ") .. (app.category == "Games" and "G" or "A") .. " " .. brief(app.name, nameWidth), active and colors.white or colors.yellow, active and colors.blue or colors.black, nameWidth + 3)
        put(listWidth - #tag + 1, y, tag, active and colors.white or fg, active and colors.blue or colors.black, #tag)
        if step == 2 then
          put(6, y + 1, brief(app.subtitle or app.genre or "", listWidth - 7), colors.lightGray)
        end
        hit(2, y, listWidth, "select", offset + i)
        if step == 2 then
          hit(2, y + 1, listWidth, "select", offset + i)
        end
      end
    end
    if wide then
      local x = listWidth + 2
      for y = 4, h - 4 do
        put(x, y, "|", colors.gray)
      end
      local app = list[selected]
      if app then
        header(4, "GAME DETAILS")
        put(x + 2, 5, brief(app.name, w - x - 4), colors.white, colors.blue, w - x - 3)
        put(x + 2, 7, brief(app.subtitle or "", w - x - 4), colors.orange)
        put(x + 2, 9, "TYPE   " .. (app.genre or ""), colors.cyan)
        put(x + 2, 10, "VERS   " .. (app.version or "?"), colors.lightGray)
        put(x + 2, 12, "ABOUT", colors.yellow)
        printDescription(app, x + 2, 13, w - x - 4, math.max(1, h - 21))
        button(x + 2, h - 4, "DETAILS", "detail")
      end
    end
    local x = 2
    x = button(x, h - 3, "DETAILS", "detail", nil, false, #list > 0)
    x = button(x, h - 3, list[selected] and manager.installed(list[selected]) and "LAUNCH" or "INSTALL", "primary", nil, false, #list > 0)
    button(x, h - 3, "SETUP", "settings")
    bottom("UP/DOWN Select  ENTER Details  / Find  S Setup")
  end
  local function launchTarget(app)
    return prefs.launchTargets[app.id] or "ask"
  end
  local function targetRow(app, y)
    put(2, y, "START ON", colors.lightGray)
    local x = 12
    for _, name in ipairs({ "term", "monitor", "ask" }) do
      local label = name == "monitor" and "MON" or name:upper()
      x = button(x, y, label, "target", name, launchTarget(app) == name, true)
    end
  end
  local function detail()
    local app = current()
    if not app then
      return
    end
    local s = manager.status(app)
    put(2, 4, brief(app.name, w - 16), colors.white, colors.blue, w - 3)
    right(4, "v" .. (app.version or "?"), colors.lime, 2)
    put(2, 5, brief((app.subtitle or "") .. " / " .. (app.genre or ""), w - 4), colors.yellow)
    put(2, 6, ("-"):rep(w - 3), colors.gray)
    printDescription(app, 2, 7, w - 4, 3)
    put(2, 10, "STATUS", colors.lightGray)
    put(15, 10, s.installed and (s.updateAvailable and "UPDATE AVAILABLE" or "INSTALLED") or (s.managed and "DISK MISSING" or "NOT INSTALLED"), s.installed and colors.lime or colors.orange)
    put(2, 11, "SOURCE", colors.lightGray)
    put(15, 11, brief(source and source.label or (s.source and s.source.label) or "main", w - 16), colors.lightBlue)
    put(2, 12, "LOCATION", colors.lightGray)
    put(15, 12, brief(s.root or app.root or "", w - 16), colors.white)
    if h >= 17 then
      targetRow(app, 14)
    end
    local x = 2
    if s.installed then
      x = button(x, h - 4, "LAUNCH", "launch")
      x = button(x, h - 4, s.updateAvailable and "UPDATE" or "REINSTALL", "install")
      button(x, h - 4, "BUILD", "source")
      x = 2
      x = button(x, h - 3, "REMOVE", "remove")
      button(x, h - 3, "BACK", "back")
    else
      x = button(x, h - 4, "INSTALL", "install")
      x = button(x, h - 4, "BUILD", "source")
      button(x, h - 4, "BACK", "back")
    end
    bottom("ESC Back  I Install  B Build  T Target")
  end
  local function disks(app)
    return manager.disks and manager.disks(app) or { { root = app.root, name = "Computer" } }
  end
  local function beginInstall(app)
    if not app then
      return
    end
    local choices = disks(app)
    local s = manager.status(app)
    installRoot = s.root or app.root
    installIndex = 1
    for i, d in ipairs(choices) do
      if d.root == installRoot then
        installIndex = i
      end
    end
    installRoot = choices[installIndex] and choices[installIndex].root or app.root
    installOpus = prefs.opusApps ~= false and prefs.opusShortcuts[app.id] ~= false
    installTarget = launchTarget(app)
    page = "install"
  end
  local function installPage()
    local app = current()
    if not app then
      return
    end
    header(4, "INSTALL / REINSTALL")
    put(2, 5, brief(app.name .. " v" .. (app.version or "?"), w - 4), colors.white)
    put(2, 7, "DESTINATION", colors.yellow)
    local choices = disks(app)
    if not choices[installIndex] then
      installIndex = 1
    end
    local disk = choices[installIndex]
    installRoot = disk.root
    put(2, 8, brief((disk.name or "Computer") .. "  " .. disk.root, w - 4), colors.lightBlue)
    button(2, 9, "<", "disk", -1, false, #choices > 1)
    button(7, 9, ">", "disk", 1, false, #choices > 1)
    put(14, 9, #choices .. " available location(s)", colors.lightGray)
    put(2, 11, "SOURCE", colors.yellow)
    local s = manager.status(app)
    local selectedSource = source and source.label or (s.source and s.source.label) or "main"
    put(12, 11, brief(selectedSource, w - 25), colors.lightBlue)
    button(w - 11, 11, "CHANGE", "source")
    if h >= 19 then
      put(2, 13, "OPUS SHORTCUT", colors.lightGray)
      button(19, 13, installOpus and "YES" or "NO", "opus")
      put(2, 14, "START ON", colors.lightGray)
      local x = 13
      for _, name in ipairs({ "term", "monitor", "ask" }) do
        x = button(x, 14, name == "monitor" and "MON" or name:upper(), "install-target", name, installTarget == name)
      end
    end
    local x = 2
    x = button(x, h - 4, "INSTALL NOW", "confirm-install")
    button(x, h - 4, "CANCEL", "back")
    put(2, h - 3, brief("Saves and user files are preserved.", w - 4), colors.lightGray)
    bottom("ENTER Install  LEFT/RIGHT Disk  B Build  ESC Back")
  end
  local function sourcePage()
    local app = current()
    header(4, "SELECT BUILD SOURCE")
    put(2, 5, brief(app and app.name or "", w - 4), colors.white)
    local x = 2
    for _, mode in ipairs({ "main", "pr", "branch" }) do
      x = button(x, 7, mode:upper(), "source-mode", mode, sourceMode == mode)
    end
    if sourceMode == "main" then
      put(2, 9, "Stable release from main.", colors.lightGray)
    else
      put(2, 9, sourceMode == "pr" and "PR number or URL:" or "Branch name or URL:", colors.lightGray)
      put(2, 10, "> " .. brief(sourceInput .. "_", w - 5), colors.yellow)
      hit(2, 10, w - 3, "source-input")
    end
    local x2 = 2
    x2 = button(x2, h - 4, "USE BUILD", "source-save")
    button(x2, h - 4, "CANCEL", "source-cancel")
    bottom("TAB Source  TYPE/Paste Build  ENTER Select  ESC Back")
  end
  local function settingsPage()
    header(4, "STORE SETTINGS")
    put(2, 6, "STORE SCREEN", colors.lightGray)
    local x = 2
    for _, name in ipairs({ "auto", "term", "monitor" }) do
      x = button(x, 7, name == "monitor" and "MON" or name:upper(), "display", name, prefs.display == name)
    end
    put(2, 9, "Auto prefers external monitor.", colors.lightGray)
    local monitorCount = #monitors
    put(2, 11, monitorCount .. " MONITOR(S) DETECTED", monitorCount > 0 and colors.lime or colors.orange)
    if h >= 19 then
      put(2, 13, "OPUS STORE", colors.lightGray)
      button(23, 13, prefs.opusStore and "ON" or "OFF", "opus-store")
      put(2, 14, "OPUS INSTALLED APPS", colors.lightGray)
      button(23, 14, prefs.opusApps and "ON" or "OFF", "opus-apps")
    end
    button(2, h - 4, "DONE", "back")
    bottom("Click options  M Screen  O Opus  ESC Back")
  end
  local function removePage()
    local app = confirmApp
    header(5, "REMOVE " .. (app and app.name or "") .. "?")
    put(2, 7, "Only managed program files", colors.lightGray)
    put(2, 8, "will be removed.", colors.lightGray)
    put(2, 10, "Saves remain untouched.", colors.lime)
    local x = button(2, h - 4, "CANCEL", "back")
    button(x, h - 4, "REMOVE", "confirm-remove")
    bottom("ENTER Confirm removal  ESC Cancel")
  end
  local function launchPage()
    header(5, "CHOOSE LAUNCH SCREEN")
    put(2, 7, brief(current() and current().name or "", w - 4), colors.white)
    local x = 2
    x = button(x, 10, "TERMINAL", "launch-term")
    button(x, 10, "MONITOR", "launch-monitor", nil, false, #monitors > 0)
    button(2, h - 4, "CANCEL", "back")
    bottom("Select display  ESC Cancel")
  end
  local function diagnostic()
    put(1, 4, " OPERATION FAILED", colors.white, colors.red, w)
    for y = 5, h - 3 do
      put(2, y, brief(errLines[errorTop + y - 5] or "", w - 3))
    end
    button(2, h - 3, "BACK", "back")
    bottom("UP/DOWN Scroll  ENTER Back  ESC Back")
  end
  local function redraw()
    if term.redirect then
      term.redirect(host)
    end
    w, h = host.getSize()
    reset(host)
    host.clear()
    hits = {}
    if w < 26 or h < 12 then
      put(1, 1, "FPB STORE", colors.orange)
      put(1, 3, "Minimum: 26 x 12", colors.yellow)
      put(1, h, "Q Exit", colors.lightGray)
      return
    end
    top()
    if page == "browse" then
      browse()
    elseif page == "detail" then
      detail()
    elseif page == "install" then
      installPage()
    elseif page == "source" then
      sourcePage()
    elseif page == "settings" then
      settingsPage()
    elseif page == "remove" then
      removePage()
    elseif page == "launch" then
      launchPage()
    elseif page == "error" then
      diagnostic()
    end
  end
  local function splash()
    w, h = host.getSize()
    if w < 26 or h < 12 then
      return
    end
    local art = {
      "FFFF  PPPP  BBBB",
      "F     P   P B   B",
      "FFF   PPPP  BBBB",
      "F     P     B   B",
      "F     P     BBBB",
    }
    reset(host)
    host.clear()
    local startX, startY = math.max(2, math.floor((w - 18) / 2)), math.max(2, math.floor((h - 10) / 2))
    for row, line in ipairs(art) do
      put(startX, startY + row, line, row == 3 and colors.orange or colors.lightBlue)
      if type(sleep) == "function" then
        sleep(0.045)
      end
    end
    put(startX + 4, startY + 7, "S T O R E", colors.orange)
    put(startX, startY + 9, "Loading catalog...", colors.lightGray)
    if type(sleep) == "function" then
      sleep(0.12)
    end
  end
  local function fail(why)
    errLines = {}
    for line in (tostring(why) .. "\n"):gmatch("(.-)\n") do
      local width = math.max(1, w - 3)
      repeat
        errLines[#errLines + 1] = line:sub(1, width)
        line = line:sub(width + 1)
      until #line == 0
    end
    errorTop = 1
    page = "error"
    message = "Operation failed. View details above."
  end
  local function operation(fn, success)
    local ok, result = pcall(fn)
    if not ok then
      fail(result)
    else
      message = success
    end
    return ok, result
  end
  local function syncPrefs()
    if manager.savePreferences then
      operation(function()
        manager.savePreferences(prefs)
      end, "Preferences saved")
    else
      message = "Preferences updated"
    end
  end
  local function switchDisplay()
    local previous = host
    local nextHost = prefs.display == "term" and native or (monitor() or native)
    if previous ~= nextHost then
      capture(nextHost)
      host = nextHost
      if host ~= native and host.setTextScale then
        pcall(host.setTextScale, 0.5)
      end
      reset(previous)
      message = nextHost == native and "Showing Store on terminal" or "Showing Store on external monitor"
    end
  end
  local function runApp(target)
    local app = current()
    if not app or not manager.installed(app) then
      return
    end
    local dest = target == "monitor" and monitor() or native
    if target == "monitor" and not dest then
      message = "Monitor disconnected. Select terminal."
      page = "launch"
      return
    end
    capture(dest)
    if dest ~= native and dest.setTextScale then
      pcall(dest.setTextScale, 0.5)
    end
    reset(dest)
    if term.redirect then
      term.redirect(dest)
    end
    local ok, err = pcall(manager.launch, app)
    reset(dest)
    if term.redirect then
      term.redirect(host)
    end
    if ok then
      message = "Returned from " .. app.name
      page = "detail"
    else
      fail(err)
    end
  end
  local function launchApp()
    local app = current()
    if not app or not manager.installed(app) then
      return
    end
    local target = launchTarget(app)
    if target == "ask" or (target == "monitor" and not monitor()) then
      pendingLaunch = app.id
      page = "launch"
      if target == "monitor" then
        message = "Monitor missing. Select terminal."
      end
    else
      runApp(target)
    end
  end
  local function back()
    if page == "source" then
      page = sourceReturn
    elseif page == "detail" then
      page = "browse"
    elseif page == "error" then
      page = "detail"
    elseif page == "browse" then
      return "quit"
    else
      page = "detail"
    end
    return nil
  end
  local function perform(action, value)
    local app = current()
    if action == "tab" then
      tab, selected, offset, page = value, 1, 0, "browse"
    elseif action == "search" then
      typing = true
      page = "browse"
    elseif action == "select" then
      if value == selected then
        page = "detail"
      else
        selected = value
      end
    elseif action == "detail" and app then
      page = "detail"
    elseif action == "primary" and app then
      if manager.installed(app) then
        launchApp()
      else
        beginInstall(app)
      end
    elseif action == "settings" then
      page = "settings"
    elseif action == "display" then
      prefs.display = value
      syncPrefs()
      switchDisplay()
    elseif action == "opus-store" then
      prefs.opusStore = not prefs.opusStore
      syncPrefs()
    elseif action == "opus-apps" then
      prefs.opusApps = not prefs.opusApps
      syncPrefs()
    elseif action == "target" and app then
      prefs.launchTargets[app.id] = value
      syncPrefs()
      message = "Launch target: " .. value
    elseif action == "install-target" then
      installTarget = value
    elseif action == "install" and app then
      beginInstall(app)
    elseif action == "disk" and app then
      local available = disks(app)
      installIndex = ((installIndex - 1 + value) % #available) + 1
      installRoot = available[installIndex].root
    elseif action == "opus" then
      installOpus = not installOpus
    elseif action == "source" and app then
      sourceReturn = page == "install" and "install" or "detail"
      page = "source"
      local currentSource = source or (manager.installedSource and manager.installedSource(app)) or { kind = "main", value = "main" }
      sourceMode = currentSource.kind
      sourceInput = sourceMode == "main" and "" or currentSource.value
    elseif action == "source-mode" then
      sourceMode, sourceInput = value, ""
      typing = value ~= "main" and "source" or false
    elseif action == "source-input" then
      typing = "source"
    elseif action == "source-save" then
      if manager.parseSource then
        local ok, result = pcall(manager.parseSource, sourceMode == "main" and "main" or sourceInput, sourceMode)
        if not ok then
          fail(result)
          return
        end
        source = result
      end
      page = sourceReturn
      typing = false
      message = "Build selected. Confirm install to apply."
      if page == "detail" then
        beginInstall(app)
      end
    elseif action == "source-cancel" then
      typing = false
      page = sourceReturn
    elseif action == "confirm-install" and app then
      local chosenRoot = installRoot
      local chosenSource = source
      local chosenTarget = installTarget
      local chosenOpus = installOpus
      local ok = operation(function()
        manager.install(app, chosenSource, chosenRoot)
      end, "Installed " .. app.name .. " to " .. chosenRoot)
      if ok then
        prefs.launchTargets[app.id] = chosenTarget
        prefs.opusShortcuts[app.id] = chosenOpus
        if manager.savePreferences then
          manager.savePreferences(prefs)
        end
        page = "detail"
        source = nil
      end
    elseif action == "launch" and app then
      launchApp()
    elseif action == "launch-term" then
      runApp("term")
    elseif action == "launch-monitor" then
      runApp("monitor")
    elseif action == "remove" and app then
      confirmApp = app
      page = "remove"
    elseif action == "confirm-remove" and confirmApp then
      local removed = confirmApp
      if operation(function()
        manager.remove(removed, false)
      end, "Removed " .. removed.name .. "; saves preserved") then
        page, confirmApp = "browse", nil
      end
    elseif action == "refresh" then
      operation(function()
        local ok, reason = manager.refreshVersions()
        if not ok then
          error(reason or "Catalog unavailable")
        end
      end, "Catalog refreshed")
    elseif action == "store-update" then
      if operation(function()
        manager.updateStore()
      end, "Store updated") then
        return "reload"
      end
    elseif action == "back" then
      return back()
    end
    return nil
  end

  splash()
  if manager.syncOpus then
    pcall(manager.syncOpus)
  end
  local online = manager.refreshVersions()
  message = online and "Catalog checked. Choose a title." or "Offline: installed apps still launch."
  while true do
    redraw()
    local event, a, b, c = os.pullEvent()
    local action, value
    if event == "peripheral" or event == "peripheral_detach" or event == "monitor_resize" or event == "term_resize" then
      monitor()
      if host ~= native and not (prefs.display == "term") and #monitors == 0 then
        host = native
        message = "Monitor disconnected. Store moved to terminal."
      elseif prefs.display == "auto" and host == native and #monitors > 0 then
        switchDisplay()
      end
    elseif w < 26 or h < 12 then
      if (event == "char" and a:lower() == "q") or (event == "key" and a == keys.escape) then
        restore()
        return
      end
    elseif typing then
      if event == "char" or event == "paste" then
        if typing == "source" then
          sourceInput = (sourceInput .. a):sub(1, 200)
        else
          query = (query .. a):sub(1, 100)
          selected, offset = 1, 0
        end
      elseif event == "key" and a == keys.tab and typing == "source" then
        action, value = "source-mode", sourceMode == "main" and "pr" or sourceMode == "pr" and "branch" or "main"
      elseif event == "key" and a == keys.backspace then
        if typing == "source" then
          sourceInput = sourceInput:sub(1, -2)
        else
          query = query:sub(1, -2)
        end
      elseif event == "key" and (a == keys.escape or a == keys.enter) then
        typing = false
        if page == "source" and a == keys.enter then
          action = "source-save"
        end
      end
    elseif event == "mouse_click" or event == "monitor_touch" then
      if event == "mouse_click" and host == native or event == "monitor_touch" and host ~= native and monitors[1] and a == monitors[1].name then
        local x, y = b, c
        for _, item in ipairs(hits) do
          if y == item.y and x >= item.x and x < item.x + item.width then
            action, value = item.action, item.value
            break
          end
        end
      end
    elseif event == "mouse_scroll" then
      if page == "browse" then
        selected = math.max(1, math.min(#currentList(), selected + a))
      elseif page == "error" then
        errorTop = math.max(1, math.min(#errLines, errorTop + a * 3))
      end
    elseif event == "key" then
      if a == keys.escape then
        action = "back"
      elseif a == keys.enter then
        if page == "browse" then
          action = "detail"
        elseif page == "install" then
          action = "confirm-install"
        elseif page == "source" then
          action = "source-save"
        elseif page == "remove" then
          action = "confirm-remove"
        elseif page == "error" or page == "settings" then
          action = "back"
        elseif page == "detail" then
          action = manager.installed(current()) and "launch" or "install"
        elseif page == "launch" then
          action = "launch-term"
        end
      elseif a == keys.up or a == keys.down then
        local direction = a == keys.up and -1 or 1
        if page == "browse" then
          selected = math.max(1, math.min(#currentList(), selected + direction))
        elseif page == "error" then
          errorTop = math.max(1, math.min(#errLines, errorTop + direction))
        elseif page == "install" and current() then
          action, value = "disk", direction
        end
      elseif a == keys.pageUp or a == keys.pageDown then
        if page == "browse" then
          selected = math.max(1, math.min(#currentList(), selected + (a == keys.pageUp and -8 or 8)))
        end
      elseif a == keys.tab then
        if page == "browse" then
          local order = { "GAMES", "APPS", "INSTALLED", "UPDATES" }
          for i, name in ipairs(order) do
            if tab == name then
              action, value = "tab", order[i % #order + 1]
              break
            end
          end
        elseif page == "source" then
          action, value = "source-mode", sourceMode == "main" and "pr" or sourceMode == "pr" and "branch" or "main"
        end
      elseif page == "browse" and a == keys.space then
        action = "primary"
      end
    elseif event == "char" then
      local key = a:lower()
      if key == "q" then
        action = "back"
      elseif key == "/" and page == "browse" then
        action = "search"
      elseif key == "s" then
        action = "settings"
      elseif key == "i" then
        action = "install"
      elseif key == "b" then
        action = "source"
      elseif key == "d" then
        action = "remove"
      elseif key == "r" then
        action = "refresh"
      elseif key == "u" then
        action = "store-update"
      elseif key == "t" and page == "detail" and current() then
        local target = launchTarget(current())
        action, value = "target", target == "term" and "monitor" or target == "monitor" and "ask" or "term"
      elseif key == "m" and page == "settings" then
        action, value = "display", prefs.display == "auto" and "term" or prefs.display == "term" and "monitor" or "auto"
      elseif key == "o" and page == "settings" then
        action = "opus-apps"
      elseif key == "o" and page == "install" then
        action = "opus"
      end
    end
    if action then
      local result = perform(action, value)
      if result == "quit" then
        restore()
        return
      elseif result == "reload" then
        restore()
        return "reload"
      end
    end
  end
end

return UI
