-- Host-authoritative gameplay orders shared by humans, remote players and AI.
-- Session orchestration (lobby, save, end turn) belongs to game.lua.
local Hex=dofile('/games/civcraft/hex.lua')
local World=dofile('/games/civcraft/world.lua')
local Combat=dofile('/games/civcraft/combat.lua')
local Hostiles=dofile('/games/civcraft/hostiles.lua')
local Rails=dofile('/games/civcraft/railways.lua')
local Villages=dofile('/games/civcraft/villages.lua')
local A={}
function A.apply(state,id,req,Systems)
 if type(req)~='table' then return false,'Invalid order'end
 local p
 for _,candidate in ipairs(state.players or {})do if candidate.id==id then p=candidate end end
 if not p then return false,'You are not registered'end
 if state.phase~='game' then return false,'Game not running'end
 if p.ready then return false,'Already ended turn'end
 local function at(list,x,y)
  for _,item in ipairs(list or {})do if item.x==x and item.y==y then return item end end
 end
 local function cityAt(x,y)return at(state.cities,x,y)end
 local function unitAt(x,y)return at(state.units,x,y)end
 local function terrain(x,y)return Hex.terrain(x,y,state)end
 local function log(message)
  state.logs=state.logs or {};table.insert(state.logs,1,message)
  while #state.logs>5 do table.remove(state.logs)end
 end
 if req.action=='exchange'then local ok,why=Systems.exchange(state,p,req.resource);return ok,why end
 if req.action=='assign' or req.action=='workTile' or req.action=='build' or req.action=='recruit'
    or req.action=='researchTech' or req.action=='queue' then
  local ok,why
  if req.action=='researchTech' then
   ok,why=Systems.research(p,req.id)
  else
   local cx,cy=tonumber(req.cityX or req.x),tonumber(req.cityY or req.y)
   local c=cx and cy and cityAt(cx,cy)
   if not c or c.owner~=id then return false,'Select an owned city' end
   if req.action=='workTile' then
    ok,why=Systems.workTile(state,c,tonumber(req.x),tonumber(req.y))
   elseif req.action=='assign' then
    ok,why=Systems.assign(c,req.from,req.to,state)
   elseif req.action=='queue' then
    ok,why=Systems.queue(p,c,req.kind,req.id,state,Hex,tonumber(req.tileX),tonumber(req.tileY))
   elseif req.action=='build' then
    ok,why=Systems.build(p,c,req.id,state,Hex)
   elseif req.action=='recruit' then
    ok,why=Systems.queue(p,c,'unit',req.id,state,Hex)
   end
  end
  return ok,why
 end
 local x,y=tonumber(req.x),tonumber(req.y)
 if not x or not y or x%1~=0 or y%1~=0 or not Hex.inBounds(x,y,state) then return false,'Select a tile' end
 local c,u=cityAt(x,y),unitAt(x,y)
 if req.action=='research' or req.action=='warrior' or req.action=='settler' then
  return false,'Use research and city production projects'
 elseif req.action=='standby' then
  if not u or u.owner~=id then return false,'Select an owned unit' end
  u.standby=req.value==true;if not u.standby then u.healing=false end;if u.standby then u.autoExplore=false end;return true
 elseif req.action=='autoExplore'then
  if not u or u.owner~=id then return false,'Select an owned scout'end
  if req.value==false then u.autoExplore=false;return true end
  local ok,why=Systems.autoExplore(state,u,Hex);return ok,why
 elseif req.action=='move' then
  local sx,sy=tonumber(req.sx),tonumber(req.sy)
  local moving=sx and sy and unitAt(sx,sy)
  if not moving or moving.owner~=id or (moving.movesLeft or (moving.moved and 0 or 1))<=0 then return false,'Unit cannot move' end
  local legal
  for _,dest in ipairs(Hex.reachable(state,moving,id,Systems))do
   if dest.x==x and dest.y==y then legal=dest;break end
  end
  if not legal then return false,'Destination out of range or blocked' end
  local asleep,healing=moving.standby,moving.healing
  moving.standby=false;moving.healing=false
  if legal.attack then
   local ok,why=Combat.attack(state,moving,legal,Systems)
   if not ok then moving.standby=asleep;moving.healing=healing;return false,why end
   log((p.name or tostring(id))..': '..why)
   moving.movesLeft=legal.ranged and 0 or math.max(0,(moving.movesLeft or Systems.units[moving.kind].move)-legal.cost)
  else
   moving.x=x;moving.y=y;moving.movesLeft=math.max(0,(moving.movesLeft or Systems.units[moving.kind].move)-legal.cost)
   moving.actedThisRound=true;moving.healing=false;moving.autoExplore=false
  end
  moving.standby=false;moving.healing=false
  moving.moved=moving.movesLeft<=0
 elseif req.action=='disband'then
  if not u or u.owner~=id or (req.unitID and req.unitID~=u.id)then return false,'Select an owned unit'end
  for i=#state.units,1,-1 do if state.units[i]==u then table.remove(state.units,i);break end end
 elseif req.action=='buildRail'then
  local moving=unitAt(tonumber(req.sx),tonumber(req.sy))
  local asleep=moving and moving.standby
  if moving then moving.standby=false end
  local ok,why=Rails.build(state,p,moving,x,y,Systems)
  if not ok then if moving then moving.standby=asleep end;return false,why end
  moving.healing=false
 elseif req.action=='envoy'then
  local ok,why=Villages.envoy(state,p,c);if not ok then return false,why end
 elseif req.action=='heal'then
  if not u or u.owner~=id then return false,'Select an owned unit'end
  u.healing=true;u.standby=true;u.autoExplore=false;u.movesLeft=0;u.moved=true
 elseif req.action=='cityStrike'then
  if not c or c.owner~=id then return false,'Select an owned city'end
  local tx,ty=tonumber(req.tx),tonumber(req.ty)
  if not tx or not ty or tx%1~=0 or ty%1~=0 or not Hex.inBounds(tx,ty,state)then return false,'Select a target tile'end
  local ok,why=Combat.strike(state,c,tx,ty,Systems)
  if not ok then return false,why end;log(why)
 elseif req.action=='found' then
  if not u or u.owner~=id or u.kind~='settler' then return false,'Choose a settler' end
  if (u.movesLeft or (u.moved and 0 or Systems.units.settler.move))<=0 then return false,'Settler needs movement remaining' end
  if c then return false,'Tile has a city' end
  if ((state.world or {}).landmarks or {})[x..':'..y]then return false,'Cannot settle on a landmark'end
  for _,camp in ipairs(state.spawners or {})do if not camp.cleared and camp.x==x and camp.y==y then return false,'Clear the hostile camp first'end end
  if terrain(x,y)=='water' or not Hex.passable(x,y,state,u,Systems)then return false,'Unsettleable terrain' end
  for _,v in ipairs(state.cities)do if Hex.distance(v.x,v.y,x,y)<3 then return false,'Cities need 3 hex spacing' end end
  for i,v in ipairs(state.units)do if v==u then table.remove(state.units,i);break end end
  table.insert(state.cities,{id=state.nextId,x=x,y=y,owner=id,level=1,population=2,foodStore=0,jobs={food=1,wood=1,science=0},buildings={}})
  local founded=state.cities[#state.cities];Systems.nameCity(state,founded)
  state.nextId=state.nextId+1;World.ensureTerritories(state,Hex,false);log(p.name..' founded '..founded.name)
 else return false,'Unknown action' end
 Hostiles.clear(state,Systems)
 World.reveal(state,Hex,Systems)
 return true
end
return A
