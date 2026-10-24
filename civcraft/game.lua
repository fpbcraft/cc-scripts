-- CIVCRAFT: compact networked 4X for CC:Tweaked
-- Host: /civcraft/game.lua host [--new]  Join: /civcraft/game.lua join [host ID]
local args={...}
local MODE=args[1] or 'host'
local PROTOCOL='fpbcraft.civcraft.v1'
local SAVE='/civcraft/data/save.dat'
local function modem()
 for _,side in ipairs(peripheral.getNames()) do
  if peripheral.getType(side)=='modem' then
   if not rednet.isOpen(side) then rednet.open(side) end
   return true
  end
 end
 return false
end
local function screen()
 local best,bestArea=nil,0
 for _,side in ipairs(peripheral.getNames()) do
  if peripheral.getType(side)=='monitor' then
   local m=peripheral.wrap(side);m.setTextScale(0.5)
   local w,h=m.getSize()
   if w*h>bestArea then best,bestArea=m,w*h end
  end
 end
 return best or term.current()
end
local display=screen()
local W,H=12,8
local function key(x,y)return y*W+x end
local function terrain(x,y)
 local n=(x*37+y*61+x*y*13)%19
 if n==0 or n==1 then return '~' end
 if n==2 or n==3 then return '^' end
 if n<9 then return 'f' end
 return '.'
end
local starts={{2,2},{11,7},{11,2},{2,7}}
local function newGame()
 return {version=1,phase='lobby',round=1,turn=1,players={},cities={},units={},nextId=1,logs={'Welcome to CIVCRAFT'},winner=nil}
end
local state=newGame()
local function log(s)
 table.insert(state.logs,1,s)
 while #state.logs>5 do table.remove(state.logs) end
end
local function cityAt(x,y)
 for _,c in ipairs(state.cities)do if c.x==x and c.y==y then return c end end
end
local function unitAt(x,y)
 for _,u in ipairs(state.units)do if u.x==x and u.y==y then return u end end
end
local function addUnit(owner,x,y,kind)
 local u={id=state.nextId,owner=owner,x=x,y=y,kind=kind,moved=false}
 state.nextId=state.nextId+1;table.insert(state.units,u);return u
end
local function player(id)
 for i,p in ipairs(state.players)do if p.id==id then return p,i end end
end
local function save()
 local dir=fs.getDir(SAVE);if not fs.exists(dir)then fs.makeDir(dir)end
 local h=fs.open(SAVE..'.tmp','w')
 if not h then return end
 h.write(textutils.serialize(state));h.close()
 if fs.exists(SAVE)then fs.delete(SAVE)end
 fs.move(SAVE..'.tmp',SAVE)
