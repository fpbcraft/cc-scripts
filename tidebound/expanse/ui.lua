-- The Shattered Expanse: shared-monitor touchscreen UI.
local root=_G.EXPANSE_ROOT or '/tidebound/expanse'
local Sim=dofile(root..'/sim.lua')
local Renderer=dofile(root..'/render.lua')
local C=Sim.content
local UI={};UI.__index=UI
local function trunc(s,n)s=tostring(s or ''):upper();if #s>n then return s:sub(1,n-1)..'.' end;return s end
local function wrap(s,max)
 local out={};max=math.max(8,math.floor(max));local line=''
 for word in tostring(s or ''):gmatch('%S+') do
  if #line+#word+1>max and #line>0 then out[#out+1]=line;line=word
  else line=line=='' and word or line..' '..word end
 end
 if line~='' then out[#out+1]=line end
 return out
end
local function safeName(s) return tostring(s or ''):upper():gsub('[^A-Z0-9 _%-]',''):sub(1,16) end
local function colors(p)return ({14,9,13,17})[p] or 6 end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
function UI.new(monitor,forceText)
 local self=setmetatable({},UI)
 self.r=Renderer.new(monitor,forceText);self.screen='title';self.g=nil;self.modal=nil;self.choice=nil;self.selected=nil
 self.names={'IMPERIUM','CONCORD','ASCENDANCY','FREE SYSTEMS'};self.arch={1,2,3,4};self.humans=2;self.rounds=24
 self.edit=1;self.mode=nil;self.activeShip=nil;self.partner=2;self.page=1;self.notice='';self.frame=0
 self.tab='systems';self.oldSystem=nil
 return self
end
function UI:save()
 if not fs or not textutils or not self.g then return end
 local path='/tidebound/expanse-save.dat'
 if not fs.exists('/tidebound')then path='expanse-save.dat' end
 local tmp=path..'.tmp'
 local h=fs.open(tmp,'w');if not h then return end
 h.write(textutils.serialize(self.g));h.close()
 local bk=path..'.bak'
 if fs.exists(bk)then fs.delete(bk)end
 if fs.exists(path)then fs.move(path,bk)end
 fs.move(tmp,path)
end
function UI:load()
 if not fs or not textutils then return false end
 for _,path in ipairs({'/tidebound/expanse-save.dat','/tidebound/expanse-save.dat.bak','expanse-save.dat','expanse-save.dat.bak'})do
  if fs.exists(path)then
   local h=fs.open(path,'r');if h then local data=h.readAll();h.close()
    local ok,g=pcall(textutils.unserialize,data)
    if ok and Sim.validateState(g)then self.g=g;Sim.advanceAI(g);self.screen=g.ended and 'results' or 'handoff';return true end
   end
  end
 end
 return false
end
function UI:start()
 local human={};for p=1,4 do human[p]=p<=self.humans end
 local date=(os and os.epoch and os.epoch('utc')) or math.floor(os.clock()*100000)
 self.g=Sim.new({names=self.names,archetypes=self.arch,humans=human,rounds=self.rounds,seed=math.floor(date%2000000000)+13})
 self.screen='handoff';self.selected=nil;self.mode=nil;self.notice='';self:save()
end
function UI:button(x,y,w,h,label,icon,tint,fn,description,disabled)
 if w<8 or h<3 then return end
 self.r:button(math.floor(x),math.floor(y),math.floor(w),math.floor(h),label,icon or 'star',tint or 9,fn,description,disabled)
end
function UI:background()
 local r=self.r
 r:rect(0,0,r.w,r.h,0)
 for i=1,65 do
  local x=((i*29+11)%100)/100*r.w;local y=((i*37+7)%100)/100*r.h
  local tw=(self.frame+i)%13==0 and 7 or (i%3==0 and 4 or 2)
  r:rect(x,y,1,1,tw)
 end
end
function UI:card(x,y,w,h,title)
 local r=self.r
 r:rect(x,y,w,h,1);r:rect(x,y,w,1,3);r:rect(x,y,1,h,4)
 r:text(x+2,y+1,title,7,w-4)
end
function UI:body(x,y,w,description,c,maxRows)
 local r=self.r;local lines=wrap(description,w)
 for i=1,math.min(maxRows or 80,#lines)do r:text(x,y+i-1,lines[i],c or 6,w)end
 return math.min(#lines,maxRows or 80)
end
function UI:header(title,home)
 local r=self.r;r:rect(0,0,r.w,7,1);r:rect(0,6,r.w,1,3)
 r:icon(3,2,'star',9);r:text(6,3,title,7,r.w-32)
 if home then self:button(r.w-19,1,17,5,'GALAXY','back',9,function()self.screen='galaxy';self.mode=nil end) end
end
function UI:titleScreen()
 local r=self.r;self:background()
 local cx=math.floor(r.w/2)
 for i=1,9 do local x=cx-42+i*9;local y=math.floor(r.h*.32)+math.sin(self.frame*.17+i*.8)*3
  r:disc(x,y,1+(i%3),i%2==0 and 10 or 12)
 end
 local large=r.h>=75 and 3 or 1
 local top=r.h>=75 and 12 or 8
 r:bigText(cx-9*large/2,top,'SHATTERED',9,large)
 r:bigText(cx-7*large/2,top+7*large+3,'EXPANSE',7,large)
 local subtitle=top+14*large+5
 r:text(cx-18,subtitle,'FOUR EMPIRES. ONE FRACTURED GALAXY.',6)
 local y=r.h>=75 and math.floor(r.h*.69) or r.h-19
 self:button(cx-21,y,42,6,'NEW CAMPAIGN','star',9,function()self.screen='setup' end)
 self:button(cx-21,y+8,42,6,'CONTINUE','next',17,function()
  if not self:load()then self.notice='NO V4 CAMPAIGN SAVE FOUND';self.screen='title' end
 end)
 self:button(cx-21,y+16,42,5,'HOW TO PLAY','help',11,function()self.screen='help'end)
 r:text(cx-19,r.h-3,'V4.0 | CC: GRAPHICS + TOUCH',5)
 if self.notice~=''then r:text(cx-23,y-3,self.notice,15)end
end
function UI:setupScreen()
 local r=self.r;self:background();self:header('NEW GALAXY',true)
 local x=math.max(3,math.floor(r.w*.12));local w=math.min(r.w-6,math.max(52,math.floor(r.w*.76)))
 self:card(x,9,w,r.h-18,'FOUNDING THE FOUR POWERS')
 r:text(x+3,14,'HUMAN EMPIRES',6)
 self:button(x+23,12,10,5,'-','back',11,function()self.humans=math.max(1,self.humans-1)end,nil,self.humans<=1)
 r:text(x+36,14,tostring(self.humans),9)
 self:button(x+40,12,10,5,'+','next',9,function()self.humans=math.min(4,self.humans+1)end,nil,self.humans>=4)
 local wide=math.max(16,math.floor(w*.24));local y0=20
 for p=1,4 do
  local y=y0+(p-1)*6
  r:rect(x+2,y,w-4,5,p<=self.humans and 2 or 24)
  r:rect(x+2,y,2,5,colors(p))
  r:text(x+5,y+1,p<=self.humans and ('P'..p..' HUMAN') or ('P'..p..' AI'),7,12)
  self:button(x+17,y,math.max(17,w-42),5,trunc(self.names[p],math.max(8,w-49)),'flag',colors(p),function()self.edit=p;self.screen='keyboard'end)
  self:button(x+w-23,y,21,5,trunc(C.archetypes[self.arch[p]].id,13),'star',colors(p),function()self.arch[p]=self.arch[p]%4+1;self.names[p]=C.archetypes[self.arch[p]].name end)
 end
 local foot=r.h-16
 if r.h>=78 then
  r:text(x+3,47,'FOUR ORIGINS. FOUR WAYS TO SHAPE HISTORY.',9,w-6)
  for p=1,4 do
   r:text(x+4,49+p*3,trunc(C.archetypes[self.arch[p]].name,13)..': '..trunc(C.archetypes[self.arch[p]].description,w-25),5,w-5)
  end
 end
 r:text(x+3,foot-5,'CAMPAIGN LENGTH: '..self.rounds..' YEARS',6)
 self:button(x+3,foot-2,18,5,'-4 YEARS','back',11,function()self.rounds=math.max(16,self.rounds-4)end,nil,self.rounds<=16)
 self:button(x+23,foot-2,18,5,'+4 YEARS','next',9,function()self.rounds=math.min(32,self.rounds+4)end,nil,self.rounds>=32)
 self:button(x+w-31,foot-2,29,6,'FOUND EMPIRES','check',19,function()self:start()end)
 r:text(x+2,r.h-5,'TOUCH A NAME TO EDIT | TOUCH A FACTION TO CYCLE',5,w-4)
end
function UI:keyboard()
 local r=self.r;self:background();self:header('NAME YOUR CIVILIZATION',false)
 local cx=math.floor(r.w/2);local name=self.names[self.edit]
 self:card(cx-37,11,74,r.h-19,'EMPIRE '..self.edit)
 r:text(cx-28,19,trunc(name,24),7)
 local rows={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM'}
 local keyWidth=math.min(7,math.floor((r.w-12)/10))
 local oy=math.floor(r.h*.38)
 for ri,row in ipairs(rows)do
  local ww=#row*keyWidth;local x=cx-math.floor(ww/2)
  for i=1,#row do
   local ch=row:sub(i,i)
   self:button(x+(i-1)*keyWidth,oy+(ri-1)*7,keyWidth-1,6,ch,'star',6,function()self.names[self.edit]=safeName(self.names[self.edit]..ch)end)
  end
 end
 self:button(cx-33,oy+22,20,6,'SPACE','next',9,function()self.names[self.edit]=safeName(name..' ')end)
 self:button(cx-10,oy+22,20,6,'DELETE','close',15,function()self.names[self.edit]=self.names[self.edit]:sub(1,-2)end)
 self:button(cx+13,oy+22,20,6,'DONE','check',19,function()
  if self.names[self.edit]=='' then self.names[self.edit]='EMPIRE '..self.edit end;self.screen='setup'
 end)
end
function UI:handoff()
 local r=self.r;self:background();self:header('NEW COMMAND PHASE',false)
 local g=self.g;local p=Sim.current(g);local f=g.factions[p];local cx=math.floor(r.w/2)
 r:icon(cx-4,math.floor(r.h*.25),'flag',colors(p))
 r:bigText(cx-math.min(30,#f.name),math.floor(r.h*.35),trunc(f.name,15),colors(p),2)
 r:text(cx-17,math.floor(r.h*.35)+18,'YEAR '..g.round..' / '..g.limit,6)
 r:text(cx-28,math.floor(r.h*.35)+23,'PASS THE MONITOR TO THIS PLAYER',6)
 self:button(cx-23,math.floor(r.h*.67),46,7,'BEGIN YOUR TURN','next',19,function()
  self.screen='galaxy';self.mode=nil;self.selected=nil;self.activeShip=nil
 end)
end
function UI:starPos(s)
 local r=self.r
 return math.floor(4+s.x*(r.w-8)),math.floor(10+s.y*(r.h-26))
end
function UI:galaxyBase()
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 self:background()
 for _,edge in ipairs(g.links)do
  local a,b=g.systems[edge[1]],g.systems[edge[2]]
  if f.charted[a.id] or f.charted[b.id] or f.seen[a.id] or f.seen[b.id] then
   local ax,ay=self:starPos(a);local bx,by=self:starPos(b)
   r:line(ax,ay,bx,by,3)
  end
 end
 for _,s in ipairs(g.systems)do
  if not f.charted[s.id] and not f.seen[s.id] and s.owner~=p then
   local x,y=self:starPos(s)
   r:disc(x,y,1,(s.id%4==0) and 3 or 24)
  end
 end
 for _,s in ipairs(g.systems)do
  if f.charted[s.id] or f.seen[s.id] or s.owner==p then
   local x,y=self:starPos(s)
   local discovered=f.seen[s.id] or s.owner==p
   local own=s.owner>0 and discovered and s.owner or 0
   local clr=own>0 and colors(own) or discovered and (s.kind=='RIFT' and 12 or s.kind=='RELIC' and 16 or 8) or 4
   if s.id==self.selected then r:disc(x,y,3,7) end
   r:disc(x,y,own>0 and 2 or 1,clr)
   if discovered then
    if s.colony>0 then r:icon(x-1,y-4,'colony',clr)end
    if s.anomaly and not s.investigated[p] then r:icon(x+3,y-3,'scan',17) end
   end
   for _,ship in ipairs(Sim.shipsAt(g,s.id,p))do
    if ship.kind=='fleet' or C.shipClasses[ship.kind].power>0 then
     r:icon(x-1,y+2,'ship',colors(p));break
    end
   end
   -- Invisible hitbox overlaps are ordered by draw. The nearest manually-resolved star wins.
  end
 end
end
function UI:drawHud()
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 r:rect(0,0,r.w,8,1);r:rect(0,7,r.w,1,colors(p))
 r:icon(2,2,'flag',colors(p));r:text(5,2,trunc(f.name,15),7)
 r:text(5,4,'YEAR '..g.round..'/'..g.limit,5)
 r:text(math.max(24,r.w-42),2,'C '..f.credits..'   M '..f.materials,17)
 r:text(math.max(24,r.w-42),4,'R '..f.research..'   A '..f.aether,9)
 r:rect(0,r.h-10,r.w,10,1)
 local labels={{'EMPIRE','colony','empire'},{'SCIENCE','research','research'},{'SHIPS','ship','ships'},{'DIPLOMACY','trade','diplomacy'},{'HISTORY','help','history'}}
 local cols=5;local bw=math.max(12,math.floor((r.w-15)/cols))
 for i,l in ipairs(labels)do
  local x=2+(i-1)*bw
  self:button(x,r.h-8,bw-1,6,l[1],l[2],i==1 and 9 or 11,function()self.screen=l[3];self.page=1;self.mode=nil end)
 end
 self:button(r.w-13,r.h-8,12,6,'END','next',19,function()self:endTurn()end)
end
function UI:drawGalaxy()
 local r=self.r;self:galaxyBase();self:drawHud()
 local g=self.g;local p=Sim.current(g)
 if self.mode=='move' and self.activeShip then
  r:rect(4,9,math.min(r.w-8,49),5,2);r:text(6,11,'SELECT AN ADJACENT SYSTEM TO MOVE',7)
 end
 if self.selected then
  local s=g.systems[self.selected];local f=g.factions[p]
  local w=math.min(39,math.floor(r.w*.42));local x=r.w-w-2;local y=9;local h=r.h-21
  self:card(x,y,w,h,(f.seen[s.id] or s.owner==p) and s.name or 'UNCHARTED STAR')
  r:text(x+3,y+4,'SYSTEM '..s.id..' / '..s.kind,6,w-5)
  r:text(x+3,y+7,'OWNER: '..(s.owner>0 and g.factions[s.owner].name or 'UNCLAIMED'),s.owner>0 and colors(s.owner) or 6,w-5)
  r:text(x+3,y+9,'COLONY LEVEL: '..s.colony,5)
  if f.seen[s.id] then
   local buildings={};for id,n in pairs(s.buildings)do if n>0 then buildings[#buildings+1]=id..' x'..n end end
   table.sort(buildings)
   r:text(x+3,y+12,'STRUCTURES: '..(#buildings>0 and #buildings or 'NONE'),7)
   for i=1,math.min(3,#buildings)do r:text(x+4,y+12+i,buildings[i],5,w-6)end
  else r:text(x+3,y+12,'SEND A SCIENCE VESSEL',15)end
  local shipCount=#Sim.shipsAt(g,s.id,p);r:text(x+3,y+17,'OWN SHIPS: '..shipCount,9)
  if s.construction then r:text(x+3,y+19,'BUILD: '..s.construction.remaining..' YEARS',17)end
  local actionsY=math.max(y+21,y+h-22)
  self:button(x+2,actionsY,w-4,5,'SYSTEM ORDERS','flag',9,function()self.modal={type='orders',system=s.id,page=1}end)
  self:button(x+2,actionsY+6,w-4,5,'SELECT SHIP','ship',11,function()self.screen='ships';self.filter=s.id;self.page=1 end)
  self:button(x+2,actionsY+12,w-4,5,'CLOSE DETAILS','close',15,function()self.selected=nil end)
 end
 if self.notice~=''then r:rect(2,r.h-14,math.min(r.w-4,#self.notice+6),4,2);r:text(4,r.h-13,self.notice,7)end
end
function UI:clickStar(x,y)
 local p=Sim.current(self.g);local f=self.g.factions[p]
 local nearest,distance=nil,1e9
 for _,s in ipairs(self.g.systems)do if f.charted[s.id] or f.seen[s.id] or s.owner==p then
  local xx,yy=self:starPos(s);local d=(xx-x)^2+(yy-y)^2
  if d<distance then distance=d;nearest=s.id end
 end end
 if nearest and distance<=16 then
  if self.mode=='move' then
   self:ask('move',{ship=self.activeShip,system=nearest},'ORDER HYPERSPACE JUMP',
    'Ship moves one connected lane and spends one of its own orders. Enemy fleets automatically engage if your empires are at war.',nil)
  else self.selected=nearest end
 end
end
function UI:ask(kind,args,title,description,cost)
 local ok,reason=Sim.validate(self.g,Sim.current(self.g),kind,args)
 self.modal={type='confirm',kind=kind,args=args,title=title,description=description,cost=cost,legal=ok,reason=reason}
end
function UI:apply(kind,args)
 local ok,msg=Sim.command(self.g,Sim.current(self.g),kind,args)
 self.notice=trunc(msg,70)
 if ok then
  if kind=='move' or kind=='claim' or kind=='colonize' or kind=='anomaly' then self.mode=nil;self.activeShip=nil end
  self.modal=nil;self:save()
 else self.modal=nil end
 return ok,msg
end
function UI:actionList(s)
 local actions={}
 local p=Sim.current(self.g);local f=self.g.factions[p]
 local function add(title,icon,kind,args,desc,cost)
  actions[#actions+1]={title=title,icon=icon,kind=kind,args=args,description=desc,cost=cost}
 end
 for _,ship in ipairs(Sim.shipsAt(self.g,s.id,p))do
  if ship.kind=='builder' then
   if s.owner==0 then add('ESTABLISH OUTPOST','flag','claim',{ship=ship.id,system=s.id},'Adds an adjacent surveyed system to your empire. A construction ship spends one order.','C5 M7')
   elseif s.owner==p and s.colony==0 then add('FOUND COLONY','colony','colonize',{ship=ship.id,system=s.id},'Creates a permanent colony that generates resources and provides building slots. Builder spends one order.','C9 M9')end
  elseif ship.kind=='scout' then
   if not f.seen[s.id] then add('SURVEY SYSTEM','scan','survey',{ship=ship.id,system=s.id},'Survey an unexplored star, revealing its details. Science vessel spends one order.','SHIP: 1 ORDER')end
   if s.anomaly and not s.investigated[p] then add('STUDY ANOMALY','research','anomaly',{ship=ship.id,system=s.id},'Gain Research and perhaps uncover a narrative event. Science vessel spends one order.','SHIP: 1 ORDER')end
  elseif C.shipClasses[ship.kind].power>0 and s.owner>0 and s.owner~=p then
   add('INVADE SYSTEM','war','assault',{ship=ship.id,system=s.id},'Occupy an enemy world after its defensive fleet is defeated. Warship spends one order.','SHIP: 1 ORDER')
  end
 end
 if s.neutral and s.owner==0 then add('INTEGRATE PEACEFULLY','trade','integrate',{system=s.id},'Bring this neutral settlement into your empire through diplomacy. Requires Embassies.','C16 M5')end
 if s.owner==p and s.colony>0 then
  add('EXPAND COLONY','colony','upgrade',{system=s.id},'Raises colony level, income and building slots after two years.','C '..11*s.colony..' M '..9*s.colony)
  for _,id in ipairs({'mine','exchange','lab','shipyard','bastion','extractor'})do
   local b=C.buildings[id]
   if id~='extractor' or s.kind=='RIFT' then
    add(b.name,'forge','build',{system=s.id,building=id},b.desc,'C'..(b.cost.credits or 0)..' M'..(b.cost.materials or 0))
   end
  end
  if s.buildings.shipyard and s.buildings.shipyard>0 then
   for _,id in ipairs({'scout','builder','frigate','cruiser','capital'})do
    local sh=C.shipClasses[id]
    add('CONSTRUCT '..sh.name,'ship','shipbuild',{system=s.id,class=id},sh.desc,'C'..sh.cost.credits..' M'..sh.cost.materials..(sh.cost.aether and ' A'..sh.cost.aether or ''))
   end
  end
 end
 return actions
end
function UI:ordersModal()
 local r=self.r;local m=self.modal;local s=self.g.systems[m.system]
 local actions=self:actionList(s)
 local w=math.min(r.w-8,75);local x=math.floor((r.w-w)/2);local h=math.min(r.h-14,66);local y=math.floor((r.h-h)/2)
 r:rect(0,8,r.w,r.h-18,0);self:card(x,y,w,h,'ORDERS: '..s.name)
 local rows=math.max(2,math.floor((h-14)/6));local pages=math.max(1,math.ceil(#actions/rows));m.page=math.min(pages,m.page or 1)
 local start=(m.page-1)*rows+1
 for i=start,math.min(start+rows-1,#actions)do
  local action=actions[i];local yy=y+6+(i-start)*6
  local ok,why=Sim.validate(self.g,Sim.current(self.g),action.kind,action.args)
  self:button(x+3,yy,w-6,5,action.title,action.icon,ok and 9 or 5,function()
   self:ask(action.kind,action.args,action.title,action.description,action.cost)
  end,ok and action.cost or trunc(why,32))
 end
 r:text(x+4,y+h-7,'PAGE '..m.page..'/'..pages..' | DISABLED? TAP TO SEE WHY',5,w-8)
 self:button(x+3,y+h-6,14,5,'PREV','back',11,function()m.page=math.max(1,m.page-1)end,nil,m.page==1)
 self:button(x+19,y+h-6,14,5,'NEXT','next',11,function()m.page=math.min(pages,m.page+1)end,nil,m.page>=pages)
 self:button(x+w-19,y+h-6,16,5,'CLOSE','close',15,function()self.modal=nil end)
end
function UI:confirmModal()
 local r=self.r;local m=self.modal
 local w=math.min(r.w-8,70);local h=math.min(r.h-16,36);local x=math.floor((r.w-w)/2);local y=math.floor((r.h-h)/2)
 self:card(x,y,w,h,trunc(m.title,w-5))
 self:body(x+3,y+5,w-6,m.description,6,math.max(3,h-20))
 if m.cost then r:text(x+3,y+h-13,'COST: '..m.cost,17,w-6)end
 if not m.legal then
  r:text(x+3,y+h-10,'UNAVAILABLE: '..trunc(m.reason,w-18),15,w-5)
 end
 self:button(x+3,y+h-7,21,5,'CANCEL','close',11,function()self.modal=nil end)
 self:button(x+w-25,y+h-7,22,5,'CONFIRM','check',19,function()self:apply(m.kind,m.args)end,nil,not m.legal)
end
function UI:pendingEvent()
 local g=self.g;local p=Sim.current(g);local f=g.factions[p];local event=f.events[1]
 if not event then return false end
 local r=self.r;local w=math.min(r.w-8,82);local h=math.min(r.h-14,65)
 local x=math.floor((r.w-w)/2);local y=math.floor((r.h-h)/2)
 r:rect(0,7,r.w,r.h-17,0);self:card(x,y,w,h,'DECISION: '..event.title)
 local l=self:body(x+4,y+5,w-8,event.body,6,7)
 local first=y+8+l;local available=h-(first-y)-5;local rowH=math.min(9,math.max(5,math.floor(available/#event.choices)))
 for i,o in ipairs(event.choices)do
  local yy=first+(i-1)*rowH
  local valid,why=Sim.validate(g,p,'choose',{choice=i})
  self:button(x+3,yy,w-6,rowH-1,o.label,'check',i%2==0 and 11 or 9,function()
   self:apply('choose',{choice=i})
  end,valid and trunc(o.desc,w-12) or why,not valid)
 end
 r:text(x+3,y+h-3,'THE CHOICE WILL HAVE LASTING CONSEQUENCES',5,w-6)
 return true
end
function UI:incomingOffer()
 local f=self.g.factions[Sim.current(self.g)];local offer=f.offers[1]
 if not offer then return false end
 local r=self.r;local w=math.min(r.w-8,68);local h=31
 local x=math.floor((r.w-w)/2);local y=math.floor((r.h-h)/2)
 self:card(x,y,w,h,'DIPLOMATIC ENVOY')
 r:text(x+3,y+5,self.g.factions[offer.from].name..' PROPOSES',7,w-5)
 r:text(x+3,y+8,C.pacts[offer.pact].name,9,w-5)
 self:body(x+3,y+11,w-6,C.pacts[offer.pact].desc,6,7)
 self:button(x+3,y+24,21,5,'DECLINE','close',15,function()self:apply('offer_reply',{accept=false})end)
 self:button(x+w-25,y+24,22,5,'ACCEPT','check',19,function()self:apply('offer_reply',{accept=true})end)
 return true
end
function UI:drawEmpire()
 local g=self.g;local p=Sim.current(g);local f=g.factions[p];local r=self.r
 self:background();self:header('EMPIRE OVERVIEW',true)
 local w=math.min(r.w-8,85);local x=math.floor((r.w-w)/2)
 self:card(x,9,w,r.h-22,f.name..' / '..C.archetypes[f.archetype].name)
 r:text(x+3,14,'RULER: '..f.leader..' | '..f.personality,7,w-6)
 r:text(x+3,18,'POLICY: '..f.policy,9,w-6)
 r:text(x+3,21,'STABILITY '..f.stability..' | PRESTIGE '..f.prestige,6)
 local o=Sim.projectProgress(g,p);local inc=Sim.income(g,p)
 r:text(x+3,24,'SYSTEMS '..o.systems..'/40 | COLONIES '..o.colonies,6)
 r:text(x+3,27,'LEGACY SCORE '..o.score,17)
 r:text(x+3,29,'VALUES: KIND '..f.ethics.compassion..' | ORDER '..f.ethics.authority..' | LORE '..f.ethics.curiosity,5,w-6)
 r:text(x+3,32,'INCOME NEXT YEAR',7)
 r:text(x+3,35,'C'..inc.credits..' M'..inc.materials..' R'..inc.research..' A'..inc.aether,9)
 r:text(x+3,39,'CHANGE YOUR CIVIC PRIORITIES',6)
 local policies={{'BALANCED','DEFAULT'},{'INDUSTRY','+3 M, -1 R'},{'SCHOLARSHIP','+3 R, -2 C'},{'MERCANTILE','+4 C, -1 M'}}
 local py=42
 for _,item in ipairs(policies)do
  self:button(x+3,py,w-6,5,item[1],item[1]==f.policy and 'check' or 'flag',9,function()self:ask('policy',{policy=item[1]},'ADOPT '..item[1],item[2]..'. Changing a policy costs 4 Credits and is limited to once per year.','4 C')end,item[2])
  py=py+6
 end
 local y=math.min(r.h-20,py+2)
 self:button(x+3,y,w-6,5,'AETHER EXCHANGE','energy',17,function()self:ask('market',{item='aether'},'PURCHASE AETHER','Exchange Credits for a single Aether. Only one purchase per year; price rises during the Aether Crisis.',(g.galactic.aetherCrisis and '32 C' or '20 C'))end)
 self:button(x+3,y+6,w-6,5,'GRAND VICTORY PROJECTS','trophy',17,function()self.screen='projects'end)
end
function UI:drawResearch()
 local r=self.r;local g=self.g;local f=g.factions[Sim.current(g)]
 self:background();self:header('SCIENCE & TECHNOLOGY',true)
 local w=math.min(r.w-10,94);local x=math.floor((r.w-w)/2)
 r:text(x+2,10,'RESEARCH RESERVE: '..f.research..' | SPEND WITHOUT EMPIRE ACTION POINTS',9,w-4)
 local branches={{'engineering','forge'},{'physics','ship'},{'society','trade'},{'exploration','scan'}}
 for i,b in ipairs(branches)do
  local key=b[1];local lvl=f.tech[key];local tech=C.tech[key][lvl+1]
  local h=math.floor((r.h-24)/4);local y=14+(i-1)*h
  r:rect(x,y,w,h-1,1);r:rect(x,y,2,h-1,({17,11,9,13})[i])
  r:text(x+4,y+2,key:upper()..' '..lvl..'/4',7)
  if tech then
   r:text(x+4,y+5,tech.name,9,w-36)
   self:body(x+4,y+7,w-34,tech.desc,5,3)
   self:button(x+w-30,y+math.floor((h-5)/2),27,5,'STUDY '..Sim.researchCost(f,key)..' R',b[2],9,function()
    self:ask('research',{branch=key},tech.name,tech.desc..' Research unlocks immediately using accumulated Research.','R '..Sim.researchCost(f,key))end)
  else r:text(x+4,y+6,'BRANCH COMPLETE',19)end
 end
end
function UI:drawShips()
 local r=self.r;local g=self.g;local p=Sim.current(g)
 self:background();self:header('FLEET & EXPLORATION',true)
 local ships={};for _,sh in ipairs(g.ships)do if sh.owner==p and (not self.filter or sh.location==self.filter) then ships[#ships+1]=sh end end
 local w=math.min(r.w-8,90);local x=math.floor((r.w-w)/2)
 self:card(x,9,w,r.h-22,'YOUR VESSELS / '..#ships)
 local rows=math.max(3,math.floor((r.h-33)/7));local pages=math.max(1,math.ceil(#ships/rows));self.page=math.min(self.page,pages)
 for i=(self.page-1)*rows+1,math.min(self.page*rows,#ships)do
  local sh=ships[i];local yy=15+(i-(self.page-1)*rows-1)*7
  r:text(x+3,yy,sh.name,7,w-18)
  r:text(x+3,yy+2,g.systems[sh.location].name..' | ORDERS '..sh.ap,sh.ap>0 and 9 or 5,w-22)
  self:button(x+w-21,yy-1,18,6,'ORDER','move',9,function()
   self.mode='move';self.activeShip=sh.id;self.selected=sh.location;self.screen='galaxy';self.filter=nil
  end)
 end
 r:text(x+3,r.h-20,'PAGE '..self.page..'/'..pages,5)
 self:button(x+3,r.h-18,17,5,'PREVIOUS','back',11,function()self.page=math.max(1,self.page-1)end,nil,self.page<=1)
 self:button(x+22,r.h-18,17,5,'NEXT','next',11,function()self.page=math.min(pages,self.page+1)end,nil,self.page>=pages)
 self:button(x+w-22,r.h-18,19,5,'SHOW ALL','scan',9,function()self.filter=nil;self.page=1 end)
end
function UI:drawDiplomacy()
 local r=self.r;local g=self.g;local p=Sim.current(g)
 self:background();self:header('DIPLOMATIC CHAMBER',true)
 if self.partner==p then self.partner=p%4+1 end
 local w=math.min(r.w-8,82);local x=math.floor((r.w-w)/2)
 self:card(x,9,w,r.h-22,'TREATIES AND CONFLICT')
 local xx=x+3
 for q=1,4 do if q~=p then
  self:button(xx,15,math.floor((w-9)/3)-1,5,trunc(g.factions[q].name,11),'flag',colors(q),function()self.partner=q end)
  xx=xx+math.floor((w-9)/3)
 end end
 local to=self.partner;local f=g.factions[to]
 r:text(x+4,24,'COUNTERPART: '..f.name,7,w-6)
 r:text(x+4,27,'RELATIONS '..Sim.relation(g,p,to)..' | '..(Sim.atWar(g,p,to) and 'AT WAR' or 'AT PEACE'),Sim.atWar(g,p,to) and 15 or 9)
 local y=32
 for _,k in ipairs({'trade','research','nonaggression','alliance'})do
  local v=C.pacts[k]
  local exists=Sim.hasTreaty(g,p,to,k)
  self:button(x+3,y,w-6,5,exists and ('ACTIVE: '..v.name) or ('OFFER '..v.name),'trade',exists and 19 or 9,function()
   self:ask('diplomacy',{to=to,pact=k},v.name,v.desc..' The other civilization may accept or reject.','3 C')
  end,trunc(v.desc,w-12),exists)
  y=y+6
 end
 self:button(x+3,y+1,w-6,5,Sim.atWar(g,p,to) and 'SIGN PEACE TREATY' or 'DECLARE WAR','war',15,function()
  local war=Sim.atWar(g,p,to)
  self:ask(war and 'peace' or 'war',{to=to},war and 'END THE WAR' or 'DECLARE WAR',war and 'Immediately end hostilities and improve relations.' or 'Cancel agreements, severely damage relations and allow your warships to attack systems. This decision is consequential.',nil)
 end)
end
function UI:drawHistory()
 local r=self.r;self:background();self:header('GALACTIC ARCHIVES',true)
 local g=self.g;local x=5;local w=r.w-10
 self:card(x,9,w,r.h-22,'CHRONICLE OF THE EXPANSE')
 local rows=math.floor((r.h-30)/3)
 for i=1,math.min(rows,#g.log)do r:text(x+3,13+(i-1)*3,trunc(g.log[i],w-8),i%2==0 and 5 or 6)end
end
function UI:drawProjects()
 local r=self.r;self:background();self:header('VICTORY PATHS',true)
 local g=self.g;local p=Sim.current(g);local f=g.factions[p];local x=math.floor(r.w*.12);local w=r.w-2*x
 self:card(x,9,w,r.h-22,'A LEGACY FOR YOUR PEOPLE')
 local paths={{'science','TRANSCENDENCE','Complete Physics + Exploration 4, then pay C35 M40 A4. Three years to complete.'},
  {'diplomatic','GALACTIC CHARTER','Research Society 3 and sign two defensive alliances, then pay C45 M18. Three years.'},
  {'economic','GREAT MERCANTILE UNION','Control five developed colonies and stockpile C125 M65. Invest everything in a three-year project.'}}
 for i,item in ipairs(paths)do
  local y=16+(i-1)*math.floor((r.h-32)/3)
  r:text(x+4,y,item[2],9,w-6)
  self:body(x+4,y+3,w-8,item[3],5,4)
  local ok,why=Sim.validate(g,p,'project',{victory=item[1]})
  self:button(x+w-23,y+2,20,5,'INITIATE','trophy',19,function()self:ask('project',{victory=item[1]},item[2],item[3],nil)end,ok and 'READY' or trunc(why,15))
 end
 if f.project then r:text(x+4,r.h-20,'ACTIVE PROJECT: '..f.project.type..' / '..f.project.remaining..' YEARS',17)end
end
function UI:help()
 local r=self.r;self:background();self:header('CAPTAINS HANDBOOK',true)
 local lines={
  'SHATTERED EXPANSE - A FOUR EMPIRE SPACE 4X',
  '1. START WITH A SCIENCE SHIP, BUILDER AND FRIGATE.',
  '2. SHIPS HAVE INDEPENDENT ORDERS. NO EMPIRE AP CAP.',
  '3. TAP SHIPS, ORDER A MOVE, THEN TAP A LINKED STAR.',
  '4. SCIENCE VESSELS SURVEY AND STUDY ANOMALIES.',
  '5. BUILDERS CLAIM SURVEYED BORDER STARS THEN COLONIZE.',
  '6. COLONIES GENERATE RESOURCES EVERY YEAR.',
  '7. BUILDINGS AND SHIPS USE CREDITS AND MATERIALS.',
  '8. SPEND RESEARCH IN FOUR TECHNOLOGY BRANCHES.',
  '9. DIPLOMATIC OFFERS MAY TAKE A TURN TO RESOLVE.',
  '10. EVENT CHOICES ALTER YOUR HISTORY AND RELATIONS.',
  '11. DECLARE WAR TO ASSAULT ANOTHER EMPIRE.',
  '12. WIN VIA PROJECTS, CONQUEST OR LEGACY SCORE.',
  '13. ALL ICON BUTTONS SHOW EFFECTS BEFORE CONFIRMING.',
  '14. AI FACTIONS TAKE THEIR OWN TURNS AUTOMATICALLY.',
 }
 for i,s in ipairs(lines)do r:text(5,10+i*3,s,i==1 and 9 or 6,r.w-9)end
 self:button(5,r.h-8,22,5,'TITLE','back',11,function()self.screen='title'end)
end
function UI:results()
 local g=self.g;local r=self.r;self:background();self:header('THE GALAXY REMEMBERS',false)
 local cx=math.floor(r.w/2);local f=g.factions[g.winner]
 r:bigText(cx-28,math.floor(r.h*.24),'VICTORY',17,2)
 r:text(cx-24,math.floor(r.h*.24)+17,trunc(f.name..' - '..g.reason,40),9)
 local score={};for p=1,4 do score[#score+1]={name=g.factions[p].name,points=Sim.score(g,p),p=p}end
 table.sort(score,function(a,b)return a.points>b.points end)
 for i,s in ipairs(score)do r:text(cx-27,math.floor(r.h*.49)+i*5,i..'. '..trunc(s.name,16)..'   '..s.points..' LEGACY',colors(s.p))end
 self:button(cx-18,r.h-11,36,6,'RETURN TO TITLE','back',9,function()self.screen='title'end)
end
function UI:endTurn()
 local g=self.g;local p=Sim.current(g)
 local ok,msg=Sim.endTurn(g,p)
 if not ok then self.notice=msg;return end
 Sim.advanceAI(g)
 self.mode=nil;self.activeShip=nil;self.selected=nil;self.filter=nil;self.modal=nil;self.notice=''
 self.screen=g.ended and 'results' or 'handoff'
 self:save()
end
function UI:draw()
 local r=self.r;r:beginFrame();self.frame=self.frame+1
 if self.screen=='title' then self:titleScreen()
 elseif self.screen=='setup' then self:setupScreen()
 elseif self.screen=='keyboard' then self:keyboard()
 elseif self.screen=='handoff' then self:handoff()
 elseif self.screen=='galaxy' then self:drawGalaxy()
 elseif self.screen=='empire' then self:drawEmpire()
 elseif self.screen=='research' then self:drawResearch()
 elseif self.screen=='ships' then self:drawShips()
 elseif self.screen=='diplomacy' then self:drawDiplomacy()
 elseif self.screen=='history' then self:drawHistory()
 elseif self.screen=='projects' then self:drawProjects()
 elseif self.screen=='help' then self:help()
 elseif self.screen=='results' then self:results()
 end
 if self.g and self.screen~='title' and self.screen~='setup' and self.screen~='keyboard' and self.screen~='handoff' and self.screen~='results' then
  if #self.g.factions[Sim.current(self.g)].events>0 then r.buttons={};self:pendingEvent()
  elseif #self.g.factions[Sim.current(self.g)].offers>0 then r.buttons={};self:incomingOffer()
  elseif self.modal then r.buttons={};if self.modal.type=='orders' then self:ordersModal()else self:confirmModal()end end
 end
 r:endFrame()
end
function UI:touch(x,y)
 if self.r:hit(x,y)then return true end
 if self.screen=='galaxy' and not self.modal then self:clickStar(x,y);return true end
 return false
end
-- CC: Graphics monitor_touch is zero-indexed PIXELS; CC:T text is one-indexed CHARACTERS.
function UI:monitorTouch(x,y)
 if type(x)~='number' or type(y)~='number' then return false end
 local r=self.r
 if r.kind=='gfx' then
  if x<0 or y<0 or x>=r.w*r.px or y>=r.h*r.py then return false end
  x=math.floor(x/r.px)+1;y=math.floor(y/r.py)+1
 end
 if x<1 or y<1 or x>r.w or y>r.h then return false end
 return self:touch(x-1,y-1)
end
function UI:loop(name)
 self:draw();local timer=os.startTimer(.38)
 while true do
  local ev,a,b,c=os.pullEvent()
  if ev=='monitor_touch' and (not name or a==name) then self:monitorTouch(b,c);self:draw()
  elseif ev=='mouse_click' and self.r.m==term.current() then self:touch(b-1,c-1);self:draw()
  elseif ev=='char' and self.screen=='keyboard' then self.names[self.edit]=safeName(self.names[self.edit]..a);self:draw()
  elseif ev=='key' and self.screen=='keyboard' and keys and a==keys.backspace then self.names[self.edit]=self.names[self.edit]:sub(1,-2);self:draw()
  elseif ev=='monitor_resize' and (not name or a==name) then self.r:resize();self:draw()
  elseif ev=='timer' and a==timer then self:draw();timer=os.startTimer(self.screen=='galaxy' and .5 or .9)end
 end
end
return UI