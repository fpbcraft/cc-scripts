local U=require('railbreak.core.util')
local C=require('railbreak.content.catalog')
local S=require('railbreak.game.state')
local K=require('railbreak.game.kinetics')
local A=require('railbreak.game.commands')
local R=require('railbreak.render.canvas')
local Disk=require('railbreak.platform.storage')
local App={};App.__index=App
local function textwrap(str,width)
 local out,line={},''
 for word in tostring(str or ''):gmatch('%S+')do
  if #line+#word+1>width and line~=''then out[#out+1]=line;line=word
  else line=(line=='' and word or line..' '..word)end
 end
 if line~=''then out[#out+1]=line end
 return out
end
function App.new(m,opt)
 local self=setmetatable({r=R.new(m),scene='title',game=nil,selected=nil,tool='shaft',mode='select',buildPage=1,
  playerCount=1,editing=1,names={'','','',''},modal=nil,
  toast='',animation=0,autoTarget='iron_sheet',settings={audio=true},buttons={},presaved=nil,seed=12825},App)
 if opt and opt.game then self.game=opt.game;self.scene='factory' end
 return self
end
function App:notify(msg)
 self.toast=tostring(msg or '')
end
function App:save()
 if self.game then local ok,err=Disk.save(self.game)
  if not ok and fs then self:notify('SAVE ERROR: '..tostring(err)) end
 end
end
function App:action(fn)
 local ok,msg=fn()
 self:notify(msg)
 if ok then
  local count=self.game.contributions and self.game.contributions[self.game.currentPlayer]
  if count then count.actions=count.actions+1 end
  self:save();self.animation=5
 end
 return ok
end
function App:newGame()
 local names={};for i=1,self.playerCount do names[i]=U.name(self.names[i])end
 self.game=S.new({seed=self.seed,names=names,count=self.playerCount})
 K.analyze(self.game);self.scene='factory';self.selected=nil;self.mode='select';self.modal=nil
 self:save();self:notify('STARTER FACTORY READY. RUN A SHIFT TO MAKE SHEETS.')
end
function App:layout()
 local r=self.r;local sidebar=math.max(33,math.min(40,math.floor(r.w*.30)))
 local available=r.w-sidebar-6
 local step=math.floor(math.min(available/S.W,(r.h-21)/S.H))
 step=math.max(3,step)
 return {x=3,y=12,step=step,gw=S.W*step,gh=S.H*step,side=r.w-sidebar-1,sw=sidebar,
  bottom=r.h-9}
end
function App:header()
 local r=self.r;local g=self.game
 r:rect(0,0,r.w,8,1);r:rect(0,7,r.w,1,7)
 r:rect(2,1,2,5,6);r:text(5,2,'RAILBREAK',17);r:text(5,4,'KINETIC FRONTIER',11)
 if g then
  r:text(31,2,'STAGE '..math.min(g.chapter,g.totalChapters)..'/'..g.totalChapters..' | SHIFT '..g.shift,6)
  local k=g.machineStatus
  r:text(31,4,'KINETICS '..k.load..'/'..k.capacity..' SU',k.overstressed and 18 or 9)
  r:button(r.w-38,1,37,3,'CREW '..g.currentPlayer..': '..g.players[g.currentPlayer],function()
   g.currentPlayer=g.currentPlayer%#g.players+1;self:save()
  end,{color=11,icon='info'})
  r:text(r.w-36,4,'SCORE '..A.score(g),6)
 end
end
function App:bottom()
 local r=self.r;local b=self:layout().bottom;local g=self.game
 r:rect(0,b,r.w,r.h-b,1);r:rect(0,b,r.w,1,7)
 local bw=math.floor((r.w-10)/6)
 local menu={
  {'WORKSHOP','factory'}, {'RAILWAY','railway'}, {'WAREHOUSE','warehouse'},
  {'BLUEPRINTS','blueprints'}, {'HELP','help'}, {'MENU','title'},
 }
 for i,item in ipairs(menu)do
  local xx=2+(i-1)*(bw+1)
  r:button(xx,b+2,bw,5,item[1],function()self.scene=item[2];self.modal=nil end,
   {color=self.scene==item[2] and 9 or 6,icon=i==1 and 'factory' or i==2 and 'train' or i==3 and 'stock' or i==4 and 'tools' or 'info'})
 end
 if g and self.scene~='title' then r:text(2,r.h-2,self.toast,5,r.w-4) end
end
function App:factory()
 local r=self.r;local g=self.game;local l=self:layout()
 self:header()
 r:text(l.x,l.y-2,'WORKSHOP / TOP VIEW     CLICK TILE TO INSPECT',4)
 r:rect(l.x-1,l.y-1,l.gw+2,l.gh+2,1)
 K.analyze(g)
 local components={wheel=6,steam=18,shaft=4,gear=6,press=9,saw=11,crusher=7,mixer=15,assembler=18,
  belt=14,depot=12,chest=10,empty=19}
 for y=1,S.H do for x=1,S.W do
  local t=S.get(g,x,y);local xx=l.x+(x-1)*l.step;local yy=l.y+(y-1)*l.step
  local selected=self.selected and self.selected.x==x and self.selected.y==y
  local base=(x+y)%2==0 and 20 or 19
  r:rect(xx,yy,l.step-1,l.step-1,selected and 7 or base)
  if t.id~='empty' then
   r:rect(xx+1,yy+1,l.step-3,l.step-3,components[t.id] or 4)
   r:icon(xx+math.floor(l.step/2)-1,yy+math.floor(l.step/2)-1,t.id,17,l.step<=5 and 2 or 3)
   if self.animation>0 and (t.id=='wheel' or t.id=='gear' or t.id=='steam') then
    r:text(xx+l.step-3,yy+1,(self.animation%2==0) and '+' or '-',6)
   end
   if t.id=='belt' then r:icon(xx+1,yy+l.step-3,({ 'next','next','back','info' })[t.face],17) end
   if t.item then r:text(xx+1+(self.animation>0 and self.animation%2 or 0),yy+1,'*',6) end
   if t.id=='depot' then r:text(xx+1,yy+1,t.filter:sub(1,1),23) end
   if C.recipes[t.id] then
    local power=g.machineStatus.connections[U.key(x,y)]
    r:rect(xx+l.step-3,yy+1,1,1,power and power.powered and 9 or 8)
    if next(t.output)then r:text(xx+1,yy+l.step-2,'!',6) end
   end
  end
  r.buttons[#r.buttons+1]={x=xx,y=yy,w=l.step-1,h=l.step-1,fn=function()
   self.selected={x=x,y=y}
   if self.mode=='build' and t.id=='empty' then self:action(function()return A.build(g,x,y,self.tool)end)end
  end}
 end end
 -- Utility status below the factory, not over the grid.
 local row=l.y+l.gh+2
 local kinetic=g.machineStatus
 local msg=kinetic.overstressed and 'OVERSTRESSED - DISENGAGE OR ADD GENERATION' or 'CONNECTED FACTORY - READY FOR PRODUCTION'
 if row+3<l.bottom then
  r:text(l.x,row,msg,kinetic.overstressed and 18 or 9,l.gw)
  r:text(l.x,row+2,'IRON '..g.warehouse.iron..'  WOOD '..g.warehouse.logs..'  SHEETS '..g.warehouse.iron_sheet..'  TRACK '..g.warehouse.track,5,l.gw)
 end
 self:factoryPanel(l)
 self:bottom()
end
function App:factoryPanel(l)
 local r=self.r;local g=self.game;local x=l.side;local w=l.sw
 r:rect(x,9,w,l.bottom-10,1);r:rect(x,9,w,1,7)
 r:text(x+2,10,self.mode=='build' and 'MACHINE BLUEPRINTS' or 'FACTORY CONTROLS',6)
 local shiftW=math.floor((w-6)/3)
 r:button(x+2,14,shiftW,4,'1 SHIFT',function()
  if self:action(function()return A.advance(g,1)end) then g.contributions[g.currentPlayer].shifts=g.contributions[g.currentPlayer].shifts+1;self:save()end
 end,{color=9})
 r:button(x+3+shiftW,14,shiftW,4,'5 SHIFTS',function()
  local before=g.shift
  if self:action(function()return A.advance(g,5)end) then g.contributions[g.currentPlayer].shifts=g.contributions[g.currentPlayer].shifts+(g.shift-before);self:save()end
 end,{color=9})
 r:button(x+4+shiftW*2,14,shiftW,4,'AUTO',function()self.modal='auto'end,{color=11})
 if self.mode=='build' then
  r:text(x+2,20,'TAP EMPTY TILE TO PLACE',4)
  local max=l.bottom<68 and 4 or 6
  local pages=math.ceil(#C.buildOrder/max);self.buildPage=U.clamp(self.buildPage,1,pages)
  for n=1,max do
   local idx=(self.buildPage-1)*max+n;local id=C.buildOrder[idx]
   if id then
    local spec=C.spec[id];local disabled=(C.unlocks[id] or 0)>g.unlocked
    r:button(x+2,22+(n-1)*5,w-4,4,spec.name,function()
      self.tool=id;self:notify(spec.help..' COST: '..U.format(spec.cost))
    end,{icon=id,color=id==self.tool and 9 or 6,disabled=disabled})
   end
  end
  local by=l.bottom-12
  r:button(x+2,by,math.floor((w-5)/2),4,'PREV',function()self.buildPage=math.max(1,self.buildPage-1)end,{icon='back',disabled=self.buildPage==1})
  r:button(x+3+math.floor((w-5)/2),by,math.floor((w-5)/2),4,'NEXT',function()self.buildPage=math.min(pages,self.buildPage+1)end,{icon='next',disabled=self.buildPage==pages})
  r:button(x+2,by+5,w-4,4,'INSPECT MODE',function()self.mode='select' end,{color=11,icon='info'})
 else
  local selected=self.selected and S.get(g,self.selected.x,self.selected.y)
  if selected then
   local spec=C.spec[selected.id]
   r:text(x+2,20,'TILE '..self.selected.x..','..self.selected.y..'  '..spec.name,17,w-4)
   local lines=textwrap(spec.help or 'Empty tile. Select Build to place machinery.',w-5)
   for i=1,math.min(#lines,4)do r:text(x+2,22+i,lines[i],4,w-4) end
   if selected.id~='empty' then
    local st=g.machineStatus.connections[U.key(self.selected.x,self.selected.y)]
    r:text(x+2,29,'FACE '..({'EAST','SOUTH','WEST','NORTH'})[selected.face],6)
    if st then r:text(x+2,31,'RPM '..st.rpm..' | '..st.networkLoad..'/'..st.capacity..' SU',st.powered and 9 or 18,w-4)end
    if C.recipes[selected.id] then
     local recipe=C.recipes[selected.id]
     r:text(x+2,33,'IN: '..U.format(recipe.input),11,w-4)
     r:text(x+2,35,'OUT: '..U.format(recipe.output),9,w-4)
     r:text(x+2,37,'BUFFER: '..U.format(selected.slot),4,w-4)
    elseif selected.id=='depot' then r:text(x+2,33,'FEED: '..selected.filter,11)end
    local by=l.bottom-(selected.id=='depot' and 20 or 15)
    r:button(x+2,by,w-4,4,'ROTATE',function()self:action(function()return A.rotate(g,self.selected.x,self.selected.y)end)end,{icon='next'})
    r:button(x+2,by+5,w-4,4,'DISMANTLE',function()self.modal='demolish' end,{icon='tools',color=18})
    if selected.id=='depot' then
     r:button(x+2,by+10,w-4,4,'CHANGE FEED',function()self.modal='filter' end,{icon='stock',color=11})
    end
   end
  else r:text(x+2,23,'SELECT A MACHINE',4);r:text(x+2,25,'TO VIEW ITS DETAILS',4) end
  r:button(x+2,l.bottom-6,w-4,4,'BUILD MACHINES',function()self.mode='build' end,{icon='build',color=9})
 end
end
function App:route()
 local r=self.r;local g=self.game;self:header()
 r:text(6,10,'EXPEDITION MAP  /  RAILWAY ROUTE PLANNING',6)
 local baseX=math.floor(r.w*.17);local baseY=math.floor(r.h*(r.h<80 and .22 or .48))
 for i=1,g.totalChapters do
  local x=baseX+(i-1)*math.floor(r.w*.18);local y=baseY+math.floor(math.sin(i*.9)*6)
  if i>1 then
   local xx=baseX+(i-2)*math.floor(r.w*.18);local yy=baseY+math.floor(math.sin((i-1)*.9)*6)
   r:line(xx+3,yy+3,x-3,y+3,i<g.chapter and 9 or 3)
  end
  r:rect(x-3,y-3,8,8,i<g.chapter and 10 or i==g.chapter and 6 or 3)
  r:icon(x,y,'train',17);r:text(x-2,y+7,'LEG '..i,5)
 end
 local compact=r.h<80
 r:text(6,compact and 34 or 19,'NEXT DESTINATIONS',17)
 for i,route in ipairs(g.routeChoices)do
  local width=math.floor((r.w-20)/2);local x=6+(i-1)*(width+7);local y=compact and r.h-31 or r.h-36
  r:rect(x,y,width,compact and 20 or 24,1);r:rect(x,y,width,2,i==1 and 6 or 11)
  r:text(x+2,y+4,route.title,17,width-4)
  r:text(x+2,y+7,route.detail,5,width-4)
  r:text(x+2,y+10,'REQUIRES: '..U.format(route.cost),6,width-4)
  r:text(x+2,y+13,'SUPPLIES: '..U.format(route.reward),9,width-4)
  r:button(x+3,y+(compact and 15 or 18),width-6,4,'BUILD AND TRAVEL',function()
   self.routeChoice=i;self.modal='travel'
  end,{icon='train',color=9})
 end
 local contractY=compact and 25 or r.h-44
 r:text(6,contractY,'CURRENT CONTRACT',6)
 local contract=C.contracts[g.currentContract]
 r:text(6,contractY+2,contract.title..' - '..U.format(contract.needs),17,r.w-11)
 r:text(6,contractY+4,'STATUS '..g.contractStatus..' | DEADLINE '..math.max(0,g.contractLimit-g.contractAge)..' SHIFTS',5)
 r:button(6,contractY+5,27,4,'FULFILL CONTRACT',function()self:action(function()return A.deliver(g)end)end,{icon='contract',color=11,disabled=g.contractStatus~='OPEN'})
 self:bottom()
end
function App:warehouse()
 local r=self.r;local g=self.game;self:header();r:text(5,11,'MATERIAL WAREHOUSE',17)
 local width=math.floor((r.w-18)/3)
 for i,item in ipairs(C.resources)do
  local col=(i-1)%3;local row=math.floor((i-1)/3);local x=5+col*(width+4);local y=17+row*10
  r:rect(x,y,width,8,1);r:text(x+2,y+2,item:upper(),6,width-4)
  r:text(x+2,y+5,tostring(g.warehouse[item] or 0),17)
 end
 r:button(5,r.h-24,36,5,'EMERGENCY SCAVENGE',function()self.modal='scavenge'end,{icon='stock',color=18,note='RAW MATERIALS / -35 SCORE'})
 r:text(5,r.h-17,'Scavenging costs one shift and a score penalty.',4,r.w-10)
 self:bottom()
end
function App:blueprints()
 local r=self.r;local g=self.game;self:header();r:text(5,10,'MACHINE CATALOG / CREATE KINETIC WORKSHOP',17)
 local box=math.floor((r.w-18)/3)
 for index,id in ipairs(C.buildOrder)do
  local spec=C.spec[id];local col=(index-1)%3;local row=math.floor((index-1)/3)
  local x=5+col*(box+4);local y=(r.h<80 and 14 or 16)+row*(r.h<80 and 10 or 14);local locked=(C.unlocks[id] or 0)>g.unlocked
  r:rect(x,y,box,r.h<80 and 9 or 12,locked and 1 or 2)
  r:icon(x+2,y+2,id,locked and 4 or 9);r:text(x+5,y+2,spec.name,locked and 4 or 17,box-7)
  r:text(x+2,y+4,U.format(spec.cost),6,box-4)
  local lines=textwrap(spec.help,box-4)
  for i=1,math.min(r.h<80 and 1 or 2,#lines)do r:text(x+2,y+5+i,lines[i],4,box-4)end
  if locked then r:text(x+2,y+(r.h<80 and 8 or 10),'LOCKED: STAGE '..(C.unlocks[id]+1),18,box-4)end
 end
 self:bottom()
end
function App:help()
 local r=self.r;self:header()
 r:text(5,10,'FIELD MANUAL  /  KINETIC FRONTIER',17)
 local lines={
  'GOAL: BUILD A RAILWAY THROUGH FOUR FRONTIER SECTIONS.',
  'SINGLE PLAYER OR 2-4 FRIENDS SHARE ONE TOUCH MONITOR.',
  'PLANNING HAS NO TIMER. ONLY SHIFTS ADVANCE SIMULATION.',
  'THE STARTER PRESS LINE ALREADY WORKS. TRY SHIFT 5.',
  'WATER WHEEL > SHAFT > PRESS = MECHANICAL POWER.',
  'DEPOT > BELT > PRESS > BELT > CHEST = ITEM FLOW.',
  'PRESS NEEDS IRON TO MAKE IRON SHEETS.',
  'SELECT BUILD, CHOOSE A MACHINE, TAP AN EMPTY TILE.',
  'CONNECT MACHINES TO SHAFTS OR GEARS FOR ROTATION.',
  'WHEN STRESS LOAD EXCEEDS CAPACITY, MACHINE STOPS.',
  'GEARS DOUBLE RPM AND DOUBLE MACHINERY STRESS.',
  'DEPOTS PULL A FILTERED MATERIAL FROM THE WAREHOUSE.',
  'BELTS MOVE A SINGLE PACKET ONE TILE EACH SHIFT.',
  'MACHINES OUTPUT TOWARD THEIR FACING DIRECTION.',
  'CHESTS RETURN BELT OUTPUT TO THE SHARED WAREHOUSE.',
  'FOR MORE INPUTS, BUILD ADDITIONAL DEPOTS AND BELTS.',
  'SHIFT 1 FOR PRECISION, SHIFT 5 FOR PRODUCTION.',
  'AUTO STOPS WHEN A MATERIAL TARGET IS REACHED.',
  'RAILWAY TAB SHOWS CONTRACTS AND BRANCHING ROUTES.',
  'COMPLETE CONTRACTS FOR REWARDS AND REPUTATION.',
  'BUILD TRACK AND BRIDGES TO EXTEND THE RAILWAY.',
  'NO MULTITOUCH REQUIRED; TEAMMATES CAN TAKE TURNS.',
  'EMERGENCY SCAVENGE RESTOCKS RAW MATERIALS AT A COST.',
  'NEW BLUEPRINTS UNLOCK AFTER REACHING LATER STATIONS.',
 }
 local y=16;for i,line in ipairs(lines) do
  if y>r.h-12 then break end
  r:text(6,y,line,i%4==1 and 9 or 5,r.w-10);y=y+2
 end
 self:bottom()
end
function App:dialog()
 if not self.modal then return end
 local r=self.r;local g=self.game;local w,h=math.min(61,r.w-10),24
 local x=math.floor((r.w-w)/2);local y=math.floor((r.h-h)/2)
 r:rect(x,y,w,h,1);r:rect(x,y,w,2,6);r:text(x+3,y+3,self.modal:upper()..' / CONFIRM',17)
 local desc,cancel,confirm
 if self.modal=='travel' then
  local route=g.routeChoices[self.routeChoice]
  desc='Build rails to '..route.title..'. Spend '..U.format(route.cost)..'. Gain '..U.format(route.reward)..'. The expedition advances to the next region.'
  confirm=function()self:action(function()return A.travel(g,self.routeChoice)end);self.scene=g.finished and 'results' or 'railway' end
 elseif self.modal=='demolish' then
  desc='Dismantle selected machinery. Recover materials at 75 percent, plus buffered items. Connected networks may stop.'
  confirm=function()self:action(function()return A.remove(g,self.selected.x,self.selected.y)end);self.selected=nil end
 elseif self.modal=='scavenge' then
  desc='Scavenge 2 iron, 2 logs, 2 cobblestone and 1 coal. Consumes a shift and reduces your score by 35 points.'
  confirm=function()self:action(function()return A.scavenge(g)end)end
 elseif self.modal=='auto' then
  local target=self.autoTarget
  desc='Run up to 20 production shifts, stopping on new warnings or when '..target..' increases by 4. Does not advance in real time.'
  confirm=function()
   local start=g.warehouse[target]
   local simulated=0
   for i=1,20 do
    local ok,why=A.advance(g,1);if not ok then self:notify(why);break end
    simulated=i
    if g.warehouse[target]>=start+4 or #g.production.events>0 then break end
   end
   g.contributions[g.currentPlayer].shifts=g.contributions[g.currentPlayer].shifts+simulated
   self:notify('AUTO: '..simulated..' SHIFTS EXECUTED.');self:save();self.animation=5
  end
 elseif self.modal=='filter' then
  desc='Select an item for the input depot to send into its facing conveyor.'
  local names=C.resources;local cols=3;local bw=math.floor((w-8)/cols)
  for i,name in ipairs(names)do
   local xx=x+3+((i-1)%cols)*bw;local yy=y+8+math.floor((i-1)/cols)*4
   r:button(xx,yy,bw-1,3,name,function()
    self:action(function()return A.filter(g,self.selected.x,self.selected.y,name)end);self.modal=nil
   end,{color=11})
  end
  r:button(x+3,y+h-5,19,4,'CANCEL',function()self.modal=nil end,{color=18})
  return
 end
 for i,line in ipairs(textwrap(desc or '',w-8)) do r:text(x+4,y+6+(i-1)*2,line,5,w-8)end
 r:button(x+3,y+h-6,math.floor((w-8)/2),4,'CANCEL',function()self.modal=nil end,{color=18})
 r:button(x+5+math.floor((w-8)/2),y+h-6,math.floor((w-8)/2),4,'CONFIRM',function()
  self.modal=nil;confirm()
 end,{color=9})
end
function App:title()
 local r=self.r
 -- Static poster-like train, copper boiler, smoke, pistons and cargo wagons.
 local cx=math.floor(r.w/2);local cy=math.min(math.floor(r.h*.36),r.h-49)
 for i=0,18 do local px=math.floor((i*67+13)%r.w);local py=math.floor((i*17+9)%(r.h*.65));r:rect(px,py,1,1,3)end
 r:rect(cx-43,cy+13,95,2,4);r:rect(cx-41,cy+17,95,1,14)
 for i=-5,5 do local x=cx+i*8;r:rect(x,cy+18,3,1,14)end
 r:rect(cx-36,cy-2,25,16,7);r:rect(cx-33,cy-13,15,12,14);r:rect(cx-31,cy-10,10,6,11)
 r:rect(cx-13,cy-4,8,18,14);r:rect(cx-12,cy-11,6,8,7)
 for i=0,3 do local x=cx-36+i*12;r:rect(x,cy+12,6,6,3);r:rect(x+1,cy+13,4,4,6)end
 for i=0,2 do local x=cx+3+i*17;r:rect(x,cy+2,14,13,10+i%2);r:rect(x+2,cy+5,10,5,12)
  r:rect(x+2,cy+13,3,5,3);r:rect(x+10,cy+13,3,5,3)
 end
 r:bigText(cx-18,5,'RAILBREAK',17,4);r:bigText(cx-16,11,'KINETIC FRONTIER',6,2)
 r:text(cx-25,cy+23,'A CREATE-INSPIRED FACTORY RAILWAY GAME',5)
 local b=math.min(41,r.w-15);local xx=cx-math.floor(b/2)
 r:button(xx,cy+28,b,5,'NEW EXPEDITION',function()self.scene='setup' end,{color=9,icon='train',note='1-4 LOCAL PLAYERS'})
 r:button(xx,cy+34,b,5,'CONTINUE',function()
  local loaded=Disk.load();if loaded then self.game=loaded;self.scene='factory';self:notify('EXPEDITION RESTORED')
  else self:notify('NO SAVED EXPEDITION FOUND')end
 end,{color=11,icon='play'})
 r:button(xx,cy+40,b,4,'ABOUT AND GUIDE',function()self.scene='intro' end,{color=6,icon='info'})
 r:text(cx-22,r.h-3,self.toast~='' and self.toast or 'TURN-BASED AUTOMATION  |  NO TIME PRESSURE',4)
end
function App:setup()
 local r=self.r;local compact=r.h<80
 r:bigText(6,2,'EXPEDITION SETUP',17,2)
 for i=1,4 do
  local x=6+(i-1)*math.floor((r.w-14)/4);local width=math.floor((r.w-18)/4)
  r:button(x,compact and 7 or 11,width,4,(i==1 and 'SOLO' or (i..' PLAYERS')),function()
   self.playerCount=i;self.editing=math.min(i,self.editing)
  end,{color=self.playerCount==i and 9 or 6})
 end
 r:text(6,compact and 13 or 20,'SELECT AN ENGINEER TO RENAME',6)
 local count=self.playerCount
 for i=1,count do
  local width=math.floor((r.w-16)/count)
  r:button(6+(i-1)*(width+1),compact and 15 or 24,width,4,self.names[i]~='' and self.names[i] or ('NAME '..i),function()
   self.editing=i
  end,{color=self.editing==i and 9 or 4})
 end
 local labelY=compact and 21 or 33;local startY=compact and 24 or 37
 r:text(6,labelY,'ON-SCREEN KEYBOARD  /  EDITING '..self.editing,5)
 local rows={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM'};local keyStep=compact and 5 or 6
 local keyWidth=keyStep-1;local rowStep=compact and 5 or 6
 for line,row in ipairs(rows) do
  local x=math.floor((r.w-#row*keyStep)/2)
  for i=1,#row do local ch=row:sub(i,i)
   r:button(x+(i-1)*keyStep,startY+(line-1)*rowStep,keyWidth,4,ch,function()
    self.names[self.editing]=U.name(self.names[self.editing]..ch)
   end,{color=6})
  end
 end
 local controlY=compact and 40 or 57
 local buttonWidth=math.min(23,math.floor((r.w-24)/3));local x=math.floor((r.w-(buttonWidth+2)*3)/2)
 r:button(x,controlY,buttonWidth,4,'BACKSPACE',function()self.names[self.editing]=self.names[self.editing]:sub(1,-2)end,{color=18})
 r:button(x+buttonWidth+2,controlY,buttonWidth,4,'SPACE',function()self.names[self.editing]=U.name(self.names[self.editing]..' ')end,{color=6})
 r:button(x+(buttonWidth+2)*2,controlY,buttonWidth,4,'CLEAR',function()self.names[self.editing]=''end,{color=18})
 r:text(6,compact and 47 or 66,'SHIFTS ADVANCE ONLY WHEN PLAYERS CHOOSE.',5)
 r:button(6,r.h-10,24,5,'BACK',function()self.scene='title'end,{color=11,icon='back'})
 r:button(r.w-44,r.h-10,39,5,'BEGIN EXPEDITION',function()
  self.seed=math.floor(((os.epoch and os.epoch('utc')) or (os.clock()*1000))%1900000)+5123
  self:newGame()
 end,{color=9,icon='train'})
end
function App:intro()
 local r=self.r;r:text(6,8,'RAILBREAK - KINETIC FRONTIER',17)
 local lines={
  'BUILD A RAILWAY ACROSS A PROCEDURALLY CHOSEN FRONTIER.',
  'CREATE-INSPIRED COGS, SHAFTS, BELTS AND WORKSHOPS.',
  'ENGINEERING AND PLANNING, NOT REAL-TIME REACTIONS.',
  'A PRODUCTION SHIFT RUNS ONLY WHEN YOU PRESS THE BUTTON.',
  'A SOLO ENGINEER CAN OPERATE EVERYTHING.',
  '2-4 FRIENDS CAN SHARE DESIGN TASKS ON ONE MONITOR.',
  'THE STARTER FACTORY MAKES IRON SHEETS ALREADY.',
  'MAKE TRACK, BUILD BRIDGES AND PICK YOUR NEXT ROUTE.',
  'FOUR RAILWAY STAGES LEAD TO THE FINAL CITY.',
 }
 for i,v in ipairs(lines)do r:text(6,13+i*4,v,i==1 and 9 or 5,r.w-10)end
 r:button(6,r.h-12,29,5,'BACK TO TITLE',function()self.scene='title'end,{icon='back',color=11})
end
function App:results()
 local r=self.r;local g=self.game;self:header()
 r:text(math.floor(r.w/2)-22,math.floor(r.h/4),'RAILWAY COMPLETED',9)
 r:text(math.floor(r.w/2)-25,math.floor(r.h/4)+7,'THE CLOCKWORK RAILWAY REACHES THE CAPITAL',17)
 r:text(math.floor(r.w/2)-13,math.floor(r.h/4)+13,'TOTAL SCORE '..A.score(g),6)
 r:text(math.floor(r.w/2)-13,math.floor(r.h/4)+16,'SHIFTS '..g.shift..'  CONTRACTS '..g.delivered,5)
 for i,name in ipairs(g.players)do
  local c=g.contributions[i]
  r:text(math.floor(r.w/2)-16,math.floor(r.h/4)+18+i*2,name..' - '..c.actions..' ACTIONS, '..c.shifts..' SHIFTS',11)
 end
 r:button(math.floor(r.w/2)-20,math.floor(r.h/4)+23,40,5,'NEW EXPEDITION',function()self.scene='setup'end,{icon='train',color=9})
 self:bottom()
end
function App:draw()
 local r=self.r;r:begin()
 if r.w<95 or r.h<64 then
  r:text(3,4,'RAILBREAK REQUIRES A 5X5 ADVANCED MONITOR',18)
  r:text(3,8,'TEXT SCALE 0.5 / GRAPHICS MODE OPTIONAL',5)
 else
  if self.scene=='title' then self:title()
  elseif self.scene=='setup' then self:setup()
  elseif self.scene=='intro' then self:intro()
  elseif self.scene=='factory' and self.game then self:factory()
  elseif self.scene=='railway' and self.game then self:route()
  elseif self.scene=='warehouse' and self.game then self:warehouse()
  elseif self.scene=='blueprints' and self.game then self:blueprints()
  elseif self.scene=='help' and self.game then self:help()
  elseif self.scene=='results' and self.game then self:results()
  else self.scene='title';self:title()end
  if self.modal then
   -- Modal controls must be exclusive; underlying buttons are not interactive.
   r.buttons={};self:dialog()
  end
 end
 r:finish()
end
function App:touch(x,y)
 local lx,ly=x-1,y-1
 return self.r:hit(lx,ly)
end
return App
