-- Lightweight CraftOS screen for a Remote Node.
-- No Basalt dependency; it runs alongside Rednet and watchdog tasks.
local UI = {}
UI.__index = UI
local C = colors
local function crop(s, n)
  s = tostring(s or "")
  n = math.max(1, n)
  if #s > n then
    return s:sub(1, n - 1) .. "~"
  end
  return s
end
function UI.new(opts)
  assert(type(opts) == "table" and type(opts.info) == "function")
  assert(type(opts.export) == "function")
  return setmetatable({
    opts = opts,
    status = "",
    showKey = false,
    overwrite = false,
    buttons = {},
    drive = nil,
    screen = term,
    monitorName = nil,
    focus = 1,
  }, UI)
end
-- Prefer an attached Advanced Monitor: unlike a basic computer it is touchable.
function UI:selectDisplay()
  self.screen = term.current and term.current() or term
  self.monitorName = nil
  local names = peripheral.getNames()
  table.sort(names)
  for _, name in ipairs(names) do
    if peripheral.getType(name) == "monitor" then
      local ok, mon = pcall(peripheral.wrap, name)
      if ok and mon and mon.isColor then
        local colorOK, color = pcall(mon.isColor)
        if colorOK and color then
          local sized, w, h = pcall(mon.getSize)
          if sized and w >= 29 and h >= 17 then
            self.screen = mon
            self.monitorName = name
            break
          end
        end
      end
    end
  end
end
function UI:line(y, text, fg)
  local w, h = self.screen.getSize()
  if y < 1 or y > h then
    return
  end
  self.screen.setCursorPos(1, y)
  self.screen.setBackgroundColor(C.black)
  self.screen.clearLine()
  self.screen.setTextColor(fg or C.white)
  self.screen.write(crop(text, w))
