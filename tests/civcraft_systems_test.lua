local nativeDofile=dofile
dofile=function(p)
 if p:sub(1,10)=="/civcraft/"then return nativeDofile(p:sub(2))end
 return nativeDofile(p)
end
local S=assert(loadfile("civcraft/systems.lua"))()
local H=assert(loadfile("civcraft/hex.lua"))()
local W=assert(loadfile("civcraft/world.lua"))()
local state={version=3,nextId=3,phase="game",
 players={{id=1,name="P1",civ="verdant",techs={},food=30,wood=60,science=0},
  {id=2,name="P2",civ="iron",ai=true,food=30,wood=60,science=0}},
 cities={{id=1,owner=1,x=3,y=3},{id=2,owner=2,x=16,y=10}},units={}}
state.world=W.generate(802,"compact",2,"continents")
S.migrate(state)
local city,p=state.cities[1],state.players[1]
assert(state.version==4 and city.population==2 and city.jobs.food==1)
assert(not S.canResearch(p,"writing"),"Research prerequisites enforced")
assert(S.research(p,"agriculture"))
assert(p.researchTarget=="agriculture" and not p.techs.agriculture,
 "Research should be scheduled, not instantly purchased")
local beforeStaffing=S.yields(p,city,state,H)
assert(S.assign(city,"wood","science"))
local afterStaffing=S.yields(p,city,state,H)
assert(afterStaffing.science==beforeStaffing.science+1 and
 afterStaffing.industry==beforeStaffing.industry-1,
 "Direct +/- assignment changes projected science and industry")
assert(city.jobs.wood==0 and city.jobs.science==1)
assert(not S.assign(city,"wood","science"))
local oldPop=city.population
for i=1,8 do S.production(state,H)end
assert(p.techs.agriculture and not p.researchTarget,
 "Research completes after enough global turn science")
assert(city.population>oldPop,"Food surplus grows population")
assert(city.jobs.food+city.jobs.wood+city.jobs.science==city.population,
 "Population allocation is conserved")
assert(S.research(p,"writing"))
for i=1,10 do S.production(state,H)end
assert(p.techs.writing,"Prerequisite tech completed over turns")
assert(S.build(p,city,"farm",state,H))
assert(not city.buildings.farm,"Buildings must enter a production project")
local beforeWood=p.wood
assert(city.project.kind=="building" and city.project.id=="farm")
for i=1,6 do S.production(state,H)end
assert(city.buildings.farm and not city.project,"Building finishes on turn boundary")
assert(p.wood>=beforeWood,"No instant building purchase")
assert(not S.canRecruit(p,"horseman",state,H),"Units require technology")
assert(S.research(p,"horseback"))
for i=1,10 do S.production(state,H)end
assert(p.techs.horseback)
assert(not S.canRecruit(p,"horseman",state,H),
 "Cavalry requires strategic horses within controlled territory")
local unitBefore=#state.units
assert(S.queue(p,city,"unit","scout",state,H))
for i=1,8 do S.production(state,H)end
assert(#state.units>unitBefore,"Produced units spawn after turns")
local ai=state.players[2]
ai.ready=false
S.aiTurn(state,ai,H)
assert(ai.ready and ai.researchTarget and state.cities[2].project,
 "AI selects research and production without instant purchases")
print("CIVCRAFT: turn research/production, population, resources, AI OK")
