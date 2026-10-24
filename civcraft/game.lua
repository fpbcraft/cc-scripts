-- CIVCRAFT v0.4.0: Railbreak-style 4X with local hotseat or rednet networking
-- Host: /civcraft/game.lua host [--new]  Join: /civcraft/game.lua join [host ID]
local args={...}
local MODE=args[1] or 'local'
local PROTOCOL='fpbcraft.civcraft.v1'
local localMode=MODE=='local'
local SAVE='/civcraft/data/save.dat'
local slot=1
local mapSizes={'compact','standard','large'}
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
local Hex=dofile('/civcraft/hex.lua')
local Systems=dofile('/civcraft/systems.lua')
local World=dofile('/civcraft/world.lua')
local Saves=dofile('/civcraft/saves.lua')
local W,H=Hex.width,Hex.height
local state
local function terrain(x,y)return Hex.terrain(x,y,state)end
local function newGame()
 return {version=3,phase='lobby',round=1,turn=1,players={},cities={},units={},nextId=1,logs={'Welcome to CIVCRAFT'},winner=nil,mapSize='standard',mapSeed=12345,name='NEW EMPIRE'}
end
state=newGame()
local hasHumanSave=false
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
 local u={id=state.nextId,owner=owner,x=x,y=y,kind=kind,moved=false,movesLeft=Systems.units[kind].move}
 state.nextId=state.nextId+1;table.insert(state.units,u);return u
end
local function player(id)
 for i,p in ipairs(state.players)do if p.id==id then return p,i end end
end
local function save()
 World.reveal(state,Hex,Systems)
 if localMode then Saves.save(slot,state);return end
 local dir=fs.getDir(SAVE);if not fs.exists(dir)then fs.makeDir(dir)end
 local h=assert(fs.open(SAVE..'.tmp','w'))
 h.write(textutils.serialize(state));h.close()
 if fs.exists(SAVE)then fs.delete(SAVE)end
 fs.move(SAVE..'.tmp',SAVE)
end
local function initMap()
 state.world=World.generate(state.mapSeed,state.mapSize,#state.players)
 W,H=state.world.width,state.world.height
 state.name='EMPIRE '..state.world.seed
 for i,p in ipairs(state.players)do
  local pos=state.world.starts[i]
  local x,y=pos.x,pos.y
  table.insert(state.cities,{id=state.nextId,x=x,y=y,owner=p.id,level=1,population=2,foodStore=0,jobs={food=1,wood=1,science=0},buildings={}})
  state.nextId=state.nextId+1
  addUnit(p.id,x+((x<W/2) and 1 or -1),y,'warrior')
  p.food=12;p.wood=12;p.science=0;p.tech=0;p.ready=false;p.techs=p.techs or {};p.civ=p.civ or Systems.civs[i].id
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
 Systems.production(state)
 for _,p in ipairs(state.players)do p.ready=false end
 for _,u in ipairs(state.units)do
  local owner=player(u.owner)
  local base=Systems.units[u.kind] or Systems.units.warrior
  u.movesLeft=base.move+(owner and owner.civ=='nomad' and u.kind=='scout' and 1 or 0)+
   (owner and owner.civ=='mariner' and base.naval and 1 or 0)
  u.moved=false
 end
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
 if req.action=='assign' or req.action=='build' or req.action=='recruit'
    or req.action=='researchTech' then
  local x,y=tonumber(req.x),tonumber(req.y)
  local c=x and y and cityAt(x,y)
  if req.action=='researchTech' then
   local ok,why=Systems.research(p,req.id)
   if ok then save()end
   return ok,why
  end
  if not c or c.owner~=id then return false,'Select your city' end
  local ok,why
  if req.action=='assign' then ok,why=Systems.assign(c,req.from,req.to)
  elseif req.action=='build' then ok,why=Systems.build(p,c,req.id)
  elseif req.action=='recruit' then
   local template=Systems.units[req.id]
   if not template or not Systems.canRecruit(p,req.id) then
    return false,'Unit locked or too expensive'
   end
   local spawnX,spawnY=x,y
   if template.naval then
    spawnX=nil
    for _,hex in ipairs(Hex.neighbours(x,y,state))do
     if terrain(hex.x,hex.y)=='water' and not unitAt(hex.x,hex.y)then
      spawnX,spawnY=hex.x,hex.y;break
     end
    end
    if not spawnX then return false,'Requires an open coastal hex' end
   elseif unitAt(x,y)then return false,'City occupied' end
   p.food=p.food-template.food;p.wood=p.wood-template.wood
   addUnit(id,spawnX,spawnY,req.id);ok=true
  end
  if ok then save()end
  return ok,why
 end
 if req.action=='end' then
  p.ready=true;log(p.name..' is ready')
  local all=true;for _,q in ipairs(state.players)do if not q.ready then all=false end end
  if all then nextTurn() else save() end
  return true
 end
 local x,y=tonumber(req.x),tonumber(req.y)
 if not x or not y or not Hex.inBounds(x,y,state) then return false,'Select a tile' end
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
  if not moving or moving.owner~=id or (moving.movesLeft or (moving.moved and 0 or 1))<=0 then return false,'Unit cannot move' end
  local legal
  for _,dest in ipairs(Hex.reachable(state,moving,id,Systems))do
   if dest.x==x and dest.y==y then legal=dest;break end
  end
  if not legal then return false,'Destination out of range or blocked' end
  local stats=Systems.units[moving.kind] or Systems.units.warrior
  if u and u.owner~=id then
   local enemy=Systems.units[u.kind] or Systems.units.warrior
   local offense=stats.strength or 0
   local defense=enemy.defense or enemy.strength or 1
   if u.kind=='horseman' and moving.kind=='spearman' then offense=offense+2 end
   if terrain(x,y)=='hills' then defense=defense+1 end
   if p.civ=='highland' and terrain(sx,sy)=='hills' then offense=offense+1 end
   if c and c.owner==u.owner and c.buildings then
    if c.buildings.walls then defense=defense+1 end
    if c.buildings.fortress then defense=defense+2 end
   end
   for _,defender in ipairs(state.players)do
    if defender.id==u.owner and defender.civ=='sentinel' and c then defense=defense+1 end
   end
   if offense<defense then
    for i,v in ipairs(state.units)do
     if v==moving then table.remove(state.units,i);break end
    end
    log(p.name..' lost an attack');save();return true
   end
   for i,v in ipairs(state.units)do if v==u then table.remove(state.units,i);break end end
   log(p.name..' won a battle')
  end
  if c and c.owner~=id and not legal.ranged then
   if (stats.strength or 0)<=0 then return false,'Military unit needed' end
   c.owner=id;log(p.name..' captured a city!')
  end
  if not legal.ranged then moving.x=x;moving.y=y end
  moving.movesLeft=legal.ranged and 0 or math.max(0,moving.movesLeft-legal.cost)
  moving.moved=moving.movesLeft<=0
 elseif req.action=='found' then
  if not u or u.owner~=id or u.kind~='settler' then return false,'Choose a settler' end
  if c then return false,'Tile has a city' end
  if not Hex.passable(x,y,state,u,Systems)then return false,'Unsettleable terrain' end
  for _,v in ipairs(state.cities)do if Hex.distance(v.x,v.y,x,y)<3 then return false,'Cities need 3 hex spacing' end end
  for i,v in ipairs(state.units)do if v==u then table.remove(state.units,i);break end end
  table.insert(state.cities,{id=state.nextId,x=x,y=y,owner=id,level=1,population=2,foodStore=0,jobs={food=1,wood=1,science=0},buildings={}})
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
   if type(loaded)=='table' and (loaded.version==1 or loaded.version==2) then state=Systems.migrate(loaded);hasHumanSave=true end
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
Systems.migrate(state)
local snapshot=localHost and state or nil
local message='Tap a tile, then choose an action'
local handoff=false
local exitRequested=false
local appScreen=hasHumanSave and 'title' or 'title'
local gamePaused=false
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
  handoff=handoff,localMode=localMode,hostID=hostId,screen=appScreen,paused=gamePaused,hasSave=hasHumanSave})
