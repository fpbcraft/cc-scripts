local script=(arg and arg[0]) or ''
local root=script:match('^(.*)/railbreak/tests/[^/]+$') or '.'
package.path=root..'/railbreak/?.lua;'..root..'/railbreak/?/init.lua;'..package.path
local S=require('train.state')
local A=require('train.rules')
local C=require('train.catalog')
local UI=require('train.ui')
local passed=0
local function eq(ok,label)passed=passed+1;assert(ok,'TEST '..passed..': '..label)end
local function doIt(g,command,...)
 local ok,msg=A[command](g,...)
 eq(ok,command..' FAILED: '..tostring(msg))
 eq(S.valid(g),command..' corrupts state')
 return msg
end
for n=1,4 do local g=S.new({count=n,names={'ADA','BOB','CARL','DAN'},seed=42})
 eq(S.valid(g),'game creation '..n)
 eq(#g.players==n,'player count')
 eq(S.load(g)<=S.capacity(g),'starter capacity')
 doIt(g,'accept',1)
 local ref=g.coins;doIt(g,'buy','planks');eq(g.coins<ref,'buy charges coins')
 doIt(g,'sell','planks');eq(g.coins<ref,'market spread')
 doIt(g,'shift');eq(g.shift==1,'shift turn counts')
 doIt(g,'depart',2);eq(g.pending~=nil,'first travel encounter')
 local event=C.eventById[g.pending.event]
 local choice=2
 doIt(g,'resolve',choice);eq(g.location==2 and not g.pending,'arrival')
 doIt(g,'deliver',1);eq(g.contracts[1]=='done','delivery complete')
 doIt(g,'salvage');eq(g.coins>=12,'salvage recovery')
 eq(g.delivered==1 and g.reputation>=1,'reward')
 eq(g.version==2,'v2 saves independent')
end
local g=S.new({seed=100,difficulty='explorer'})
local stock=g.cargo.planks
doIt(g,'shift');eq(g.cargo.planks>=stock,'sawmill outputs')
doIt(g,'module','foundry');eq(g.stations[1].modules.foundry==1,'module installed')
doIt(g,'upgrade','loader');eq(g.upgrades.loader,'train upgrade')
local cap=S.capacity(g);while g.coins<58 do doIt(g,'salvage')end;doIt(g,'addWagon','cargo');eq(S.capacity(g)>cap,'wagon capacity')
local p=g.coins;doIt(g,'salvage');eq(g.coins==p+12,'salvage is deterministic')
for id in pairs(g.cargo)do eq(g.cargo[id]>=0,'no negative stock')end
local gone,reason=A.buy(g,'unknown');eq(not gone and reason,'invalid product fails')
local pass,why=A.deliver(g,1);eq(not pass and why,'cannot deliver unaccepted')
local pass2=A.depart(g,5);eq(not pass2,'no teleport')
-- End to end trip to Eastport with two jobs; allow work through supplies and event options.
local run=S.new({seed=64})
doIt(run,'accept',1);doIt(run,'accept',2)
doIt(run,'depart',2);doIt(run,'resolve',2);doIt(run,'deliver',1)
-- Return to Iron Junction then proceed via Stonebridge.
if run.fuel<2 then doIt(run,'refuel')end
doIt(run,'depart',1)
if run.fuel<2 then doIt(run,'refuel')end
-- If track requires parts, purchase them before leaving.
while run.cargo.parts<2 do if S.load(run)>=S.capacity(run)then doIt(run,'sell','planks')end doIt(run,'buy','parts')end
doIt(run,'depart',3);if run.pending then doIt(run,'resolve',2)end
doIt(run,'deliver',2);eq(run.reputation>=2 and run.delivered>=2,'victory contracts done')
while run.fuel<3 do doIt(run,'refuel')end
if run.cargo.parts<1 then doIt(run,'buy','parts')end
doIt(run,'depart',4);if run.pending then doIt(run,'resolve',2)end
while run.fuel<3 do doIt(run,'refuel')end
while run.cargo.parts<2 do if S.load(run)>=S.capacity(run)then doIt(run,'sell','planks')end doIt(run,'buy','parts')end
doIt(run,'depart',5);if run.pending then doIt(run,'resolve',2)end
eq(run.won and run.finished,'full campaign win')
-- Fake terminals simulate actual zero-based CC Graphics touch and one-based text touch.
local sizes={{160,162},{212,162},{212,219},{212,276},{270,219},{270,276}}
local scenes={'title','setup','hub','map','station','modules','market','contracts','train','wagons','upgrades','travel','results','help'}
local function monitor(w,h,mode)
 local m={cw=w/2,ch=h/3,draws=0,mode=mode}
 function m.getSize(flag)if flag then return w*3,h*3 end return m.cw,m.ch end
 function m.setGraphicsMode(n)if not mode then error('No graphics mode')end m.gmode=n end
 function m.setFrozen(_)end
 function m.drawPixels(...)m.draws=m.draws+1 end
 function m.setPaletteColor(...)end
 function m.getPaletteColor(...)return 0,0,0 end
 function m.setBackgroundColor(...)end
 function m.setTextColor(...)end
 function m.setCursorPos(...)end
 function m.write(...)end
 return m
end
for _,dim in ipairs(sizes)do for _,graphics in ipairs({false,true})do
 local m=monitor(dim[1],dim[2],graphics)
 local ui=UI.new(m)
 ui:draw()
 eq(ui.r.w==dim[1] and ui.r.h==dim[2],'expected canvas dimensions')
 eq(#ui.r.buttons>=2,'title buttons')
 local b=ui.r.buttons[1]
 local x=b.x+math.floor(b.w/2);local y=b.y+math.floor(b.h/2)
 local px=graphics and x*3 or math.floor(x/2)+1
 local py=graphics and y*3 or math.floor(y/3)+1
 eq(ui:touch(px,py)~=false,'touch activates title button')
 eq(ui.scene=='setup','click new expedition')
 -- Force gameplay and check every screen rendering, bounds and touch hitboxes.
 ui:newGame()
 for _,sc in ipairs(scenes)do
  ui.scene=sc;ui:draw();eq(#ui.r.buttons>0,'touch targets present in '..sc)
  for _,hit in ipairs(ui.r.buttons)do
   eq(hit.w>0 and hit.h>0,'positive hit area')
   eq(hit.x>=-10 and hit.x<=ui.r.w+2 and hit.y>=0 and hit.y<=ui.r.h+3,'hit box not grossly out of view '..sc)
  end
 end
 ui.scene='hub';ui:draw();local counts=#ui.r.buttons;eq(counts>=8,'wagon touch controls')
 ui.scene='map';ui:draw();eq(#ui.r.buttons>=8,'map nodes selectable')
 -- Rendering a connected destination used to crash because the UI called
 -- the fuel cost helper on the graphics renderer instead of the rules module.
 ui.selected=2;ui:draw()
 eq(ui.scene=='map','connected station renders without a runtime error')
 eq(ui.r:textWidth('STATION MARKET')== (graphics and 14*4 or 14*2),
   'normal font uses compact width in graphics mode')
 local depart
 for _,hit in ipairs(ui.r.buttons)do if hit.label=='DEPART' then depart=hit end end
 eq(depart~=nil,'connected route exposes depart action')
 local dx=depart.x+math.floor(depart.w/2)
 local dy=depart.y+math.floor(depart.h/2)
 local touchX=graphics and dx*3 or math.floor(dx/2)+1
 local touchY=graphics and dy*3 or math.floor(dy/3)+1
 eq(ui:touch(touchX,touchY)=='DEPART','touch dispatches departure')
 eq(ui.g.pending~=nil and ui.scene=='travel','departure triggers event scene')
 local resolve
 for _,hit in ipairs(ui.r.buttons)do
  if hit.label=='TAKE DETOUR' then resolve=hit end
 end
 -- Event labels may be different; select the second offered choice directly.
 local event=C.eventById[ui.g.pending.event]
 if not resolve then
  for _,hit in ipairs(ui.r.buttons)do if hit.label==event.choices[2].label then resolve=hit end end
 end
 eq(resolve~=nil,'event choice has a button')
 local ex=resolve.x+math.floor(resolve.w/2)
 local ey=resolve.y+math.floor(resolve.h/2)
 local rtx=graphics and ex*3 or math.floor(ex/2)+1
 local rty=graphics and ey*3 or math.floor(ey/3)+1
 eq(ui:touch(rtx,rty)~=false,'travel choice is touchable')
 eq(ui.g.location==2 and ui.g.pending==nil,'event resolves arrival')

 ui.scene='market';ui:draw();eq(#ui.r.buttons>=7,'market buttons present')
 ui.scene='travel';ui.g.pending={from=1,to=2,event='rocks'};ui:draw();eq(#ui.r.buttons>=5,'event choices tappable')
 ui:close()
end end
print('TRAIN-FIRST GAME/UI: '..passed..' checks passed')
