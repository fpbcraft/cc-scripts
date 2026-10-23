-- CC: Graphics optional high-resolution renderer for a SECONDARY display.
-- Never calls setGraphicsMode() on the Basalt primary display.
-- Compatible with CraftOS-PC/CC: Graphics pixels and 0-based positions.
local Viewer={}
Viewer.__index=Viewer
local C={
  background=0,panel=1,grid=2,edge=3,text=4,muted=5,
  cyan=6,orange=7,green=8,blue=9,pink=10,yellow=11,red=12,purple=13
}
local RGB={
  [0]=0x09121B,0x10202D,0x254153,0x365669,0xE9F5FF,0x8FA6B7,
  0x27C5E9,0xF2A64C,0x57DAA1,0x64A7FA,0xF075AF,0xF4D266,
  0xF06B78,0xB69AF8
}
local CHAR={
  [" "]={0,0,0,0,0,0,0},["-"]={0,0,0,31,0,0,0},
  ["."]={0,0,0,0,0,12,12},[":"]={0,12,12,0,12,12,0},
  ["/"]={1,2,4,8,16,0,0},["%"]={17,2,4,8,17,0,0},
  ["_"]={0,0,0,0,0,0,31},["?"]={14,17,1,2,4,0,4},
  ["("]={2,4,8,8,8,4,2},[")"]={8,4,2,2,2,4,8},
  ["0"]={14,17,19,21,25,17,14},["1"]={4,12,4,4,4,4,14},
  ["2"]={14,17,1,2,4,8,31},["3"]={30,1,1,14,1,1,30},
  ["4"]={2,6,10,18,31,2,2},["5"]={31,16,30,1,1,17,14},
  ["6"]={7,8,16,30,17,17,14},["7"]={31,1,2,4,8,8,8},
  ["8"]={14,17,17,14,17,17,14},["9"]={14,17,17,15,1,2,28},
  ["A"]={14,17,17,31,17,17,17},["B"]={30,17,17,30,17,17,30},
  ["C"]={14,17,16,16,16,17,14},["D"]={30,17,17,17,17,17,30},
  ["E"]={31,16,16,30,16,16,31},["F"]={31,16,16,30,16,16,16},
  ["G"]={14,17,16,23,17,17,15},["H"]={17,17,17,31,17,17,17},
  ["I"]={14,4,4,4,4,4,14},["J"]={7,2,2,2,18,18,12},
  ["K"]={17,18,20,24,20,18,17},["L"]={16,16,16,16,16,16,31},
  ["M"]={17,27,21,21,17,17,17},["N"]={17,25,21,19,17,17,17},
  ["O"]={14,17,17,17,17,17,14},["P"]={30,17,17,30,16,16,16},
  ["Q"]={14,17,17,17,21,18,13},["R"]={30,17,17,30,20,18,17},
  ["S"]={15,16,16,14,1,1,30},["T"]={31,4,4,4,4,4,4},
  ["U"]={17,17,17,17,17,17,14},["V"]={17,17,17,17,17,10,4},
  ["W"]={17,17,17,21,21,21,10},["X"]={17,17,10,4,10,17,17},
  ["Y"]={17,17,10,4,4,4,4},["Z"]={31,1,2,4,8,16,31},
  ["="]={0,31,0,0,31,0,0},["+"]={0,4,4,31,4,4,0},
  ["#"]={10,10,31,10,31,10,10},["|"]={4,4,4,4,4,4,4}
}
local function finite(n)
  return type(n)=="number" and n==n and n<math.huge and n>-math.huge
end
local function clamp(n,a,b)
  return math.max(a,math.min(b,n))
end
local function fmt(n)
  if not finite(n) then return "--" end
  local a=math.abs(n)
  if a>=1e9 then return string.format("%.1fG",n/1e9)
  elseif a>=1e6 then return string.format("%.1fM",n/1e6)
  elseif a>=10000 then return string.format("%.1fK",n/1000)
  elseif a>=100 then return string.format("%.0f",n)
  elseif a>=10 then return string.format("%.1f",n)
  else return string.format("%.2f",n) end
