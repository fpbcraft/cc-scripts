-- Lightweight CraftOS screen for a Remote Node.
-- No Basalt dependency; it runs alongside Rednet and watchdog tasks.
local UI={}
UI.__index=UI
local C=colors
local function crop(s,n)
  s=tostring(s or "")
  n=math.max(1,n)
  if #s>n then return s:sub(1,n-1).."~" end
  return s
end
function UI.new(opts)
  assert(type(opts)=="table" and type(opts.info)=="function")
  assert(type(opts.export)=="function")
  return setmetatable({opts=opts,status="",showKey=false,
    overwrite=false,buttons={},drive=nil},UI)
end
function UI:line(y,text,fg)
  local w,h=term.getSize()
  if y<1 or y>h then return end
  term.setCursorPos(1,y)
  term.setBackgroundColor(C.black)
  term.clearLine()
  term.setTextColor(fg or C.white)
  term.write(crop(text,w))
end
function UI:button(y,label,id,enabled,bg)
  local w,h=term.getSize()
  if y>h-1 or y<1 then return end
  local width=math.min(w-2,math.max(13,#label+4))
  local x=math.floor((w-width)/2)+1
  self.buttons[#self.buttons+1]={id=id,x=x,y=y,width=width,enabled=enabled}
  term.setCursorPos(x,y)
  term.setBackgroundColor(enabled and (bg or C.blue) or C.gray)
  term.setTextColor(enabled and C.white or C.lightGray)
  term.write(string.rep(" ",width))
  term.setCursorPos(x+math.floor((width-#label)/2),y)
  term.write(label)
  term.setBackgroundColor(C.black)
end
function UI:draw()
  local info=self.opts.info()
  local w,h=term.getSize()
  self.buttons={}
  term.setBackgroundColor(C.black)
  term.clear()
  self:line(1," FPBCRAFT / REMOTE NODE",C.cyan)
  self:line(2," "..crop(info.name,w-3).."  #"..info.id,C.lightGray)
  self:line(4," Radio: "..(info.wireless and "ONLINE" or "OFFLINE")..
    "  |  Sensors: "..(info.sensors or 0),
    info.wireless and C.lime or C.orange)
  self:line(5," Paired hub: "..tostring(info.hubId or "Not paired"),
    info.hubId and C.lime or C.yellow)
  local disks=self.opts.drives()
  self.drive=disks[1]
  self:line(6," Floppy: "..(self.drive and
      ("READY ("..self.drive.name..")") or "Insert a writable disk"),
    self.drive and C.lime or C.orange)
  self:line(7," Managed outputs: "..(info.outputs or 0)..
    "  |  Watchdog: 15s",C.lightGray)
  local actionY=math.max(9,math.floor(h/2))
  if h>=12 then
    self:button(actionY,"EXPORT KEY TO DISK","export",
      self.drive~=nil,C.green)
    if h>=16 then
      self:button(actionY+2,"EJECT DISK","eject",
        self.drive~=nil,C.blue)
      self:button(actionY+4,self.showKey and "HIDE PAIRING KEY" or
        "SHOW PAIRING KEY","key",true,C.gray)
    else
      self:button(actionY+2,self.showKey and "HIDE KEY" or "SHOW KEY",
        "key",true,C.gray)
    end
  end
  if self.showKey then
    local k=tostring(info.key or "")
    -- Show key in manageable groups. It is still only visible locally.
    local keyY=math.max(actionY+(h>=16 and 6 or 4),h-5)
    self:line(keyY," Key (enter at main hub):",C.yellow)
    self:line(keyY+1," "..k:sub(1,math.max(1,w-2)),C.yellow)
    if #k>w-2 then self:line(keyY+2," "..k:sub(w-1),C.yellow) end
  end
  self:line(h-2,self.status~="" and (" "..self.status) or
    " Click export or press E. K=key; R=refresh",C.yellow)
  self:line(h-1," Pair at hub: Devices > PAIR FROM DISK",C.lightGray)
end
function UI:perform(action)
  if action=="export" then
    local ok,msg,drive=self.opts.export(self.overwrite)
    if ok then
      self.status=msg..(drive and (" ("..drive.name..")") or "")
      self.overwrite=false
    elseif msg and msg:find("confirm overwrite",1,true) then
      self.overwrite=true
      self.status="Press EXPORT again to overwrite pairing file"
    else
      self.overwrite=false
      self.status=msg or "Export failed"
    end
  elseif action=="eject" then
    local d=self.drive
    if d then
      local ok,err=pcall(disk.eject,d.name)
      self.status=ok and "Disk ejected. Move to main hub." or
        ("Eject failed: "..tostring(err))
    end
  elseif action=="key" then
    self.showKey=not self.showKey
    self.status=self.showKey and "Keep the pairing key private" or ""
  end
  self:draw()
end
function UI:handle(event,...)
  if event=="mouse_click" then
    local btn,x,y=...
    if btn~=1 then return end
    for _,button in ipairs(self.buttons) do
      if button.enabled and y==button.y and
          x>=button.x and x<button.x+button.width then
        self:perform(button.id)
        return
      end
    end
  elseif event=="key" then
    local code=...
    if code==keys.e then self:perform("export")
    elseif code==keys.k then self:perform("key")
    elseif code==keys.r then self:draw() end
  elseif event=="disk" or event=="disk_eject" or
         event=="peripheral" or event=="peripheral_detach" or
         event=="term_resize" then
    self.overwrite=false
    self:draw()
  end
end
function UI:run()
  self:draw()
  local tick=os.startTimer(1)
  while true do
    local event,a,b,c=os.pullEvent()
    if event=="timer" and a==tick then
      self:draw()
      tick=os.startTimer(1)
    elseif event~="timer" then
      self:handle(event,a,b,c)
    end
  end
end
return UI
