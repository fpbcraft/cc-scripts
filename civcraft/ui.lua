-- CIVCRAFT local/network UI built on the RAILBREAK pixel canvas.
-- Never mutate simulation here: all commands flow through dispatch().
local Renderer=dofile("/civcraft/render.lua")
local UI={};UI.__index=UI
local P={8,13,11,21}
local MAP_W,MAP_H=12,8
local function clip(s,n)return tostring(s or ""):upper():sub(1,math.max(0,n))end
local function terrain(x,y)
 local v=(x*37+y*61+x*y*13)%19
 if v<=1 then return "water" end
 if v<=3 then return "mountain" end
 if v<9 then return "forest" end
 return "plains"
end
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
  self:command("move",{sx=self.source.x,sy=self.source.y,x=x,y=y})
  self.source=nil
 else self.selected={x=x,y=y}end
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
 local mine
 for _,p in ipairs(state.players)do if p.id==playerID then mine=p end end
 local compact=w<150 or h<110
 local top=header+7
 local contentBottom=h-footer-3
 local tile=math.max(3,math.min(
  math.floor((contentBottom-top-4)/MAP_H),
  math.floor((w-(compact and 8 or math.max(68,math.floor(w*.29)))-18)/MAP_W)))
 local mx,my=8,top+2
 local boardW,boardH=MAP_W*tile,MAP_H*tile
 r:fill(mx-3,my-3,boardW+6,boardH+6,1)
 r:outline(mx-3,my-3,boardW+6,boardH+6,3)
 for y=1,MAP_H do for x=1,MAP_W do
  local px=mx+(x-1)*tile;local py=my+(y-1)*tile
  local t=terrain(x,y)
  local c=where(state.cities,x,y)
  local u=where(state.units,x,y)
  local base=t=="water" and 19 or t=="mountain" and 4 or
    t=="forest" and 12 or 2
  r:fill(px,py,tile-1,tile-1,base)
  if t=="water"then
   r:fill(px+2,py+math.floor(tile/2),math.max(1,tile-5),1,13)
  elseif t=="mountain"then
   r:fill(px+math.floor(tile/2),py+1,2,math.max(1,tile-3),5)
  elseif t=="forest"then
   r:fill(px+math.floor(tile/3),py+2,math.max(1,math.floor(tile/3)),
    math.max(1,tile-4),11)
  end
  if c then
   local pc=P[ownerIndex(state,c.owner)]or 8
   r:fill(px+1,py+math.floor(tile*.35),math.max(1,tile-3),
     math.max(2,math.floor(tile*.55)),pc)
   r:fill(px+2,py+1,math.max(1,tile-5),2,7)
  end
  if u then
   local pc=P[ownerIndex(state,u.owner)]or 8
   if u.kind=="warrior"then
    r:fill(px+math.floor(tile/3),py+1,math.max(2,math.floor(tile/3)),
      math.max(2,tile-3),pc)
    r:fill(px+1,py+math.floor(tile/2),tile-2,2,7)
   else
    r:fill(px+1,py+math.floor(tile/2),tile-2,math.max(2,math.floor(tile/3)),pc)
    r:fill(px+math.floor(tile/3),py+2,math.max(2,math.floor(tile/3)),2,7)
   end
  end
  if self.selected.x==x and self.selected.y==y then
   r:outline(px,py,tile-1,tile-1,8)
  end
  r.buttons[#r.buttons+1]={x=px,y=py,w=tile,h=tile,fn=function()self:tile(x,y)end}
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
 local actions={{"MOVE",function()self.source={x=self.selected.x,y=self.selected.y};self.notice="SELECT DESTINATION"end},
  {"FOUND",function()self:command("found",{x=self.selected.x,y=self.selected.y})end},
  {"WARRIOR",function()self:command("warrior",{x=self.selected.x,y=self.selected.y})end},
  {"SETTLER",function()self:command("settler",{x=self.selected.x,y=self.selected.y})end},
  {"RESEARCH",function()self:command("research",{x=self.selected.x,y=self.selected.y})end},
  {"END TURN",function()self:command("end")end}}
 local cols=3;local gap=3;local buttonW=math.floor((w-18-(cols-1)*gap)/cols)
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
 if rx then return self.r:hit(rx,ry)end
 return false
end
function UI:resize()self.r:resize()end
function UI:close()self.r:close()end
return UI