end
local function shorten(s,limit)
  s=tostring(s or ""):upper()
  s=s:gsub("[ÀÁÂÃÄÅ]","A"):gsub("[ÈÉÊË]","E")
    :gsub("[ÌÍÎÏ]","I"):gsub("[ÒÓÔÕÖ]","O")
    :gsub("[ÙÚÛÜ]","U"):gsub("Ç","C"):gsub("Ñ","N")
    :gsub("[^A-Z0-9 %./:_+%-#|()]","?")
  return s:sub(1,math.max(1,limit))
end
local function tickStep(range)
  if not finite(range) or range<=0 then return 1 end
  local raw=range/4
  local magnitude=10^math.floor(math.log(raw)/math.log(10))
  local n=raw/magnitude
  return (n<=1 and 1 or n<=2 and 2 or n<=5 and 5 or 10)*magnitude
end
local function dimensions(screen)
  local ok,w,h=pcall(screen.getSize,2)
  if not ok or type(w)~="number" or type(h)~="number" then
    return nil,nil
  end
  return w,h
end
function Viewer.supported(screen)
  if not screen or type(screen.setGraphicsMode)~="function" or
     type(screen.getGraphicsMode)~="function" or
     type(screen.drawPixels)~="function" or
     type(screen.setPixel)~="function" then return false end
  local w,h=dimensions(screen)
  return w~=nil and w>=120 and h>=90
end
function Viewer.new(screen)
  assert(Viewer.supported(screen),"Pixel graphics unsupported")
  return setmetatable({screen=screen,active=false,mode=0,
    w=0,h=0,drawCount=0},Viewer)
end
function Viewer:start()
  if self.active then return true end
  local screen=self.screen
  local old=screen.getGraphicsMode()
  local ok=pcall(screen.setGraphicsMode,2)
  local mode=2
  if not ok then
    ok=pcall(screen.setGraphicsMode,1)
    mode=1
  end
  if not ok then return false,"Could not enter pixel mode" end
  self.mode=mode
  self.previousMode=old
  self.w,self.h=dimensions(screen)
  if not self.w then
    pcall(screen.setGraphicsMode,old or false)
    return false,"Pixel dimensions unavailable"
  end
  if mode==2 then
    for index,rgb in pairs(RGB) do
      pcall(screen.setPaletteColor,index,rgb)
    end
  end
  self.active=true
  return true
end
function Viewer:stop()
  if not self.active then return end
  self.active=false
  local screen=self.screen
  if screen.setFrozen then pcall(screen.setFrozen,false) end
  pcall(screen.setGraphicsMode,self.previousMode or false)
end
function Viewer:color(index)
  if self.mode==2 then return index end
  local lookup={
    [C.background]=colors.black,[C.panel]=colors.gray,
    [C.grid]=colors.gray,[C.edge]=colors.lightGray,
    [C.text]=colors.white,[C.muted]=colors.lightGray,
    [C.cyan]=colors.cyan,[C.orange]=colors.orange,
    [C.green]=colors.lime,[C.blue]=colors.lightBlue,
    [C.pink]=colors.pink,[C.yellow]=colors.yellow,
    [C.red]=colors.red,[C.purple]=colors.purple
  }
  return lookup[index] or colors.white
end
function Viewer:fill(x,y,w,h,col)
  x=math.floor(x);y=math.floor(y);w=math.floor(w);h=math.floor(h)
  if x<0 then w=w+x;x=0 end
  if y<0 then h=h+y;y=0 end
  w=math.min(w,self.w-x);h=math.min(h,self.h-y)
  if w>0 and h>0 then
    self.screen.drawPixels(x,y,self:color(col),w,h)
  end
end
function Viewer:pixel(x,y,col)
  x=math.floor(x);y=math.floor(y)
  if x>=0 and x<self.w and y>=0 and y<self.h then
    self.screen.setPixel(x,y,self:color(col))
  end
