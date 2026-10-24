-- Hex movement, offsets and player-visible path eligibility.
local H=assert(loadfile("games/civcraft/hex.lua"))()
for y=1,H.height do for x=1,H.width do
 local neighbors=H.neighbours(x,y)
 assert(#neighbors>=2 and #neighbors<=6)
 for _,p in ipairs(neighbors)do
  assert(H.distance(x,y,p.x,p.y)==1,"Neighbor must be hex adjacent")
  assert(H.inBounds(p.x,p.y))
 end
end end
assert(H.distance(2,2,2,3)==1)
assert(H.distance(2,2,3,3)==1,"Odd-row diagonal must be a legal hex move")
assert(H.distance(2,2,2,4)==2)
local state={units={},cities={}}
local unit={owner=1,x=2,y=2,kind="warrior",moved=false}
state.units[1]=unit
local open=H.reachable(state,unit,1)
for _,p in ipairs(open)do
 assert(H.distance(unit.x,unit.y,p.x,p.y)==1)
 assert(H.passable(p.x,p.y))
end
unit.moved=true;assert(#H.reachable(state,unit,1)==0)
unit.moved=false
assert(#H.reachable(state,unit,2)==0)
unit.movesLeft=2 -- A warrior can now traverse a two-cost forest hex.
state.units[2]={owner=1,x=3,y=2}
for _,p in ipairs(H.reachable(state,unit,1))do
 assert(not(p.x==3 and p.y==2),"Allied units should block destination")
end
state.units[2].owner=2
local enemyVisible=false
for _,p in ipairs(H.reachable(state,unit,1))do
 if p.x==3 and p.y==2 then enemyVisible=p.attack end
end
assert(enemyVisible,"Warriors should see legal enemy attacks")
unit.kind="settler"
for _,p in ipairs(H.reachable(state,unit,1))do
 assert(not(p.x==3 and p.y==2),"Settlers cannot attack")
end
print("CIVCRAFT hex: 6-neighbour directions, distance, blocking and movement passed.")
