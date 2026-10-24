-- TIDEBOUND v5: single-focus touch interface. Screen geometry is expressed in
-- character cells; the render adapter maps it to 256-colour CC: Graphics pixels.
local root=_G.EXPANSE_V5_ROOT or '/tidebound/expanse-v5'
local Sim=dofile(root..'/sim.lua')
local Renderer=dofile(root..'/render.lua')
local C=Sim.content
local UI={};UI.__index=UI
local function clip(s,max) s=tostring(s or ''):upper();max=math.max(2,math.floor(max or 99));return #s<=max and s or s:sub(1,max-1)..'.' end
local function wrap(s,n)
 local out,line={},''
 for word in tostring(s or ''):upper():gmatch('%S+')do
  if #line+#word+1>math.max(10,n) and line~='' then out[#out+1]=line;line=word
  else line=(line=='' and word or line..' '..word)end
 end
 if line~='' then out[#out+1]=line end
 return out
end
local function where(f,arr)
 local result={};for _,v in ipairs(arr)do if f(v)then result[#result+1]=v end end;return result
end
local function factionColor(p)return ({14,9,13,17})[p] or 5 end
local function safeName(s)return tostring(s or ''):upper():gsub('[^A-Z0-9 %-]',''):sub(1,16)end
local function costText(cost)
 local t={};for _,k in ipairs({'credits','alloy','knowledge'})do if cost[k] then t[#t+1]=({credits='C',alloy='A',knowledge='K'})[k]..cost[k]end end
 return table.concat(t,' ')
end
function UI.new(monitor,forceText)
 local self=setmetatable({},UI)
 self.r=Renderer.new(monitor,forceText)
 self.screen='title';self.g=nil;self.humans=2;self.rounds=20;self.names={};self.arch={1,2,3,4}
 for i,a in ipairs(C.factions)do self.names[i]=a.name end
 self.selected=nil;self.focusSystem=nil;self.shipID=nil;self.pending=nil;self.notice='';self.frame=0
 self.target=2;self.section='galaxy';self.page=1;self.edit=1;self.galaxyPage=1
 self.recentIncome=nil;self.returnTo='galaxy';self.activeAction=nil
 return self
end
function UI:save()
 if not self.g or not fs or not textutils then return end
 local path='/tidebound/v5-save.dat';if not fs.exists('/tidebound')then path='v5-save.dat'end
 local tmp=path..'.new';local h=fs.open(tmp,'w');if not h then return end
 h.write(textutils.serialize(self.g));h.close()
 if fs.exists(path..'.bak')then fs.delete(path..'.bak')end
 if fs.exists(path)then fs.move(path,path..'.bak')end
 fs.move(tmp,path)
end
function UI:load()
 if not fs or not textutils then return false end
 for _,path in ipairs({'/tidebound/v5-save.dat','/tidebound/v5-save.dat.bak','v5-save.dat','v5-save.dat.bak'})do
  if fs.exists(path)then local h=fs.open(path,'r')
   if h then local value=h.readAll();h.close();local ok,g=pcall(textutils.unserialize,value)
    if ok and Sim.validState(g)then self.g=g;Sim.advanceAI(g);self.screen=g.ended and 'results' or 'handoff';self.selected=nil;self.shipID=nil;return true end
   end
  end
 end
 return false
end
function UI:start(seed)
 local h={};for i=1,4 do h[i]=i<=self.humans end
 seed=seed or math.floor(((os and os.epoch and os.epoch('utc'))or(os.clock()*100000))%2100000000)+1
 self.g=Sim.new({humans=h,names=self.names,archetypes=self.arch,rounds=self.rounds,seed=seed})
 self.screen='handoff';self.selected=nil;self.notice='';self.shipID=nil;self:save()
end
function UI:box(x,y,w,h,tint)
 local r=self.r;r:rect(x,y,w,h,tint or 1);r:rect(x,y,w,1,3)
end
function UI:button(x,y,w,h,label,icon,fn,detail,color)
 x=math.floor(x);y=math.floor(y);w=math.floor(w);h=math.floor(h)
 if w<5 or h<3 then return end
 local r=self.r;r:rect(x,y,w,h,2);r:rect(x,y,1,h,color or 8)
 if icon then r:icon(x+1,y+math.floor((h-2)/2),icon,color or 9)end
 local start=x+(icon and 4 or 2)
 r:text(start,y+1,clip(label,w-(start-x)-1),7,w-(start-x)-1)
 if detail and h>=5 then r:text(start,y+2,clip(detail,w-(start-x)-1),5,w-(start-x)-1)end
 if fn then r.buttons[#r.buttons+1]={x=x,y=y,w=w,h=h,fn=fn,label=label,
  alt=function()
   -- Menus remain usable with either button; gameplay left-click is inspect-only.
   if not self.g or self.screen=='setup' or self.screen=='keyboard' then fn();return end
   self.notice=clip(detail or ('RIGHT-CLICK TO '..label),math.max(10,self.r.w-8))
  end}end
end
function UI:lines(x,y,w,text,color,max)
 local r=self.r;local rows=wrap(text,w);for i=1,math.min(#rows,max or 10)do r:text(x,y+i-1,rows[i],color or 6,w)end
 return math.min(#rows,max or 10)
end
function UI:space()
 local r=self.r;local count=math.max(24,math.floor(r.w*r.h/110))
 for i=1,count do local x=(i*71+27)%r.w;local y=(i*43+7)%r.h
  r:rect(x,y,1,1,(i+self.frame)%11==0 and 7 or i%4==0 and 4 or 3)
 end
end
function UI:headline(text,back)
 local r=self.r;r:rect(0,0,r.w,7,1);r:rect(0,6,r.w,1,3)
 r:icon(2,2,'star',9);r:text(5,3,clip(text,r.w-27),7,r.w-27)
 if back then self:button(r.w-14,1,12,5,'BACK','back',function()self.screen=back;self.page=1 end)end
end
function UI:title()
 local r=self.r;self:space();local cx=math.floor(r.w/2)
 r:disc(cx,math.floor(r.h*.27),math.max(8,math.floor(r.h*.12)),3)
 r:disc(cx-3,math.floor(r.h*.25),math.max(4,math.floor(r.h*.07)),10)
 local scale=r.w>=90 and 2 or 1
 r:bigText(cx-13*scale/2,math.floor(r.h*.38),'SHATTERED',9,scale)
 r:bigText(cx-10*scale/2,math.floor(r.h*.38)+scale*9,'EXPANSE',7,scale)
 r:text(cx-14,math.floor(r.h*.57),'A FOUR EMPIRE SPACE SAGA',6)
 local y=math.min(math.floor(r.h*.67),r.h-20)
 self:button(cx-19,y,38,5,'NEW CAMPAIGN','star',function()self.screen='setup'end)
 self:button(cx-19,y+6,38,5,'CONTINUE','next',function()if not self:load()then self.notice='NO V5 SAVE FOUND' end end)
 self:button(cx-19,y+12,38,5,'HOW TO PLAY','help',function()self.screen='help'end)
 if self.notice~=''then r:text(cx-18,y-3,clip(self.notice,40),15)end
 r:text(cx-17,r.h-2,'V5 | SIMPLE 4X + STORIES',5)
end
function UI:setup()
 local r=self.r;self:space();self:headline('NEW CAMPAIGN','title')
 r:text(3,9,'HUMAN COMMANDERS',6)
 self:button(23,8,8,4,'-','back',function()self.humans=math.max(1,self.humans-1)end)
 r:text(33,10,tostring(self.humans)..' / 4',9)
 self:button(42,8,8,4,'+','next',function()self.humans=math.min(4,self.humans+1)end)
 local y0=15;local rowH=math.min(9,math.max(4,math.floor((r.h-31)/4)))
 for p=1,4 do
  local y=y0+(p-1)*rowH
  r:rect(3,y,r.w-6,rowH-1,1);r:rect(3,y,2,rowH-1,factionColor(p))
  r:text(6,y+1,p<=self.humans and 'HUMAN' or 'AI',p<=self.humans and 9 or 5)
  local buttonX=math.max(15,math.floor(r.w*.20));local fw=math.max(13,math.floor(r.w*.38))
  self:button(buttonX,y,fw,rowH-1,clip(self.names[p],fw-5),'flag',function()self.edit=p;self.screen='keyboard'end)
  self:button(buttonX+fw+1,y,math.max(12,r.w-(buttonX+fw+5)),rowH-1,clip(C.factions[self.arch[p]].trait,14),'star',function()
   self.arch[p]=self.arch[p]%4+1;self.names[p]=C.factions[self.arch[p]].name
  end)
 end
 local footer=r.h-12;r:text(4,footer,'GALACTIC YEARS: '..self.rounds,6)
 self:button(25,footer-2,8,5,'-','back',function()self.rounds=math.max(16,self.rounds-4)end)
 self:button(34,footer-2,8,5,'+','next',function()self.rounds=math.min(28,self.rounds+4)end)
 self:button(r.w-29,footer-2,26,6,'LAUNCH','next',function()self:start()end,nil,19)
 r:text(4,r.h-3,'TAP A NAME TO EDIT OR TRAIT TO CHANGE',5)
end
function UI:keyboard()
 local r=self.r;self:space();self:headline('NAME YOUR EMPIRE','setup')
 r:text(5,9,'EMPIRE '..self.edit..': '..clip(self.names[self.edit],r.w-19),9)
 local letters={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM'}
 local step=math.max(5,math.min(9,math.floor((r.w-9)/10)))
 local y0=math.max(13,math.floor(r.h*.32));local h=math.max(4,math.min(6,math.floor((r.h-y0-10)/4)))
 for row,s in ipairs(letters)do
  local x=math.floor((r.w-#s*step)/2)
  for i=1,#s do local key=s:sub(i,i)
   self:button(x+(i-1)*step,y0+(row-1)*(h+1),step-1,h,key,nil,function()self.names[self.edit]=safeName(self.names[self.edit]..key)end)
  end
 end
 local lastY=y0+3*(h+1)
 self:button(4,lastY,math.floor((r.w-11)/3),5,'SPACE',nil,function()self.names[self.edit]=safeName(self.names[self.edit]..' ')end)
 self:button(5+math.floor((r.w-11)/3),lastY,math.floor((r.w-11)/3),5,'DELETE','close',function()self.names[self.edit]=self.names[self.edit]:sub(1,-2)end)
 self:button(r.w-math.floor((r.w-11)/3)-5,lastY,math.floor((r.w-11)/3),5,'DONE','check',function()
  if self.names[self.edit]=='' then self.names[self.edit]='EMPIRE '..self.edit end;self.screen='setup'
 end)
end
function UI:handoff()
 local r=self.r;self:space();self:headline('NEW COMMAND PHASE')
 local g=self.g;local p=Sim.current(g);local f=g.factions[p];local cx=math.floor(r.w/2)
 r:icon(cx-3,math.floor(r.h*.25),'flag',factionColor(p))
 r:bigText(cx-math.min(#f.name,12),math.floor(r.h*.39),clip(f.name,12),factionColor(p),2)
 r:text(cx-12,math.floor(r.h*.55),'YEAR '..g.round..' OF '..g.limit,6)
 r:text(cx-17,math.floor(r.h*.61),'PASS MONITOR TO COMMANDER',5)
 self:button(cx-20,math.floor(r.h*.70),40,7,'BEGIN TURN','next',function()
  self.screen=(#f.events>0 and 'event') or (f.offers and #f.offers>0 and 'diplomacy') or 'galaxy'
  self.selected=nil;self.shipID=nil;self.page=1
 end,nil,19)
end
function UI:navigate(name)
 self.screen=name;self.page=1;self.notice=''
 if name~='galaxy' then self.selected=nil end
end
function UI:status()
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 r:rect(0,0,r.w,7,1);r:rect(0,6,r.w,1,3)
 r:rect(1,1,2,4,factionColor(p));r:text(5,1,clip(f.name,math.max(6,math.floor(r.w*.27))),7)
 r:text(5,3,'YEAR '..g.round..'/'..g.limit,5)
 local sx=math.max(math.floor(r.w*.35),25)
 local gap=math.floor((r.w-sx-2)/3)
 for i,d in ipairs({{'coin','credits','C',17},{'alloy','alloy','A',9},{'science','knowledge','K',13}})do
  local x=sx+(i-1)*gap
  r:icon(x,2,d[1],d[4]);r:text(x+4,3,d[3]..math.floor(f[d[2]]),7)
 end
end
function UI:dock()
 local r=self.r;local y=r.h-8;r:rect(0,y,r.w,8,1);r:rect(0,y,r.w,1,3)
 local nav={{'GALAXY','star','galaxy'},{'SHIPS','ship','ships'},{'WORLDS','colony','colony'},{'TECH','lab','research'},{'DIPLO','trade','diplomacy'},{'EMPIRE','flag','empire'}}
 local ew=math.max(13,math.floor(r.w*.13));local available=r.w-ew-2;local tabW=math.floor(available/6)
 for i,v in ipairs(nav)do
  local x=1+(i-1)*tabW
  r:rect(x,y+1,tabW-1,6,self.screen==v[3] and 3 or 1)
  r:icon(x+math.floor(tabW/2)-1,y+1,v[2],self.screen==v[3] and 9 or 5)
  local label=clip(v[1],math.max(3,tabW-1));r:text(x+math.max(0,math.floor((tabW-#label)/2)),y+4,label,self.screen==v[3] and 7 or 5,tabW)
  r.buttons[#r.buttons+1]={x=x,y=y+1,w=tabW-1,h=6,label=v[1],fn=function()self:navigate(v[3])end}
 end
 self:button(r.w-ew,y+1,ew-1,6,'END','next',function()self:finishTurn()end,nil,19)
end
function UI:frameScreen()
 self:space();self:status();self:dock()
end
function UI:noticeBar()
 if self.notice=='' then return end
 local r=self.r;local y=r.h-12
 r:rect(1,y,r.w-2,4,3);r:text(3,y+1,clip(self.notice,r.w-6),7)
end
function UI:starPos(s,mapRight)
 local r=self.r;mapRight=mapRight or r.w
 local width=mapRight-10
 return math.floor(5+s.x*width),math.floor(10+s.y*(r.h-25))
end
function UI:starMap(mapRight)
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 mapRight=mapRight or r.w;local selectedShip=self.shipID and Sim.findShip(g,self.shipID)
 r:text(3,8,self.shipID and 'SELECT LINKED DESTINATION' or 'GALAXY / SELECT A STAR',5,math.max(8,mapRight-5))
 for _,e in ipairs(g.links)do
  local a,b=g.systems[e[1]],g.systems[e[2]]
  if f.charted[a.id] or f.charted[b.id] or f.seen[a.id] or f.seen[b.id]then
   local x,y=self:starPos(a,mapRight);local xx,yy=self:starPos(b,mapRight)
   r:line(x,y,xx,yy,3)
  end
 end
 for _,s in ipairs(g.systems)do
  local x,y=self:starPos(s,mapRight);local visible=f.seen[s.id] or s.owner==p;local scanned=f.charted[s.id]
  local col=s.owner==p and factionColor(p) or (s.owner>0 and visible and factionColor(s.owner)) or visible and (s.kind=='RELIC' and 13 or 7) or 4
  local radius=visible and 2 or 1
  r:disc(x,y,radius,col)
  if s.owner~=0 and visible then r:disc(x,y,math.max(1,radius-1),7)end
  if self.selected==s.id then r:disc(x,y,math.min(3,radius+1),9)end
  if selectedShip and Sim.linked(g,selectedShip.location,s.id)then r:rect(x-3,y-3,7,1,19)end
  if visible and r.w>=90 and mapRight>=66 then r:text(x-4,y+3,clip(s.name,9),5)end
  -- Map geometry and hitboxes use the same coordinates. Not added for systems
  -- covered by an inspector, avoiding hidden clickable hotspots.
  local hitW=math.min(7,math.floor((mapRight-10)/6)-1);local hitH=math.max(3,math.min(5,math.floor((r.h-25)/5)-1))
  if hitW>=3 and x-hitW/2>0 and x+hitW/2<mapRight and y-hitH/2>8 and y+hitH/2<r.h-9 then
   r.buttons[#r.buttons+1]={x=math.floor(x-hitW/2),y=math.floor(y-hitH/2),w=hitW,h=hitH,label=s.name,fn=function()
    if self.shipID then self:requestMove(s.id) else self.selected=s.id;self.notice='' end
   end,alt=function()
    -- Inspect while choosing a movement target, without consuming ship orders.
    self.selected=s.id;self.notice=visible and ('INTEL: '..s.name..' / '..s.kind) or 'UNKNOWN SYSTEM - SCOUT TO REVEAL'
   end}
  end
 end
end
function UI:galaxy()
 local r=self.r;local panelW=self.selected and math.min(44,math.floor(r.w*.38)) or 0
 self:starMap(self.selected and r.w-panelW-3 or nil)
 if self.selected then self:inspector(self.g.systems[self.selected],panelW)end
 if self.shipID then self:button(3,r.h-16,20,5,'CANCEL MOVE','close',function()self.shipID=nil;self.notice=''end)end
end
function UI:inspector(s,panelW)
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 local x=r.w-panelW;local y=9;local bottom=r.h-10
 self:box(x,y,panelW-2,bottom-y,1)
 local visible=f.seen[s.id] or s.owner==p
 r:text(x+2,y+2,clip(visible and s.name or 'UNSURVEYED',panelW-10),9);self:button(x+panelW-10,y+1,7,4,'X',nil,function()self.selected=nil;self.notice=''end)
 r:text(x+2,y+5,visible and clip(s.kind..' / '..(s.owner==0 and 'NEUTRAL' or g.factions[s.owner].name),panelW-5) or 'SEND A SCOUT TO REVEAL',5)
 local own=s.owner==p;local buttons={}
 if not visible then buttons={{'UNEXPLORED','scan',function()self.notice='MOVE A SCOUT HERE TO SURVEY THIS SYSTEM'end}}
 elseif own and s.colony then
  buttons={{'DEVELOP','colony',function()self.focusSystem=s.id;self:navigate('colony')end,'Change specialization or upgrade'},
   {'SCOUT C3 A7','scan',function()self:ask('build_ship',{system=s.id,kind='scout'},'LAUNCH SCOUT','Explores connected systems.',C.ships.scout.cost)end},
   {'ARK C5 A12','ark',function()self:ask('build_ship',{system=s.id,kind='ark'},'LAUNCH ARK','Establishes a new colony.',C.ships.ark.cost)end},
   {'FLEET C5 A10','ship',function()self:ask('build_ship',{system=s.id,kind='fleet'},'LAUNCH FLEET','Defends and attacks border systems.',C.ships.fleet.cost)end}}
 elseif own then buttons={{'OWNED OUTPOST','flag',function()self.notice='OUTPOSTS PRODUCE +1 ALLOY PER YEAR' end}}
 elseif s.owner==0 then
  local ark
  for _,sh in ipairs(Sim.shipsAt(g,s.id,p))do if sh.kind=='ark' then ark=sh.id;break end end
  buttons={{'FOUND COLONY','colony',function()
    if ark then self:ask('colonize',{ship=ark},'FOUND COLONY','Consumes this Ark. Adds a specialized world.',{credits=8,alloy=12})
    else self.notice='SEND AN ARK HERE, THEN FOUND A COLONY' end
   end}, {'HOW TO CLAIM','help',function()self.notice='SCOUT, MOVE AN ARK HERE, AND COLONIZE' end}}
 else buttons={{'RIVAL SYSTEM','war',function()self:navigate('diplomacy');self.target=s.owner end}, {'MY FLEETS','ship',function()self:navigate('ships')end}}end
 local pos=y+9;local rowH=5;local max=math.max(1,math.floor((bottom-pos-2)/rowH));local maxPage=math.max(1,math.ceil(#buttons/max))
 self.page=math.max(1,math.min(self.page,maxPage))
 for i=(self.page-1)*max+1,math.min(#buttons,self.page*max)do
  local b=buttons[i];self:button(x+2,pos+((i-1)%max)*rowH,panelW-6,rowH-1,b[1],b[2],b[3])
 end
 if maxPage>1 then
  self:button(x+2,bottom-6,11,4,'PREV','back',function()self.page=math.max(1,self.page-1)end)
  self:button(x+panelW-15,bottom-6,11,4,'NEXT','next',function()self.page=math.min(maxPage,self.page+1)end)
 end
end
function UI:ask(kind,args,title,description,cost)
 local g=self.g;local p=Sim.current(g);local ok,why=Sim.can(g,p,kind,args)
 if not ok then self.notice=why;return false end
 self.pending={kind=kind,args=args,title=title,description=description,cost=cost,returnTo=self.screen}
 self.screen='confirm';self.notice='';return true
end
function UI:requestMove(id)
 local ship=self.shipID
 if not ship then return end
 local sh=Sim.findShip(self.g,ship)
 if sh and sh.location==id then self.notice='SHIP IS ALREADY HERE';return end
 self:ask('move',{ship=ship,system=id},'MOVE '..(sh and sh.name or 'SHIP'),
  'Move to '..self.g.systems[id].name..'. Uses one of this ship\'s two yearly orders.')
end
function UI:confirm()
 local r=self.r;local p=self.pending;if not p then self.screen='galaxy';return end
 self:space();self:headline('CONFIRM ORDER',p.returnTo)
 local x=math.max(3,math.floor(r.w*.14));local w=r.w-2*x;local top=math.floor(r.h*.21)
 self:box(x,top,w,math.max(23,math.floor(r.h*.55)),1)
 r:icon(x+3,top+3,'check',9);r:text(x+7,top+4,clip(p.title,w-10),7)
 self:lines(x+4,top+9,w-8,p.description,6,math.max(3,math.floor(r.h*.17)))
 if p.cost then r:text(x+4,top+15,'COST: '..costText(p.cost),17)end
 self:button(x+3,top+math.max(19,math.floor(r.h*.55)-7),math.floor((w-8)/2),6,'CANCEL','close',function()self.screen=p.returnTo;self.pending=nil end)
 self:button(x+5+math.floor((w-8)/2),top+math.max(19,math.floor(r.h*.55)-7),math.floor((w-8)/2),6,'CONFIRM','check',function()
  local valid,reason=Sim.command(self.g,Sim.current(self.g),p.kind,p.args)
  self.pending=nil;self.shipID=nil;self.screen=p.returnTo
  if valid then self.notice='ORDER COMPLETED';self:save()
   if #self.g.factions[Sim.current(self.g)].events>0 then self.screen='event' end
  else self.notice=reason end
 end,nil,19)
end
function UI:contentPanel(title)
 local r=self.r;self:box(2,9,r.w-4,r.h-19,1)
 r:text(5,11,clip(title,r.w-12),9)
end
function UI:ships()
 local r=self.r;local p=Sim.current(self.g);local own=where(function(s)return s.owner==p end,self.g.ships)
 table.sort(own,function(a,b)return a.id<b.id end)
 self:contentPanel('FLEET REGISTRY / TWO ORDERS PER SHIP')
 local top=15;local rowH=8;local rows=math.max(1,math.floor((r.h-34)/rowH));local pages=math.max(1,math.ceil(#own/rows))
 self.page=math.min(self.page,pages)
 for i=(self.page-1)*rows+1,math.min(#own,self.page*rows)do
  local s=own[i];local y=top+((i-1)%rows)*rowH
  r:rect(5,y,r.w-10,rowH-1,2);r:icon(7,y+2,C.ships[s.kind].icon,9)
  r:text(12,y+1,clip(s.name,18),7)
  r:text(12,y+4,clip(self.g.systems[s.location].name..' | '..s.orders..'/2 ORDERS',32),5)
  self:button(r.w-23,y+1,16,rowH-3,'ORDER','move',function()
   if s.orders<=0 then self.notice='SHIP HAS NO ORDERS THIS YEAR' else self.shipID=s.id;self.screen='galaxy';self.selected=nil end
  end)
  if s.kind=='ark' then self:button(math.max(34,r.w-40),y+1,15,rowH-3,'FOUND','colony',function()
   self:ask('colonize',{ship=s.id},'FOUND COLONY','Spend 8 Credits and 12 Alloy to settle the Ark\'s current system.',{credits=8,alloy=12})
  end)end
 end
 self:paging(pages)
 if #own==0 then self:lines(7,18,r.w-14,'NO SHIPS REMAIN. BUILD NEW ONES FROM YOUR COLONIES.',6,4)end
end
function UI:paging(pages)
 if pages<=1 then return end
 local r=self.r;local y=r.h-17
 self:button(5,y,17,5,'PREVIOUS','back',function()self.page=math.max(1,self.page-1)end)
 r:text(math.floor(r.w/2)-3,y+2,self.page..'/'..pages,6)
 self:button(r.w-22,y,17,5,'NEXT','next',function()self.page=math.min(pages,self.page+1)end)
end
function UI:colony()
 local r=self.r;local g=self.g;local p=Sim.current(g)
 local owned=where(function(s)return s.owner==p and s.colony end,g.systems)
 self:contentPanel('YOUR WORLDS / CHOOSE ONE SPECIALIZATION')
 if #owned==0 then return end
 local idx=1;for i,s in ipairs(owned)do if s.id==self.focusSystem then idx=i end end
 idx=math.min(#owned,math.max(1,idx));local s=owned[idx];self.focusSystem=s.id
 r:text(6,17,clip(s.name..' / '..s.kind,r.w-22),7)
 r:text(6,20,'FOCUS: '..(s.focus or 'NONE')..'  LEVEL '..s.level..'/3',9)
 self:button(r.w-29,16,11,5,'<','back',function()self.focusSystem=owned[(idx-2)%#owned+1].id end)
 self:button(r.w-16,16,11,5,'>','next',function()self.focusSystem=owned[idx%#owned+1].id end)
 if r.h<65 then
  local tileW=math.floor((r.w-14)/3)
  for i,type in ipairs({'industry','science','commerce'})do
   local focus=C.focus[type]
   self:button(5+(i-1)*(tileW+1),25,tileW,6,focus.name:sub(1,3),focus.icon,function()
    self:ask('focus',{system=s.id,focus=type},'SPECIALIZE '..focus.name,focus.description,focus.cost)
   end)
  end
 else
  local y=25;local rowH=math.min(10,math.max(6,math.floor((r.h-52)/3)))
  for i,type in ipairs({'industry','science','commerce'})do
   local focus=C.focus[type];local yy=y+(i-1)*(rowH+1)
   if yy+rowH>=r.h-10 then break end
   r:rect(5,yy,r.w-10,rowH,2);r:rect(5,yy,2,rowH,s.focus==type and 9 or 4)
   r:icon(8,yy+2,focus.icon,9)
   r:text(13,yy+1,focus.name..(s.focus==type and ' [ACTIVE]' or ''),7)
   r:text(13,yy+3,clip(focus.description,r.w-49),5)
   self:button(r.w-25,yy+1,19,math.min(rowH-2,5),'CHOOSE','check',function()
    self:ask('focus',{system=s.id,focus=type},'SPECIALIZE '..focus.name,focus.description,focus.cost)
   end)
  end
 end
 self:button(5,r.h-17,math.min(51,r.w-10),6,'UPGRADE COLONY C9 A8','forge',function()
  self:ask('upgrade',{system=s.id},'DEVELOP '..s.name,'Increases specialty production by 2 per year. Maximum level is 3.',{credits=9,alloy=8})
 end)
end
function UI:research()
 local r=self.r;local f=self.g.factions[Sim.current(self.g)]
 self:contentPanel('RESEARCH / THREE PATHS')
 local paths={{'exploration','scan'},{'prosperity','trade'},{'warfare','shield'}}
 local top=17;local spacing=math.floor((r.h-36)/3)
 for i,d in ipairs(paths)do
  local path,icon=d[1],d[2];local level=f.tech[path];local tech=C.tech[path][level+1];local y=top+(i-1)*spacing
  r:rect(5,y,r.w-10,spacing-2,2)
  r:icon(7,y+2,icon,9);r:text(12,y+1,path:upper()..' '..level..'/3',7)
  if tech then
   r:text(12,y+3,clip(tech.name,r.w-42),9)
   r:text(12,y+5,clip(tech.description,r.w-43),5)
   self:button(r.w-26,y+1,20,math.max(4,math.min(7,spacing-4)),'LEARN K'..tech.cost,'science',function()
    self:ask('research',{path=path},tech.name,tech.description,{knowledge=tech.cost})
   end)
  else r:text(12,y+3,'PATH COMPLETE',19)end
 end
end
function UI:diplomacy()
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 self:contentPanel('DIPLOMACY / EVERY EMPIRE HAS AN AGENDA')
 if f.offers and #f.offers>0 then
  local offer=f.offers[1];self:box(5,16,r.w-10,16,2)
  r:text(8,18,clip('INCOMING: '..g.factions[offer.from].name,r.w-18),17)
  r:text(8,21,clip('PROPOSES '..offer.kind,r.w-18),6)
  self:button(8,25,20,5,'DECLINE','close',function()Sim.command(g,p,'reply',{accept=false});self:save()end)
  self:button(30,25,20,5,'ACCEPT','check',function()Sim.command(g,p,'reply',{accept=true});self:save()end)
  return
 end
 local other={};for i=1,4 do if i~=p then other[#other+1]=i end end
 local y=16;local colW=math.max(15,math.floor((r.w-16)/3))
 for i,q in ipairs(other)do
  local x=5+(i-1)*(colW+3)
  r:rect(x,y,colW,11,q==self.target and 3 or 2)
  r:rect(x,y,colW,2,factionColor(q))
  r:text(x+2,y+3,clip(g.factions[q].name,colW-4),7)
  r:text(x+2,y+5,'TRUST '..Sim.relation(g,p,q),6)
  self:button(x+2,y+7,colW-4,4,'OPEN','trade',function()self.target=q end)
 end
 if self.target==p then self.target=other[1]end
 local target=self.target;local targetF=g.factions[target]
 r:text(6,30,'NEGOTIATING WITH '..clip(targetF.name,r.w-23),9)
 local choices={
  {'TRADE C3','trade','pact','trade',C.pacts.trade.desc},
  {'NON-AGGRESSION C3','shield','pact','nonaggression',C.pacts.nonaggression.desc},
  {'ALLIANCE C3','council','pact','alliance',C.pacts.alliance.desc},
  {Sim.atWar(g,p,target) and 'PEACE OFFER' or 'DECLARE WAR C5','war',Sim.atWar(g,p,target)and'peace'or'war',nil,'War allows Fleet attacks on rival territory.'}
 }
 local row=math.max(5,math.min(9,math.floor((r.h-47)/4)))
 for i,c in ipairs(choices)do
  local yy=34+(i-1)*row;if yy+5>=r.h-9 then break end
  self:button(6,yy,math.min(r.w-12,math.max(39,math.floor(r.w*.48))),row-1,c[1],c[2],function()
   local action=c[3];local args={to=target,kind=c[4]}
   self:ask(action,args,c[1],c[5],action=='war' and {credits=5} or action=='peace' and nil or {credits=3})
  end,c[5])
  if r.w>92 then
   local status=c[3]=='pact' and (Sim.hasPact(g,p,target,c[4]) and 'ACTIVE' or 'AVAILABLE') or ''
   r:text(math.floor(r.w*.62),yy+2,status,5)
  end
 end
end
function UI:event()
 local r=self.r;local f=self.g.factions[Sim.current(self.g)];local ev=f.events[1]
 if not ev then self.screen='galaxy';return end
 self:space();self:headline('STORY EVENT')
 local panelX=4;local width=r.w-8;self:box(panelX,9,width,r.h-13,1)
 r:icon(7,13,'orbit',13);r:text(12,14,clip(ev.title,width-16),13)
 local bodyStart=19;local summaryRows=self:lines(8,bodyStart,width-10,ev.body,6,math.max(3,math.floor(r.h*.17)))
 local start=bodyStart+summaryRows+3;local choiceH=math.max(6,math.min(10,math.floor((r.h-7-start)/#ev.choices)))
 for i,choice in ipairs(ev.choices)do
  local y=start+(i-1)*choiceH
  if y+choiceH>r.h-3 then break end
  self:button(7,y,width-6,choiceH-1,i..'. '..choice.title,'council',function()
   local ok,why=Sim.command(self.g,Sim.current(self.g),'choose',{choice=i})
   if ok then self:save();self.screen=(#f.events>0 and 'event')or'galaxy';self.notice='COUNCIL DECISION RECORDED'
   else self.notice=why end
  end,choice.detail,13)
 end
end
function UI:empire()
 local r=self.r;local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 self:contentPanel('CIVILIZATION / YOUR LEGACY')
 local inc=Sim.income(g,p)
 r:text(6,16,clip(f.name..' / '..C.factions[f.archetype].trait,r.w-13),7)
 r:text(6,20,'SYSTEMS '..Sim.owned(g,p)..'/30  COLONIES '..Sim.colonies(g,p)..'  SCORE '..Sim.score(g,p),9)
 r:text(6,24,'ANNUAL INCOME',5)
 r:text(7,27,'C +'..inc.credits..'   A +'..inc.alloy..'   K +'..inc.knowledge,7)
 local progress=Sim.winProgress(g,p)
 if r.h<65 then
  r:text(6,31,'DISCOVERY '..f.tech.exploration..'/3',6)
  r:text(26,31,'UNITY '..progress.alliances..'/2',6)
  r:text(45,31,'DOMINION '..progress.dominion..'/15',6)
  self:button(6,37,math.floor((r.w-16)/2),5,'DISCOVERY','science',function()
   self:ask('project',{kind='discovery'},'ANCIENT ARCHIVE','Requires Exploration III, 14 surveyed stars, 3 ancient clues, 3 colonies; then a three-year project.',{credits=25,alloy=15,knowledge=18})
  end)
  self:button(8+math.floor((r.w-16)/2),37,math.floor((r.w-16)/2),5,'UNITY','trade',function()
   self:ask('project',{kind='unity'},'GALACTIC ACCORD','Requires Prosperity II, two alliances and 4 colonies; then a three-year project.',{credits=30,alloy=12,knowledge=12})
  end)
 else
  r:text(6,32,'THREE PATHS TO VICTORY',9)
  r:text(7,36,'DISCOVERY '..f.tech.exploration..'/3 + '..(f.clues or 0)..' CLUES / 3',6)
  r:text(7,40,'UNITY '..progress.alliances..'/2 ALLIANCES + PROJECT',6)
  r:text(7,44,'DOMINION '..progress.dominion..'/15 SYSTEMS',6)
  if f.project then r:text(7,48,'PROJECT '..f.project.type:upper()..' '..f.project.progress..'/2 YEARS',19)end
  local y=math.min(r.h-18,54)
  self:button(6,y,math.min(42,r.w-12),5,'DISCOVERY PROJECT','science',function()
   self:ask('project',{kind='discovery'},'ANCIENT ARCHIVE','Requires Exploration III, 14 surveyed stars, 3 ancient clues, 3 colonies; then a three-year project.',{credits=25,alloy=15,knowledge=18})
  end)
  self:button(math.min(50,math.floor(r.w*.49)),y,math.min(40,math.floor(r.w*.44)),5,'UNITY PROJECT','trade',function()
   self:ask('project',{kind='unity'},'GALACTIC ACCORD','Requires Prosperity II, two alliances and 4 colonies; then a three-year project.',{credits=30,alloy=12,knowledge=12})
  end)
 end
 if r.h>78 then
  r:text(6,r.h-24,'YOUR RECENT HISTORY',5)
  for i=1,math.min(2,#g.log)do r:text(7,r.h-23+i*2,clip(g.log[i],r.w-14),6)end
 end
end
function UI:finishTurn()
 local g=self.g;local p=Sim.current(g);local f=g.factions[p]
 if #f.events>0 then self.screen='event';return end
 if f.offers and #f.offers>0 then self.screen='diplomacy';return end
 local income=Sim.income(g,p);local completed=g.round
 local success,reason=Sim.endTurn(g,p)
 if not success then self.notice=reason;return end
 Sim.advanceAI(g);self.recentIncome={credits=income.credits,alloy=income.alloy,knowledge=income.knowledge,year=completed}
 self.screen=g.ended and 'results' or 'summary';self.selected=nil;self.shipID=nil;self:save()
end
function UI:summary()
 local r=self.r;self:space();self:headline('COUNCIL REPORT')
 local inc=self.recentIncome or {credits=0,alloy=0,knowledge=0,year=math.max(1,self.g.round-1)}
 self:box(4,10,r.w-8,r.h-17,1)
 r:text(8,15,'GALACTIC YEAR '..inc.year..' COMPLETE',9)
 r:text(8,20,'YEARLY PRODUCTION',6)
 r:text(8,24,'CREDITS +'..inc.credits,17)
 r:text(8,28,'ALLOY +'..inc.alloy,9)
 r:text(8,32,'KNOWLEDGE +'..inc.knowledge,13)
 local y=math.min(r.h-23,39);r:text(8,y,'GALACTIC NEWS',5)
 for i=1,math.min(3,#self.g.log)do r:text(8,y+2*i,clip(self.g.log[i],r.w-18),6)end
 self:button(math.floor((r.w-46)/2),r.h-13,46,7,'PASS TO NEXT COMMANDER','next',function()
  self.screen=self.g.ended and 'results' or 'handoff';self.notice=''
 end,nil,19)
end
function UI:results()
 local r=self.r;self:space();self:headline('THE GALAXY HAS CHOSEN')
 local g=self.g;local winner=g.factions[g.winner or 1];local cx=math.floor(r.w/2)
 r:icon(cx-3,r.h<68 and 9 or 13,'trophy',17)
 r:bigText(cx-13,r.h<68 and 15 or 23,clip(winner.name,r.h<68 and 11 or 15),9,r.h<68 and 1 or 2)
 r:text(cx-18,r.h<68 and 24 or 36,'VICTORY BY '..(g.winReason or 'LEGACY'),17)
 local ranks={1,2,3,4};table.sort(ranks,function(a,b)return Sim.score(g,a)>Sim.score(g,b)end)
 for i,p in ipairs(ranks)do
  r:text(cx-22,(r.h<68 and 25 or 40)+i*(r.h<68 and 3 or 5),i..'. '..clip(g.factions[p].name,17),factionColor(p))
  r:text(cx+10,(r.h<68 and 25 or 40)+i*(r.h<68 and 3 or 5),tostring(Sim.score(g,p)),7)
 end
 self:button(cx-22,math.min(r.h-12,66),44,6,'NEW CAMPAIGN','star',function()self.screen='setup';self.g=nil end,nil,19)
end
function UI:help()
 local r=self.r;self:space();self:headline('HOW TO PLAY','title')
 self:box(3,9,r.w-6,r.h-13,1)
 local blocks={
  '1. EXPLORE: SEND SCOUTS ALONG LINKED STARS. EACH SHIP HAS TWO ORDERS PER YEAR.',
  '2. COLONIZE: MOVE AN ARK TO A SCOUTED NEUTRAL STAR NEXT TO YOUR BORDERS. FOUND A COLONY WITH CREDITS AND ALLOY.',
  '3. SPECIALIZE: WORLDS PRODUCE INDUSTRY, SCIENCE OR COMMERCE. CHANGE THEIR FOCUS OR UPGRADE THEM.',
  '4. RESEARCH: SPEND KNOWLEDGE ON EXPLORATION, PROSPERITY OR WARFARE. NO EMPIRE ACTION CAP.',
  '5. DIPLOMACY: SIGN TRADE, NON-AGGRESSION OR ALLIANCE PACTS. FLEETS ONLY FIGHT WHEN YOU ARE AT WAR.',
  '6. STORIES: COUNCIL DECISIONS GRANT RESOURCES, CHANGE TRUST AND MAY START LATER EVENTS.',
  '7. WIN: COMPLETE DISCOVERY OR UNITY PROJECTS, HOLD 15 SYSTEMS, OR LEAD THE LEGACY SCORE AT YEAR END.'}
 local y=13;for i,t in ipairs(blocks)do
  local count=self:lines(7,y,r.w-14,t,i%2==0 and 5 or 6,4)
  y=y+count+2;if y>r.h-17 then break end
 end
 self:button(math.floor(r.w/2)-17,r.h-10,34,6,'NEW CAMPAIGN','next',function()self.screen='setup'end)
end
function UI:draw()
 local r=self.r;r:beginFrame();self.frame=self.frame+1;r:resize()
 if self.screen=='title' then self:title()
 elseif self.screen=='setup' then self:setup()
 elseif self.screen=='keyboard' then self:keyboard()
 elseif self.screen=='handoff' then self:handoff()
 elseif self.screen=='confirm' then self:confirm()
 elseif self.screen=='event' then self:event()
 elseif self.screen=='summary' then self:summary()
 elseif self.screen=='results' then self:results()
 elseif self.screen=='help' then self:help()
 elseif self.g then
  self:frameScreen()
  if self.screen=='galaxy' then self:galaxy()
  elseif self.screen=='ships' then self:ships()
  elseif self.screen=='colony' then self:colony()
  elseif self.screen=='research' then self:research()
  elseif self.screen=='diplomacy' then self:diplomacy()
  elseif self.screen=='empire' then self:empire()end
  self:noticeBar()
 end
 r:endFrame()
end
function UI:touch(x,y)return self.r:hit(x,y)end
-- Companion NeoForge mod sends zero-to-one normalized monitor coordinates.
-- They deliberately differ from CC: Graphics' zero-based pixel monitor_touch.
function UI:monitorLeftTouch(nx,ny)
 if type(nx)~='number' or type(ny)~='number' or nx<0 or nx>=1 or ny<0 or ny>=1 then return false end
 local x=math.floor(nx*self.r.w);local y=math.floor(ny*self.r.h)
 return self.r:hitSecondary(x,y)
end
function UI:monitorTouch(x,y)
 local r=self.r;if type(x)~='number' or type(y)~='number'then return false end
 if r.kind=='gfx' then
  if x<0 or y<0 or x>=r.w*r.px or y>=r.h*r.py then return false end
  x=math.floor(x/r.px)+1;y=math.floor(y/r.py)+1
 end
 if x<1 or y<1 or x>r.w or y>r.h then return false end
 return self:touch(x-1,y-1)
end
function UI:loop(name)
 self:draw();local timer=os.startTimer(.8)
 while true do
  local ev,a,b,c=os.pullEvent()
  if ev=='monitor_touch' and (not name or a==name)then self:monitorTouch(b,c);self:draw()
  elseif ev=='monitor_left_click' and (not name or a==name) then self:monitorLeftTouch(b,c);self:draw()
  elseif ev=='monitor_resize' and (not name or a==name) then self.r:resize();self:draw()
  elseif ev=='timer' and a==timer then self:draw();timer=os.startTimer((self.screen=='title' or self.screen=='galaxy') and .85 or 1.8)
  elseif ev=='char' and self.screen=='keyboard' then self.names[self.edit]=safeName(self.names[self.edit]..a);self:draw()
  elseif ev=='key' and self.screen=='keyboard' and keys and a==keys.backspace then self.names[self.edit]=self.names[self.edit]:sub(1,-2);self:draw()
  end
 end
end
return UI