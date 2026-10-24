-- CIVCRAFT local/network UI built on the RAILBREAK pixel canvas.
-- Never mutate simulation here: all commands flow through dispatch().
local Renderer=dofile("/civcraft/render.lua")
local Hex=dofile("/civcraft/hex.lua")
local Icons=dofile("/civcraft/icons.lua")
local UI={};UI.__index=UI
local P={8,13,11,21}
local MAP_W,MAP_H=Hex.width,Hex.height
local function clip(s,n)return tostring(s or ""):upper():sub(1,math.max(0,n))end
local terrain=Hex.terrain
local function where(list,x,y)
 for _,thing in ipairs(list or {})do
  if thing.x==x and thing.y==y then return thing end
 end
end
local function ownerIndex(state,id)
 for i,p in ipairs(state.players or {})do if p.id==id then return i end end
 return 1
end
function UI.new(m,dispatch)
 local self=setmetatable({r=Renderer.new(m),dispatch=dispatch,
  selected={x=2,y=2},source=nil,mode="map",frame=0,notice=""},UI)
 return self
end
function UI:message(s)self.notice=tostring(s or "")end
function UI:command(action,params)
 if self.dispatch then self.dispatch(action,params or {})end
end
function UI:tile(x,y)
 if self.source then
  local legal=false
  for _,p in ipairs(self.reachable or {})do if p.x==x and p.y==y then legal=true end end
  if legal then
   self:command("move",{sx=self.source.x,sy=self.source.y,x=x,y=y})
   self.source=nil;self.reachable={}
  else
   self.notice="OUT OF RANGE - SELECT HIGHLIGHTED HEX"
  end
 else
  self.selected={x=x,y=y}
  local unit=where(self.state and self.state.units,x,y)
  if unit and unit.owner==self.playerID and not unit.moved then
   self.source={x=x,y=y}
   self.reachable=Hex.reachable(self.state,unit,self.playerID)
   self.notice="SELECT A GREEN HEX TO MOVE"
  else self.reachable={};self.source=nil end
 end
