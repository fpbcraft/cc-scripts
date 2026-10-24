-- Odd-r offset hex map: storage uses the existing x/y coordinates.
-- Pointy-top six-neighbour geometry with identical movement/server/UI rules.
local H={width=12,height=8}
function H.inBounds(x,y)return x>=1 and x<=H.width and y>=1 and y<=H.height end
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
function H.neighbours(x,y)
 local dirs=((y-1)%2==0) and
  {{-1,-1},{0,-1},{-1,0},{1,0},{-1,1},{0,1}} or
  {{0,-1},{1,-1},{-1,0},{1,0},{0,1},{1,1}}
 local out={}
 for _,d in ipairs(dirs)do
  local nx,ny=x+d[1],y+d[2]
  if H.inBounds(nx,ny)then out[#out+1]={x=nx,y=ny}end
 end
 return out
end
function H.terrain(x,y)
 local v=(x*37+y*61+x*y*13)%19
 if v<=1 then return "water"end
 if v<=3 then return "mountain"end
 if v<9 then return "forest"end
 return "plains"
end
function H.passable(x,y)return H.terrain(x,y)~="water"and H.terrain(x,y)~="mountain"end
function H.reachable(state,unit,owner)
 local out={}
 if not unit or unit.owner~=owner or unit.moved then return out end
 for _,p in ipairs(H.neighbours(unit.x,unit.y))do
  if H.passable(p.x,p.y)then
   local occupied
   for _,other in ipairs(state.units or {})do
    if other.x==p.x and other.y==p.y then occupied=other;break end
   end
   if not occupied or (occupied.owner~=owner and unit.kind=="warrior")then
    local blocked=false
    for _,city in ipairs(state.cities or {})do
     if city.x==p.x and city.y==p.y and city.owner~=owner
       and unit.kind~="warrior"then blocked=true end
    end
    if not blocked then
     out[#out+1]={x=p.x,y=p.y,attack=occupied~=nil}
    end
   end
  end
 end
 return out
end
return H
