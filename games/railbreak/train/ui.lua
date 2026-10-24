local C=require('train.catalog')
local S=require('train.state')
local Rules=require('train.rules')
local R=require('train.render')
local Art=require('train.art')
local Disk=require('train.storage')
local U=require('core.util')
local Info=require('train.info')
local UI={};UI.__index=UI
local function first(text,n)return tostring(text or ''):sub(1,n or 18)end
function UI.new(m,opt)
 local self=setmetatable({r=R.new(m),g=opt and opt.game or nil,scene='title',frame=0,toast='',page=1,
  selected=1,selectedWagon=2,marketSide='buy',difficulty='standard',players=1,
  names={'','','',''},editing=nil,helpPage=1,info=nil,infoPage=1},UI)
 if self.g then self.scene='hub' end
 return self
end
function UI:notify(message)self.toast=tostring(message or '') end
function UI:save()if self.g then local yes,err=Disk.save(self.g);if not yes and fs then self:notify('SAVE ERROR '..tostring(err))end end end
function UI:act(method,...)
 local ok,message=Rules[method](self.g,...)
 self:notify(message)
 if ok then
  self:save()
  if self.g.finished then self.scene='results'
  elseif self.g.pending then self.scene='travel'
  elseif method=='resolve' or method=='depart' then self.scene='hub' end
 end
 return ok,message
end
-- Inspecting is free, does not advance turns or touch the save file.
function UI:inspect(kind,id,extra)
 self.info=Info.describe(self.g,kind,id,extra)
 self.infoPage=1
