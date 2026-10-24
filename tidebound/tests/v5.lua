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
print('TIDEBOUND v5: '..checks..' assertions passed')