end
local function dispatch(action,params)
 if action=='exit' then exitRequested=true;return end
 if action=='newGame' then
  if localHost then
   state=newGame();Systems.migrate(state);hasHumanSave=false
   if localMode then
    for i=1,2 do table.insert(state.players,{
     id=myId*16+i,name='PLAYER '..i,ready=false,
     civ=Systems.civs[i].id,ai=false,techs={}})end
    state.activeIndex=1
   else table.insert(state.players,{id=myId,name='P1',ready=false,
     civ=Systems.civs[1].id,ai=false,techs={}})end
  end
  appScreen='game';gamePaused=false;return
 end
 if action=='continue' then appScreen='game';gamePaused=false;return end
 if action=='pause' then gamePaused=true;return end
 if action=='resume' then gamePaused=false;return end
 if action=='title' then appScreen='title';gamePaused=false;save();return end
 if action=='save' then save();message='GAME SAVED';return end
 if action=='civ' and state.phase=='lobby' then
  local p=state.players[params and params.player or 1]
  if p then
   local current=1
   for i,c in ipairs(Systems.civs)do if c.id==p.civ then current=i end end
   p.civ=Systems.civs[current%#Systems.civs+1].id;save()
  end
  return
 end
 if action=='toggleAI' and state.phase=='lobby' and localMode then
  local p=state.players[params and params.player or 1]
  if p then
   local humans=0
   for _,q in ipairs(state.players)do if not q.ai then humans=humans+1 end end
   if p.ai or humans>1 then p.ai=not p.ai;save()
   else message='KEEP AT LEAST ONE HUMAN PLAYER'end
  end
  return
 end
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
  if ok then hasHumanSave=true end
  if localMode and ok and action=='end' then
   for _,q in ipairs(state.players)do
    if q.ai and not q.ready then Systems.aiTurn(state,q,Hex)end
   end
   local complete=true
   for _,q in ipairs(state.players)do if not q.ready then complete=false end end
   if complete and state.phase=='game' then nextTurn()end
   -- The existing rules advance the round when everyone ends their turn.
   -- Only one local participant is shown at a time.
   local nextIndex=(state.activeIndex or 1)%#state.players+1
   for _=1,#state.players do
    if not state.players[nextIndex].ready and not state.players[nextIndex].ai then break end
    nextIndex=nextIndex%#state.players+1
   end
   -- AIs never own the screen even immediately after nextTurn clears ready.
   if state.players[nextIndex].ai then
    nextIndex=state.activeIndex or 1
   end
   state.activeIndex=nextIndex
   handoff=state.phase=='game' and not state.players[nextIndex].ai
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
   gamePaused=not gamePaused;draw()
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
