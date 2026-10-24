-- Independent per-display Factory Manager dashboard.
-- Each display maintains its own page, focus, time window and chart order.
-- No automated output methods are called by this module.
local Layout=require("layout")
local Text=require("ui_text")
local Screen={}
Screen.__index=Screen
local C=colors
local TABS={"OVERVIEW","GRAPHS","MACHINES","READINGS"}
local GLYPHS=".-:=+*#@"
local function finite(x)
  return type(x)=="number" and x==x and x<math.huge and x>-math.huge
end
local function format(x)
  if not finite(x) then return "--" end
  if math.abs(x)>1000000 then return string.format("%.1fM",x/1000000) end
  if math.abs(x)>10000 then return string.format("%.1fK",x/1000) end
  return string.format("%.1f",x)
end
function Screen.new(id,surface,core,metrics,kind)
  assert(type(id)=="string" and surface and core)
  return setmetatable({
    id=id,surface=surface,core=core,metrics=metrics,kind=kind or "monitor",
    page="OVERVIEW",focus=nil,graphPage=1,range=300,
    order={},buttons={},tiles={},selection=nil,dragged=nil,reorder=false,
    status="",reorderCount=0
  },Screen)
end
function Screen:text(x,y,message,fg,bg,n)
  local w,h=self.surface.getSize()
  if x<1 or x>w or y<1 or y>h then return end
  local max=math.min(w-x+1,n or w)
  self.surface.setCursorPos(x,y)
  self.surface.setBackgroundColor(bg or C.black)
  self.surface.setTextColor(fg or C.white)
  self.surface.write(Text.clip(message,max))