end
function Viewer:line(x1,y1,x2,y2,col)
  x1=math.floor(x1+0.5);x2=math.floor(x2+0.5)
  y1=math.floor(y1+0.5);y2=math.floor(y2+0.5)
  local dx=math.abs(x2-x1)
  local dy=math.abs(y2-y1)
  if dx+dy>math.max(self.w,self.h)*6 then return end
  if y1==y2 then
    self:fill(math.min(x1,x2),y1,dx+1,1,col)
    return
  end
  if x1==x2 then
    self:fill(x1,math.min(y1,y2),1,dy+1,col)
    return
  end
  local sx=x1<x2 and 1 or -1
  local sy=y1<y2 and 1 or -1
  local err=dx-dy
  while true do
    self:pixel(x1,y1,col)
    if x1==x2 and y1==y2 then break end
    local twice=2*err
    if twice>-dy then err=err-dy;x1=x1+sx end
    if twice<dx then err=err+dx;y1=y1+sy end
  end
end
function Viewer:text(x,y,string,color,scale,maxChars)
  scale=scale or 1
  string=shorten(string,maxChars or 80)
  for i=1,#string do
    local rows=CHAR[string:sub(i,i)] or CHAR["?"]
    for row,bits in ipairs(rows) do
      for col=0,4 do
        if bits%2^(5-col)>=2^(4-col) then
          self:fill(x+(i-1)*6*scale+col*scale,
            y+(row-1)*scale,scale,scale,color)
        end
      end
    end
  end
