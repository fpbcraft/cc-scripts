-- Persistent natural landmarks and world-unique constructed wonders.
local Content=dofile('/games/civcraft/content.lua')
local Hex=dofile('/games/civcraft/hex.lua')
local L={}
local function key(x,y)return x..':'..y end
function L.generate(world)
 world.landmarks={};world.rails={}
 local kinds={'lushcavern','amethyst','mushroom','ice_spikes','dripstone','ancientcity'}
 local used={}
 for index,id in ipairs(kinds)do
  local best,score
  for y=2,world.height-1 do for x=2,world.width-1 do
   local k=key(x,y);local safe=true
   for _,p in ipairs(world.starts)do if Hex.distance(x,y,p.x,p.y)<4 then safe=false end end
   for placed in pairs(used)do local xx,yy=placed:match('^(%d+):(%d+)$');if Hex.distance(x,y,tonumber(xx),tonumber(yy))<3 then safe=false end end
   local terrain=world.tiles[k]
   if safe and not used[k] and terrain~='water' and terrain~='mountain'then
    local value=((world.seed+index*997)*48271+x*7919+y*104729)%2147483647
    if not score or value<score then best={x=x,y=y};score=value end
   end
  end end
  if best then local k=key(best.x,best.y);world.landmarks[k]={kind=id,natural=true};used[k]=true end
 end
end
function L.available(state,id)
 for _,landmark in pairs(state.world and state.world.landmarks or {})do
  if not landmark.natural and landmark.kind==id then return false end
 end
 return true
end
function L.canPlace(state,city,id,x,y,systems)
 local record=Content.wonders[id]
 if not record or not state.world or not Hex.inBounds(x,y,state)then return false end
 local player;for _,p in ipairs(state.players)do if p.id==city.owner then player=p end end
 if not player or not player.techs[record.tech] or not L.available(state,id)then return false end
 if record.coastal and not systems.coastal(state,city)then return false end
 local terrain=Hex.terrain(x,y,state);local k=key(x,y)
 if terrain=='water' or terrain=='mountain' or (state.world.landmarks or {})[k] or (state.world.rails or {})[k]then return false end
 for _,c in ipairs(state.cities)do if c.x==x and c.y==y then return false end end
 return city.claimed and city.claimed[k]==true and systems.territoryCity(state,x,y)==city
end
function L.complete(state,city,project,systems)
 if not L.canPlace(state,city,project.id,project.x,project.y,systems)then return false end
 state.world.landmarks=state.world.landmarks or {}
 state.world.landmarks[key(project.x,project.y)]={kind=project.id,cityId=city.id,natural=false}
 -- A competing city's reservation is released; its invested industry is retained.
 for _,other in ipairs(state.cities)do
  if other~=city and other.project and other.project.kind=='wonder' and other.project.id==project.id then
   other.projectProgress['wonder:'..project.id]=other.project.progress;other.project=nil
  end
 end
 return true
end
function L.effects(state,city,systems)
 local effects={food=0,industry=0,science=0,gold=0}
 for k,v in pairs(state.world and state.world.landmarks or {})do
  if not v.natural then
   local x,y=k:match('^(%d+):(%d+)$')
   if systems.territoryCity(state,tonumber(x),tonumber(y))==city then
    for name,value in pairs((Content.wonders[v.kind]or {}).effects or {})do effects[name]=effects[name]+value end
   end
  end
 end
 return effects
end
return L
