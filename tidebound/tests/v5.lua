local root=(arg and arg[1])or './tidebound/expanse-v5'
_G.EXPANSE_V5_ROOT=root
local M=dofile(root..'/sim.lua')
local UI=dofile(root..'/ui.lua')
local checks=0
local function test(cond,msg)checks=checks+1;if not cond then error('TEST '..checks..': '..(msg or 'assertion failed'),2)end end
for seed=1,32 do
 local g=M.new({seed=seed*331,humans={true,false,false,false},rounds=16})
 test(#g.systems==30 and #g.links>=29 and #g.factions==4,'world size')
 test(#g.ships==12 and M.validState(g),'initial ships')
 local visited={[1]=true};local todo={1};local i=1
 while todo[i]do for _,v in ipairs(M.neighbors(g,todo[i]))do if not visited[v]then visited[v]=true;todo[#todo+1]=v end end;i=i+1 end
 for j=1,30 do test(visited[j],'disconnected '..j)end
 local home=g.systems[1];test(home.owner==1 and home.colony,'capital')
 local p=1;local f=g.factions[1]
 local scout=M.shipsAt(g,1,1)[1];test(scout.kind=='scout')
 local nearby=M.neighbors(g,1)[1]
 test(M.command(g,1,'move',{ship=scout.id,system=nearby}),'scout movement')
 test(f.seen[nearby],'scout must reveal')
 test(scout.orders==1,'movement consumes 1 of 2 ship orders')
 if #f.events>0 then while #f.events>0 do local ok,why=M.command(g,1,'choose',{choice=1});test(ok,why)end end
 local ark=M.shipsAt(g,1,1)[1]
 -- Find an actual Ark regardless of ship iteration order.
 for _,sh in ipairs(M.shipsAt(g,1,1))do if sh.kind=='ark' then ark=sh end end
 test(M.command(g,1,'move',{ship=ark.id,system=nearby}),'ark moves')
 local ok,why=M.command(g,1,'colonize',{ship=ark.id});test(ok,why)
 test(g.systems[nearby].colony and g.systems[nearby].owner==1,'colonization')
 test(not M.findShip(g,ark.id),'ark consumed')
 f.knowledge=120
 for _=1,3 do test(M.command(g,1,'research',{path='exploration'}),'unlimited empire research while funded')end
 test(f.tech.exploration==3,'path max 3')
 f.credits=100;f.alloy=100;f.clues=3
 for id=1,20 do f.seen[id]=true end
 g.systems[3].owner=1;g.systems[3].colony=true;g.systems[3].focus='industry'
 test(M.command(g,1,'project',{kind='discovery'}),'discovery victory project')
 local income=M.income(g,1);test(income.alloy>0 and income.credits>0 and income.knowledge>0)
 for year=1,16 do
  while #f.events>0 do local found=false
   for ix=1,#f.events[1].choices do if M.can(g,1,'choose',{choice=ix})then test(M.command(g,1,'choose',{choice=ix}));found=true;break end end
   test(found,'event choice deadlock')
  end
  while f.offers and #f.offers>0 do test(M.command(g,1,'reply',{accept=false}))end
  if g.ended then break end
  test(M.endTurn(g,1),'end turn')
  M.advanceAI(g)
  test(M.validState(g),'valid after AI')
  if g.ended then break end
  test(M.current(g)==1,'AI progressed to human')
 end
 test(g.ended,'simulation should end')
 for p=1,4 do
  local fac=g.factions[p]
  for _,key in ipairs({'credits','alloy','knowledge'})do test(fac[key]>=0,'negative stock')end
 end
end
-- Human counts, AI-only and deterministic outcomes.
for humans=1,4 do
 local h={};for p=1,4 do h[p]=p<=humans end
 local g=M.new({seed=400+humans,humans=h})
 for p=1,4 do test(g.factions[p].human==h[p])end
 for n=1,14 do
  if g.ended then break end
  local p=M.current(g)
  if h[p]then
   local f=g.factions[p]
   while #f.events>0 do local finished=false;for i=1,#f.events[1].choices do if M.can(g,p,'choose',{choice=i})then test(M.command(g,p,'choose',{choice=i}));finished=true;break end end;test(finished)end
   while f.offers and #f.offers>0 do test(M.command(g,p,'reply',{accept=false}))end
   test(M.endTurn(g,p))
  end
  M.advanceAI(g);test(M.validState(g));test(g.ended or h[M.current(g)])
 end
end
local function fakeMonitor(w,h,gfx)
 local m={calls=0}
 function m.setTextScale()end
 function m.getSize(mode)if mode==2 then return w*6,h*9 end;return w,h end
 function m.setGraphicsMode()end
 function m.setPaletteColor()end
 function m.drawPixels()m.calls=m.calls+1 end
 function m.setFrozen()end
 function m.setCursorPos()end
 function m.setBackgroundColor()end
 function m.setTextColor()end
 function m.write()end
 if not gfx then m.drawPixels=nil;m.setGraphicsMode=nil end
 return m
end
local sizes={{72,51},{103,73},{126,89}}
for _,size in ipairs(sizes)do for _,gfx in ipairs({true,false})do
 local ui=UI.new(fakeMonitor(size[1],size[2],gfx));test(ui.r.kind==(gfx and 'gfx' or 'text'))
 local function draw(screen)ui.screen=screen;local ok,err=pcall(function()ui:draw()end);test(ok,screen..' '..tostring(err))end
 local function tap(b)
  local x=math.floor(b.x+b.w/2);local y=math.floor(b.y+b.h/2)
  if gfx then return ui:monitorTouch(x*ui.r.px,y*ui.r.py)end
  return ui:monitorTouch(x+1,y+1)
 end
 draw('title');local btn=ui.r.buttons[1];test(btn.label=='NEW CAMPAIGN');test(tap(btn));test(ui.screen=='setup','setup transition')
 draw('setup');test(#ui.r.buttons>=8,'setup controls')
 ui:start(1024);draw('handoff');test(tap(ui.r.buttons[#ui.r.buttons]));test(ui.screen=='galaxy','handoff')
 for _,screen in ipairs({'galaxy','ships','colony','research','diplomacy','empire','help','summary','results','event'})do
  if screen=='event' then ui.g.factions[M.current(ui.g)].events={M.events.create('beacon',1)}end
  draw(screen)
  test(#ui.r.buttons>0,screen..' must be navigable')
  for _,b in ipairs(ui.r.buttons)do
   test(b.x>=0 and b.y>=0 and b.x+b.w<=ui.r.w+1 and b.y+b.h<=ui.r.h+1,screen..' hitbox outside display: '..tostring(b.label))
  end
  for i=1,#ui.r.buttons do for j=i+1,#ui.r.buttons do
   local a,b=ui.r.buttons[i],ui.r.buttons[j]
   local dx=math.min(a.x+a.w,b.x+b.w)-math.max(a.x,b.x)
   local dy=math.min(a.y+a.h,b.y+b.h)-math.max(a.y,b.y)
   test(dx<=0 or dy<=0,screen..' overlapping hitboxes: '..tostring(a.label)..' / '..tostring(b.label))
  end end
  if screen=='event' then
   local choices=0;for _,b in ipairs(ui.r.buttons)do if tostring(b.label):match('^[123]%. ')then choices=choices+1 end end
   test(choices==3,'all narrative choices must fit at '..size[1]..'x'..size[2])
  end
 end
 test(ui:monitorTouch(-1,-1)==false)
 draw('galaxy');ui.selected=1;draw('galaxy');test(#ui.r.buttons>5,'inspector buttons')
end end
-- Diplo: a human-to-human proposal remains pending until explicitly accepted.
local d=M.new({seed=910,humans={true,true,true,true}})
test(M.command(d,1,'pact',{to=2,kind='trade'}))
test(d.factions[2].offers and #d.factions[2].offers==1)
test(M.endTurn(d,1))
test(M.command(d,2,'reply',{accept=true}))
test(M.hasPact(d,1,2,'trade'))
-- Player cannot start an unavailable order, or initiate an extra ship move.
local e=M.new({seed=114,humans={true,true,true,true}})
local sh=e.ships[1];sh.orders=0
test(not M.can(e,1,'move',{ship=sh.id,system=M.neighbors(e,1)[1]}))
test(not M.can(e,1,'project',{kind='unity'}))
-- Deterministic replays of the same AI-only seed must produce the same victor.
local function outcome(seed)
 local g=M.new({seed=seed,humans={false,false,false,false},rounds=20})
 for i=1,20 do if g.ended then break end;test(M.advanceAI(g)>0)end
 return M.current(g),g.round,g.winner,g.winReason
end
for i=1,5 do
 local a,b,c,d=outcome(i*173);local aa,bb,cc,dd=outcome(i*173)
 test(a==aa and b==bb and c==cc and d==dd,'deterministic AI campaign')
end
-- Map-first controls: every planet and every visible ship has its own touch
-- target, and the Windows-style menu is the only overlay on the galaxy map.
local function overlaps(a,b)
 return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y
end
for _,size in ipairs(sizes) do for _,gfx in ipairs({true,false}) do
 local ui=UI.new(fakeMonitor(size[1],size[2],gfx))
 ui:start(1703);ui.screen='galaxy';ui:draw()
 local initial=ui.mapMarkers
 local count=0
 for _,star in ipairs(ui.g.systems)do
  test(initial.systems[star.id]~=nil,'no planet target '..star.id)
  count=count+1
 end
 for _,sh in ipairs(ui.g.ships)do
  if sh.owner==M.current(ui.g) then test(initial.ships[sh.id]~=nil,'no owned ship target '..sh.id)end
 end
 local function tapMarker(marker)
  local x=marker.x+math.floor(marker.w/2);local y=marker.y+math.floor(marker.h/2)
  return gfx and ui:monitorTouch(x*ui.r.px,y*ui.r.py) or ui:monitorTouch(x+1,y+1)
 end
 local targets={}
 for _,rect in pairs(initial.systems)do targets[#targets+1]=rect end
 for _,rect in pairs(initial.ships)do targets[#targets+1]=rect end
 for i=1,#targets do
  local a=targets[i]
  test(a.x>=0 and a.y>=0 and a.x+a.w<=ui.r.w and a.y+a.h<=ui.r.h,'offscreen marker')
  for j=i+1,#targets do test(not overlaps(a,targets[j]),'ambiguous map marker')end
 end
 local home=ui.g.systems[1];local original=initial.systems[1]
 test(tapMarker(original),'touch planet directly')
 test(ui.selected==1 and not ui.selectedShip,'planet target selects directly')
 ui:draw()
 local menu=ui.contextBounds
 test(menu~=nil and menu.w<=30 and menu.h<=18,'compact context menu')
 test(menu.x>=0 and menu.y>=7 and menu.x+menu.w<=ui.r.w and menu.y+menu.h<=ui.r.h-9,'context menu out of map')
 test(ui.mapMarkers.systems[1].x==original.x and ui.mapMarkers.systems[1].y==original.y,'galaxy shifted on selection')
 local foundWorld=false
 for _,b in ipairs(ui.r.buttons)do if b.label=='MANAGE WORLD' then foundWorld=true end end
 test(foundWorld,'direct colony context menu option')
 local firstShip
 for _,sh in ipairs(ui.g.ships)do if sh.owner==1 then firstShip=sh;break end end
 local marker=ui.mapMarkers.ships[firstShip.id]
 -- If the popover covers a ship at a cramped size, tapping empty space closes
 -- it. No intermediate Ships or Worlds screen is required.
 if overlaps(marker,menu)then
  test(ui:touch(0,ui.r.h-10),'outside tap closes context menu')
  ui:draw();marker=ui.mapMarkers.ships[firstShip.id]
 end
 test(tapMarker(marker),'touch ship directly')
 test(ui.selectedShip==firstShip.id and ui.screen=='galaxy','direct ship selection')
 ui:draw()
 local menus=ui.contextBounds
 test(menus and menus.ship and menus.ship.id==firstShip.id,'ship context menu shows selected unit')
 local move
 for _,b in ipairs(ui.r.buttons)do
  if b.label=='MOVE SHIP' or b.label=='MOVE / ATTACK' then move=b end
 end
 test(move~=nil,'ship move command without ship submenu')
 local before=firstShip.location
 test(tapMarker(move),'move command touch')
 test(ui.shipID==firstShip.id and ui.screen=='galaxy','move mode activates without fleet registry')
 ui:draw()
 local targetID=M.neighbors(ui.g,before)[1]
 test(tapMarker(ui.mapMarkers.systems[targetID]),'touch destination star')
 test(ui.screen=='confirm','ship destination confirmation')
 ui:draw()
 local accept
 for _,b in ipairs(ui.r.buttons)do if b.label=='CONFIRM' then accept=b end end
 test(accept and tapMarker(accept),'confirm move')
 test(M.findShip(ui.g,firstShip.id).location==targetID,'directly selected ship moved')
 ui.screen='galaxy';ui.selected=home.id;ui:draw()
 local registered=ui.r.buttons
 for i=1,#registered do for j=i+1,#registered do
  test(not overlaps(registered[i],registered[j]),'context overlaps touch targets: '..tostring(registered[i].label)..' vs '..tostring(registered[j].label))
 end end
end end
for seed=1,12 do
 local ui=UI.new(fakeMonitor(126,89,true));ui:start(seed*733);ui.screen='galaxy';ui:draw()
 local targetList={}
 for _,t in pairs(ui.mapMarkers.systems)do targetList[#targetList+1]=t end
 for _,t in pairs(ui.mapMarkers.ships)do targetList[#targetList+1]=t end
 test(#targetList>=33,'all starting planets and friendly ships represented')
 for i=1,#targetList do for j=i+1,#targetList do
  test(not overlaps(targetList[i],targetList[j]),'seeded map target collision')
 end end
end

print('TIDEBOUND v5: '..checks..' assertions passed')