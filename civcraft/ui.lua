-- CIVCRAFT local/network UI built on the RAILBREAK pixel canvas.
-- Never mutate simulation here: all commands flow through dispatch().
local Renderer=dofile("/civcraft/render.lua")
local Hex=dofile("/civcraft/hex.lua")
local Systems=dofile("/civcraft/systems.lua")
local World=dofile("/civcraft/world.lua")
local TechTree=dofile("/civcraft/tech_tree.lua")
local Icons=dofile("/civcraft/icons.lua")
local UI={};UI.__index=UI
local P={8,13,11,21}
local MAP_W,MAP_H=Hex.width,Hex.height
local function clip(s,n)return tostring(s or ""):upper():sub(1,math.max(0,n))end
local function terrain(x,y,state)return Hex.terrain(x,y,state)end
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
   mapMode="terrain",panX=0,panY=0,
  selected={x=2,y=2},source=nil,mode="map",frame=0,notice="",panel="context",
  mapMode="terrain",productionCategory="unit",productionPage=1,workCity=nil},UI)
 return self
end
function UI:message(s)self.notice=tostring(s or "")end
function UI:command(action,params)
 if self.dispatch then self.dispatch(action,params or {})end
end
function UI:tile(x,y)
 if self.workCity then
  self:command("workTile",{cityX=self.workCity.x,cityY=self.workCity.y,x=x,y=y})
  return
 end
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
  self.selected={x=x,y=y};self.panel="context";self.actionPage=1
  self.cityPanel="jobs";self.workCity=nil
  local unit=where(self.state and self.state.units,x,y)
  if unit and unit.owner==self.playerID and not unit.moved then
   self.source={x=x,y=y}
   self.reachable=Hex.reachable(self.state,unit,self.playerID,Systems)
   self.notice="SELECT A GREEN HEX TO MOVE"
  else self.reachable={};self.source=nil end
 end
