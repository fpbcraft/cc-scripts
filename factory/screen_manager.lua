-- Automatic independent monitor/workstation management.
-- A monitor must never silently disappear due to size or drawing failures.
local Dashboard=require("screen_dashboard")
local Manager={}
Manager.__index=Manager
function Manager.new(core,metrics,primary,api)
  return setmetatable({
    core=core,metrics=metrics,primary=primary,api=api or peripheral,
    screens={},errors={},scaleAdjusted={},lastDiscovery=0
  },Manager)
end
local function isType(api,name,kind)
  local ok,actual=pcall(api.getType,name)
  if ok and actual==kind then return true end
  if api.hasType then
    local good,yes=pcall(api.hasType,name,kind)
    if good and yes then return true end
  end
  return false
end
function Manager:drawFailure(name,screen,message)
  self.errors[name]=tostring(message)
  local target=screen.surface
  -- Make failures visible IN WORLD instead of swallowing pcall failures.
  pcall(function()
    target.setBackgroundColor(colors.black)
    target.setTextColor(colors.red)
    target.clear()
    target.setCursorPos(1,1)
    target.write("FPBCRAFT SCREEN ERROR")
    target.setCursorPos(1,2)
    target.write(tostring(message):sub(1,100))
  end)
end
function Manager:draw(name)
  local screen=self.screens[name]
  if not screen then return false end
  local ok,err=pcall(screen.draw,screen)
  if not ok then
    self:drawFailure(name,screen,err)
    return false
  end
  self.errors[name]=nil
  return true
end
function Manager:discover()
  local ok,names=pcall(self.api.getNames)
  if not ok or type(names)~="table" then
    self.errors.discovery=tostring(names)
    return 0
  end
  table.sort(names)
  local found={}
  for _,name in ipairs(names) do
    if name~=self.primary then
      local monitor=isType(self.api,name,"monitor")
      local terminal=isType(self.api,name,"terminal")
      if monitor or terminal then
        local good,surface=pcall(self.api.wrap,name)
        if good and type(surface)=="table" and
           type(surface.getSize)=="function" and
           type(surface.write)=="function" and
           type(surface.setCursorPos)=="function" and
           type(surface.setBackgroundColor)=="function" and
           type(surface.setTextColor)=="function" and
           type(surface.clear)=="function" then
          local measured,w,h=pcall(surface.getSize)
          if measured and type(w)=="number" and type(h)=="number" then
            -- Give smaller monitor constructions the best possible size.
            -- Never change the main monitor's scale.
            if monitor and (w<32 or h<19) and
               type(surface.setTextScale)=="function" and
               not self.scaleAdjusted[name] then
              local scaled=pcall(surface.setTextScale,0.5)
              if scaled then
                self.scaleAdjusted[name]=true
                local sized,nw,nh=pcall(surface.getSize)
                if sized then w=nw;h=nh end
              end
            end
            found[name]=true
            local existing=self.screens[name]
            if existing then
              existing.surface=surface
              existing.kind=terminal and "terminal" or "monitor"
            else
              local screen=Dashboard.new(name,surface,self.core,
                self.metrics,terminal and "terminal" or "monitor")
              self.screens[name]=screen
              self:draw(name)
            end
          else
            self.errors[name]="Could not read display dimensions"
          end
        else
          self.errors[name]="Display peripheral does not expose terminal methods"
        end
      end
    end
  end
  for name in pairs(self.screens) do
    if not found[name] then
      self.screens[name]=nil
      self.errors[name]=nil
      self.scaleAdjusted[name]=nil
    end
  end
  local count=0
  for _ in pairs(self.screens) do count=count+1 end
  return count
end
function Manager:refresh()
  -- Poll discovery periodically: some peripheral events get consumed by
  -- a UI framework before a scheduled coroutine observes them.
  self:discover()
  for name in pairs(self.screens) do self:draw(name) end
end
function Manager:handle(event,a,b,c,d)
  if event=="peripheral" or event=="peripheral_detach" or
     event=="monitor_resize" or event=="term_resize" then
    self:discover()
    if a and self.screens[a] then self:draw(a) end
    return false
  end
  local screen=self.screens[a]
  if not screen then return false end
  if event=="monitor_touch" or event=="terminal_mouse_click" or
     event=="terminal_mouse_drag" or event=="terminal_mouse_up" or
     event=="terminal_mouse_scroll" then
    local ok,handled=pcall(screen.handle,screen,event,a,b,c,d)
    if not ok then
      self:drawFailure(a,screen,handled)
      return false
    end
    return handled
  end
  return false
end
function Manager:status()
  local count,errors=0,{}
  for _ in pairs(self.screens) do count=count+1 end
  for name,err in pairs(self.errors) do
    errors[#errors+1]=name..": "..err
  end
  table.sort(errors)
  return count,errors
end
return Manager
