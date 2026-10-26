-- Run installed programs from an Opus shortcut without losing the launch preference.
return function(id)
  local manager = assert(loadfile("/apps/fpbstore/main.lua"))("--test-api")
  local app = assert(manager.get(id), "Unknown application: " .. tostring(id))
  assert(manager.installed(app), "Application is not installed (check the external disk)")
  local prefs = manager.preferences()
  local target = (prefs.launchTargets or {})[id] or "ask"
  local monitors = manager.monitors and manager.monitors() or {}
  local function choose()
    if target == "term" then
      return nil
    end
    if target == "monitor" and #monitors == 0 and manager.ensureMonitor then
      local entry = manager.ensureMonitor()
      if entry then
        monitors = { entry }
      end
    end
    if target == "monitor" and #monitors == 0 then
      print("Preferred monitor disconnected. Launch on terminal? [Y/n]")
      if read and (read() or ""):lower() == "n" then
        return false
      end
      return nil
    end
    if target == "ask" then
      if #monitors == 0 and not (type(periphemu) == "table" and type(periphemu.create) == "function") then
        return nil
      end
      print("Launch " .. app.name .. " on: [T]erminal / [M]onitor")
      local choice = read and (read() or "t"):lower() or "t"
      if choice:sub(1, 1) ~= "m" then
        return nil
      end
    end
    if #monitors == 0 and manager.ensureMonitor then
      local entry = manager.ensureMonitor()
      if entry then
        monitors = { entry }
      end
    end
    return monitors[1] and monitors[1].screen or nil
  end
  local display = choose()
  if display == false then
    return
  end
  local original = term.current()
  local saved = {}
  if display then
    if display.setTextScale then
      pcall(display.setTextScale, 0.5)
    end
    if display.getPaletteColor then
      for i = 0, 15 do
        local col = 2 ^ i
        saved[col] = { display.getPaletteColor(col) }
      end
    end
    term.redirect(display)
  end
  local ok, result = pcall(manager.launch, app)
  term.redirect(original)
  if display and display.setGraphicsMode then
    pcall(display.setGraphicsMode, 0)
  end
  if display and display.setPaletteColor then
    for color, rgb in pairs(saved) do
      pcall(display.setPaletteColor, color, table.unpack(rgb))
    end
  end
  if not ok then
    error(result, 0)
  end
  return result
end