end
function UI:draw(state,playerID,opts)
 local r=self.r;local w,h=r.w,r.h;opts=opts or {}
 -- Never carry a previous hotseat player's selection or movement overlay
 -- into the next player's screen (including the concealed handoff).
 if self.lastPlayer~=nil and self.lastPlayer~=playerID then
  self.source=nil;self.reachable={};self.panel="context"
  self.actionPage=1;self.techModel=nil;self.workCity=nil
  self.selected={x=2,y=2}
  for _,city in ipairs(state.cities or {})do
   if city.owner==playerID then
    self.selected={x=city.x,y=city.y};break
   end
  end
 end
 self.lastPlayer=playerID
 if opts.handoff or
    (self.state and self.source and not (function()
      for _,u in ipairs(state.units or {})do
       if u.x==self.source.x and u.y==self.source.y and
         u.owner==playerID and not u.moved then return true end
      end
      return false
     end)())then
  self.source=nil;self.reachable={}
 end
 r:begin()
 self.hexTargets={}
 self.modalBounds=nil
 r:fill(0,0,w,h,0)
 self.state=state;self.playerID=playerID
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
 if opts.screen=="title" then
  if h<115 then
   r:center(3,"CIVCRAFT",8,1)
   r:center(11,"SELECT A SAVE SLOT",6)
   if opts.slots then
    local size=math.floor((w-8)/3)
    for i,record in ipairs(opts.slots)do
     local label="SLOT "..i..(record.occupied and " R"..(record.round or 1) or " FREE")
     r:button(3+(i-1)*size,16,size-2,10,label,function()
      self:command("selectSlot",{slot=i})
     end,{primary=opts.slot==i})
    end
   end
   local by=math.max(26,h-31)
   local bx,bw=math.max(4,math.floor(w*.12)),math.max(33,math.floor(w*.76))
   r:button(bx,by,bw,10,"NEW CAMPAIGN",function()self:command("newGame")end,{primary=true})
   r:button(bx,by+10,bw,10,"CONTINUE",function()self:command("continue")end)
   r:button(bx,by+20,bw,10,"EXIT",function()self:command("exit")end)
   r:finish();return
  end
  r:center(math.floor(h*.10),"CIVCRAFT",8,w>=155 and 3 or 2)
  r:center(math.floor(h*.23),"HEX EMPIRES / EXPLORE / CONQUER",7)
  local bw=math.min(w-20,math.max(100,math.floor(w*.72)))
  local bx=math.floor((w-bw)/2)
  if opts.slots then
   local sy=math.floor(h*.32)
   for i,record in ipairs(opts.slots)do
    local active=i==opts.slot
    local title=record.occupied and
     ("SLOT "..i.."  "..(record.name or "CAMPAIGN").."  R"..(record.round or 1)) or
     ("SLOT "..i.."  EMPTY")
    r:button(bx,sy+(i-1)*21,bw-35,17,title,function()
     self:command("selectSlot",{slot=i})
    end,{primary=active})
   end
   r:button(bx+bw-31,sy,31,17,
    opts.deleteConfirm==opts.slot and "SURE?" or "DELETE",
    function()self:command("deleteSlot")end)
  end
  local by=math.min(h-53,math.max(math.floor(h*.55),math.floor(h*.32)+65))
  r:button(bx,by,bw,16,"NEW CAMPAIGN",
   function()self:command("newGame")end,{primary=true})
  r:button(bx,by+19,bw,16,
   opts.hasSave and "CONTINUE CAMPAIGN" or "NO SAVED CAMPAIGN",
   function()self:command("continue")end)
  r:button(bx,by+38,bw,14,"EXIT",
   function()self:command("exit")end)
  r:finish();return
 end
 if opts.paused then
  r:center(math.floor(h*.24),"PAUSED",8,2)
  local bw=math.min(105,w-30);local x=math.floor((w-bw)/2)
  r:button(x,math.floor(h*.38),bw,18,"RESUME",function()self:command("resume")end,{primary=true})
  r:button(x,math.floor(h*.38)+22,bw,18,"SAVE",function()self:command("save")end)
  r:button(x,math.floor(h*.38)+44,bw,18,"MAIN MENU",function()self:command("title")end)
  r:button(x,math.floor(h*.38)+66,bw,18,"EXIT",function()self:command("exit")end)
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
   r:text(22,row+2,i..". "..clip(p.name,9).." "..clip(Systems.civ(p.civ).name,17),7)
   if opts.localMode then
    r:button(math.min(w-56,150),row,23,11,p.ai and "AI" or "HUMAN",
     function()self:command("toggleAI",{player=i})end)
    r:button(math.min(w-29,179),row,22,11,"CIV",
     function()self:command("civ",{player=i})end)
   end
  end
  local y=h-37
  r:text(13,y-27,"MAP "..tostring(state.mapSize or "STANDARD"):upper()..
   " / "..tostring(state.mapType or "continents"):upper()..
    " / SEED "..tostring(state.mapSeed or 12345),8,1,w-25)
  r:button(12,y-15,52,12,"MAP SIZE",function()self:command("mapSize")end)
  r:button(68,y-15,58,12,"MAP TYPE",function()self:command("mapType")end)
   r:button(128,y-15,58,12,"REROLL SEED",function()self:command("mapSeed")end)
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
 local compact=w<185 or h<120
 local world=state.world
 local MAP_W,MAP_H=world and world.width or Hex.width,
  world and world.height or Hex.height
 local top=header+5
 local barY=h-math.max(18,math.floor(h*.115))
 local contentBottom=barY-2
 local leftW=compact and 35 or 54
 local rightW=compact and math.max(62,math.floor(w*.31)) or
   math.max(88,math.floor(w*.30))
 local vx,vy=leftW+3,top+1
 local vw=math.max(44,w-leftW-rightW-9)
 local vh=math.max(48,contentBottom-vy)
 local tile=math.max(12,math.min(23,math.floor(vh/8)))
 local stepY=tile*.75
 local boardW=(MAP_W+.5)*tile
 local boardH=(MAP_H-1)*stepY+tile
 local maxPanX=math.max(0,math.ceil(boardW-vw))
 local maxPanY=math.max(0,math.ceil(boardH-vh))
 if self.lastWorld~=world then
  self.panX,self.panY=0,0;self.lastWorld=world
  for _,c in ipairs(state.cities)do
   if c.owner==playerID then
    self.panX=(c.x-.5)*tile-vw/2
    self.panY=(c.y-.5)*stepY-vh/2;break
   end
  end
 end
 self.panX=math.max(0,math.min(maxPanX,self.panX or 0))
 self.panY=math.max(0,math.min(maxPanY,self.panY or 0))
 self.mapViewport={x=vx,y=vy,w=vw,h=vh,tile=tile,
  maxX=maxPanX,maxY=maxPanY}
 self.hexTargets={}
 r:fill(vx-2,vy-2,vw+4,vh+4,1)
 r:outline(vx-2,vy-2,vw+4,vh+4,3)
 local function tilePos(x,y)
  return math.floor(vx+(x-1)*tile+((y-1)%2)*tile/2-self.panX),
   math.floor(vy+(y-1)*stepY-self.panY)
 end
 local owners=World.territory(state,Hex)
 for y=1,MAP_H do for x=1,MAP_W do
  local px,py=tilePos(x,y)
  if px+tile>vx and px<vx+vw and py+tile>vy and py<vy+vh then
   local visibility=World.known(mine,x,y)
   local hidden=visibility=="hidden"
   local t=terrain(x,y,state)
   local c=not hidden and where(state.cities,x,y)
   local u=visibility=="visible" and where(state.units,x,y)
   if c and c.owner~=playerID and visibility~="visible" then c=nil end
   local owner=owners[World.key(x,y)]
   if owner~=playerID and visibility~="visible" then owner=nil end
   local deposit=not hidden and World.deposit(world,x,y) or nil
   local hexYield=not hidden and World.yields(world,x,y) or nil
   local base=hidden and 15 or
    visibility=="explored" and 14 or
    t=="water" and 19 or t=="mountain" and 4 or
    t=="forest" and 12 or t=="hills" and 9 or 2
   if visibility=="visible" then
    if self.mapMode=="territory" then base=owner and P[ownerIndex(state,owner)] or 3
    elseif self.mapMode=="resources"then base=deposit and 9 or 2
    elseif self.mapMode=="yields"then
     base=hexYield.science>hexYield.industry and 8 or
      hexYield.food>=hexYield.industry and 12 or 9
    end
   end
   local half=math.floor(tile/2)
   local bevel=math.max(2,math.floor(tile*.24))
   for dy=0,tile-1 do
    local inset=dy<bevel and math.floor((bevel-dy)*half/bevel) or
      dy>=tile-bevel and math.floor((dy-(tile-bevel)+1)*half/bevel) or 0
    r:fill(px+inset,py+dy,math.max(1,tile-inset*2-1),1,base)
   end
   if tile>=14 and deposit and
      (self.mapMode=="resources" or self.mapMode=="terrain")then
    Icons.draw(r,deposit,px+half-5,py+1,11,9)
   elseif tile>=13 and not hidden and visibility=="visible" and
      (t=="forest" or t=="mountain" or t=="water")then
    Icons.draw(r,t,px+half-4,py+half-4,9,7)
   end
   if self.mapMode=="yields" and hexYield and tile>=17 and
      visibility=="visible"then
    r:text(px+2,py+3,"F"..hexYield.food,7,1,tile-3)
    r:text(px+2,py+tile-10,"P"..hexYield.industry,7,1,tile-3)
   end
   if owner and not hidden then
    local borderColor=P[ownerIndex(state,owner)] or 8
    if self.mapMode=="territory"then r:fill(px+half-2,py+half-2,4,4,borderColor)end
    local edge={
     {x=px+half,y=py},{x=px+tile-1,y=py+bevel},
     {x=px+tile-1,y=py+tile-bevel},
     {x=px+half,y=py+tile-1},
     {x=px,y=py+tile-bevel},{x=px,y=py+bevel}
    }
    -- Border only the edges facing territory of another owner or no owner.
    -- Neighbor order comes from the same pointy-top odd-row coordinates.
    local dirs=(y%2==1) and
      {{-1,-1},{0,-1},{1,0},{0,1},{-1,1},{-1,0}} or
      {{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,0}}
    for side=1,6 do
     local n=dirs[side]
     if owners[World.key(x+n[1],y+n[2])]~=owner then
      local a1=edge[side];local b1=edge[side%6+1]
      if a1.x>=vx and a1.x<vx+vw and a1.y>=vy and a1.y<vy+vh and
          b1.x>=vx and b1.x<vx+vw and b1.y>=vy and b1.y<vy+vh then
       r:line(a1.x,a1.y,b1.x,b1.y,borderColor)
      end
     end
    end
   end
   if self.workCity and visibility~="hidden" and
      Hex.distance(x,y,self.workCity.x,self.workCity.y)<=2 then
    local city=where(state.cities,self.workCity.x,self.workCity.y)
    if city and World.territoryCity(state,Hex,x,y)==city and
       not(x==city.x and y==city.y)then
     local employed=city.worked and city.worked[World.key(x,y)]
     r:fill(px+bevel,py+tile-4,math.max(2,tile-2*bevel),3,
      employed and 11 or 9)
    end
   end
   local reach
   for _,p in ipairs(self.reachable or {})do
    if p.x==x and p.y==y then reach=p;break end
   end
   if reach and px>=vx and px+tile<=vx+vw and py>=vy and py+tile<=vy+vh then
    local color=reach.attack and 10 or 11
    r:fill(px+bevel,py+tile-3,math.max(2,tile-2*bevel),2,color)
    r:text(px+half-2,py+tile-10,reach.ranged and "R" or
      tostring(reach.cost),7,1,8)
   end
   if c and px>=vx and px+tile<=vx+vw and py>=vy and py+tile<=vy+vh then
    Icons.draw(r,"city",px+half-5,py+half-5,11,P[ownerIndex(state,c.owner)]or 8)
   end
   if u and px>=vx and px+tile<=vx+vw and py>=vy and py+tile<=vy+vh then
    Icons.draw(r,u.kind,px+half-5,py+half-5,11,P[ownerIndex(state,u.owner)]or 8)
   end
   if self.selected.x==x and self.selected.y==y and px>=vx and
      px+tile<=vx+vw and py>=vy and py+tile<=vy+vh then
    r:outline(px+bevel,py,math.max(2,tile-2*bevel),tile,8)
   end
   if px>=vx and py>=vy and px+tile<=vx+vw and py+tile<=vy+vh then
    self.hexTargets[#self.hexTargets+1]={x=px,y=py,w=tile,h=tile,tx=x,ty=y}
   end
  end
 end end
 -- Overlay the two side bars after painting the world, never as map children.
 r:fill(0,top,leftW,contentBottom-top,1)
 r:fill(w-rightW-1,top,rightW+1,contentBottom-top,1)
 r:fill(leftW,top,2,contentBottom-top,3)
 r:fill(w-rightW-2,top,2,contentBottom-top,3)
 local bx=3;local bw=math.max(28,leftW-6)
 r:text(bx+2,top+3,"MAP",8,1,bw-4)
 local mapModes={{"TERRAIN","map"},{"TERRITORY","station"},
   {"RESOURCES","ore"},{"YIELDS","food"}}
 for i,entry in ipairs(mapModes)do
  local py=top+15+(i-1)*18
  r:button(bx,py,bw,16,entry[1],function()
   self.mapMode=entry[1]:lower()
  end,{icon=entry[2],selected=(self.mapMode or "terrain")==entry[1]:lower()})
 end
 local navY=top+93
 r:button(bx,navY,bw,13,"UP",function()self:pan(0,-tile*3)end,{icon="map"})
 r:button(bx,navY+15,bw,13,"LEFT",function()self:pan(-tile*3,0)end,{icon="back"})
 r:button(bx,navY+30,bw,13,"RIGHT",function()self:pan(tile*3,0)end,{icon="right"})
 r:button(bx,navY+45,bw,13,"DOWN",function()self:pan(0,tile*3)end,{icon="map"})
 r:button(bx,navY+60,bw,13,"CENTER",function()
  local px,py=tilePos(self.selected.x,self.selected.y)
  self:pan(px-(vx+vw/2),py-(vy+vh/2))
 end,{icon="map"})
 local sidebarX=w-rightW+1
 local sw=rightW-5
 local selectedCity=where(state.cities,self.selected.x,self.selected.y)
 local selectedUnit=where(state.units,self.selected.x,self.selected.y)
 r:text(sidebarX+3,top+3,"INSPECTOR",8,1,sw-7)
 if selectedCity and selectedCity.owner==playerID then
  r:icon("station",sidebarX+3,top+17,1)
  r:text(sidebarX+16,top+19,"CITY POP "..(selectedCity.population or 2),7,1,sw-19)
  local yields=Systems.yields(mine,selectedCity,state,Hex,owners)
  r:text(sidebarX+3,top+31,"F"..yields.food.." I"..yields.industry..
    " S"..yields.science.."/TURN",11,1,sw-6)
  if selectedCity.project then
   local pr=selectedCity.project
   local cost=Systems.projectCost(pr.kind,pr.id) or 1
   local remain=math.ceil((cost-pr.progress)/math.max(1,yields.industry))
   r:text(sidebarX+3,top+42,pr.id:upper().." "..math.max(0,remain).." TURNS",8,1,sw-6)
  else r:text(sidebarX+3,top+42,"NO PRODUCTION",5,1,sw-6)end
  Systems.ensureWorkers(state,selectedCity)
  local used=0;for _ in pairs(selectedCity.worked or {})do used=used+1 end
  -- City inspector tabs keep staffing and production inside the viewport.
  -- All three citizen sectors are adjustable directly with touch +/- controls.
  local tabY=top+53
  local tabW=math.floor((sw-8)/3)
  local function cityTab(tab)
   self.cityPanel=tab
   if tab~="tiles" then self.workCity=nil end
  end
  r:button(sidebarX+3,tabY,tabW,13,"JOBS",function()cityTab("jobs")end,
   {selected=(self.cityPanel or "jobs")=="jobs"})
  r:button(sidebarX+5+tabW,tabY,tabW,13,"TILES",function()
   cityTab("tiles")
   self.source=nil;self.reachable={}
   self.workCity={x=selectedCity.x,y=selectedCity.y}
  end,{selected=self.cityPanel=="tiles"})
  r:button(sidebarX+7+tabW*2,tabY,tabW,13,"PROD",function()
   cityTab("production")
   self.actionPage=1
  end,{selected=self.cityPanel=="production"})
  if self.cityPanel=="production"then
   local categoryY=tabY+16
   local half=math.floor((sw-8)/2)
   r:button(sidebarX+3,categoryY,half,14,"UNITS",function()
    self.productionCategory="unit";self.actionPage=1
   end,{icon="train",selected=self.productionCategory~="building"})
   r:button(sidebarX+5+half,categoryY,half,14,"BUILDS",function()
    self.productionCategory="building";self.actionPage=1
   end,{icon="foundry",selected=self.productionCategory=="building"})
   local source=self.productionCategory=="building" and Systems.buildings or Systems.units
   local list={}
   for id in pairs(source)do list[#list+1]=id end
   table.sort(list)
   local startY=categoryY+17
   local visibleRows=math.max(1,math.floor((contentBottom-startY-18)/14))
   self.actionPage=math.max(1,math.min(self.actionPage or 1,
    math.max(1,#list-visibleRows+1)))
   for n=self.actionPage,math.min(#list,self.actionPage+visibleRows-1)do
    local id=list[n]
    local kind=self.productionCategory=="building" and "building" or "unit"
    local eligible=kind=="unit" and Systems.canRecruit(mine,id,state,Hex) or
     Systems.canBuild(mine,selectedCity,id)
    local cost=Systems.projectCost(kind,id) or 1
    local active=selectedCity.project and selectedCity.project.kind==kind and
      selectedCity.project.id==id
    local progress=active and selectedCity.project.progress or
      (selectedCity.projectProgress or {})[kind..":"..id] or 0
    local turns=math.max(1,math.ceil((cost-progress)/math.max(1,yields.industry)))
    r:button(sidebarX+3,startY+(n-self.actionPage)*14,sw-6,12,
      (eligible and "" or "!")..id:upper().." "..turns.."T",function()
       if eligible then self:command("queue",{x=selectedCity.x,y=selectedCity.y,
        kind=kind,id=id}) else self.notice="LOCKED / NEED TECH OR RESOURCE" end
      end,{icon=kind=="unit" and "train" or "foundry",selected=active})
   end
   if #list>visibleRows then
    r:button(sidebarX+3,contentBottom-16,half,14,"PREV",function()
     self.actionPage=math.max(1,(self.actionPage or 1)-visibleRows)
    end)
    r:button(sidebarX+5+half,contentBottom-16,half,14,"NEXT",function()
     self.actionPage=math.min(#list,(self.actionPage or 1)+visibleRows)
    end)
   end
  elseif self.cityPanel=="tiles"then
   Systems.ensureWorkers(state,selectedCity)
   local used=0
   for _ in pairs(selectedCity.worked or {})do used=used+1 end
   r:text(sidebarX+3,tabY+20,"WORKED "..used.."/"..(selectedCity.population or 2),7,1,sw-6)
   r:button(sidebarX+3,tabY+32,sw-6,15,"DONE WORK",function()
    self.workCity=nil;self.cityPanel="jobs"
   end,{icon="people"})
   r:text(sidebarX+3,tabY+54,"TAP LAND HEXES",6,1,sw-6)
  else
   local rowY=tabY+16
   for i,job in ipairs(Systems.jobs)do
    local iy=rowY+(i-1)*17
    local count=selectedCity.jobs[job] or 0
    local name=job=="food" and "FOOD" or job=="wood" and "IND" or "SCI"
    r:text(sidebarX+3,iy+4,name.." "..count,7,1,sw-47)
    r:button(sidebarX+sw-44,iy,20,14,"-",function()
     if selectedCity.jobs[job]>0 then
      local to=job=="food" and "wood" or "food"
      self:command("assign",{x=selectedCity.x,y=selectedCity.y,from=job,to=to})
     end
    end)
    r:button(sidebarX+sw-22,iy,20,14,"+",function()
     for _,from in ipairs(Systems.jobs)do
      if from~=job and selectedCity.jobs[from]>0 then
       self:command("assign",{x=selectedCity.x,y=selectedCity.y,from=from,to=job})
       break
      end
     end
    end)
   end
  end
 elseif selectedUnit and selectedUnit.owner==playerID then
  local unit=Systems.units[selectedUnit.kind] or Systems.units.warrior
  r:icon("train",sidebarX+3,top+17,1)
  r:text(sidebarX+16,top+19,selectedUnit.kind:upper(),7,1,sw-20)
  r:text(sidebarX+3,top+37,"ATTACK "..(unit.strength or 0).." DEF "..(unit.defense or 0),7,1,sw-6)
  r:text(sidebarX+3,top+49,"MOVE "..(selectedUnit.movesLeft or 0)..
    " / "..(unit.move or 1),7,1,sw-6)
  r:text(sidebarX+3,top+61,"RANGE "..(unit.range or 1)..
    "  VISION "..(unit.vision or 2),7,1,sw-6)
  r:text(sidebarX+3,top+75,unit.ability or "",6,1,sw-6)
  r:button(sidebarX+3,top+94,sw-6,17,"MOVE / ATTACK",function()
   self.source={x=selectedUnit.x,y=selectedUnit.y}
   self.reachable=Hex.reachable(state,selectedUnit,playerID,Systems)
  end,{icon="right"})
  if selectedUnit.kind=="settler"then
   r:button(sidebarX+3,top+114,sw-6,17,"FOUND CITY",function()
    self:command("found",{x=selectedUnit.x,y=selectedUnit.y})
   end,{icon="station"})
  end
 else
  r:text(sidebarX+3,top+22,"TILE "..self.selected.x..","..self.selected.y,7,1,sw-6)
  local knowledge=World.known(mine,self.selected.x,self.selected.y)
  r:text(sidebarX+3,top+35,knowledge=="hidden" and "UNEXPLORED" or
   terrain(self.selected.x,self.selected.y,state),6,1,sw-6)
  if World.known(mine,self.selected.x,self.selected.y)~="hidden"then
   r:text(sidebarX+3,top+47,World.deposit(world,self.selected.x,self.selected.y) or
     "NO DEPOSIT",8,1,sw-6)
  end
 end
 local barY=h-footer+1
 r:fill(0,barY-4,w,footer+4,1)
 r:fill(0,barY-4,w,2,8)
 local selectedCity=where(state.cities,self.selected.x,self.selected.y)
 local selectedUnit=where(state.units,self.selected.x,self.selected.y)
 local known=World.known(mine,self.selected.x,self.selected.y)
 local description=known=="hidden" and "UNCHARTED TERRITORY" or
  ("HEX "..self.selected.x..","..self.selected.y.." "..terrain(self.selected.x,self.selected.y,state))
 if selectedCity and known~="hidden" then description=description.." CITY" end
 if selectedUnit and known=="visible" then
  local stats=Systems.units[selectedUnit.kind]or{}
  description=description.." "..selectedUnit.kind..
   " ATK"..(stats.strength or 0).." DEF"..(stats.defense or 0)..
   " MOV"..(selectedUnit.movesLeft or 0).."/"..(stats.move or 1)..
   " RNG"..(stats.range or 1)
 end
 r:text(8,barY,clip(description,math.floor((w-10)/4)),7)
 local actions={
  {"TECH TREE","bolt",function()self.panel="tech";self.actionPage=1 end},
  {"BACK","back",function()
   self.panel="context";self.source=nil;self.reachable={}
  end},
  {"END TURN","clock",function()self:command("end")end},
  {"PAUSE","back",function()self:command("pause")end}
 }
 local gap=3
 local cols=#actions
 local buttonW=math.max(12,math.floor((w-16-(cols-1)*gap)/cols))
 local buttonH=math.max(11,math.min(20,footer-13))
 for i,action in ipairs(actions)do
  r:button(4+(i-1)*(buttonW+gap),barY+7,
   buttonW,buttonH,action[1],action[3],
   {icon=action[2],primary=i==3})
 end
 if self.panel=="tech" and selectedCity and selectedCity.owner==playerID then
  local ox,oy=math.max(5,math.floor(w*.06)),header+3
  local ow,oh=w-2*ox,math.max(70,barY-oy-3)
  self.modalBounds={x=ox,y=oy,w=ow,h=oh}
  self.techModel=self.techModel or {}
  TechTree.draw(r,Systems,mine,self.modalBounds,self.techModel,
   function(id)self:command("researchTech",{id=id})end,
   function()self.panel="context"end)
 end
 if self.notice~="" and barY>=10 then
  r:text(8,barY-10,clip(self.notice,math.floor((w-12)/4)),8)
 end
 r:finish()
end
-- All pan mutations are clamped using the same viewport geometry as drawing.
function UI:pan(dx,dy)
 local v=self.mapViewport
 if not v then return end
 self.panX=math.max(0,math.min(v.maxX,(self.panX or 0)+dx))
 self.panY=math.max(0,math.min(v.maxY,(self.panY or 0)+dy))
end
function UI:drag(x,y)
 local rx,ry=self.r:touch(x,y)
 if not rx then self.lastDrag=nil;return false end
 local v=self.mapViewport
 if not v or rx<v.x or rx>v.x+v.w or ry<v.y or ry>v.y+v.h then
  self.lastDrag=nil;return false
 end
 if self.lastDrag then
  self:pan(self.lastDrag.x-rx,self.lastDrag.y-ry)
 end
 self.lastDrag={x=rx,y=ry}
 return true
end
function UI:scroll(delta,x,y)
 local rx,ry=self.r:touch(x,y)
 local v=self.mapViewport
 if not v or not rx or rx<v.x or rx>v.x+v.w or ry<v.y or ry>v.y+v.h then return false end
 self:pan(0,delta*v.tile*2);return true
end
function UI:tap(x,y)
 local rx,ry=self.r:touch(x,y)
 if not rx then return false end
 self.lastDrag=nil
 local modal=self.modalBounds
 if modal and rx>=modal.x and ry>=modal.y and
    rx<modal.x+modal.w and ry<modal.y+modal.h then
  return self.r:hit(rx,ry)
 end
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