end
function Screen:button(x,y,w,text,action)
  if w<3 then return end
  self:text(x,y," "..Text.clip(text,w-2).." ",C.white,C.blue,w)
  self.buttons[#self.buttons+1]={x=x,y=y,w=w,action=action}
end
function Screen:getMetrics()
  local metrics=self.metrics()
  local available={}
  for _,metric in ipairs(metrics) do available[metric[1]]=metric end
  local result,seen={},{}
  for _,id in ipairs(self.order) do
    local metric=available[id]
    if metric then result[#result+1]=metric;seen[id]=true end
  end
  for _,metric in ipairs(metrics) do
    if not seen[metric[1]] then result[#result+1]=metric end
  end
  return result
end
function Screen:series(key,width)
  local now=self.core.samples[#self.core.samples]
  if not now then return "",nil end
  local maxTime=now.time
  local start=maxTime-self.range
  local raw={}
  local low,high,latest=nil,nil,nil
  for _,sample in ipairs(self.core.samples) do
    local value=sample[key]
    if finite(sample.time) and (self.range==0 or sample.time>=start)
       and finite(value) then
      raw[#raw+1]={sample.time,value}
      latest=value
      low=low and math.min(low,value) or value
      high=high and math.max(high,value) or value
    end
  end
  if #raw==0 then return "no samples",nil end
  if low==high then high=low+1 end
  local chars={}
  local span=(self.range==0 and raw[#raw][1]-raw[1][1] or self.range)
  if span<=0 then span=1 end
  local origin=self.range==0 and raw[1][1] or start
  local slots={}
  for _,p in ipairs(raw) do
    local idx=math.max(1,math.min(width,
      math.floor((p[1]-origin)/span*(width-1))+1))
    slots[idx]=p[2]
  end
  for i=1,width do
    if slots[i] then
      local position=math.floor((slots[i]-low)/(high-low)*(#GLYPHS-1))+1
      chars[i]=GLYPHS:sub(position,position)
    else chars[i]=" " end
  end
  return table.concat(chars),latest
end
function Screen:tile(metric,x,y,w,h)
  local id=metric[1]
  self:text(x,y,metric[2],C.cyan,C.black,w)
  local trace,value=self:series(id,math.max(3,w-2))
  self:text(x,y+1,format(value).." "..tostring(metric[3] or ""),C.white,C.black,w)
  self:text(x,y+3,trace,C.lime,C.black,w)
  self.tiles[#self.tiles+1]={id=id,x=x,y=y,w=w,h=h}
  if self.selection==id then
    self:text(x,y+h-1,"SELECTED > TAP TARGET",C.yellow,C.black,w)
  elseif self.dragged==id then
    self:text(x,y+h-1,"DRAGGING...",C.orange,C.black,w)
  else
    self:text(x,y+h-1,"TAP TO EXPAND",C.lightGray,C.black,w)
  end
end
function Screen:draw()
  local w,h=self.surface.getSize()
  self.buttons={};self.tiles={}
  -- A single-block or otherwise small monitor is still a display.
  -- Show a compact readout instead of silently leaving it blank.
  if w<32 or h<19 then
    self.surface.setBackgroundColor(C.black)
    self.surface.clear()
    if w<8 or h<4 then return end
    self:text(1,1,"FPBCRAFT",C.cyan,C.black,w)
    self:text(1,2,Text.clip(self.id,w),C.lightGray,C.black,w)
    local stock=0
    for _,item in ipairs(self.core.snapshot.stock or {}) do
      stock=stock+(item.count or 0)
    end
    self:text(1,3,"STOCK "..tostring(stock),C.white,C.black,w)
    if h>=5 then self:text(1,5,
      "MACHINES "..tostring(#self.core.machines),C.lime,C.black,w)
    end
    if h>=7 then self:text(1,7,
      "Enlarge monitor for pages",C.orange,C.black,w)
    end
    return
  end
  self.surface.setBackgroundColor(C.black)
  self.surface.clear()
  self:text(2,1,"FPBCRAFT / "..self.id,C.cyan,C.black,w-3)
  local cell=math.floor((w-3)/#TABS)
  for index,name in ipairs(TABS) do
    local x=2+(index-1)*cell
    self:button(x,3,cell-1,name,function()
      self.page=name;self.focus=nil;self.selection=nil;self.graphPage=1
    end)
  end
  local metrics=self:getMetrics()
  if self.page=="OVERVIEW" then
    local snap=self.core.snapshot
    local stock=0
    for _,item in ipairs(snap.stock or {}) do stock=stock+(item.count or 0) end
    self:text(2,6,"STOCK: "..stock.."  MACHINES: "..#self.core.machines,
      C.white,C.black,w-4)
    self:text(2,8,"DEVICES: "..#(self.core.devices:list())..
      "  REMOTE NODES: "..tostring(self.core.remote and
        (function()
          local n=0
          for _,v in pairs(self.core.remote.nodes or {}) do
            if self.core.remote:online(v) then n=n+1 end
          end
          return n
        end)() or 0),C.lightGray,C.black,w-4)
    local tiles=Layout.overviewCharts(w,h,#metrics)
    for _,tile in ipairs(tiles) do
      self:tile(metrics[tile.index],tile.x,tile.y,tile.width,tile.height)
    end
  elseif self.page=="GRAPHS" then
    if self.reorder and not self.focus then
      self:button(2,h-6,15,"REORDER: ON",function()
        self.reorder=false;self.selection=nil
      end)
    elseif not self.focus then
      self:button(2,h-6,15,"REORDER: OFF",function()
        self.reorder=true;self.selection=nil
      end)
    end
    if self.focus then
      for _,metric in ipairs(metrics) do
        if metric[1]==self.focus then
          self:text(2,5,metric[2],C.cyan,C.black,w-4)
          self:text(2,7,"RANGE "..(self.range==0 and "ALL" or
            tostring(self.range/60).."M"),C.lightGray,C.black,w-4)
          local trace,value=self:series(metric[1],w-5)
          self:text(2,10,format(value).." "..tostring(metric[3] or ""),
            C.lime,C.black,w-4)
          self:text(2,13,trace,C.lime,C.black,w-4)
          self:button(2,h-4,14,"< ALL CHARTS",function()self.focus=nil end)
          break
        end
      end
    else
      local grid=Layout.graphGrid(w,h,#metrics,self.graphPage)
      self.graphPage=grid.page
      for _,tile in ipairs(grid.tiles) do
        self:tile(metrics[tile.index],tile.x,tile.y,tile.width,tile.height)
      end
      if grid.pages>1 then
        self:button(2,h-4,12,"< PREVIOUS",function()
          self.graphPage=math.max(1,self.graphPage-1)
        end)
        self:button(w-14,h-4,12,"NEXT >",function()
          self.graphPage=math.min(grid.pages,self.graphPage+1)
        end)
      end
    end
    self:button(math.max(2,w-27),h-6,12,"RANGE -",function()
      local options={0,60,300,900,1800}
      local index=1
      for i,v in ipairs(options) do if self.range==v then index=i end end
      self.range=options[math.max(1,index-1)]
    end)
    self:button(math.max(2,w-14),h-6,12,"RANGE +",function()
      local options={0,60,300,900,1800}
      local index=1
      for i,v in ipairs(options) do if self.range==v then index=i end end
      self.range=options[math.min(#options,index+1)]
    end)
  elseif self.page=="MACHINES" then
    local machines=self.core.machines
    local count=math.min(#machines,math.floor((h-8)/2))
    for i=1,count do
      local m=machines[i]
      local actual=self.core:actual(m)
      local status=actual==nil and "?" or actual and "ON" or "OFF"
      self:text(2,5+(i-1)*2,m.name.." | "..status..
        " | "..format(self.core.rates[m.id]).."/min",
        actual and C.lime or C.lightGray,C.black,w-4)
    end
    self:text(2,h-3,"READ ONLY / USE MAIN SCREEN TO CONTROL",
      C.yellow,C.black,w-4)
  elseif self.page=="READINGS" then
    local readings=self.core.devices.readings
    for i=1,math.min(#readings,math.floor((h-8)/2)) do
      local r=readings[i]
      local value=self.core.devices.values[r.id] or {}
      self:text(2,5+(i-1)*2,r.label..": "..
        tostring(value.value==nil and "--" or value.value).." "..(r.unit or ""),
        value.status=="online" and C.lime or C.orange,C.black,w-4)
    end
  end
  self:text(2,h-1,self.status~="" and self.status or
    "CHART DRAG / DROP: CC TERMINALS ADVANCED",C.lightGray,C.black,w-3)
end
function Screen:tileAt(x,y)
  for _,tile in ipairs(self.tiles) do
    if x>=tile.x and x<tile.x+tile.w and y>=tile.y and y<tile.y+tile.h then
      return tile.id
    end
  end
end
function Screen:moveChart(source,target)
  if not source or not target or source==target then return false end
  local current=self:getMetrics()
  local order={}
  local from,to=nil,nil
  for i,entry in ipairs(current) do
    order[#order+1]=entry[1]
    if entry[1]==source then from=i end
    if entry[1]==target then to=i end
  end
  if not from or not to then return false end
  table.remove(order,from)
  table.insert(order,to,source)
  self.order=order
  self.selection=nil
  self.reorderCount=self.reorderCount+1
  self.status="CHART ORDER UPDATED"
  return true
end
function Screen:activate(x,y)
  for _,button in ipairs(self.buttons) do
    if x>=button.x and x<button.x+button.w and y==button.y then
      button.action()
      self:draw()
      return true
    end
  end
  local id=self:tileAt(x,y)
  if not id then return false end
  if self.reorder then
    if self.selection then
      if id==self.selection then self.selection=nil
      else self:moveChart(self.selection,id) end
    else self.selection=id end
  elseif self.page=="GRAPHS" then
    self.focus=id
  else
    self.page="GRAPHS";self.focus=id
  end
  self:draw()
  return true
end
function Screen:handle(event,a,b,c,d)
  if event=="monitor_touch" and self.kind=="monitor" and a==self.id then
    return self:activate(b,c)
  end
  if self.kind~="terminal" or a~=self.id then return false end
  if event=="terminal_mouse_click" and b==1 then
    self.dragged=self:tileAt(c,d)
    if not self.dragged then return self:activate(c,d) end
    return true
  elseif event=="terminal_mouse_drag" and self.dragged then
    -- Preserve the origin until release; only actual drop changes order.
    return true
  elseif event=="terminal_mouse_up" and b==1 then
    local source=self.dragged
    self.dragged=nil
    if not source then return false end
    local target=self:tileAt(c,d)
    if source and target and source~=target then
      self:moveChart(source,target)
      self:draw()
      return true
    end
    return self:activate(c,d)
  elseif event=="terminal_mouse_scroll" then
    if self.page=="GRAPHS" then
      self.graphPage=math.max(1,self.graphPage+(b>0 and 1 or -1))
      self:draw()
      return true
    end
  end
  return false
end
return Screen
