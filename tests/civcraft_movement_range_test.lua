local H=assert(loadfile("games/civcraft/hex.lua"))()
local oldDofile=dofile
dofile=function(p)
 if p=="/games/civcraft/content.lua"then return oldDofile("games/civcraft/content.lua")end
 return oldDofile(p)
end
local S=assert(loadfile("games/civcraft/systems.lua"))()
dofile=oldDofile
local tiles={}
for y=1,8 do for x=1,12 do tiles[x..":"..y]="plains"end end
tiles["3:2"]="forest"
tiles["4:2"]="hills"
tiles["2:4"]="water"
tiles["3:4"]="water"
local world={width=12,height=8,seed=5,size="test",tiles=tiles}
local player={id=1,techs={},science=90,visible={}}
local enemy={id=2,techs={},science=90,visible={}}
local unit={owner=1,x=2,y=2,kind="warrior",moved=false,movesLeft=2}
local state={world=world,players={player,enemy},units={unit},cities={}}
local function find(targetX,targetY,list)
 for _,v in ipairs(list)do if v.x==targetX and v.y==targetY then return v end end
end
assert(find(3,2,H.reachable(state,unit,1,S)).cost==2,
 "Warriors can enter forests using both movement points")
unit.movesLeft=1
assert(not find(3,2,H.reachable(state,unit,1,S)))
unit.kind="scout";unit.movesLeft=4
assert(find(3,2,H.reachable(state,unit,1,S)).cost==1,
 "Scouts ignore forest movement surcharge")
local far=H.reachable(state,unit,1,S)
local maximum=0
for _,v in ipairs(far)do maximum=math.max(maximum,H.distance(2,2,v.x,v.y))end
assert(maximum>=3,"Scouts have longer movement range than warriors")
unit.kind="horseman";unit.movesLeft=2
assert(not find(4,2,H.reachable(state,unit,1,S)),
 "Mounted cavalry requires more movement points to cross hills")
unit.kind="galley";unit.x=2;unit.y=4;unit.movesLeft=3
local sea=H.reachable(state,unit,1,S)
assert(find(3,4,sea) and not find(3,3,sea),
 "Naval movement cannot leave water")
unit.kind="archer";unit.x=2;unit.y=2;unit.movesLeft=2
local target={owner=2,x=4,y=2,kind="warrior"}
state.units[2]=target
player.visible["4:2"]=true
local hit=find(4,2,H.reachable(state,unit,1,S))
assert(hit and hit.ranged and hit.attack,
 "Archer can attack a visible enemy at two hexes without moving")
player.visible={}
assert(not find(4,2,H.reachable(state,unit,1,S)),
 "Archer cannot target enemies hidden by fog at range")
local order={}
for i,id in ipairs(S.techOrder)do
 assert(S.techs[id] and S.techs[id].tier and S.techs[id].lane)
 order[id]=i
end
for _,id in ipairs(S.techOrder)do
 for _,pre in ipairs(S.techs[id].requires)do
  assert(order[pre]<order[id],"Tech graph must be acyclic and topological")
 end
end
assert(#S.civs>=10 and #S.techOrder>=24,
 "Expanded content must ship with 10 civs and 24 technologies")
print("CIVCRAFT: weighted movement, naval limits, ranged fog targeting and tech DAG passed.")
