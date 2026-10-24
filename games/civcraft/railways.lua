-- Rail movement and freight networks are derived from current territory.
local Hex=dofile('/games/civcraft/hex.lua')
local World=dofile('/games/civcraft/world.lua')
local R={cost=2}
function R.owner(state,x,y)
 local rail=state.world and state.world.rails and state.world.rails[World.key(x,y)]
 if not rail then return nil end
 local city=World.territoryCity(state,Hex,x,y)
 return city and city.owner
end
function R.canBuild(state,p,unit,x,y,systems)
 if not state.world or not Hex.inBounds(x,y,state) or not p.techs.railways then return false end
 if not unit or unit.owner~=p.id or not (systems.units[unit.kind]or {}).engineer or unit.standby or (unit.movesLeft or 0)<=0 then return false end
 if Hex.distance(unit.x,unit.y,x,y)>1 then return false end
 local city=World.territoryCity(state,Hex,x,y);local k=World.key(x,y)
 local t=Hex.terrain(x,y,state)
 if not city or city.owner~=p.id or t=='water' or t=='mountain' or (state.world.landmarks or {})[k] or (state.world.rails or {})[k]then return false end
 for _,u in ipairs(state.units)do if u.owner~=p.id and u.x==x and u.y==y then return false end end
 return ((p.stockpile or {}).iron or 0)>=R.cost
end
function R.build(state,p,unit,x,y,systems)
 if not R.canBuild(state,p,unit,x,y,systems)then return false,'Rail needs an awake engineer, adjacent owned land, Railways and 2 iron'end
 state.world.rails=state.world.rails or {};state.world.rails[World.key(x,y)]=true
 p.stockpile.iron=p.stockpile.iron-R.cost;unit.movesLeft=0;unit.moved=true;unit.actedThisRound=true
 return true,'Rail segment built'
end
function R.network(state,p)
 local result={};if not state.world then return result end
 local owned=World.territory(state,Hex);local visited={}
 local stations={}
 for _,city in ipairs(state.cities)do if city.owner==p.id and (city.buildings or {}).station then stations[World.key(city.x,city.y)]=city end end
 for _,city in ipairs(state.cities)do if stations[World.key(city.x,city.y)] then
  local start=World.key(city.x,city.y)
  if not visited[start] and (state.world.rails or {})[start]then
   local queue={{x=city.x,y=city.y}};local members={};visited[start]=true;local index=1
   while index<=#queue do
    local t=queue[index];index=index+1;local k=World.key(t.x,t.y)
    if stations[k]then members[#members+1]=stations[k]end
    for _,n in ipairs(Hex.neighbours(t.x,t.y,state))do local nk=World.key(n.x,n.y)
     if not visited[nk] and owned[nk]==p.id and (state.world.rails or {})[nk]then visited[nk]=true;queue[#queue+1]=n end
    end
   end
   if #members>=2 then for _,member in ipairs(members)do result[member.id]={size=#members,cities=members}end end
  end
 end end
 return result
end
return R