end
-- Preserve gaps and actual elapsed time. Missing values are not joined.
function Viewer.series(samples,key,range,clock)
  local output={}
  clock=tonumber(clock)
  if not clock then
    clock=#samples>0 and samples[#samples].time or 0
  end
  local cutoff=range==0 and -math.huge or clock-range
  for _,sample in ipairs(samples or {}) do
    local t=sample.time
    if finite(t) and t>=cutoff and t<=clock then
      local value=sample[key]
      output[#output+1]={time=t,value=finite(value) and value or nil}
    end
  end
  return output
end
local function bounds(data)
  local min,max=nil,nil
  for _,entry in ipairs(data) do
    if finite(entry.value) then
      min=not min and entry.value or math.min(min,entry.value)
      max=not max and entry.value or math.max(max,entry.value)
    end
  end
  if min==nil then return 0,100,0 end
  local step=tickStep(math.max(1e-9,max-math.min(0,min)))
  local low=math.floor(math.min(0,min)/step)*step
  local high=math.ceil(math.max(0,max)/step)*step
  if high<=low then high=low+step end
  return low,high,#data
end
function Viewer:chart(samples,metric,x,y,w,h,range,clock,palette,overlays)
  local key,title,unit=metric[1],metric[2],metric[3]
  self:fill(x,y,w,h,C.panel)
  self:fill(x,y,w,1,C.edge)
  self:text(x+10,y+7,title,C.text,1,math.floor((w-20)/6))
  local plotX=x+58
  local plotY=y+35
  local plotW=w-70
  local plotH=h-66
  if plotW<20 or plotH<15 then return end
  local data=Viewer.series(samples,key,range,clock)
  local combined={}
  for _,item in ipairs(data) do combined[#combined+1]=item end
  local extra={}
  for _,other in ipairs(overlays or {}) do
    if other[1]~=key and other[3]==unit then
      local series=Viewer.series(samples,other[1],range,clock)
      extra[#extra+1]={metric=other,series=series}
      for _,item in ipairs(series) do combined[#combined+1]=item end
    end
  end
  local low,high=bounds(combined)
  local startTime=clock-(range==0 and
    (#data>1 and clock-data[1].time or 60) or range)
  if startTime==clock then startTime=clock-60 end
  for i=0,4 do
    local yy=plotY+math.floor((plotH-1)*i/4)
    self:line(plotX,yy,plotX+plotW-1,yy,C.grid)
    self:text(x+4,yy-3,fmt(high-(high-low)*i/4),C.muted,1,8)
  end
  for i=0,4 do
    local xx=plotX+math.floor((plotW-1)*i/4)
    self:line(xx,plotY,xx,plotY+plotH-1,C.grid)
  end
  self:line(plotX,plotY,plotX,plotY+plotH,C.text)
  self:line(plotX,plotY+plotH,plotX+plotW,plotY+plotH,C.text)
  local stroke=palette or C.cyan
  local function trace(points,color)
    local prev=nil
    for _,point in ipairs(points) do
      if finite(point.value) then
        local xx=plotX+clamp((point.time-startTime)/(clock-startTime),0,1)*(plotW-1)
        local yy=plotY+plotH-1-
          clamp((point.value-low)/(high-low),0,1)*(plotH-1)
        if prev then self:line(prev[1],prev[2],xx,yy,color) end
        prev={xx,yy}
      else prev=nil end
    end
  end
  trace(data,stroke)
  for i,extraLine in ipairs(extra) do
    local color=({C.green,C.orange,C.pink})[((i-1)%3)+1]
    trace(extraLine.series,color)
    self:text(plotX+8,plotY+5+(i-1)*11,extraLine.metric[2],
      color,1,math.floor((plotW-18)/6))
  end
  local value="--"
  for i=#data,1,-1 do
    if finite(data[i].value) then value=fmt(data[i].value);break end
  end
  self:text(x+10,y+19,value.." "..(unit or ""),stroke,1,
    math.floor((w-18)/6))
  local shownRange=range==0 and "ALL" or range<3600 and
    (tostring(range/60).." MIN") or (tostring(range/3600).." HR")
  self:text(plotX,plotY+plotH+9,"-"..shownRange,C.muted,1,13)
  self:text(plotX+plotW-20,plotY+plotH+9,"NOW",C.muted,1,3)
  if #data==0 then
    self:text(plotX+10,plotY+plotH/2,"NO NUMERIC DATA",C.orange,1,20)
  end
end
function Viewer:render(samples,metrics,options)
  assert(self.active,"Graphics viewer is not active")
  samples=samples or {}
  metrics=metrics or {}
  options=options or {}
  local range=options.range or 300
  local clock=options.clock or
    (#samples>0 and samples[#samples].time) or 0
  local detail=options.detail
  local toDraw={}
  if detail then
    for _,metric in ipairs(metrics) do
      if metric[1]==detail then toDraw[1]=metric;break end
    end
  end
  if #toDraw==0 then
    for i=1,math.min(4,#metrics) do toDraw[#toDraw+1]=metrics[i] end
  end
  if self.screen.setFrozen then pcall(self.screen.setFrozen,true) end
  local ok,err=pcall(function()
    self:fill(0,0,self.w,self.h,C.background)
    self:text(12,10,"FPBCRAFT / HIGH RES TELEMETRY",C.cyan,1,43)
    local count=#toDraw
    -- A small computer screen is often only ~170 pixel rows: show two
    -- useful charts rather than four tiny charts with invisible plot areas.
    if not detail and self.h<255 and #toDraw>2 then
      while #toDraw>2 do table.remove(toDraw) end
      count=#toDraw
    end
    local cols=detail and 1 or (count>=2 and 2 or 1)
    local rows=math.max(1,math.ceil(count/cols))
    local margin=12
    local top=32
    local cw=math.floor((self.w-margin*(cols+1))/cols)
    local ch=math.floor((self.h-top-margin*(rows+1))/rows)
    for i,metric in ipairs(toDraw) do
      local ix=(i-1)%cols
      local iy=math.floor((i-1)/cols)
      local px=margin+ix*(cw+margin)
      local py=top+margin+iy*(ch+margin)
      self:chart(samples,metric,px,py,cw,ch,range,clock,
        ({C.cyan,C.green,C.orange,C.pink})[i],
        detail and options.overlay and metrics or nil)
    end
    if count==0 then
      self:text(20,self.h/2,"NO TRACKED METRICS",C.orange,2,35)
    end
    self:text(12,self.h-13,"CONTROL FROM MAIN MONITOR - PIXEL VIEW IS READ ONLY",
      C.muted,1,69)
  end)
  if self.screen.setFrozen then pcall(self.screen.setFrozen,false) end
  if not ok then return false,tostring(err) end
  self.drawCount=self.drawCount+1
  return true
end
return Viewer
