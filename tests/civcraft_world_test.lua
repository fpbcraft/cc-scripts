-- Deterministic worlds, seed differentiation, exploration and hotseat isolation.
local oldDofile=dofile
dofile=function(p)
 if p:sub(1,16)=="/games/civcraft/"then return oldDofile(p:sub(2))end
 return oldDofile(p)
end
local W=assert(loadfile("games/civcraft/world.lua"))()
local H=assert(loadfile("games/civcraft/hex.lua"))()
local S=assert(loadfile("games/civcraft/systems.lua"))()
dofile=oldDofile
local a=W.generate(12345,"standard",3)
local b=W.generate(12345,"standard",3)
local c=W.generate(12346,"standard",3)
local islands=W.generate(12345,"standard",3,"archipelago")
local inland=W.generate(12345,"standard",3,"pangaea")
local differing=0
for k,v in pairs(islands.tiles)do if v~=inland.tiles[k] then differing=differing+1 end end
assert(differing>30,"Map presets produce distinct geography")
assert(a.width==28 and a.height==18)
for y=1,a.height do for x=1,a.width do
 assert(a.tiles[W.key(x,y)]==b.tiles[W.key(x,y)])
end end
local differences=0
for k,v in pairs(a.tiles)do if c.tiles[k]~=v then differences=differences+1 end end
assert(differences>12,"Different seeds should produce different geography")
for _,size in ipairs({"compact","standard","large"})do
 local world=W.generate(731,size,4)
 for _,pos in ipairs(world.starts)do
  assert(W.terrain(world,pos.x,pos.y)=="plains","Start must be habitable")
 end
end
local state={world=a,players={
 {id=1,explored={}},{id=2,explored={}},{id=3,explored={}}},
 cities={{owner=1,x=2,y=2},{owner=2,x=27,y=17}},
 units={{kind="scout",owner=1,x=3,y=2},{kind="warrior",owner=2,x=26,y=17}}}
W.reveal(state,H,S)
assert(W.known(state.players[1],2,2)=="visible")
assert(W.known(state.players[1],27,17)=="hidden","Hotseat must not reveal opponent territory")
assert(W.known(state.players[2],27,17)=="visible")
state.phase="game";state.version=4;state.round=1
state.players[2].techs={mining=true}
local view=W.forPlayer(state,1)
assert(#view.cities==1 and #view.units==1,
 "Network clients must never receive unseen enemy cities or units")
assert(not view.world.tiles[W.key(27,17)] and
 not view.world.resources[W.key(27,17)],
 "Unexplored terrain and deposits must not be transmitted")
assert(not view.players[2].techs and not view.players[2].explored,
 "Opponents\' research and exploration remain private")
local old=state.players[1].explored[W.key(5,2)]
state.units[1].x=12;state.units[1].y=5
W.reveal(state,H,S)
assert(old and W.known(state.players[1],5,2)=="explored",
 "Discovery persists when scouts leave an area")
local fog=W.known(state.players[3],5,2)
assert(fog=="hidden","Third civilization must have its own map")
print("CIVCRAFT: seeded worlds, guaranteed starts, explorer sight and private discovery passed.")
