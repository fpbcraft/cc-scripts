local S=assert(loadfile("civcraft/systems.lua"))()
local H=assert(loadfile("civcraft/hex.lua"))()
local state={version=1,nextId=3,players={{id=1,name="P1",civ="verdant",food=30,wood=60,science=50},{id=2,name="P2",ai=true,food=30,wood=60,science=50}},cities={{id=1,owner=1,x=2,y=2}},units={}}
S.migrate(state)
local city=state.cities[1];local p=state.players[1]
assert(state.version==2 and city.population==2 and city.jobs.food==1)
assert(not S.canResearch(p,"writing"),"Prerequisites required")
assert(S.research(p,"agriculture"))
assert(S.canResearch(p,"writing"))
assert(S.research(p,"writing"))
assert(S.build(p,city,"farm"))
assert(S.build(p,city,"library"))
assert(not S.build(p,city,"farm"),"Cannot rebuild identical improvement")
assert(S.assign(city,"wood","science"))
assert(city.jobs.wood==0 and city.jobs.science==1)
assert(not S.assign(city,"wood","science"))
local oldPop=city.population
for i=1,12 do S.production(state)end
assert(city.population>oldPop,"Food grows population")
assert(city.jobs.food+city.jobs.wood+city.jobs.science==city.population,"Workers stay balanced")
assert(not S.canRecruit(p,"horseman"),"Units require tech")
assert(S.research(p,"horseback"))
assert(S.canRecruit(p,"horseman"))
local ai=state.players[2]
state.cities[#state.cities+1]={id=2,owner=2,x=9,y=6,
 population=2,foodStore=0,jobs={food=1,wood=1,science=0},buildings={}}
ai.ready=false
S.aiTurn(state,ai,H)
assert(ai.ready and next(ai.techs)~=nil,"AI researches and ends turn")
print("CIVCRAFT expanded economy, tech, city population, buildings, units, AI: OK")
