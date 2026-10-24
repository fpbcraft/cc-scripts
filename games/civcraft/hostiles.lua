-- Bounded, deterministic wilderness opposition; never a player or city owner.
local Hex=dofile('/games/civcraft/hex.lua')
local World=dofile('/games/civcraft/world.lua')
local Combat=dofile('/games/civcraft/combat.lua')
local H={owner=-2147483647}
local function at(list,x,y)for _,v in ipairs(list or {})do if v.x==x and v.y==y then return v end end end
function H.generate(state)
 state.spawners={}
 if state.hostileMode=='off'then return end
 local candidates={};local world=state.world
 for y=2,world.height-1 do for x=2,world.width-1 do
  local safe=true;for _,s in ipairs(world.starts)do if Hex.distance(x,y,s.x,s.y)<5 then safe=false end end
  local t=Hex.terrain(x,y,state)
  if safe and t~='water' and t~='mountain' and not (world.landmarks or {})[World.key(x,y)]then candidates[#candidates+1]={x=x,y=y,score=(world.seed+x*7919+y*104729)%100003}end
 end end
 table.sort(candidates,function(a,b)return a.score<b.score end)
 local limit=math.max(1,math.floor(world.width*world.height/100))
 for _,c in ipairs(candidates)do
  local safe=true;for _,s in ipairs(state.spawners)do if Hex.distance(s.x,s.y,c.x,c.y)<4 then safe=false end end
  if safe and #state.spawners<limit then state.spawners[#state.spawners+1]={id=#state.spawners+1,x=c.x,y=c.y,kind=#state.spawners%3==2 and 'outpost' or 'spawner'}end
 end
end
function H.clear(state,systems)
 for _,s in ipairs(state.spawners or {})do if not s.cleared then
  local unit=at(state.units,s.x,s.y);local stats=unit and systems.units[unit.kind]
  if unit and unit.owner~=H.owner and stats and stats.strength>0 and stats.range==1 and not stats.naval then
   s.cleared=true
   for _,p in ipairs(state.players)do if p.id==unit.owner then p.gold=(p.gold or 0)+25;p.mobClears=(p.mobClears or 0)+1 end end
  end
 end end
end
function H.round(state,systems)
 if state.ruleset~='create' or state.hostileMode=='off' or state.hostileRound==state.round then return end
 state.hostileRound=state.round;H.clear(state,systems)
 local count=0;local per={};local mobs={}
 for _,u in ipairs(state.units)do if u.owner==H.owner then count=count+1;per[u.spawner]=(per[u.spawner]or 0)+1;mobs[#mobs+1]=u end end
 local dangerous=state.hostileMode=='dangerous';local interval=dangerous and 3 or 5
 local cap=math.floor(state.world.width*state.world.height/20)
 if state.round>5 and state.round%interval==0 then
  for _,s in ipairs(state.spawners or {})do if not s.cleared and count<cap and (per[s.id]or 0)<3 and not at(state.units,s.x,s.y) and not at(state.cities,s.x,s.y)then
   local kinds=state.round>=60 and {'zombie','skeleton','spider','creeper','pillager'} or state.round>=25 and {'zombie','skeleton','spider','creeper'} or {'zombie','skeleton','spider'}
   local kind=s.kind=='outpost' and state.round>=40 and 'pillager' or kinds[(state.round+s.id)%#kinds+1]
   state.units[#state.units+1]={id=state.nextId,owner=H.owner,kind=kind,x=s.x,y=s.y,hp=100,movesLeft=0,moved=true,spawner=s.id}
   state.nextId=state.nextId+1;count=count+1
  end end
 end
 for _,u in ipairs(mobs)do if at(state.units,u.x,u.y)==u then
  local stats=systems.units[u.kind];u.movesLeft=stats.move;u.moved=false
  -- Mobs have local sight only; they do not inspect private player discovery.
  local target,dist
  for _,list in ipairs({state.units,state.cities})do for _,v in ipairs(list)do if v.owner~=H.owner then
   local d=Hex.distance(u.x,u.y,v.x,v.y)
   if d<=stats.vision and (not dist or d<dist)then target=v;dist=d end
  end end end
  if target then
   local choices=Hex.reachable(state,u,H.owner,systems)
   table.sort(choices,function(a,b)
    if (a.attack==true)~=(b.attack==true)then return a.attack==true end
    local da=Hex.distance(a.x,a.y,target.x,target.y);local db=Hex.distance(b.x,b.y,target.x,target.y)
    if da~=db then return da<db end
    return a.y==b.y and a.x<b.x or a.y<b.y
   end)
   local c=choices[1]
   if c then if c.attack then Combat.attack(state,u,c,systems)else u.x=c.x;u.y=c.y;u.actedThisRound=true end end
  end
  u.movesLeft=0;u.moved=true
 end end
 H.clear(state,systems)
end
return H
