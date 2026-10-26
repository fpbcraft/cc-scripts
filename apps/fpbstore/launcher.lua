-- One responsive storefront for monitors and plain CraftOS terminals.
local UI = {}
function UI.run(manager)
  local host = term.current()
  local selected, offset, filter, query, editing = 1, 0, "all", "", false
  local notice = "Ready"
  local confirmation = nil
  local build = nil
  local hits = {}
  local saved = {}
  if host.getPaletteColor then
    for i = 0, 15 do
      saved[2 ^ i] = { host.getPaletteColor(2 ^ i) }
    end
  end
  local function restore()
    if term.redirect then
      term.redirect(host)
    end
    if host.setGraphicsMode then
      pcall(host.setGraphicsMode, 0)
    end
    if host.setPaletteColor then
      for color, rgb in pairs(saved) do
        pcall(host.setPaletteColor, color, table.unpack(rgb))
      end
    end
    if host.setCursorBlink then
      host.setCursorBlink(false)
    end
    host.setBackgroundColor(colors.black)
    host.setTextColor(colors.white)
  end
  local function list()
    local result = {}
    for _, app in ipairs(manager.catalog.apps) do
      local text = (app.name .. " " .. (app.subtitle or "") .. " " .. (app.genre or "")):lower()
      if (filter == "all" or manager.installed(app)) and text:find(query:lower(), 1, true) then
        result[#result + 1] = app
      end
    end
    selected = math.max(1, math.min(selected, #result))
    return result
  end
  local function put(x, y, text, fg, bg, width)
    local w, h = host.getSize()
    if x < 1 or x > w or y < 1 or y > h then
      return
    end
    width = math.min(width or w - x + 1, w - x + 1)
    host.setCursorPos(x, y)
    host.setTextColor(fg or colors.white)
    host.setBackgroundColor(bg or colors.black)
    local value = tostring(text)
    host.write((value .. (" "):rep(width)):sub(1, width))
  end
  local function button(x, y, width, label, action, arg, enabled)
    put(
      x,
      y,
      label,
      enabled == false and colors.lightGray or colors.white,
      enabled == false and colors.gray or colors.blue,
      width
    )
    if enabled ~= false then
      hits[#hits + 1] = { x = x, y = y, w = width, action = action, arg = arg }
    end
  end
  local function draw()
    restore()
    host.clear()
    hits = {}
    local w, h = host.getSize()
    put(1, 1, " FPB STORE " .. manager.storeStatus().installedVersion, colors.orange, colors.gray, w)
    if w < 26 or h < 12 then
      put(1, 3, "Use a terminal of at least 26 x 12.", colors.yellow)
      put(1, h, "Q: exit", colors.lightGray)
      return {}, 0
    end
    local apps = list()
    if build then
      local current = manager.installedSource and manager.installedSource(build.app) or { label = "main" }
      put(2, 3, "BUILD: " .. build.app.name, colors.yellow, nil, w - 2)
      local third = math.floor((w - 4) / 3)
      button(2, 4, third, (build.mode == "main" and "> " or "") .. "MAIN", "source-mode", "main")
      button(3 + third, 4, third, (build.mode == "pr" and "> " or "") .. "PR", "source-mode", "pr")
      button(4 + third * 2, 4, third, (build.mode == "branch" and "> " or "") .. "BRANCH", "source-mode", "branch")
      put(2, 6, "Installed source: " .. (current.label or "main"), colors.lightBlue, nil, w - 2)
      if build.mode == "main" then
        put(2, 7, "Install the stable main branch.", colors.white, nil, w - 2)
      else
        local prompt = build.mode == "pr" and "PR number or GitHub PR URL:" or "Branch name or GitHub URL:"
        put(2, 7, prompt, colors.lightGray, nil, w - 2)
        put(2, 8, "> " .. build.input .. "_", colors.yellow, nil, w - 2)
      end
      button(2, h - 3, math.floor((w - 3) / 2), "INSTALL BUILD", "install-source")
      button(3 + math.floor((w - 3) / 2), h - 3, math.floor((w - 3) / 2), "CANCEL", "cancel-source")
      put(2, h - 2, "Enter: install | Esc: back", colors.lightGray, nil, w - 2)
      put(1, h - 1, " Paste supported for PR and branch URLs", colors.white, colors.gray, w)
      put(1, h, " MAIN / PR / BRANCH - choose a source", colors.lightGray, nil, w)
      return apps, 0
    end
    local tabs = math.floor((w - 3) / 2)
    button(2, 3, tabs, (filter == "all" and "> " or "  ") .. "ALL APPS", "all")
    button(3 + tabs, 3, tabs, (filter == "installed" and "> " or "  ") .. "INSTALLED", "installed")
    put(2, 4, (editing and "SEARCH> " or "/ Search: ") .. query, editing and colors.yellow or colors.lightGray)
    local step = h >= 20 and 2 or 1
    local capacity = math.max(1, math.floor((h - 10) / step))
    offset = math.max(0, math.min(offset, math.max(0, #apps - capacity)))
    if selected <= offset then
      offset = selected - 1
    end
    if selected > offset + capacity then
      offset = selected - capacity
    end
    if #apps == 0 then
      put(2, 6, filter == "installed" and "No installed apps match." or "No apps match your search.", colors.yellow)
    end
    for row = 1, capacity do
      local index = offset + row
      local app = apps[index]
      if app then
        local y = 5 + (row - 1) * step
        local status = manager.status(app)
        local source = status.source or { kind = "main" }
        local tag = "GET"
        if status.installed then
          tag = status.updateAvailable and "UPDATE"
            or (source.kind == "pr" and ("PR #" .. source.value))
            or (source.kind == "branch" and "BRANCH")
            or "READY"
        end
        local active = index == selected
        put(2, y, (active and "> " or "  ") .. app.name, active and colors.yellow or colors.white, nil, w - 10)
        put(w - 7, y, tag, colors.lightBlue, nil, 7)
        if step == 2 then
          put(4, y + 1, app.subtitle or app.genre or "", colors.lightGray, nil, w - 5)
        end
        hits[#hits + 1] = { x = 2, y = y, w = w - 2, action = "select", arg = index }
      end
    end
    local app = apps[selected]
    local status = app and manager.status(app)
    local third = math.floor((w - 4) / 3)
    if confirmation then
      put(2, h - 5, "Remove " .. confirmation.name .. "? Saves stay.", colors.yellow)
      button(2, h - 4, third, "CANCEL", "cancel")
      button(3 + third, h - 4, third, "REMOVE", "confirm")
    else
      put(
        2,
        h - 5,
        app
            and ((status.installed and "v" .. (status.installedVersion or "?") .. " | " or "") .. "Source: " .. ((status.source and status.source.label) or "main") .. " | Latest v" .. (status.latestVersion or app.version or "?"))
          or "Choose All apps to browse.",
        colors.lightBlue
      )
      button(2, h - 4, third, status and status.installed and "LAUNCH" or "INSTALL", "primary", nil, app ~= nil)
      button(
        3 + third,
        h - 4,
        third,
        status and status.updateAvailable and "UPDATE" or "REINSTALL",
        "install",
        nil,
        status and status.installed or false
      )
      button(4 + third * 2, h - 4, third, "REMOVE", "remove", nil, status and status.installed or false)
    end
    button(2, h - 3, w - 2, "B BUILD SOURCE", "source", nil, app ~= nil)
    button(2, h - 2, math.floor((w - 4) / 2), "R REFRESH", "refresh")
    button(
      3 + math.floor((w - 4) / 2),
      h - 2,
      math.floor((w - 4) / 2),
      manager.storeStatus().updateAvailable and "U UPDATE STORE!" or "U STORE UPDATE",
      "store-update"
    )
    put(1, h - 1, " " .. notice, colors.white, colors.gray, w)
    put(1, h, (" " .. selected .. "/" .. #apps .. "  UP/DOWN ENTER  / SEARCH  Q EXIT"), colors.lightGray, nil, w)
    return apps, capacity
  end
  local function diagnostic(message)
    restore()
    local top = 1
    while true do
      local w, h = host.getSize()
      local lines = {}
      for line in (tostring(message) .. "\n"):gmatch("(.-)\n") do
        repeat
          lines[#lines + 1] = line:sub(1, math.max(1, w - 2))
          line = line:sub(math.max(1, w - 2) + 1)
        until #line == 0
      end
      top = math.min(top, math.max(1, #lines - h + 2))
      host.setBackgroundColor(colors.black)
      host.clear()
      put(1, 1, " FPB STORE / OPERATION FAILED", colors.white, colors.red, w)
      for y = 2, h - 1 do
        put(2, y, lines[top + y - 2] or "")
      end
      put(1, h, "UP/DOWN SCROLL | ENTER / TAP BACK", colors.yellow)
      local ev, a = os.pullEvent()
      if ev == "term_resize" then
      -- Reflow the diagnostic to the new terminal size.
      elseif ev == "mouse_scroll" then
        top = math.max(1, math.min(math.max(1, #lines - h + 2), top + a * 3))
      elseif ev == "key" and (a == keys.up or a == keys.down) then
        top = math.max(1, math.min(math.max(1, #lines - h + 2), top + (a == keys.up and -1 or 1)))
      elseif ev == "key" or ev == "mouse_click" or ev == "monitor_touch" then
        return
      end
    end
  end
  local function perform(action, arg)
    local apps = list()
    local app = apps[selected]
    local targetSource = nil
    if build then
      if action == "cancel-source" then
        build = nil
        return
      elseif action == "source-mode" then
        build.mode = arg
        build.input = ""
        return
      elseif action == "install-source" then
        local ok, parsed = pcall(function()
          return manager.parseSource(build.mode == "main" and "main" or build.input, build.mode)
        end)
        if not ok then
          diagnostic(parsed)
          return
        end
        targetSource = parsed
        app = build.app
        build = nil
        action = "install"
      else
        return
      end
    end
    if action == "source" then
      if app then
        local source = manager.installedSource and manager.installedSource(app) or { kind = "main", value = "main" }
        build = { app = app, mode = source.kind, input = source.kind == "main" and "" or source.value }
      end
      return
    end
    if confirmation and action ~= "confirm" and action ~= "cancel" then
      return
    end
    if action == "select" then
      selected = arg
      return
    end
    if action == "all" or action == "installed" then
      filter = action
      selected = 1
      offset = 0
      return
    end
    if action == "cancel" then
      confirmation = nil
      return
    end
    if action == "remove" then
      if app and manager.installed(app) then
        confirmation = app
      end
      return
    end
    if action == "confirm" then
      app = confirmation
      confirmation = nil
      action = "remove-code"
    end
    if action == "primary" then
      action = app and manager.installed(app) and "launch" or "install"
    end
    if (action == "install" or action == "launch" or action == "remove-code") and not app then
      return
    end
    restore()
    host.clear()
    host.setCursorPos(1, 1)
    print("FPB STORE / " .. action:upper())
    local ok, result = pcall(function()
      if action == "refresh" then
        local online, reason = manager.refreshVersions()
        notice = online and "Catalog refreshed" or "Offline: using cached catalog"
        return online, reason
      elseif action == "launch" then
        return manager.launch(app)
      elseif action == "install" then
        return manager.install(app, targetSource)
      elseif action == "remove-code" then
        return manager.remove(app, false)
      elseif action == "store-update" then
        return manager.updateStore()
      end
    end)
    restore()
    if not ok then
      notice = "Operation failed; press R to retry refresh"
      diagnostic(result)
    elseif action == "store-update" then
      return "reload"
    elseif action ~= "refresh" then
      notice = action == "remove-code" and "App removed; saves preserved"
        or (action == "launch" and "Returned from " .. app.name or "Installation complete")
    end
  end
  local function loop()
    local online = manager.refreshVersions()
    notice = online and "Catalog checked | Enter launches installed apps" or "Offline: installed apps still launch"
    while true do
      local apps, capacity = draw()
      local event, a, b, c = os.pullEvent()
      local action, arg
      local w, h = host.getSize()
      if w < 26 or h < 12 then
        if (event == "char" and a:lower() == "q") or (event == "key" and a == keys.escape) then
          return
        end
      elseif build then
        if event == "char" then
          if build.mode ~= "main" then
            build.input = build.input .. a
          end
        elseif event == "paste" then
          if build.mode ~= "main" then
            build.input = build.input .. a
          end
        elseif event == "key" then
          if a == keys.escape then
            action = "cancel-source"
          elseif a == keys.enter then
            action = "install-source"
          elseif a == keys.backspace then
            build.input = build.input:sub(1, -2)
          elseif a == keys.tab then
            action = "source-mode"
            arg = build.mode == "main" and "pr" or (build.mode == "pr" and "branch" or "main")
          end
        elseif event == "mouse_click" or event == "monitor_touch" then
          for _, hit in ipairs(hits) do
            if b >= hit.x and b < hit.x + hit.w and c == hit.y then
              action, arg = hit.action, hit.arg
              break
            end
          end
        end
      elseif editing then
        if event == "char" then
          query = query .. a
          selected = 1
          offset = 0
        elseif event == "paste" then
          query = query .. a
          selected = 1
          offset = 0
        elseif event == "key" and a == keys.backspace then
          query = query:sub(1, -2)
        elseif event == "key" and (a == keys.escape or a == keys.enter) then
          editing = false
        end
      elseif event == "key" then
        if a == keys.escape then
          if confirmation then
            confirmation = nil
          else
            return
          end
        elseif a == keys.enter then
          action = confirmation and "confirm" or "primary"
        elseif not confirmation then
          if a == keys.up then
            selected = math.max(1, selected - 1)
          elseif a == keys.down then
            selected = math.min(#apps, selected + 1)
          elseif a == keys.pageUp then
            selected = math.max(1, selected - capacity)
          elseif a == keys.pageDown then
            selected = math.min(#apps, selected + capacity)
          elseif a == keys.tab then
            action = filter == "all" and "installed" or "all"
          elseif a == keys.space then
            action = "launch"
          end
        end
      elseif event == "char" then
        local ch = a:lower()
        if ch == "q" then
          if confirmation then
            confirmation = nil
          else
            return
          end
        elseif ch == "/" and not confirmation then
          editing = true
        elseif ch == "r" then
          action = "refresh"
        elseif ch == "u" then
          action = "store-update"
        elseif ch == "i" then
          action = "install"
        elseif ch == "d" then
          action = "remove"
        elseif ch == "b" then
          action = "source"
        end
      elseif event == "mouse_scroll" and not confirmation then
        selected = math.max(1, math.min(#apps, selected + a))
      elseif event == "mouse_click" or event == "monitor_touch" then
        for _, hit in ipairs(hits) do
          if b >= hit.x and b < hit.x + hit.w and c == hit.y then
            action, arg = hit.action, hit.arg
            break
          end
        end
      end
      if action and perform(action, arg) == "reload" then
        return "reload"
      end
    end
  end
  local ok, result = xpcall(loop, function(e)
    return tostring(e) .. (debug and debug.traceback and "\n" .. debug.traceback() or "")
  end)
  restore()
  host.clear()
  host.setCursorPos(1, 1)
  if not ok then
    error(result, 0)
  end
  return result
end
return UI
