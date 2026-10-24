-- Odd-row offset pointy hexes. All geometry/pathfinding uses the same rules.
local H={width=12,height=8}
local function dims(state)
 local world=state and state.world
 return world and world.width or H.width,world and world.height or H.height
end
function H.inBounds(x,y,state)
 local w,h=dims(state)
 return x>=1 and x<=w and y>=1 and y<=h
end
function H.toCube(x,y)
 local q=x-1-math.floor((y-1-((y-1)%2))/2)
 local r=y-1
 return q,r,-q-r
end
function H.distance(x,y,xx,yy)
 local a,b,c=H.toCube(x,y)
 local d,e,f=H.toCube(xx,yy)
 return math.max(math.abs(a-d),math.abs(b-e),math.abs(c-f))
end
function H.neighbours(x,y,state)
 local dirs=((y-1)%2==0) and
  {{-1,-1},{0,-1},{-1,0},{1,0},{-1,1},{0,1}} or
  {{0,-1},{1,-1},{-1,0},{1,0},{0,1},{1,1}}
 local out={}
 for _,d in ipairs(dirs)do
  local nx,ny=x+d[1],y+d[2]
  if H.inBounds(nx,ny,state)then out[#out+1]={x=nx,y=ny}end
 end
 return out
end
function H.terrain(x,y,state)
 local world=state and state.world
 if world and world.tiles then return world.tiles[x..":"..y] or "plains"end
 local v=(x*37+y*61+x*y*13)%19
 if v<=1 then return "water"end
 if v<=3 then return "mountain"end
 if v<9 then return "forest"end
 return "plains"
end
local function statsFor(unit,Systems)
 return Systems and Systems.units and Systems.units[unit.kind] or
  ({scout={move=2,vision=3,strength=1},warrior={move=1,strength=2},
    settler={move=1,strength=0},horseman={move=2,strength=4},
    spearman={move=1,strength=3}})[unit.kind] or {move=1,strength=2}
end
function H.moveCost(x,y,state,unit,Systems)
 local t=H.terrain(x,y,state)
 local stats=statsFor(unit,Systems)
 if stats.naval then return t=="water" and 1 or nil end
 if t=="water" or t=="mountain"then return nil end
 if t=="forest" and (unit.kind=="scout" or unit.kind=="ranger") then return 1 end
 if t=="forest" and Systems and state and state.players then
  for _,p in ipairs(state.players)do
   if p.id==unit.owner and p.civ=="wild"then return 1 end
  end
 end
 if t=="forest" or t=="hills"then return unit.kind=="horseman" and 3 or 2 end
 return 1
end
function H.passable(x,y,state,unit,Systems)
 return H.moveCost(x,y,state,unit or {kind="warrior"},Systems)~=nil
end
local function occupant(state,x,y)
 for _,u in ipairs(state.units or {})do
  if u.x==x and u.y==y then return u end
 end
end
local function settlement(state,x,y)
 for _,c in ipairs(state.cities or {})do
  if c.x==x and c.y==y then return c end
 end
end
function H.reachable(state,unit,owner,Systems)
 local out={}
 if not unit or unit.owner~=owner or unit.moved then return out end
 local budget=unit.movesLeft
 if budget==nil then budget=statsFor(unit,Systems).move or 1 end
 if budget<=0 then return out end
 local stats=statsFor(unit,Systems)
 local w,h=dims(state)
 local start=unit.y*w+unit.x
 local distance={[start]=0}
 local fringe={{x=unit.x,y=unit.y,cost=0}}
 local attacks={}
 while #fringe>0 do
  table.sort(fringe,function(a,b)return a.cost<b.cost end)
  local cur=table.remove(fringe,1)
  if cur.cost==distance[cur.y*w+cur.x] then
   for _,nextHex in ipairs(H.neighbours(cur.x,cur.y,state))do
    local nx,ny=nextHex.x,nextHex.y
    local moveCost=H.moveCost(nx,ny,state,unit,Systems)
    local total=moveCost and cur.cost+moveCost
    local u=occupant(state,nx,ny)
    local c=settlement(state,nx,ny)
    local enemy=(u and u.owner~=owner) or (c and c.owner~=owner)
    if total and total<=budget then
     if enemy then
      if (stats.strength or 0)>0 and (stats.range or 1)>=1 and
        (not u or u.owner~=owner) then
       attacks[ny*w+nx]={x=nx,y=ny,cost=total,attack=true}
      end
     elseif not u and (not c or c.owner==owner) then
      local idx=ny*w+nx
      if not distance[idx] or total<distance[idx]then
       distance[idx]=total
       fringe[#fringe+1]={x=nx,y=ny,cost=total}
      end
     end
    end
   end
  end
 end
 for y=1,h do for x=1,w do
  local idx=y*w+x
  if idx~=start and distance[idx]then
   out[#out+1]={x=x,y=y,cost=distance[idx]}
  end
  if attacks[idx]then out[#out+1]=attacks[idx]end
 end end
 -- Ranged strikes do not teleport the unit into an enemy tile.
 if (stats.range or 1)>1 and (stats.strength or 0)>0 then
  for _,u in ipairs(state.units or {})do
   if u.owner~=owner and H.distance(unit.x,unit.y,u.x,u.y)<=stats.range and
     H.distance(unit.x,unit.y,u.x,u.y)>1 then
    local p=state.players or {}
    local visible=false
    for _,player in ipairs(p)do
     if player.id==owner and player.visible and player.visible[u.x..":"..u.y] then visible=true end
    end
    if visible then
     local idx=u.y*w+u.x
     if not attacks[idx]then
      out[#out+1]={x=u.x,y=u.y,cost=budget,attack=true,ranged=true}
     end
    end
   end
  end
 end
 table.sort(out,function(a,b)
  if a.cost~=b.cost then return a.cost<b.cost end
  return a.y==b.y and a.x<b.x or a.y<b.y
 end)
 return out
end
return H