end
function UI:button(y, label, id, enabled, bg)
  local w, h = self.screen.getSize()
  if y > h - 1 or y < 1 then
    return
  end
  local width = math.min(w - 2, math.max(13, #label + 4))
  local x = math.floor((w - width) / 2) + 1
  self.buttons[#self.buttons + 1] = { id = id, x = x, y = y, width = width, enabled = enabled }
  self.screen.setCursorPos(x, y)
  self.screen.setBackgroundColor(enabled and (bg or C.blue) or C.gray)
  self.screen.setTextColor(enabled and C.white or C.lightGray)
  self.screen.write(string.rep(" ", width))
  self.screen.setCursorPos(x + math.floor((width - #label) / 2), y)
  self.screen.write(label)
  self.screen.setBackgroundColor(C.black)
end
function UI:draw()
  local info = self.opts.info()
  local w, h = self.screen.getSize()
  self.buttons = {}
  self.screen.setBackgroundColor(C.black)
  self.screen.clear()
  self:line(1, " FPBCRAFT / REMOTE NODE", C.cyan)
  self:line(2, " " .. crop(info.name, w - 3) .. "  #" .. info.id, C.lightGray)
  self:line(
    4,
    " Radio: " .. (info.wireless and "ONLINE" or "OFFLINE") .. "  |  Sensors: " .. (info.sensors or 0),
    info.wireless and C.lime or C.orange
  )
  self:line(5, " Paired hub: " .. tostring(info.hubId or "Not paired"), info.hubId and C.lime or C.yellow)
  local disks = self.opts.drives()
  self.drive = disks[1]
  self:line(
    6,
    " Floppy: " .. (self.drive and ("READY (" .. self.drive.name .. ")") or "Insert a writable disk"),
    self.drive and C.lime or C.orange
  )
  self:line(7, " Managed outputs: " .. (info.outputs or 0) .. "  |  Watchdog: 15s", C.lightGray)
  local actionY = math.max(9, math.floor(h / 2))
  if h >= 12 then
    self:button(actionY, "EXPORT KEY TO DISK", "export", self.drive ~= nil, C.green)
    if h >= 16 then
      self:button(actionY + 2, "EJECT DISK", "eject", self.drive ~= nil, C.blue)
      self:button(actionY + 4, self.showKey and "HIDE PAIRING KEY" or "SHOW PAIRING KEY", "key", true, C.gray)
    else
      self:button(actionY + 2, self.showKey and "HIDE KEY" or "SHOW KEY", "key", true, C.gray)
    end
  end
  if self.showKey then
    local k = tostring(info.key or "")
    -- Show key in manageable groups. It is still only visible locally.
    local keyY = math.min(h - 5, actionY + (h >= 16 and 6 or 4))
    self:line(keyY, " Key (enter at main hub):", C.yellow)
    self:line(keyY + 1, " " .. k:sub(1, math.max(1, w - 2)), C.yellow)
    if #k > w - 2 then
      self:line(keyY + 2, " " .. k:sub(w - 1), C.yellow)
    end
  end
  self:line(h - 2, self.status ~= "" and (" " .. self.status) or " E=Export J=Eject K=Key Tab/Enter=Select", C.yellow)
  self:line(h - 1, " Pair at hub: Devices > PAIR FROM DISK", C.lightGray)
end
-- A detached monitor must not crash the node's radio/watchdog tasks.
function UI:refresh()
  local ok = pcall(self.draw, self)
  if not ok then
    self.monitorName = nil
    self.screen = term.current and term.current() or term
    pcall(self.draw, self)
  end
end
function UI:perform(action)
  if action == "export" then
    local executed, ok, msg, drive = pcall(self.opts.export, self.overwrite)
    if not executed then
      self.overwrite = false
      self.status = "Disk write failed: " .. tostring(ok)
      self:refresh()
      return
    end
    if ok then
      self.status = msg .. (drive and (" (" .. drive.name .. ")") or "")
      self.overwrite = false
    elseif msg and msg:find("confirm overwrite", 1, true) then
      self.overwrite = true
      self.status = "Press EXPORT again to overwrite pairing file"
    else
      self.overwrite = false
      self.status = msg or "Export failed"
    end
  elseif action == "eject" then
    local d = self.drive
    if d then
      local ok, err = pcall(disk.eject, d.name)
      self.status = ok and "Disk ejected. Move to main hub." or ("Eject failed: " .. tostring(err))
      self.overwrite = false
    end
  elseif action == "key" then
    self.showKey = not self.showKey
    self.status = self.showKey and "Keep the pairing key private" or ""
  end
  self:refresh()
end
function UI:handle(event, ...)
  if event == "mouse_click" and not self.monitorName or event == "monitor_touch" and self.monitorName then
    local btn, x, y = ...
    if event == "monitor_touch" then
      if btn ~= self.monitorName then
        return
      end
    elseif btn ~= 1 then
      return
    end
    for _, button in ipairs(self.buttons) do
      if button.enabled and y == button.y and x >= button.x and x < button.x + button.width then
        self:perform(button.id)
        return
      end
    end
  elseif event == "key" then
    local code = ...
    if code == keys.e then
      self:perform("export")
    elseif code == keys.j then
      self:perform("eject")
    elseif code == keys.k then
      self:perform("key")
    elseif code == keys.tab then
      self.focus = self.focus % 3 + 1
      self.status = "Enter: " .. ({ "EXPORT", "EJECT", "KEY" })[self.focus]
      self:refresh()
    elseif code == keys.enter or code == keys.numPadEnter then
      local action = ({ "export", "eject", "key" })[self.focus]
      if action ~= "eject" or self.drive then
        self:perform(action)
      end
    elseif code == keys.r then
      self:refresh()
    end
  elseif
    event == "disk"
    or event == "disk_eject"
    or event == "peripheral"
    or event == "peripheral_detach"
    or event == "monitor_resize"
    or event == "term_resize"
  then
    if event == "peripheral" or event == "peripheral_detach" or event == "monitor_resize" then
      self:selectDisplay()
    end
    self.overwrite = false
    self:refresh()
  end
end
function UI:run()
  self:selectDisplay()
  self:refresh()
  local tick = os.startTimer(1)
  while true do
    local event, a, b, c = os.pullEvent()
    if event == "timer" and a == tick then
      self:refresh()
      tick = os.startTimer(1)
    elseif event ~= "timer" then
      self:handle(event, a, b, c)
    end
  end
end
return UI
