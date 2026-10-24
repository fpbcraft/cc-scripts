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
  selected={x=2,y=2},source=nil,mode="map",frame=0,notice="",panel="context"},UI)
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
  self.selected={x=x,y=y};self.panel="context";self.actionPage=1
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
  self.actionPage=1;self.techModel=nil
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
 local MAP_W,MAP_H=state.world and state.world.width or Hex.width,
  state.world and state.world.height or Hex.height
 local top=header+7
 local contentBottom=h-footer-3
 -- Pointy odd-row hexes: centres are half a cell apart horizontally between
 -- adjacent rows; 3/4 cell vertically, matching the same Hex distance rules.
 local reserved=compact and 14 or math.max(75,math.floor(w*.29))
 local tile=math.max(5,math.min(
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
  local t=terrain(x,y,state)
  local visibility=World.known(mine,x,y)
  local hidden=visibility=="hidden"
  local c=not hidden and where(state.cities,x,y)
  local u=visibility=="visible" and where(state.units,x,y)
  if c and c.owner~=playerID and visibility~="visible"then c=nil end
  local base=hidden and 15 or
    visibility=="explored" and 14 or
    t=="water" and 19 or t=="mountain" and 4 or
    t=="forest" and 12 or t=="hills" and 9 or 2
  local half=math.floor(tile/2)
  local bevel=math.max(2,math.floor(tile*.24))
  -- Filled pointy hex silhouette (top/bottom caps and vertical body).
  for dy=0,tile-1 do
   local inset=dy<bevel and math.floor((bevel-dy)*half/bevel) or
    dy>=tile-bevel and math.floor((dy-(tile-bevel)+1)*half/bevel) or 0
   r:fill(px+inset,py+dy,math.max(1,tile-inset*2-1),1,base)
  end
  r:outline(px+bevel,py,math.max(1,tile-2*bevel),1,3)
  if tile>=9 and not hidden and
     (t=="water" or t=="forest" or t=="mountain" or t=="hills")then
   Icons.draw(r,t,px+half-4,py+half-4,9,7)
  end
  local reachable
  for _,p in ipairs(self.reachable or {})do
   if p.x==x and p.y==y then reachable=p;break end
  end
  if reachable then
   local tint=reachable.attack and 10 or 11
   r:fill(px+bevel,py+tile-3,math.max(2,tile-2*bevel),2,tint)
   r:fill(px+1,py+half,2,2,tint)
   if tile>=13 then
    r:text(px+half-2,py+tile-10,
     reachable.ranged and "R" or tostring(reachable.cost),7,1,6)
   end
  end
  if c then
   if tile>=11 then Icons.draw(r,"city",px+half-5,py+half-5,11,P[ownerIndex(state,c.owner)]or 8)
   else r:fill(px+half-2,py+half-2,4,4,P[ownerIndex(state,c.owner)]or 8)end
  end
  if u then
   if tile>=11 then Icons.draw(r,u.kind,px+half-5,py+half-5,11,P[ownerIndex(state,u.owner)]or 8)
   else r:fill(px+half-1,py+half-1,3,3,P[ownerIndex(state,u.owner)]or 8)end
   if u.moved then r:fill(px+tile-4,py+half,2,2,4)end
  end
  if visibility=="explored"then r:fill(px+half-1,py+half-1,2,2,4)end
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
   r:text(sidebarX+4,my+62,"TECHS "..(function()
    local n=0;for _ in pairs(mine.techs or {})do n=n+1 end
    return n
   end)(),6,1,sw-8)
   local selectedCity=where(state.cities,self.selected.x,self.selected.y)
   local selectedUnit=where(state.units,self.selected.x,self.selected.y)
   if selectedUnit and selectedUnit.owner==playerID then
    local unit=Systems.units[selectedUnit.kind] or Systems.units.warrior
    local cy=my+76
    r:fill(sidebarX+3,cy,sw-6,math.max(16,boardH-79),2)
    r:text(sidebarX+5,cy+3,selectedUnit.kind:upper(),8,1,sw-9)
    r:text(sidebarX+5,cy+15,
     "ATK "..(unit.strength or 0).." / DEF "..(unit.defense or 0),7,1,sw-9)
    r:text(sidebarX+5,cy+27,
     "MOVE "..(selectedUnit.movesLeft or 0).."/"..(unit.move or 1)..
     "  SIGHT "..(unit.vision or 2),7,1,sw-9)
    r:text(sidebarX+5,cy+39,"ABILITY",9,1,sw-9)
    r:text(sidebarX+5,cy+50,unit.ability or "-",6,1,sw-9)
   elseif selectedCity and selectedCity.owner==playerID then
    local cy=my+76
    r:fill(sidebarX+3,cy,sw-6,math.max(16,boardH-79),2)
    r:text(sidebarX+5,cy+3,"CITY POP "..(selectedCity.population or 2),7,1,sw-9)
    local jobs=selectedCity.jobs or {food=1,wood=1,science=0}
    r:text(sidebarX+5,cy+15,"F"..jobs.food.." W"..jobs.wood.." S"..jobs.science,8,1,sw-9)
    local y=cy+28
    for _,id in ipairs({"farm","mine","library","walls","workshop","academy","market","fortress","university","bazaar","observatory","bank","grandacademy"})do
     if selectedCity.buildings and selectedCity.buildings[id] and y<my+boardH-12 then
      r:text(sidebarX+5,y,id:upper(),11,1,sw-9);y=y+10
     end
    end
   end
  end
  for i,p in ipairs(state.players)do
   local iy=my+79+(i-1)*11
   if iy+10<my+boardH and
    not ((where(state.cities,self.selected.x,self.selected.y) and
      where(state.cities,self.selected.x,self.selected.y).owner==playerID) or
      (where(state.units,self.selected.x,self.selected.y) and
       where(state.units,self.selected.x,self.selected.y).owner==playerID)) then
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
 local actions={}
 local x,y=self.selected.x,self.selected.y
 local function act(label,name,args)
  actions[#actions+1]={label,function()
   self:command(name,args or {x=x,y=y})
  end}
 end
 if selectedUnit and selectedUnit.owner==playerID then
  if selectedUnit.kind=="settler"then act("FOUND","found")end
  actions[#actions+1]={"MOVE",function()
   if selectedUnit.moved then self.notice="ALREADY MOVED";return end
   self.source={x=x,y=y}
   self.reachable=Hex.reachable(state,selectedUnit,playerID,Systems)
  end}
 elseif selectedCity and selectedCity.owner==playerID then
  if self.panel=="context" then
   actions[#actions+1]={"UNITS",function()self.panel="units";self.actionPage=1 end}
   actions[#actions+1]={"BUILDINGS",function()self.panel="buildings";self.actionPage=1 end}
   actions[#actions+1]={"POPULATION",function()self.panel="population";self.actionPage=1 end}
   actions[#actions+1]={"TECH TREE",function()self.panel="tech";self.actionPage=1 end}
  elseif self.panel=="units"then
   for _,id in ipairs({"warrior","settler","scout","spearman","horseman","archer","explorer","ranger","swordsman","galley","navigator","frigate","flagship"})do
    if Systems.canRecruit(mine,id) then
     act(id:upper(),"recruit",{x=x,y=y,id=id})
    end
   end
  elseif self.panel=="buildings"then
   for _,id in ipairs({"farm","mine","library","walls","workshop","academy"})do
    if Systems.canBuild(mine,selectedCity,id)then
     act(id:upper(),"build",{x=x,y=y,id=id})
    end
   end
  elseif self.panel=="population"then
   for _,from in ipairs(Systems.jobs)do
    for _,to in ipairs(Systems.jobs)do
     if from~=to and selectedCity.jobs and selectedCity.jobs[from]>0 then
      act(from:sub(1,1):upper()..">"..to:sub(1,1):upper(),"assign",
       {x=x,y=y,from=from,to=to})
     end
    end
   end
  elseif self.panel=="tech"then
   -- Research options live in the connected canvas, not the footer.
  end
 else
  actions[#actions+1]={"INSPECT",function()self.notice=terrain(x,y,state):upper()end}
 end
 -- Context lists can be much larger than the narrow bottom action bar.
 -- Paginate rather than drawing buttons over the map or beyond the screen.
 if #actions>4 then
  self.actionPage=self.actionPage or 1
  local itemsPerPage=3
  local pages=math.ceil(#actions/itemsPerPage)
  self.actionPage=math.max(1,math.min(self.actionPage,pages))
  local page={}
  for i=(self.actionPage-1)*itemsPerPage+1,
     math.min(#actions,self.actionPage*itemsPerPage)do
   page[#page+1]=actions[i]
  end
  if self.actionPage>1 then
   page[#page+1]={"PREV",function()self.actionPage=self.actionPage-1 end}
  end
  if self.actionPage<pages then
   page[#page+1]={"NEXT",function()self.actionPage=self.actionPage+1 end}
  end
  actions=page
 end
 actions[#actions+1]={"BACK",function()
  self.panel="context";self.source=nil;self.reachable={}
 end}
 actions[#actions+1]={"END TURN",function()self:command("end")end}
 actions[#actions+1]={"PAUSE",function()self:command("pause")end}
 local cols=math.min(4,#actions);local gap=3;local buttonW=math.floor((w-18-(cols-1)*gap)/cols)
 local buttonH=math.max(10,math.floor((footer-20)/math.max(2,math.ceil(#actions/cols))))
 for i,action in ipairs(actions)do
  local col=(i-1)%cols;local row=math.floor((i-1)/cols)
  r:button(8+col*(buttonW+gap),barY+11+row*(buttonH+2),
   buttonW,buttonH,action[1],action[2],
   {primary=i==6,selected=(i==1 and self.source~=nil)})
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
function UI:tap(x,y)
 local rx,ry=self.r:touch(x,y)
 if not rx then return false end
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