end
local function initMap()
 for i,p in ipairs(state.players)do
  local x,y=starts[i][1],starts[i][2]
  table.insert(state.cities,{id=state.nextId,x=x,y=y,owner=p.id,level=1})
  state.nextId=state.nextId+1
  addUnit(p.id,x+((x<W/2) and 1 or -1),y,'warrior')
  p.food=12;p.wood=12;p.science=0;p.tech=0;p.ready=false
 end
 state.phase='game';state.round=1;state.turn=1
 log('Game started: '..#state.players..' civilizations')
 save()
end
local function winner()
 local lead,best=nil,-1
 for _,p in ipairs(state.players)do
  local cities=0;for _,c in ipairs(state.cities)do if c.owner==p.id then cities=cities+1 end end
  local score=cities*10+p.tech*6+p.science+p.wood+p.food
  if score>best then lead,best=p,score end
  if cities>=5 then state.winner=p.name;state.phase='over';return end
 end
 if state.round>25 then state.winner=lead and lead.name;state.phase='over' end
end
local function nextTurn()
 state.round=state.round+1
 for _,p in ipairs(state.players)do
  p.ready=false
  for _,c in ipairs(state.cities)do
   if c.owner==p.id then
    p.food=p.food+2+p.tech;p.wood=p.wood+2
    p.science=p.science+1+p.tech
   end
  end
 end
 for _,u in ipairs(state.units)do u.moved=false end
 winner();log('Round '..state.round);save()
end
local function apply(id,req)
 local p=player(id)
 if not p then return false,'You are not registered' end
 if req.action=='start' then
  if id~=state.players[1].id or state.phase~='lobby' then return false,'Host only' end
  if #state.players<2 then return false,'Need 2 players' end
  initMap();return true
 end
 if state.phase~='game' then return false,'Game not running' end
 if p.ready then return false,'Already ended turn' end
 if req.action=='end' then
  p.ready=true;log(p.name..' is ready')
  local all=true;for _,q in ipairs(state.players)do if not q.ready then all=false end end
  if all then nextTurn() else save() end
  return true
 end
 local x,y=tonumber(req.x),tonumber(req.y)
 if not x or not y or x<1 or x>W or y<1 or y>H then return false,'Select a tile' end
 local c,u=cityAt(x,y),unitAt(x,y)
 if req.action=='research' then
  local cost=8+p.tech*6
  if p.tech>=3 or p.science<cost then return false,'Need '..cost..' science (max III)' end
  p.science=p.science-cost;p.tech=p.tech+1;log(p.name..' researched tech '..p.tech)
 elseif req.action=='warrior' or req.action=='settler' then
  if not c or c.owner~=id then return false,'Choose your city' end
  if u then return false,'City tile occupied' end
  local food,wood=0,5
  if req.action=='settler' then food,wood=8,8 end
  if p.food<food or p.wood<wood then return false,'Not enough resources' end
  p.food=p.food-food;p.wood=p.wood-wood;addUnit(id,x,y,req.action)
 elseif req.action=='move' then
  local sx,sy=tonumber(req.sx),tonumber(req.sy)
  local moving=sx and sy and unitAt(sx,sy)
  if not moving or moving.owner~=id or moving.moved then return false,'Select an unmoved unit' end
  if math.abs(sx-x)+math.abs(sy-y)~=1 then return false,'Move only 1 tile' end
  if terrain(x,y)=='~' or terrain(x,y)=='^' then return false,'Impassable terrain' end
  if u then
   if u.owner==id then return false,'Occupied by ally' end
   if moving.kind~='warrior' then return false,'Settlers cannot fight' end
   for i,v in ipairs(state.units)do if v==u then table.remove(state.units,i);break end end
   log(p.name..' defeated an enemy unit')
  end
  if c and c.owner~=id then
   if moving.kind~='warrior' then return false,'Warrior needed to capture city' end
   c.owner=id;log(p.name..' captured a city!')
  end
  moving.x=x;moving.y=y;moving.moved=true
 elseif req.action=='found' then
  if not u or u.owner~=id or u.kind~='settler' then return false,'Choose a settler' end
  if c then return false,'Tile has a city' end
  for _,v in ipairs(state.cities)do if math.abs(v.x-x)+math.abs(v.y-y)<3 then return false,'Cities need 3 tile spacing' end end
  for i,v in ipairs(state.units)do if v==u then table.remove(state.units,i);break end end
  table.insert(state.cities,{id=state.nextId,x=x,y=y,owner=id,level=1})
  state.nextId=state.nextId+1;log(p.name..' founded a city')
 else return false,'Unknown action' end
 winner();save();return true
end
local hasModem=modem()
local myId=os.getComputerID()
local hostId,localHost=nil,MODE=='host'
if localHost then
 if fs.exists(SAVE) and args[2]~='--new' then
  local h=fs.open(SAVE,'r')
  if h then local loaded=textutils.unserialize(h.readAll());h.close()
   if type(loaded)=='table' and loaded.version==1 then state=loaded end
  end
 elseif args[2]=='--new' and fs.exists(SAVE)then fs.delete(SAVE) end
 if not player(myId) then
  if state.phase~='lobby' then error('Save belongs to another host. Run host --new for a new match') end
  table.insert(state.players,{id=myId,name='P1',ready=false})
 end
 hostId=myId
 if hasModem then rednet.host(PROTOCOL,'CIVCRAFT-'..myId) end
else
 assert(hasModem,'A wired/wireless modem is required to join')
 hostId=tonumber(args[2])
 if not hostId then
  print('Searching for a CIVCRAFT host...')
  hostId=rednet.lookup(PROTOCOL)
 end
 assert(hostId,'No game found; use join <host computer ID>')
 rednet.send(hostId,{action='join',name=os.getComputerLabel() or ('Computer '..myId)},PROTOCOL)
end
local snapshot=localHost and state or nil
local message='Tap a tile, then choose an action'
local selected={x=2,y=2};local source=nil
local buttons={}
local colors={colors.red,colors.cyan,colors.lime,colors.orange}
local function draw()
 local s=localHost and state or snapshot
 if not s then display.setBackgroundColor(colors.black);display.clear();display.setCursorPos(1,1);display.write('Connecting to '..hostId..'...');return end
 local me=player(myId)
 if not localHost then
  me=nil;for _,v in ipairs(s.players)do if v.id==myId then me=v end end
 end
 display.setBackgroundColor(colors.black);display.setTextColor(colors.white);display.clear()
 local w,h=display.getSize()
 buttons={}
 local function line(x,y,text,color)
  if y<1 or y>h or x>w then return end
  display.setCursorPos(x,y);display.setTextColor(color or colors.white)
  display.write(tostring(text):sub(1,math.max(0,w-x+1)))
 end
 local function button(x,y,label,action,params)
  if y>h or x>w then return end
  line(x,y,'['..label..']',colors.yellow)
  table.insert(buttons,{x=x,y=y,w=#label+2,action=action,params=params})
 end
 line(1,1,'CIVCRAFT  '..(s.phase=='game' and ('ROUND '..s.round) or s.phase:upper()),colors.yellow)
 if s.phase=='lobby' then
  line(1,3,'Players connected: '..#s.players..'/4')
  for i,p in ipairs(s.players)do line(1,4+i,i..'. '..p.name) end
  line(1,11,'Host ID: '..hostId)
  if localHost then button(1,13,'START GAME','start')end
  line(1,15,'Players join with: game.lua join '..hostId)
  line(1,17,message,colors.lightGray)
  return
 end
 if s.phase=='over' then
  line(1,4,'WINNER: '..tostring(s.winner),colors.lime)
  line(1,6,'Game finished after '..s.round..' rounds')
  return
 end
 for y=1,H do
  for x=1,W do
   local t=terrain(x,y)
   local c,u=nil,nil
   for _,v in ipairs(s.cities)do if v.x==x and v.y==y then c=v;break end end
   for _,v in ipairs(s.units)do if v.x==x and v.y==y then u=v;break end end
   local mark=t;local color=t=='~' and colors.blue or (t=='^' and colors.gray or (t=='f' and colors.green or colors.lightGray))
   if c then mark='C';for i,p in ipairs(s.players)do if p.id==c.owner then color=colors[i] end end end
   if u then mark=u.kind=='warrior' and 'W' or 'S';for i,p in ipairs(s.players)do if p.id==u.owner then color=colors[i] end end end
   if selected.x==x and selected.y==y then display.setBackgroundColor(colors.white);color=colors.black
   else display.setBackgroundColor(colors.black) end
   line((x-1)*2+1,y+2,mark..' ',color)
  end
 end
 display.setBackgroundColor(colors.black)
 local x0=math.min(27,w)
 line(x0,3,'PLAYERS')
 for i,p in ipairs(s.players)do
  local mine=p.id==myId
  line(x0,3+i,(mine and '>' or ' ')..i..' '..p.name:sub(1,6)..(p.ready and '*' or ''),colors[i])
 end
 if me then
  line(x0,10,'Food '..me.food..' Wood '..me.wood)
  line(x0,11,'Science '..me.science..' Tech '..me.tech)
 end
 local c,u=nil,nil
 for _,v in ipairs(s.cities)do if v.x==selected.x and v.y==selected.y then c=v end end
 for _,v in ipairs(s.units)do if v.x==selected.x and v.y==selected.y then u=v end end
 line(1,12,'Tile '..selected.x..','..selected.y..' '..terrain(selected.x,selected.y)..' '..(c and 'CITY' or '')..' '..(u and u.kind or ''))
 line(1,13,'Tap your unit -> MOVE -> adjacent tile')
 if source then line(1,14,'Moving from '..source.x..','..source.y,colors.yellow) end
 button(1,16,'MOVE','selectMove')
 button(9,16,'FOUND','found')
 button(19,16,'WARRIOR','warrior')
 button(30,16,'SETTLER','settler')
 button(1,18,'RESEARCH','research')
 button(13,18,'END TURN','end')
 line(1,20,message,colors.lightGray)
 line(1,22,'C city W warrior S settler | ~ water ^ mountain',colors.lightGray)
 line(1,23,'Win: 5 cities or highest score after 25 rounds',colors.lightGray)
end
local function send(action,params)
 local req=params or {};req.action=action
 if localHost then
  local ok,reason=apply(myId,req);message=ok and 'Order accepted' or reason
 else
  rednet.send(hostId,req,PROTOCOL)
 end
end
local function tap(tx,ty)
 local s=localHost and state or snapshot
 if not s then return end
 if s.phase=='game' and ty>=3 and ty<=H+2 and tx>=1 and tx<=W*2 then
  local x=math.floor((tx-1)/2)+1;local y=ty-2
  if source then
   send('move',{sx=source.x,sy=source.y,x=x,y=y});source=nil
  else selected={x=x,y=y} end
  return
 end
 for _,b in ipairs(buttons)do
  if ty==b.y and tx>=b.x and tx<b.x+b.w then
   if b.action=='selectMove' then source={x=selected.x,y=selected.y};message='Select adjacent destination'
   else send(b.action,{x=selected.x,y=selected.y}) end
   return
  end
 end
end
local function publish()
 if not hasModem then return end
 for _,p in ipairs(state.players)do
  if p.id~=myId then rednet.send(p.id,{type='state',state=state},PROTOCOL)end
 end
end
local function server()
 while true do
  local id,req=rednet.receive(PROTOCOL)
  if type(req)=='table' then
   if req.action=='join' then
    local p=player(id)
    if not p and state.phase=='lobby' and #state.players<4 then
     table.insert(state.players,{id=id,name=tostring(req.name or ('P'..(#state.players+1))):sub(1,10),ready=false})
     log('Player joined: '..id)
    end
    rednet.send(id,{type='state',state=state},PROTOCOL)
   elseif player(id) then
    local ok,why=apply(id,req)
    rednet.send(id,{type='result',ok=ok,message=why or (ok and 'Order accepted')},PROTOCOL)
   end
   publish()
  end
 end
end
local function clientListener()
 while true do
  local id,packet=rednet.receive(PROTOCOL)
  if id==hostId and type(packet)=='table' then
   if packet.type=='state' and type(packet.state)=='table' then snapshot=packet.state
   elseif packet.type=='result' then message=packet.ok and 'Order accepted' or tostring(packet.message)end
   draw()
  end
 end
end
local function ui()
 draw()
 while true do
  local e,a,b,c=os.pullEvent()
  if e=='monitor_touch' and display~=term.current() then tap(b,c);draw()
  elseif e=='mouse_click' and display==term.current() then tap(b,c);draw()
  elseif e=='term_resize' or e=='monitor_resize' then draw()
  elseif e=='timer' then draw()
  elseif e=='key' and a==keys.q then return end
  if localHost then publish() end
  os.startTimer(1)
 end
end
if localHost and hasModem then
 parallel.waitForAny(server,ui)
elseif localHost then ui()
else parallel.waitForAny(clientListener,ui)end
if localHost and hasModem then pcall(rednet.unhost,PROTOCOL)end