end
function UI:draw(state,playerID,opts)
 local r=self.r;local w,h=r.w,r.h;opts=opts or {}
 r:begin()
 r:fill(0,0,w,h,0)
 local header=math.min(27,math.max(16,math.floor(h*.16)))
 local footer=math.max(22,math.floor(h*.20))
 r:fill(0,0,w,header,1);r:fill(0,header-2,w,2,8)
 r:text(7,math.max(4,math.floor(header/2)-6),"CIVCRAFT",8,w>=150 and 2 or 1,math.max(35,w-75))
 local phase=state and state.phase or "lobby"
 r:text(math.max(50,w-84),math.max(3,header-10),
  phase=="game" and ("ROUND "..state.round)or phase,6,1,80)
 if not state then
  r:center(math.floor(h/2),"CONNECTING TO HOST...",6)
  r:finish();return
 end
 if opts.handoff then
  r:fill(8,header+6,w-16,h-header-18,1)
  r:center(header+12,"PASS THE COMPUTER",8,w>=155 and 2 or 1)
  local active
  for _,p in ipairs(state.players)do if p.id==playerID then active=p end end
  local label=active and active.name or "NEXT PLAYER"
  r:center(header+31,clip(label,18).." - YOUR TURN",7)
  r:center(header+42,"OTHER PLAYERS: LOOK AWAY",5)
  r:button(math.max(6,math.floor(w/2)-44),h-31,88,18,
   "READY TO PLAY",function()self:command("reveal")end,{primary=true})
  r:finish();return
 end
 if phase=="lobby"then
  r:fill(8,header+5,w-16,h-header-15,1)
  r:center(header+9,"LOCAL HOTSEAT" == (opts.localMode and "LOCAL HOTSEAT" or "ONLINE") and
    "LOCAL HOTSEAT" or "NETWORK LOBBY",8)
  r:text(16,header+24,"PLAYERS  "..#state.players.."/4",7)
  for i,p in ipairs(state.players)do
   local row=header+35+(i-1)*13
   r:fill(16,row,math.min(w-32,math.max(50,math.floor(w*.55))),11,2)
   r:fill(16,row,3,11,P[i] or 8)
   r:text(22,row+2,i..". "..clip(p.name,16),7)
  end
  local y=h-37
  if opts.localMode then
   r:button(12,y,40,15,"- PLAYER",function()self:command("removePlayer")end)
   r:button(56,y,40,15,"+ PLAYER",function()self:command("addPlayer")end)
  else
   r:text(13,y,"HOST ID: "..tostring(opts.hostID or "?"),5)
  end
  r:button(math.max(12,w-90),y,75,15,"START GAME",
   function()self:command("start")end,{primary=true})
  r:finish();return
 end
 if phase=="over"then
  r:center(header+20,"GAME COMPLETE",8,2)
  r:center(header+46,"WINNER  "..clip(state.winner,22),7)
  r:button(math.max(12,math.floor(w/2)-40),h-32,80,15,
   "EXIT",function()self:command("exit")end)
  r:finish();return
 end
 self.state=state;self.playerID=playerID
 local mine
 for _,p in ipairs(state.players)do if p.id==playerID then mine=p end end
 local compact=w<150 or h<110
 local top=header+7
 local contentBottom=h-footer-3
 -- Pointy odd-row hexes: centres are half a cell apart horizontally between
 -- adjacent rows; 3/4 cell vertically, matching the same Hex distance rules.
 local reserved=compact and 14 or math.max(75,math.floor(w*.29))
 local tile=math.max(10,math.min(
  math.floor((contentBottom-top-7)/(1+(MAP_H-1)*.75)),
  math.floor((w-reserved-17)/(MAP_W+.5))))
 local stepY=tile*.75
 local mx,my=8,top+2
 self.hexTargets={}
 local boardW,boardH=math.ceil((MAP_W+.5)*tile),math.ceil((MAP_H-1)*stepY+tile)
 r:fill(mx-3,my-3,boardW+6,boardH+6,1)
 r:outline(mx-3,my-3,boardW+6,boardH+6,3)
 local function tilePos(x,y)
  return math.floor(mx+(x-1)*tile+((y-1)%2)*tile/2),
   math.floor(my+(y-1)*stepY)
 end
 for y=1,MAP_H do for x=1,MAP_W do
  local px,py=tilePos(x,y)
  local t=terrain(x,y)
  local c=where(state.cities,x,y)
  local u=where(state.units,x,y)
  local base=t=="water" and 19 or t=="mountain" and 4 or
    t=="forest" and 12 or 2
  local half=math.floor(tile/2)
  local bevel=math.max(2,math.floor(tile*.24))
  -- Filled pointy hex silhouette (top/bottom caps and vertical body).
  for dy=0,tile-1 do
   local inset=dy<bevel and math.floor((bevel-dy)*half/bevel) or
    dy>=tile-bevel and math.floor((dy-(tile-bevel)+1)*half/bevel) or 0
   r:fill(px+inset,py+dy,math.max(1,tile-inset*2-1),1,base)
  end
  r:outline(px+bevel,py,math.max(1,tile-2*bevel),1,3)
  if t=="water" or t=="forest" or t=="mountain"then
   Icons.draw(r,t,px+half-4,py+half-4,9,7)
  end
  local highlighted=false
  for _,p in ipairs(self.reachable or {})do
   if p.x==x and p.y==y then highlighted=true;break end
  end
  if highlighted then
   r:fill(px+bevel,py+tile-3,math.max(2,tile-2*bevel),2,11)
   r:fill(px+1,py+half,2,2,11)
  end
  if c then
   Icons.draw(r,"city",px+half-5,py+half-5,11,P[ownerIndex(state,c.owner)]or 8)
  end
  if u then
   Icons.draw(r,u.kind,px+half-5,py+half-5,11,P[ownerIndex(state,u.owner)]or 8)
   if u.moved then r:fill(px+tile-4,py+half,2,2,4)end
  end
  if self.selected.x==x and self.selected.y==y then
   r:outline(px+bevel,py,math.max(2,tile-2*bevel),tile,8)
  end
  self.hexTargets[#self.hexTargets+1]={x=px,y=py,w=tile,h=tile,
   tx=x,ty=y}
 end end
 local sidebarX=mx+boardW+9
 if not compact and sidebarX<w-48 then
  local sw=w-sidebarX-7
  r:fill(sidebarX,my-3,sw,boardH+6,1)
  r:text(sidebarX+4,my+4,"YOUR EMPIRE",8,1,sw-8)
  if mine then
   r:icon("food",sidebarX+5,my+18,1)
   r:text(sidebarX+17,my+20,"FOOD "..(mine.food or 0),7,1,sw-21)
   r:icon("wood",sidebarX+5,my+32,1)
   r:text(sidebarX+17,my+34,"WOOD "..(mine.wood or 0),7,1,sw-21)
   r:icon("bolt",sidebarX+5,my+46,1)
   r:text(sidebarX+17,my+48,"SCI "..(mine.science or 0),7,1,sw-21)
   r:text(sidebarX+4,my+62,"TECH LV "..(mine.tech or 0),6,1,sw-8)
  end
  for i,p in ipairs(state.players)do
   local iy=my+79+(i-1)*11
   if iy+10<my+boardH then
    r:fill(sidebarX+4,iy,3,9,P[i]or 8)
    r:text(sidebarX+11,iy+2,clip(p.name,math.floor((sw-14)/4))..
      (p.ready and " DONE" or ""),6,1,sw-13)
   end
  end
 else
  if mine then
   r:text(9,my+boardH+3,("F"..mine.food.." W"..mine.wood..
     " S"..mine.science.." T"..mine.tech),7)
  end
 end
 local barY=h-footer+1
 r:fill(0,barY-4,w,footer+4,1)
 r:fill(0,barY-4,w,2,8)
 local selectedCity=where(state.cities,self.selected.x,self.selected.y)
 local selectedUnit=where(state.units,self.selected.x,self.selected.y)
 local description="TILE "..self.selected.x..","..self.selected.y.." "..terrain(self.selected.x,self.selected.y)
 if selectedCity then description=description.." CITY" end
 if selectedUnit then description=description.." "..selectedUnit.kind end
 r:text(8,barY,clip(description,math.floor((w-10)/4)),7)
 local actions={}
 if selectedUnit and selectedUnit.owner==playerID then
  if selectedUnit.kind=="settler"then
   actions[#actions+1]={"FOUND CITY",function()
    self:command("found",{x=self.selected.x,y=self.selected.y})
   end}
  end
  actions[#actions+1]={"MOVE UNIT",function()
   if selectedUnit.moved then self.notice="UNIT HAS ALREADY MOVED";return end
   self.source={x=self.selected.x,y=self.selected.y}
   self.reachable=Hex.reachable(state,selectedUnit,playerID)
  end}
 elseif selectedCity and selectedCity.owner==playerID then
  actions[#actions+1]={"WARRIOR",function()
   self:command("warrior",{x=self.selected.x,y=self.selected.y})end}
  actions[#actions+1]={"SETTLER",function()
   self:command("settler",{x=self.selected.x,y=self.selected.y})end}
  actions[#actions+1]={"RESEARCH",function()
   self:command("research",{x=self.selected.x,y=self.selected.y})end}
 else
  actions[#actions+1]={"INSPECT",function()
   self.notice=terrain(self.selected.x,self.selected.y):upper().." HEX"
  end}
 end
 actions[#actions+1]={"CANCEL",function()
  self.source=nil;self.reachable={}
 end}
 actions[#actions+1]={"END TURN",function()self:command("end")end}
 local cols=math.min(3,#actions);local gap=3;local buttonW=math.floor((w-18-(cols-1)*gap)/cols)
 local buttonH=math.max(10,math.floor((footer-20)/2))
 for i,action in ipairs(actions)do
  local col=(i-1)%cols;local row=math.floor((i-1)/cols)
  r:button(8+col*(buttonW+gap),barY+11+row*(buttonH+2),
   buttonW,buttonH,action[1],action[2],
   {primary=i==6,selected=(i==1 and self.source~=nil)})
 end
 if self.notice~="" and barY>=10 then
  r:text(8,barY-10,clip(self.notice,math.floor((w-12)/4)),8)
 end
 r:finish()
end
function UI:tap(x,y)
 local rx,ry=self.r:touch(x,y)
 if not rx then return false end
 -- Hexes occupy overlapping bounding rectangles. Resolve actual polygon
 -- containment and prefer the closest centre (never the first bounding box).
 local best,distance
 for _,hex in ipairs(self.hexTargets or {})do
  local dx=rx-hex.x;local dy=ry-hex.y
  if dx>=0 and dx<hex.w and dy>=0 and dy<hex.h then
   local bevel=math.max(2,math.floor(hex.w*.24))
   local inset=dy<bevel and (bevel-dy)*hex.w/(2*bevel) or
    dy>=hex.h-bevel and (dy-(hex.h-bevel)+1)*hex.w/(2*bevel) or 0
   if dx>=inset and dx<hex.w-inset then
    local d=(dx-hex.w/2)^2+(dy-hex.h/2)^2
    if not distance or d<distance then best=hex;distance=d end
   end
  end
 end
 if best then self:tile(best.tx,best.ty);return true end
 return self.r:hit(rx,ry)
end
function UI:resize()self.r:resize()end
function UI:close()self.r:close()end
return UI
