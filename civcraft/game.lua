-- CIVCRAFT v0.2.0: Railbreak-style 4X with local hotseat or rednet networking
-- Host: /civcraft/game.lua host [--new]  Join: /civcraft/game.lua join [host ID]
local args={...}
local MODE=args[1] or 'host'
local PROTOCOL='fpbcraft.civcraft.v1'
local localMode=MODE=='local'
local SAVE=localMode and '/civcraft/data/local-save.dat' or '/civcraft/data/save.dat'
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
local hasModem=not localMode and modem() or false
local myId=os.getComputerID and os.getComputerID() or 0
local hostId,localHost=nil,(MODE=='host' or localMode)
if localHost then
 if fs.exists(SAVE) and args[2]~='--new' then
  local h=fs.open(SAVE,'r')
  if h then local loaded=textutils.unserialize(h.readAll());h.close()
   if type(loaded)=='table' and loaded.version==1 then state=loaded end
  end
 elseif args[2]=='--new' and fs.exists(SAVE)then fs.delete(SAVE) end
 if localMode then
  -- Local players receive distinct persistent IDs on a single computer.
  if #state.players==0 then
   for i=1,2 do
    table.insert(state.players,{id=myId*16+i,name='PLAYER '..i,ready=false})
   end
  end
  state.activeIndex=math.max(1,math.min(#state.players,state.activeIndex or 1))
 else
  if not player(myId) then
   if state.phase~='lobby' then error('Save belongs to another host. Run host --new for a new match') end
   table.insert(state.players,{id=myId,name='P1',ready=false})
  end
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
local handoff=false
local exitRequested=false
local UI=dofile('/civcraft/ui.lua')
local view
local function activeID()
 if localMode then
  local index=math.max(1,math.min(#state.players,state.activeIndex or 1))
  return state.players[index] and state.players[index].id
 end
 return myId
end
local function draw()
 local s=localHost and state or snapshot
 view:message(message)
 view:draw(s,localMode and activeID() or myId,{
  handoff=handoff,localMode=localMode,hostID=hostId})
end
local function dispatch(action,params)
 if action=='exit' then exitRequested=true;return end
 if action=='reveal' then handoff=false;return end
 if localMode and state.phase=='lobby' and
    (action=='addPlayer' or action=='removePlayer')then
  if action=='addPlayer' and #state.players<4 then
   local i=#state.players+1
   table.insert(state.players,{id=myId*16+i,name='PLAYER '..i,ready=false})
   message='PLAYER '..i..' ADDED';save()
  elseif action=='removePlayer' and #state.players>2 then
   table.remove(state.players);message='PLAYER REMOVED';save()
  else message='CHOOSE TWO TO FOUR PLAYERS'end
  return
 end
 local req=params or {};req.action=action
 if localHost then
  local id=activeID()
  local ok,reason=apply(id,req)
  message=ok and 'ORDER ACCEPTED' or tostring(reason)
  if localMode and ok and action=='end' then
   -- The existing rules advance the round when everyone ends their turn.
   -- Only one local participant is shown at a time.
   local nextIndex=(state.activeIndex or 1)%#state.players+1
   for _=1,#state.players do
    if not state.players[nextIndex].ready then break end
    nextIndex=nextIndex%#state.players+1
   end
   state.activeIndex=nextIndex
   handoff=state.phase=='game'
   save()
  end
 else rednet.send(hostId,req,PROTOCOL)end
end
view=UI.new(display,dispatch)
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
 while not exitRequested do
  local e,a,b,c=os.pullEvent()
  if e=='monitor_touch' and display~=term.current()then
   view:tap(b,c);draw()
  elseif e=='mouse_click' and display==term.current()then
   view:tap(b,c);draw()
  elseif e=='term_resize' or e=='monitor_resize' then
   view:resize();draw()
  elseif e=='key' and keys and (a==keys.q or a==keys.escape)then
   return
  end
  if localHost and hasModem then publish()end
 end
end
if localHost and hasModem then
 parallel.waitForAny(server,ui)
elseif localHost then ui()
else parallel.waitForAny(clientListener,ui)end
if localHost and hasModem then pcall(rednet.unhost,PROTOCOL)end
view:close()