end
function UI:details()
 local r=self.r;local w,h=r.w,r.h;local i=self.info
 -- A full opaque overlay: old hotspots are removed to prevent click-through.
 r.buttons={};r:fill(0,0,w,h,0)
 r:fill(5,5,w-10,h-10,1);r:outline(5,5,w-10,h-10,9)
 r:fill(7,7,w-14,20,2);r:icon(i.icon or 'parts',12,12,1)
 r:text(27,13,i.title,8,1,w-61)
 r:button(w-34,9,23,15,'X',function()self.info=nil end)
 local stride=r.mode=='graphics' and 4 or 2
 local lines=Info.wrap(i.lines,math.floor((w-34)/stride))
 local lh=r.mode=='graphics' and 9 or 10
 local top=34;local bottom=h-63
 local per=math.max(2,math.floor((bottom-top)/lh))
 local pages=math.max(1,math.ceil(#lines/per))
 self.infoPage=math.max(1,math.min(self.infoPage,pages))
 for k=1,per do
  local line=lines[(self.infoPage-1)*per+k]
  if line then r:text(13,top+(k-1)*lh,line,k==1 and 7 or 6,1,w-28)end
 end
 if pages>1 then
  r:button(11,h-60,48,17,'< PREV',function()self.infoPage=math.max(1,self.infoPage-1)end)
  r:text(math.floor(w/2)-14,h-56,self.infoPage..' / '..pages,8)
  r:button(w-59,h-60,48,17,'NEXT >',function()self.infoPage=math.min(pages,self.infoPage+1)end)
 end
 local by=h-32
 local bw=math.floor((w-33)/2)
 r:button(11,by,i.action and bw or w-22,21,'BACK',function()self.info=nil end)
 if i.action then
  r:button(17+bw,by,w-28-bw,21,i.actionLabel or 'CONFIRM',function()
   local method,args=i.action,i.args or {}
   self.info=nil
   self:act(method,table.unpack(args))
  end,{primary=true})
 end
end
function UI:go(scene)
 self.info=nil
 if self.g and self.g.pending and scene~='title' and scene~='travel' then scene='travel' end
 if scene=='travel' and not(self.g and self.g.pending)then scene='map' end
 self.scene=scene;self.page=1;self.toast=''
end
function UI:newGame()
 local seed=math.floor(tonumber(os.epoch and os.epoch('utc') or os.time()) or 48819)%2147483647
 self.g=S.new({count=self.players,names=self.names,difficulty=self.difficulty,seed=seed})
 self.scene='hub';self.selected=1;self.selectedWagon=2;self.page=1
 self:save();self:notify('READY. CHOOSE A RAILWAY ROUTE.')
end
function UI:resume()
 local g=Disk.load();if not g then self:notify('NO SAVED TRAIN EXPEDITION') return end
 self.g=g;self.scene=g.finished and 'results' or g.pending and 'travel' or 'hub';self.page=1
 self:notify('EXPEDITION RESTORED')
end
-- Compact layouts depend on physical monitor dimensions, not on the
-- graphics renderer's virtual resolution (which can change independently).
function UI:small()return self.r.cw<100 or self.r.ch<65 end
function UI:header(title,sub)
 local r=self.r;local w=r.w
 r:fill(0,0,w,20,0);r:fill(0,19,w,1,9)
 r:icon('train',4,4,1);r:text(19,4,title,8,1,w-(self.g and #self.g.players>1 and 78 or 49))
 -- Context help is always a one-tap question mark, even on compact displays.
 r:button(w-23,3,18,15,'?',function()self:inspect('topic',self.scene)end)
 if self.toast~='' then r:text(19,12,self.toast,8,1,w-24)
 elseif sub and not self:small() then r:text(19,12,sub,5,1,w-24)end
 if self.g and #self.g.players>1 then
  local x=w-55;r:fill(x,3,26,12,12);r:text(x+4,6,'P'..self.g.currentPlayer,7)
  r.buttons[#r.buttons+1]={x=x,y=3,w=26,h=12,label='CREW',fn=function()
   self.g.currentPlayer=self.g.currentPlayer%#self.g.players+1;self:save()
  end}
 end
end
function UI:panel(x,y,w,h,title)
 local r=self.r;r:fill(x,y,w,h,1);r:outline(x,y,w,h,4)
 if title then r:fill(x+1,y+1,w-2,12,2);r:text(x+5,y+3,title,8,1,w-9)end
end
function UI:footer(entries)
 local r=self.r;local w,h=r.w,r.h;local y=h-24
 r:fill(0,y,w,24,0);r:fill(0,y,w,1,9)
 local bw=math.floor((w-4)/#entries)
 for i,b in ipairs(entries)do
  local x=2+(i-1)*bw
  r:button(x,y+3,bw-2,19,b[2],function()self:go(b[1])end,{selected=self.scene==b[1]})
 end
end
function UI:foot()
 self:footer({{'hub','TRAIN'},{'map','MAP'},{'station','STOP'},{'contracts','JOBS'},{'help','HELP'}})
end
function UI:status()
 if self.toast=='' then return end
 local r=self.r;local h=r.h;local y=h-35
 r:fill(2,y,r.w-4,11,0);r:text(5,y+2,first(self.toast,math.floor((r.w-11)/4)),8)
end
function UI:resourceStrip()
 local r=self.r;local g=self.g
 local y=21;local content={{'coin',g.coins},{'coal',g.fuel..'/'..g.maxFuel},{'wrench',g.hull},{'star',g.reputation}}
 local boxWidth=math.floor((r.w-8)/4)
 for i,v in ipairs(content)do
  local x=3+(i-1)*boxWidth
  r:fill(x,y,boxWidth-2,16,2)
  r:icon(v[1],x+3,y+3,1)
  r:text(x+15,y+5,v[2],7,1,boxWidth-16)
  local kind=({'coins','fuel','hull','reputation'})[i]
  r.buttons[#r.buttons+1]={x=x,y=y,w=boxWidth-2,h=16,label='INFO '..kind,fn=function()self:inspect('resource',kind)end}
 end
end
function UI:title()
 local r=self.r;local w,h=r.w,r.h
 Art.train(r,0,0,w,h*.74,{{id='engine'},{id='cargo'},{id='passenger'},{id='crane'}},self.frame)
 r:fill(0,1,w,30,0);r:center(5,'RAILBREAK',8,2)
 r:center(23,'KINETIC FRONTIER',6,1)
 local by=h-58;local small=self:small()
 if small then
  r:button(6,by,w-12,16,'NEW EXPEDITION',function()self:go('setup')end,{primary=true})
  r:button(6,by+19,math.floor((w-16)/2),16,'CONTINUE',function()self:resume()end)
  r:button(10+math.floor((w-16)/2),by+19,math.floor((w-16)/2),16,'HELP',function()self:go('help')end)
 else
  r:button(12,by,w-24,18,'NEW EXPEDITION',function()self:go('setup')end,{primary=true})
  r:button(12,by+22,math.floor((w-28)/2),18,'CONTINUE',function()self:resume()end)
  r:button(16+math.floor((w-28)/2),by+22,math.floor((w-28)/2),18,'HELP',function()self:go('help')end)
 end
end
function UI:keyboard()
 local r=self.r;local w,h=r.w,r.h;local rows={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM'}
 local top=math.max(66,h-85)
 r:fill(4,top-15,w-8,87,0);r:text(8,top-11,'NAME: '..first(self.names[self.editing],13),8)
 for row,line in ipairs(rows)do
  local bw=math.floor((w-14)/#line)
  local x=7+math.floor((w-14-#line*bw)/2)
  for j=1,#line do
   local key=line:sub(j,j)
   r:button(x+(j-1)*bw,top+(row-1)*15,bw-1,13,key,function()
    self.names[self.editing]=first(self.names[self.editing]..key,12)
   end)
  end
 end
 r:button(8,top+47,math.floor((w-22)/2),17,'DELETE',function()local s=self.names[self.editing];self.names[self.editing]=s:sub(1,-2)end)
 r:button(14+math.floor((w-22)/2),top+47,math.floor((w-22)/2),17,'DONE',function()self.editing=nil end,{primary=true})
end
function UI:setup()
 local r=self.r;local w,h=r.w,r.h;self:header('NEW EXPEDITION','SINGLE OR SHARED SCREEN')
 if self.editing then self:keyboard();return end
 local compact=self:small()
 r:button(9,25,29,16,'-',function()self.players=math.max(1,self.players-1)end)
 r:text(43,30,self.players..' PLAYER'..(self.players==1 and '' or 'S'),8,1,w-89)
 r:button(w-38,25,29,16,'+',function()self.players=math.min(4,self.players+1)end)
 local start=compact and 46 or 52;local step=compact and 13 or 17
 for i=1,self.players do
  r:button(10,start+(i-1)*step,w-20,compact and 12 or 15,
   'P'..i..': '..(self.names[i]=='' and 'TAP TO NAME' or self.names[i]),function()self.editing=i end)
 end
 local dy=compact and 102 or math.max(start+self.players*step+5,145)
 r:button(10,dy,w-20,15,'MODE: '..self.difficulty:upper(),function()
  self.difficulty=({explorer='standard',standard='frontier',frontier='explorer'})[self.difficulty]
 end)
 r:button(8,h-42,w-16,18,'BEGIN JOURNEY',function()self:newGame()end,{primary=true})
 r:button(8,h-22,w-16,17,'BACK',function()self:go('title')end)
end

function UI:hub()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header(C.stations[g.location].short,'THE CLOCKWORK RAILWAY')
 self:resourceStrip()
 local y=40;local height=h-y-63
 local taps=Art.train(r,3,y,w-6,height,g.wagons,self.frame)
 for i,box in ipairs(taps)do
  local idx=i
  r.buttons[#r.buttons+1]={x=box.x,y=box.y,w=box.w,h=box.h,label='WAGON',fn=function()self.selectedWagon=idx;self:go('train')end}
 end
 local by=h-45
 r:fill(3,by,w-6,19,1)
 r:icon('station',7,by+4,1);r:text(22,by+5,'STOP '..C.stations[g.location].short,7,1,w-30)
 r:button(w-62,by-22,58,18,'TRAVEL >',function()self:go('map')end,{primary=true})
 self:foot()
end
function UI:map()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header('RAILWAY MAP','SELECT A CONNECTED STATION')
 local y=22;local mapH=h-82
 Art.sky(r,4,y,w-8,mapH,0)
 for _,edge in ipairs(C.edges)do
  local a,b=C.stations[edge[1]],C.stations[edge[2]]
  local x1=8+a.x*(w-24);local x2=8+b.x*(w-24)
  local y1=y+6+a.y*(mapH-15);local y2=y+6+b.y*(mapH-15)
  local c=g.built[S.edgeKey(edge[1],edge[2])] and 8 or 6
  r:line(x1,y1,x2,y2,c)
 end
 for _,s in ipairs(C.stations)do
  local x,py=8+s.x*(w-24),y+6+s.y*(mapH-15)
  r:fill(x-5,py-5,11,11,s.id==g.location and 11 or s.id==self.selected and 8 or 1)
  r:outline(x-5,py-5,11,11,8)
  r:fill(x-2,py-2,5,5,s.id==g.location and 7 or 13)
  if r.cw>=100 and r.ch>=65 then r:text(x-12,py+7,s.short,7,1,72)end
  r.buttons[#r.buttons+1]={x=x-12,y=py-12,w=24,h=24,label=s.short,fn=function()self.selected=s.id end}
 end
 local sy=h-60;local station=C.stations[self.selected]
 r:fill(2,sy,w-4,34,1)
 r:text(7,sy+3,station.short,self.selected==g.location and 11 or 8,1,w-15)
 local edge=S.edge(g.location,self.selected)
 if edge then
  local key=S.edgeKey(g.location,self.selected)
  local fuel=Rules.fuelCost(g,edge);local track=g.built[key] and 0 or edge[4]
  local ready=g.fuel>=fuel and g.cargo.parts>=track
  r:text(7,sy+14,'FUEL '..fuel..'/'..g.fuel..'  PARTS '..track..'/'..g.cargo.parts,6,1,w-82)
  r:text(7,sy+25,ready and (track==0 and 'TRACK READY' or 'CAN BUILD & TRAVEL') or 'SUPPLIES NEEDED',ready and 11 or 10,1,w-16)
  r:button(w-69,sy+14,65,17,'DETAILS',function()self:inspect('route',self.selected)end,{primary=true})
  if g.upgrades.brass then
   local evt=C.events[((g.seed+(g.trips+1)*7+self.selected*3)%#C.events)+1]
   if ready then r:text(7,sy+25,g.trips%2==0 and ('FORECAST '..evt.name) or 'CLEAR TRACK',11,1,w-12)end
  end
 elseif self.selected==g.location then r:text(7,sy+14,'CURRENT STATION',6)
 else r:text(7,sy+14,'NO DIRECT RAIL CONNECTION',10,1,w-12)end
 self:foot()
end
function UI:station()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;local st=C.stations[g.location]
 self:header(st.short,'STATION & SERVICES')
 local top=21;local artH=math.min(80,math.floor((h-48)*.41))
 Art.station(r,3,top,w-6,artH,st,self.frame)
 local start=top+artH+3
 local cols=2;local gap=4;local bw=math.floor((w-14-gap)/2)
 local entries={{'MARKET','market','box'},{'MODULES','modules','press'},{'CONTRACTS','contracts','contract'},
  {'REPAIR 12C','repair','wrench'},{'FUEL 9C','refuel','coal'},{'RUN SHIFT','shift','parts'}}
 local bh=math.max(13,math.floor((h-30-start-8)/3))
 for i,e in ipairs(entries)do
  local x=5+(i-1)%2*(bw+gap);local y=start+math.floor((i-1)/2)*(bh+4)
  r:button(x,y,bw,bh,e[1],function()
   if e[2]=='repair' or e[2]=='refuel' or e[2]=='shift' then self:inspect('service',e[2])
   else self:go(e[2])end
  end,{primary=e[2]=='shift'})
  local hint=({repair='+25 HULL',refuel='+4 FUEL',shift='1 TURN',market='BUY / SELL',modules='PRODUCE',contracts='DELIVERIES'})[e[2]]
  if bh>=25 then r:text(x+5,y+bh-8,hint,5,1,bw-9)end
 end
 self:foot()
end
function UI:modules()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header('STATION MODULES','SIMPLE PRODUCTION / UPGRADES')
 local y=24;local cols=not self:small() and w>=208 and 3 or 2;local rows=math.ceil(#C.modules/cols)
 local gap=4;local bw=math.floor((w-14-(cols-1)*gap)/cols)
 local bh=math.floor((h-53-y-(rows-1)*gap)/rows)
 local current=g.stations[g.location].modules
 for i,spec in ipairs(C.modules)do
  local x=7+((i-1)%cols)*(bw+gap);local yy=y+math.floor((i-1)/cols)*(bh+gap)
  local level=current[spec.id] or 0
  r:fill(x,yy,bw,bh,2);r:outline(x,yy,bw,bh,4)
  r:icon(spec.icon,x+6,yy+5,1)
  r:text(x+19,yy+5,first(spec.name,math.floor((bw-23)/4)),7,1,bw-22)
  if bh>=38 then r:text(x+5,yy+17,spec.desc,6,1,bw-10)end
  if not self:small() then r:text(x+5,yy+33,'LV '..level..'/3  '..(spec.cost+level*25)..' COINS',level>0 and 11 or 8,1,bw-10)end
  if self:small() then
   r:text(x+5,yy+(bh>=38 and 29 or 16),'LV'..level..'/3  '..(spec.cost+level*25)..'C',level>0 and 11 or 8,1,bw-10)
   r.buttons[#r.buttons+1]={x=x,y=yy,w=bw,h=bh,label=spec.name,fn=function()self:inspect('module',spec.id)end}
  else
   r:button(x+4,yy+bh-16,bw-8,13,'UP '..(spec.cost+level*25),function()self:inspect('module',spec.id)end,{selected=level>0})
  end
 end
 self:foot()
end
function UI:market()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header('STATION MARKET','BUY / SELL GOODS')
 local top=23;local tabW=math.floor((w-21)/2)
 r:button(7,top,tabW,16,'BUY',function()self.marketSide='buy' end,{selected=self.marketSide=='buy'})
 r:button(14+tabW,top,tabW,16,'SELL',function()self.marketSide='sell' end,{selected=self.marketSide=='sell'})
 local cols=not self:small() and w>=210 and 4 or 2
 local rows=2;local count=cols*rows;local pages=math.ceil(#C.goods/count)
 self.page=math.max(1,math.min(self.page,pages))
 local gap=4;local bw=math.floor((w-14-(cols-1)*gap)/cols)
 local gridTop=top+20;local bh=math.floor((h-gridTop-48-gap)/rows)
 for j=1,count do
  local spec=C.goods[(self.page-1)*count+j];if spec then
   local x=7+((j-1)%cols)*(bw+gap);local yy=gridTop+math.floor((j-1)/cols)*(bh+gap)
   r:fill(x,yy,bw,bh,2);r:outline(x,yy,bw,bh,4)
   r:icon(spec.icon,x+5,yy+5,1)
   r:text(x+18,yy+5,first(spec.name,math.floor((bw-22)/4)),7,1,bw-20)
   if not self:small() then r:text(x+18,yy+16,'OWN '..g.cargo[spec.id],11)end
   if bh>=43 then r:text(x+5,yy+29,spec.hint or '',5,1,bw-10)end
   local buy,sell=Rules.cost(g,spec)
   local price=self.marketSide=='buy' and buy or sell
   if self:small() then
    r:text(x+18,yy+16,'OWN '..g.cargo[spec.id]..' / '..price..'C',8,1,bw-21)
    r.buttons[#r.buttons+1]={x=x,y=yy,w=bw,h=bh,label=spec.name,fn=function()self:inspect('good',spec.id,self.marketSide)end}
   else r:button(x+3,yy+bh-16,bw-6,13,(self.marketSide=='buy' and '-' or '+')..' '..price..' C',function()self:inspect('good',spec.id,self.marketSide)end)end
  end
 end
 if pages>1 then
  r:button(7,h-46,45,16,'< PAGE',function()self.page=math.max(1,self.page-1)end)
  r:text(58,h-42,self.page..'/'..pages,7)
  r:button(w-52,h-46,45,16,'NEXT >',function()self.page=math.min(pages,self.page+1)end)
 end
 self:foot()
end
function UI:contracts()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header('CONTRACT BOARD','DELIVER CARGO FOR REWARDS')
 local top=24;local compact=self:small();local per=compact and 2 or (h<330 and 3 or 4)
 local pages=math.ceil(#C.contracts/per);self.page=math.min(pages,math.max(self.page,1))
 local cardH=math.floor((h-75-top)/per)
 for j=1,per do
  local job=C.contracts[(self.page-1)*per+j];if job then
   local x=5;local yy=top+(j-1)*(cardH+4)
   r:fill(x,yy,w-10,cardH,2);r:outline(x,yy,w-10,cardH,4)
   local spec=C.goodsById[job.item]
   r:icon(spec.icon,10,yy+5,1)
   r:text(24,yy+4,job.count..' '..spec.name,7,1,w-33)
   r:text(24,yy+15,'TO '..C.stations[job.destination].short,5,1,w-95)
   local stage=g.contracts[job.id]
   local label=stage=='done' and 'DONE' or 'VIEW'
   r:button(w-66,yy+cardH-16,58,14,label,function()
    self:inspect('contract',job.id)
   end,{selected=stage=='done'})
   r.buttons[#r.buttons+1]={x=x,y=yy,w=w-75,h=cardH,label='JOB INFO',fn=function()self:inspect('contract',job.id)end}
   if cardH>43 then r:text(24,yy+27,'+'..job.reward..' C / +'..job.rep..' REP',8,1,w-32)end
   if cardH>51 then
    local status=stage=='done' and 'DONE' or stage=='active' and 'ACTIVE' or 'AVAILABLE'
    r:text(24,yy+38,'OWN '..g.cargo[job.item]..'/'..job.count..' '..status,stage=='active' and 11 or 5,1,w-108)
   end
  end
 end
 r:button(6,h-46,48,16,'< PREV',function()self.page=math.max(1,self.page-1)end)
 r:text(57,h-41,self.page..' / '..pages,7)
 r:button(w-55,h-46,49,16,'NEXT >',function()self.page=math.min(pages,self.page+1)end)
 self:foot()
end
function UI:train()
 local r=self.r;local w,h=r.w,r.h;local g=self.g;self:header('TRAIN COMPOSITION','TAP A WAGON TO INSPECT')
 local artH=self:small() and (r.mode=='graphics' and math.floor((h-64)*.45) or 44) or math.floor((h-45)*.43)
 local taps=Art.train(r,2,21,w-4,artH,g.wagons,self.frame,self.selectedWagon)
 for i,t in ipairs(taps)do local ix=i
  r.buttons[#r.buttons+1]={x=t.x,y=t.y,w=t.w,h=t.h,fn=function()self.selectedWagon=ix;self.page=math.ceil(ix/(not self:small() and w>=210 and 4 or 2))end,label='WAGON'}
 end
 local top=24+artH;local cols=not self:small() and w>=210 and 4 or 2
 local start=(self.page-1)*cols+1;local bw=math.floor((w-14-(cols-1)*3)/cols)
 for i=1,cols do
  local idx=start+i-1;local wagon=g.wagons[idx]
  if wagon then
   local x=7+(i-1)*(bw+3)
   r:fill(x,top,bw,29,self.selectedWagon==idx and 12 or 2);r:outline(x,top,bw,29,4)
   r:icon(wagon.id=='engine' and 'train' or C.wagonById[wagon.id].icon,x+4,top+4,1)
   r:text(x+16,top+4,first(wagon.id,5),7,1,bw-17)
   r:text(x+4,top+17,'LV '..wagon.level,8)
   r.buttons[#r.buttons+1]={x=x,y=top,w=bw,h=29,fn=function()self.selectedWagon=idx end,label='WAGON'}
  end
 end
 local maxPage=math.ceil(#g.wagons/cols)
 if maxPage>1 then
  local arrows=top+32
  r:button(7,arrows,41,14,'<',function()self.page=math.max(1,self.page-1)end)
  r:button(w-48,arrows,41,14,'>',function()self.page=math.min(maxPage,self.page+1)end)
 end
 local detailsY=self:small() and math.max(top+47,h-80) or top+34
 local selected=g.wagons[self.selectedWagon] or g.wagons[1]
 local detailH=self:small() and math.max(0,h-47-detailsY) or h-detailsY-27
 if detailH>=15 then
  r:fill(6,detailsY,w-12,detailH,1)
  r:text(11,detailsY+3,selected.id:upper()..' LV '..selected.level,8,1,w-52)
  if detailH>=26 then
   r:text(11,detailsY+12,Info.wagonBenefit(selected),11,1,w-26)
   r:text(11,detailsY+22,'LOAD '..S.load(g)..'/'..S.capacity(g),6,1,w-27)
  end
  r:button(w-36,detailsY+3,24,14,'?',function()self:inspect('wagon',self.selectedWagon)end)
 end
 if not self:small() then
  if selected.id=='engine' then Art.loco(r,w*.36,detailsY+25,1.25)
  else Art.wagon(r,w*.36,detailsY+26,selected.id,1.25)end
  r:text(11,detailsY+39,'FUEL '..g.fuel..'  HULL '..g.hull,11,1,90)
 end
 local cw=math.floor((w-25)/3)
 local buttonY=h-46
 r:button(8,buttonY,cw,16,'ADD',function()self:go('wagons')end)
 r:button(12+cw,buttonY,cw,16,'LV UP',function()self:inspect('wagon',self.selectedWagon)end,{primary=true})
 r:button(16+cw*2,buttonY,cw,16,'TECH',function()self:go('upgrades')end)
 self:foot()
end
function UI:wagons()
 local r=self.r;local w,h=r.w,r.h;self:header('ADD WAGON','EXPAND YOUR TRAIN')
 local top=27;local rows=2;local cols=2;local gap=5
 local bw=math.floor((w-15-gap)/cols);local bh=math.floor((h-top-56-gap)/rows)
 for i,spec in ipairs(C.wagons)do
  local x,y=5+((i-1)%cols)*(bw+gap),top+math.floor((i-1)/2)*(bh+gap)
  r:fill(x,y,bw,bh,2);r:outline(x,y,bw,bh,4)
  r:icon(spec.icon,x+5,y+5,1);r:text(x+18,y+5,spec.name,7,1,bw-21)
  if bh>=40 then r:text(x+5,y+22,spec.summary or '',6,1,bw-10)end
  r:button(x+5,y+bh-18,bw-10,15,'BUY '..spec.cost,function()self:inspect('wagonNew',spec.id)end,{primary=true})
 end
 r:button(8,h-47,w-16,18,'TRAIN COMPOSITION',function()self:go('train')end)
 self:foot()
end
function UI:upgrades()
 local r=self.r;local w,h=r.w,r.h;self:header('TRAIN UPGRADES','CREATE-STYLE MODULES')
 local cols=not self:small() and w>=210 and 3 or 2;local rows=math.ceil(#C.upgrades/cols);local gap=4
 local bh=math.floor((h-50-24-(rows-1)*gap)/rows)
 local bw=math.floor((w-14-(cols-1)*gap)/cols)
 for i,spec in ipairs(C.upgrades)do
  local x=7+((i-1)%cols)*(bw+gap);local y=24+math.floor((i-1)/cols)*(bh+gap)
  local active=self.g.upgrades[spec.id]
  r:fill(x,y,bw,bh,active and 12 or 2);r:outline(x,y,bw,bh,active and 11 or 4)
  r:icon(spec.icon,x+4,y+3,1);r:text(x+17,y+4,spec.name,7,1,bw-20)
  if bh>=36 then r:text(x+5,y+17,spec.desc,6,1,bw-10)end
  if self:small() then
   r:text(x+5,y+(bh>=36 and 29 or 15),active and 'INSTALLED' or ('COST '..spec.cost..' C'),active and 11 or 8,1,bw-10)
   r.buttons[#r.buttons+1]={x=x,y=y,w=bw,h=bh,label=spec.name,fn=function()self:inspect('upgrade',spec.id)end}
  else
   if bh>=54 then r:text(x+5,y+32,active and 'INSTALLED' or ('COST '..spec.cost..' COINS'),active and 11 or 8,1,bw-10)end
   r:button(x+4,y+bh-16,bw-8,13,active and 'INSTALLED' or 'BUY '..spec.cost,function()self:inspect('upgrade',spec.id)end,{selected=active})
  end
 end
 r:button(8,h-45,w-16,17,'BACK TO TRAIN',function()self:go('train')end)
 self:foot()
end

function UI:travel()
 local r=self.r;local w,h=r.w,r.h;local g=self.g
 self:header('RAIL EXPEDITION','TRAVEL EVENT - NO TIMER')
 local artH=math.floor((h-50)*.45)
 Art.train(r,2,21,w-4,artH,g.wagons,self.frame)
 local p=g.pending
 if not p then r:text(10,h-52,'NO ACTIVE EVENT',7);self:foot();return end
 local e=C.eventById[p.event];local y=22+artH+3
 self:panel(5,y,w-10,math.max(21,h-y-53))
 r:icon('danger',10,y+5,1);r:text(25,y+5,e.name,8,1,w-30)
 r:text(10,y+18,e.desc,6,1,w-18)
 if h-y-53>=53 then
  for i,choice in ipairs(e.choices)do
   r:text(10,y+27+i*10,i..' '..choice.label..': '..Info.eventBrief(g,i),i==1 and 11 or 6,1,w-20)
  end
 end
 local by=h-47;local bw=math.floor((w-19)/2)
 for i,c in ipairs(e.choices)do
  local x=6+(i-1)*(bw+6)
  r:button(x,by,bw,19,c.label,function()self:inspect('event',i)end,{primary=i==1})
 end
 self:foot()
end
function UI:results()
 local r=self.r;local w,h=r.w,r.h;local g=self.g
 Art.train(r,0,0,w,math.floor(h*.60),g.wagons,self.frame)
 r:fill(0,0,w,31,0);r:center(5,g.won and 'RAILWAY COMPLETE' or 'EXPEDITION ENDED',8,self:small() and 1 or 2)
 r:fill(8,math.floor(h*.59),w-16,math.floor(h*.25),1)
 local yy=math.floor(h*.59)+5
 r:text(14,yy,'STATIONS '..g.trips..'   JOBS '..g.delivered,7,1,w-26)
 r:text(14,yy+12,'REPUTATION '..g.reputation..'  COINS '..g.coins,11,1,w-26)
 r:text(14,yy+24,'FINAL SCORE '..Rules.score(g),8,1,w-26)
 r:button(8,h-31,w-16,22,'NEW EXPEDITION',function()self:go('setup')end,{primary=true})
end
function UI:help()
 local r=self.r;local w,h=r.w,r.h;self:header('HOW TO PLAY','NO REAL-TIME PRESSURE')
 local lines={
  '1. CHOOSE A MAP DESTINATION',
  '2. BUY GOODS AT A STATION',
  '3. ACCEPT DELIVERY JOBS',
  '4. BUILD WAGONS & UPGRADES',
  '5. TRAVEL & RESOLVE EVENTS',
  '6. DELIVER TO EARN REPUTATION',
  '7. REACH EASTPORT AFTER 2 JOBS',
  '8. EACH SHIFT IS TURN BASED',
  '9. CREW ALL SHARES ONE TRAIN',
  '10. NO REAL-WORLD TIMERS',
 }
 local per=self:small() and 5 or 8
 local max=math.ceil(#lines/per)
 for i=1,per do
  local s=lines[(self.helpPage-1)*per+i]
  if s then
   r:icon('parts',10,29+(i-1)*16,1)
   r:text(25,32+(i-1)*16,s,7,1,w-30)
  end
 end
 if max>1 then
  r:button(10,h-63,47,16,'< PAGE',function()self.helpPage=math.max(1,self.helpPage-1)end)
  r:text(65,h-59,self.helpPage..'/'..max,8)
  r:button(w-57,h-63,47,16,'NEXT >',function()self.helpPage=math.min(max,self.helpPage+1)end)
 end
 if self.g then
  r:button(8,h-43,math.floor((w-24)/2),17,'MENU',function()self:go('title')end)
  r:button(14+math.floor((w-24)/2),h-43,math.floor((w-24)/2),17,'BACK',function()self:go('hub')end,{primary=true})
 else
  r:button(8,h-43,w-16,17,'BACK',function()self:go('title')end,{primary=true})
 end
 if self.g then self:foot()end
end
function UI:draw()
 local r=self.r;r:begin()
 if self.scene~='title' and self.scene~='setup' and self.scene~='help' and not self.g then self.scene='title' end
 local screens={title='title',setup='setup',hub='hub',map='map',station='station',modules='modules',market='market',contracts='contracts',train='train',wagons='wagons',upgrades='upgrades',travel='travel',results='results',help='help'}
 local screen=screens[self.scene] or 'title'
 self[screen](self)
 if self.info then self:details()end
 r:finish()
end
function UI:touch(x,y)
 local a,b=self.r:touch(x,y);if not a then return false end
 local result=self.r:hit(a,b)
 if result then self:draw() end
 return result
end
function UI:resize()self.r:resize();self:draw()end
function UI:close()self.r:close()end
return UI
