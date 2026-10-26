-- FPB Store: Basalt 2.5 storefront. All actions are touchable and keyboard reachable.
local U = {}

local function shorten(value, width)
  value = tostring(value or "")
  width = math.max(1, width)
  return #value > width and value:sub(1, math.max(1, width - 2)) .. ".." or value
end

local function wrap(value, width, rows)
  local result, line = {}, ""
  for word in tostring(value or ""):gmatch("%S+") do
    if #line > 0 and #line + #word + 1 > width then
      result[#result + 1], line = line, ""
    end
    line = line .. (line == "" and "" or " ") .. word
  end
  if line ~= "" then
    result[#result + 1] = line
  end
  while #result > rows do
    table.remove(result)
  end
  return result
end

function U.run(manager, basalt)
  local native = term.current()
  local prefs = manager.preferences()
  prefs.launchTargets = prefs.launchTargets or {}
  prefs.opusShortcuts = prefs.opusShortcuts or {}
  local monitors = manager.monitors()
  local activeMonitor = (prefs.display ~= "term") and monitors[1] or nil
  local host = activeMonitor and activeMonitor.screen or native
  if activeMonitor and host.setTextScale then
    pcall(host.setTextScale, 0.5)
  end

  local oldMouseEvents
  if activeMonitor and config and config.get and config.set then
    local ok, value = pcall(config.get, "monitorsUseMouseEvents")
    if ok then
      oldMouseEvents = value
      pcall(config.set, "monitorsUseMouseEvents", false)
    end
  end
  local palettes = {}
  if host.getPaletteColor then
    for i = 0, 15 do
      local color = 2 ^ i
      palettes[color] = { host.getPaletteColor(color) }
    end
  end
  local function restore()
    term.redirect(native)
    if host.setGraphicsMode then
      pcall(host.setGraphicsMode, 0)
    end
    if host.setPaletteColor then
      for color, rgb in pairs(palettes) do
        pcall(host.setPaletteColor, color, table.unpack(rgb))
      end
    end
    if oldMouseEvents ~= nil and config and config.set then
      pcall(config.set, "monitorsUseMouseEvents", oldMouseEvents)
    end
  end
  local w, h = host.getSize()
  local compact = w < 50 or h < 18
  if w < 26 or h < 12 then
    restore()
    error("FPB Store needs at least a 26x12 terminal (monitor scale 0.5)", 0)
  end
  -- The splash is intentionally character-cell based, not a graphics bitmap.
  host.setBackgroundColor(colors.black)
  host.setTextColor(colors.orange)
  host.clear()
  local splash = { "FFFF  PPPP  BBBB", "F     P   P B   B", "FFF   PPPP  BBBB", "F     P     B   B", "F     P     BBBB" }
  for i, line in ipairs(splash) do
    host.setCursorPos(math.max(1, math.floor((w - #line) / 2)), math.max(1, math.floor((h - 6) / 2)) + i - 1)
    host.write(line)
    if type(sleep) == "function" then
      sleep(0.025)
    end
  end

  local frame = activeMonitor and basalt.createFrame(host, activeMonitor.name) or basalt.getMainFrame()
  frame.background = colors.black
  local view = nil
  local tab, page, selected, searchText = "GAMES", "browse", nil, ""
  local sourceMode, sourceInput, sourceValue = "main", "", nil
  local installIndex, installOpus, installTarget = 1, true, "ask"
  local message, failed = "Select a title to view details.", nil
  local returnCode, previousPage, keyboardField, keyboardOffset = nil, "browse", nil, 0
  local actionButtons, focusIndex = {}, 1
  local showPage, runAction

  local function apps()
    local result = {}
    for _, app in ipairs(manager.catalog.apps) do
      local status = manager.status(app)
      local category = app.category or "Games"
      local categoryMatch = (tab == "GAMES" and category == "Games")
        or (tab == "APPS" and category == "Apps")
        or (tab == "INSTALLED" and status.installed)
        or (tab == "UPDATES" and status.installed and status.updateAvailable)
      local haystack = (app.name .. " " .. (app.subtitle or "") .. " " .. (app.genre or "") .. " " .. (app.description or "")):lower()
      if categoryMatch and haystack:find(searchText:lower(), 1, true) then
        result[#result + 1] = app
      end
    end
    if #result > 0 and not selected then
      selected = result[1]
    end
    return result
  end
  local function current()
    for _, app in ipairs(apps()) do
      if app == selected then
        return app
      end
    end
    return apps()[1]
  end
  local function save()
    manager.savePreferences(prefs)
  end
  local function notify(value)
    message = value
    failed = nil
  end
  local function execute(fn, success)
    local ok, result = pcall(fn)
    if ok then
      notify(success or "Done")
    else
      failed = tostring(result)
      message = "Operation failed"
      page = "error"
    end
    return ok, result
  end
  local function back()
    if page == "browse" then
      returnCode = "exit"
      basalt.stop()
    elseif page == "keyboard" then
      page = previousPage
    elseif page == "source" then
      page = previousPage
    elseif page == "detail" then
      page = "browse"
    elseif page == "error" then
      page = "detail"
    elseif page == "menu" then
      page = "browse"
    elseif page == "manage" or page == "remove" then
      page = "detail"
    elseif page == "options" then
      page = "install"
    elseif page == "opus_settings" then
      page = "settings"
    else
      page = "detail"
    end
    showPage()
  end

  local function registerKey(element)
    element:onKey(function(_, code)
      if code == keys.escape then
        back()
      elseif code == keys.tab then
        if #actionButtons > 0 then
          focusIndex = focusIndex % #actionButtons + 1
          actionButtons[focusIndex]:focus()
        end
      end
    end)
    return element
  end
  local function label(x, y, text, color, width, parent)
    return (parent or view):addLabel({
      x = x,
      y = y,
      width = width or math.max(1, w - x),
      text = shorten(text, width or w - x),
      foreground = color or colors.white,
    })
  end
  local function button(x, y, width, text, callback, color, parent)
    if x + width > w + 1 or y > h - 1 then
      return nil
    end
    local control = (parent or view):addButton({
      x = x,
      y = y,
      width = width,
      height = 1,
      text = shorten(text, width),
      foreground = colors.white,
      background = color or colors.blue,
    })
    control:onClick(callback)
    registerKey(control)
    control:onKey(function(_, code)
      if code == keys.enter or code == keys.space then
        callback()
      end
    end)
    actionButtons[#actionButtons + 1] = control
    return control
  end
  local function nav()
    view:addFrame({ x = 1, y = 1, width = w, height = 1, background = colors.gray })
    label(2, 1, "FPB STORE " .. (manager.storeStatus().installedVersion or ""), colors.orange, 22)
    local tabs = compact and { "GAMES", "APPS" } or { "GAMES", "APPS", "INSTALLED", "UPDATES" }
    local x = 2
    for _, name in ipairs(tabs) do
      local width = #name + 2
      if x + width < w then
        button(x, 2, width, name, function()
          tab, selected, page = name, nil, "browse"
          showPage()
        end, tab == name and colors.orange or colors.blue)
        x = x + width + 1
      end
    end
    if compact then
      button(17, 2, 9, "NEXT", function()
        local order = { "GAMES", "APPS", "INSTALLED", "UPDATES" }
        for i, name in ipairs(order) do
          if name == tab then
            tab, selected, page = order[i % #order + 1], nil, "browse"
            break
          end
        end
        showPage()
      end)
      button(2, 3, 10, "MENU", function()
        page = "menu"
        showPage()
      end)
    end
    label(2, h, shorten(message, w - 3), failed and colors.red or colors.lightGray, w - 2)
  end
  local function title(text)
    label(2, 4, text, colors.yellow, w - 3)
  end
  local function keyFocus(control)
    if control then
      control:focus()
    elseif #actionButtons > 0 then
      focusIndex = 1
      actionButtons[1]:focus()
    end
  end
  local function startKeyboard(field)
    keyboardField, previousPage, keyboardOffset, page = field, page, 0, "keyboard"
    showPage()
  end
  local function source()
    title("BUILD SOURCE")
    local x = 2
    for _, mode in ipairs({ "main", "pr", "branch" }) do
      local width = #mode + 3
      button(x, 6, width, mode:upper(), function()
        sourceMode = mode
        sourceInput = ""
        showPage()
      end, sourceMode == mode and colors.orange or colors.blue)
      x = x + width + 1
    end
    if compact then
      label(2, 7, sourceMode == "main" and "Stable release" or "PR / branch ref:", colors.lightGray)
      local input
      if sourceMode ~= "main" then
        input = view:addInput({ x = 2, y = 8, width = math.max(8, w - 14), text = sourceInput, placeholder = "Type source" })
        input:onChange(function(self)
          sourceInput = self.text
        end)
        input:onEnter(function()
          runAction("source-save")
        end)
        registerKey(input)
        button(w - 10, 8, 9, "KEYS", function()
          startKeyboard("source")
        end)
      end
      button(2, 9, 13, "USE SOURCE", function()
        runAction("source-save")
      end)
      button(16, 9, 9, "BACK", back)
      keyFocus(input)
      return
    end
    local edit
    if sourceMode == "main" then
      label(2, 8, "Install from stable main.", colors.white)
    else
      label(2, 8, sourceMode == "pr" and "PR number / URL" or "Branch name / URL", colors.lightGray)
      edit = view:addInput({ x = 2, y = 9, width = math.max(8, w - 14), text = sourceInput, placeholder = "Type source" })
      edit:onChange(function(self)
        sourceInput = self.text
      end)
      edit:onEnter(function()
        runAction("source-save")
      end)
      registerKey(edit)
      button(w - 10, 9, 9, "KEYS", function()
        startKeyboard("source")
      end)
    end
    button(2, h - 3, 13, "USE SOURCE", function()
      runAction("source-save")
    end)
    button(17, h - 3, 9, "BACK", back)
    keyFocus(edit)
  end
  local function settings()
    title("STORE SETTINGS")
    label(2, 6, "Store display:", colors.lightGray)
    local x = 2
    for _, mode in ipairs({ "auto", "term", "monitor" }) do
      local width = #mode + 3
      button(x, 7, width, mode:upper(), function()
        prefs.display = mode
        save()
        returnCode = "restart"
        basalt.stop()
      end, prefs.display == mode and colors.orange or colors.blue)
      x = x + width + 1
    end
    if compact then
      label(2, 8, #manager.monitors() .. " monitor(s) attached", colors.cyan)
      button(2, 9, 12, "OPUS", function()
        page = "opus_settings"
        showPage()
      end)
      button(14, 9, 10, "BACK", back)
      keyFocus()
      return
    end
    label(2, 9, "Opus shortcuts:", colors.lightGray)
    button(2, 10, 14, prefs.opusStore and "STORE ON" or "STORE OFF", function()
      prefs.opusStore = not prefs.opusStore
      save()
      showPage()
    end)
    button(18, 10, 14, prefs.opusApps and "APPS ON" or "APPS OFF", function()
      prefs.opusApps = not prefs.opusApps
      save()
      showPage()
    end)
    local available = manager.monitors()
    label(2, 12, #available .. " attached monitor(s)", colors.cyan)
    button(2, h - 3, 12, "BACK", back)
    keyFocus()
  end
  local function detail()
    local app = current()
    if not app then
      page = "browse"
      return showPage()
    end
    local status = manager.status(app)
    title(app.name)
    label(2, 5, (app.subtitle or "") .. " / " .. (app.genre or ""), colors.orange)
    if compact then
      for i, line in ipairs(wrap(app.description, w - 4, 2)) do
        label(2, 5 + i, line, colors.white)
      end
      button(2, 8, 10, status.installed and "LAUNCH" or "INSTALL", function()
        runAction(status.installed and "launch" or "install")
      end)
      button(14, 8, 10, "BUILD", function()
        previousPage, page = "detail", "source"
        showPage()
      end)
      button(2, 9, 10, "MANAGE", function()
        page = "manage"
        showPage()
      end)
      button(14, 9, 10, "BACK", back)
      keyFocus()
      return
    end
    local lines = wrap(app.description, w - 4, 3)
    for i, line in ipairs(lines) do
      label(2, 6 + i, line, colors.white)
    end
    label(2, 10, status.installed and (status.updateAvailable and "UPDATE AVAILABLE" or "INSTALLED") or "NOT INSTALLED", status.installed and colors.lime or colors.yellow)
    label(2, 11, "Source: " .. (status.source and status.source.label or "main"), colors.lightBlue)
    label(2, 12, "Path: " .. (status.root or app.root), colors.lightGray)
    if h >= 17 then
      label(2, 13, "Launch on:", colors.lightGray)
      local x = 13
      for _, mode in ipairs({ "term", "monitor", "ask" }) do
        local caption = mode == "monitor" and "MON" or mode:upper()
        local width = #caption + 2
        button(x, 13, width, caption, function()
          prefs.launchTargets[app.id] = mode
          save()
          showPage()
        end, (prefs.launchTargets[app.id] or "ask") == mode and colors.orange or colors.blue)
        x = x + width + 1
      end
    end
    local x = 2
    local primary = status.installed and "LAUNCH" or "INSTALL"
    button(x, h - 4, 11, primary, function()
      runAction(status.installed and "launch" or "install")
    end)
    button(14, h - 4, 10, "BUILD", function()
      previousPage, page = "detail", "source"
      showPage()
    end)
    if status.installed then
      button(26, h - 4, 10, "UPDATE", function()
        runAction("install")
      end)
      button(38, h - 4, 10, "REMOVE", function()
        page = "remove"
        showPage()
      end, colors.red)
    end
    button(2, h - 3, 10, "BACK", back)
    keyFocus()
  end
  local function beginInstall()
    local app = current()
    if not app then
      return
    end
    local available = manager.disks(app)
    installIndex = 1
    local installedRoot = manager.installRoot(app)
    for i, drive in ipairs(available) do
      if drive.root == installedRoot then
        installIndex = i
      end
    end
    installTarget = prefs.launchTargets[app.id] or "ask"
    installOpus = prefs.opusShortcuts[app.id] ~= false
    page = "install"
    showPage()
  end
  local function install()
    local app = current()
    if not app then
      return
    end
    local available = manager.disks(app)
    installIndex = math.min(installIndex, #available)
    local disk = available[installIndex]
    if compact then
      title("INSTALL " .. app.name)
      label(2, 5, "Destination: " .. disk.name, colors.yellow)
      label(2, 6, disk.root, colors.lightBlue)
      button(2, 7, 8, "< DISK", function()
        installIndex = (installIndex - 2 + #available) % #available + 1
        showPage()
      end)
      button(12, 7, 8, "DISK >", function()
        installIndex = installIndex % #available + 1
        showPage()
      end)
      button(2, 8, 12, "SOURCE", function()
        previousPage, page = "install", "source"
        showPage()
      end)
      button(15, 8, 11, "OPTIONS", function()
        page = "options"
        showPage()
      end)
      button(2, 9, 13, "INSTALL NOW", function()
        runAction("install-now")
      end)
      button(16, 9, 9, "BACK", back)
      keyFocus()
      return
    end
    title("INSTALL " .. app.name)
    label(2, 6, "Destination: " .. disk.name, colors.yellow)
    label(2, 7, disk.root, colors.lightBlue)
    button(2, 8, 8, "< DISK", function()
      installIndex = (installIndex - 2 + #available) % #available + 1
      showPage()
    end)
    button(12, 8, 8, "DISK >", function()
      installIndex = installIndex % #available + 1
      showPage()
    end)
    label(2, 10, "Source: " .. (sourceValue and sourceValue.label or manager.installedSource(app).label), colors.cyan)
    button(2, 11, 14, "BUILD SOURCE", function()
      previousPage, page = "install", "source"
      showPage()
    end)
    if h >= 19 then
      button(2, 13, 16, installOpus and "OPUS SHORTCUT +" or "OPUS SHORTCUT -", function()
        installOpus = not installOpus
        showPage()
      end)
      local x = 2
      for _, mode in ipairs({ "term", "monitor", "ask" }) do
        local width = mode == "monitor" and 12 or 9
        button(x, 14, width, mode == "monitor" and "MONITOR" or mode:upper(), function()
          installTarget = mode
          showPage()
        end, installTarget == mode and colors.orange or colors.blue)
        x = x + width + 1
      end
    end
    button(2, h - 3, 16, "INSTALL NOW", function()
      runAction("install-now")
    end)
    button(20, h - 3, 10, "BACK", back)
    keyFocus()
  end
  local function launchChoice()
    title("LAUNCH ON")
    local app = current()
    label(2, 6, app and app.name or "", colors.white)
    button(2, 8, 14, "TERMINAL", function()
      runAction("launch-term")
    end)
    button(18, 8, 14, "MONITOR", function()
      runAction("launch-monitor")
    end)
    if type(periphemu) == "table" and type(periphemu.create) == "function" then
      label(2, 10, "CraftOS-PC can create a monitor.", colors.cyan)
    end
    button(2, h - 3, 12, "BACK", back)
    keyFocus()
  end
  local function keyboard()
    title("TOUCH KEYBOARD")
    local text = keyboardField == "search" and searchText or sourceInput
    label(2, 5, shorten(text .. "_", w - 4), colors.yellow)
    local alphabet = "1234567890QWERTYUIOPASDFGHJKLZXCVBNM-_. /:#?@"
    local countPerRow = math.max(1, math.floor((w - 3) / 4))
    local rows = math.max(1, math.min(3, h - 9))
    local pageSize = countPerRow * rows
    local pageCount = math.ceil(#alphabet / pageSize)
    keyboardOffset = math.max(0, math.min(keyboardOffset, pageCount - 1))
    local function append(char)
      if keyboardField == "search" then
        searchText = (searchText .. char):sub(1, 100)
      else
        sourceInput = (sourceInput .. char):sub(1, 200)
      end
      showPage()
    end
    for i = 1, pageSize do
      local index = keyboardOffset * pageSize + i
      if index > #alphabet then
        break
      end
      local char = alphabet:sub(index, index)
      local x = 2 + ((i - 1) % countPerRow) * 4
      local y = 6 + math.floor((i - 1) / countPerRow)
      button(x, y, 3, char == " " and "_" or char, function()
        append(char)
      end)
    end
    button(2, h - 3, 8, "PREV", function()
      keyboardOffset = math.max(0, keyboardOffset - 1)
      showPage()
    end)
    button(11, h - 3, 8, "NEXT", function()
      keyboardOffset = math.min(pageCount - 1, keyboardOffset + 1)
      showPage()
    end)
    button(20, h - 3, 6, "DEL", function()
      if keyboardField == "search" then
        searchText = searchText:sub(1, -2)
      else
        sourceInput = sourceInput:sub(1, -2)
      end
      showPage()
    end)
    button(2, h - 2, 10, "SPACE", function()
      append(" ")
    end)
    button(14, h - 2, 10, "DONE", back)
    keyFocus()
  end

  local function browse()
    title(tab == "GAMES" and "GAME LIBRARY" or tab)
    local input = view:addInput({
      x = 2,
      y = 5,
      width = math.max(6, w - 17),
      text = searchText,
      placeholder = "/ Search titles",
    })
    input:onChange(function(self)
      searchText = self.text
      selected = nil
      -- Search reacts without rebuilding the Input while the user types.
      -- Filter on Enter or via the SEARCH button below.
    end)
    input:onEnter(function()
      showPage()
    end)
    registerKey(input)
    button(w - 13, 5, 12, "KEYS", function()
      startKeyboard("search")
    end)
    local available = apps()
    local listWidth = w >= 72 and math.floor(w * 0.51) or w - 3
    local list = view:addList({
      x = 2,
      y = 7,
      width = listWidth,
      height = math.max(2, h - 11),
      scrollbar = "auto",
      items = {},
    })
    local selectedRow = 1
    local entries = {}
    for i, app in ipairs(available) do
      local status = manager.status(app)
      local tag = status.updateAvailable and "UPDATE" or status.installed and "READY" or "GET"
      entries[#entries + 1] = { text = shorten(app.name, listWidth - 11) .. "  " .. tag, value = app.id }
      if app == selected then
        selectedRow = i
      end
    end
    list:setItems(entries)
    list:onChange(function(_, index)
      selected = available[index]
    end)
    list:onSelect(function(_, index)
      selected = available[index]
      page = "detail"
      showPage()
    end)
    registerKey(list)
    if #entries > 0 then
      list:selectItem(selectedRow)
    end
    if w >= 72 and selected then
      local x = listWidth + 4
      label(x, 7, selected.name, colors.yellow, w - x - 1)
      label(x, 9, selected.subtitle or "", colors.orange, w - x - 1)
      for i, line in ipairs(wrap(selected.description, w - x - 2, 5)) do
        label(x, i + 11, line, colors.white, w - x - 1)
      end
    end
    if compact then
      button(2, h - 3, 11, "DETAILS", function()
        if current() then
          page = "detail"
          showPage()
        end
      end)
      button(14, h - 3, 10, "MENU", function()
        page = "menu"
        showPage()
      end)
      keyFocus(list)
      return
    end
    button(2, h - 3, 11, "DETAILS", function()
      if current() then
        page = "detail"
        showPage()
      end
    end)
    button(15, h - 3, 11, "REFRESH", function()
      runAction("refresh")
    end)
    button(28, h - 3, 10, "SETUP", function()
      page = "settings"
      showPage()
    end)
    button(40, h - 3, 10, "EXIT", back)
    -- Give the keyboard an immediately useful focus target; lists natively
    -- implement arrows, PgUp/PgDn and Enter while touch can select items.
    keyFocus(list)
  end

  showPage = function()
    if view then
      view:destroy()
    end
    w, h = host.getSize()
    actionButtons, focusIndex = {}, 1
    view = frame:addFrame({ x = 1, y = 1, width = w, height = h, background = colors.black })
    nav()
    if page == "browse" then
      browse()
    elseif page == "detail" then
      detail()
    elseif page == "source" then
      source()
    elseif page == "install" then
      install()
    elseif page == "settings" then
      settings()
    elseif page == "launch" then
      launchChoice()
    elseif page == "keyboard" then
      keyboard()
    elseif page == "menu" then
      title("STORE MENU")
      button(2, 6, 14, "SETTINGS", function()
        page = "settings"
        showPage()
      end)
      button(2, 7, 14, "REFRESH", function()
        runAction("refresh")
      end)
      button(2, 8, 14, "UPDATE STORE", function()
        runAction("store-update")
      end)
      button(2, 9, 12, "EXIT", function()
        returnCode = "exit"
        basalt.stop()
      end)
      button(15, 9, 10, "BACK", back)
      keyFocus()
    elseif page == "manage" then
      title("MANAGE " .. (current() and current().name or ""))
      local app = current()
      local target = prefs.launchTargets[app.id] or "ask"
      label(2, 5, "Launch target:", colors.lightGray)
      local x = 2
      for _, mode in ipairs({ "term", "monitor", "ask" }) do
        local width = mode == "monitor" and 9 or 7
        button(x, 6, width, mode == "monitor" and "MON" or mode:upper(), function()
          prefs.launchTargets[app.id] = mode
          save()
          showPage()
        end, target == mode and colors.orange or colors.blue)
        x = x + width + 1
      end
      button(2, 8, 11, "REINSTALL", function()
        runAction("install")
      end)
      if manager.installed(app) then
        button(14, 8, 10, "REMOVE", function()
          page = "remove"
          showPage()
        end, colors.red)
      end
      button(2, 9, 9, "BACK", back)
      keyFocus()
    elseif page == "options" then
      title("INSTALL OPTIONS")
      label(2, 5, "Run on: " .. installTarget, colors.lightGray)
      local x = 2
      for _, mode in ipairs({ "term", "monitor", "ask" }) do
        local width = mode == "monitor" and 9 or 7
        button(x, 6, width, mode == "monitor" and "MON" or mode:upper(), function()
          installTarget = mode
          showPage()
        end, installTarget == mode and colors.orange or colors.blue)
        x = x + width + 1
      end
      button(2, 8, 16, installOpus and "OPUS SHORTCUT +" or "OPUS SHORTCUT -", function()
        installOpus = not installOpus
        showPage()
      end)
      button(2, 9, 9, "BACK", back)
      keyFocus()
    elseif page == "opus_settings" then
      title("OPUS INTEGRATION")
      button(2, 6, 18, prefs.opusStore and "STORE ON" or "STORE OFF", function()
        prefs.opusStore = not prefs.opusStore
        save()
        showPage()
      end)
      button(2, 7, 18, prefs.opusApps and "APPS ON" or "APPS OFF", function()
        prefs.opusApps = not prefs.opusApps
        save()
        showPage()
      end)
      button(2, 9, 9, "BACK", function()
        page = "settings"
        showPage()
      end)
      keyFocus()
    elseif page == "remove" then
      title("REMOVE " .. (current() and current().name or "") .. "?")
      label(2, 7, "Save files are preserved.", colors.lime)
      button(2, 10, 12, "CONFIRM", function()
        runAction("remove")
      end, colors.red)
      button(16, 10, 10, "CANCEL", back)
      keyFocus()
    elseif page == "error" then
      title("OPERATION FAILED")
      local lines = wrap(failed or "Unknown error", w - 4, math.max(2, h - 10))
      for i, line in ipairs(lines) do
        label(2, i + 5, line, colors.red)
      end
      button(2, h - 3, 10, "BACK", back)
      keyFocus()
    end
  end

  local function launch(destination)
    local app = current()
    local device = native
    if destination == "monitor" then
      local entry = manager.monitors()[1]
      if not entry and manager.ensureMonitor then
        entry = manager.ensureMonitor()
      end
      if not entry then
        notify("No monitor available; choose terminal")
        page = "launch"
        showPage()
        return
      end
      device = entry.screen
      if device.setTextScale then
        pcall(device.setTextScale, 0.5)
      end
    end
    local original = term.current()
    term.redirect(device)
    local ok, result = pcall(manager.launch, app)
    term.redirect(original)
    if device.setGraphicsMode then
      pcall(device.setGraphicsMode, 0)
    end
    if ok then
      notify("Returned from " .. app.name)
      page = "detail"
    else
      failed = tostring(result)
      page = "error"
    end
    showPage()
  end

  runAction = function(action)
    local app = current()
    if action == "refresh" then
      execute(function()
        local ok, why = manager.refreshVersions()
        assert(ok, why or "Catalog unavailable")
      end, "Catalog updated")
    elseif action == "store-update" then
      if execute(function()
        manager.updateStore()
      end, "Store updated") then
        returnCode = "reload"
        basalt.stop()
        return
      end
    elseif action == "launch" then
      local target = prefs.launchTargets[app.id] or "ask"
      if target == "ask" then
        page = "launch"
      else
        launch(target)
        return
      end
    elseif action == "launch-term" or action == "launch-monitor" then
      launch(action == "launch-term" and "term" or "monitor")
      return
    elseif action == "install" then
      beginInstall()
      return
    elseif action == "source-save" then
      local ok, parsed = execute(function()
        return manager.parseSource(sourceMode == "main" and "main" or sourceInput, sourceMode)
      end, "Build selected")
      if ok then
        sourceValue = parsed
        page = previousPage == "detail" and "install" or previousPage
      end
    elseif action == "install-now" then
      local drive = manager.disks(app)[installIndex]
      if execute(function()
        manager.install(app, sourceValue, drive.root)
      end, "Installed " .. app.name) then
        prefs.launchTargets[app.id] = installTarget
        prefs.opusShortcuts[app.id] = installOpus
        save()
        sourceValue = nil
        page = "detail"
      end
    elseif action == "remove" then
      if execute(function()
        manager.remove(app, false)
      end, "Removed " .. app.name .. " (saves kept)") then
        page = "browse"
      end
    end
    showPage()
  end

  if manager.syncOpus then
    pcall(manager.syncOpus)
  end
  local ok = manager.refreshVersions()
  message = ok and "Catalog refreshed" or "Offline - installed apps still work"
  showPage()
  -- Basalt controls the event loop, pointer events, text input and focus.
  local success, err = pcall(basalt.run)
  restore()
  if not success then
    error(err, 0)
  end
  if returnCode == "restart" then
    return "reload"
  end
  return returnCode
end

return U
