-- CIVCRAFT 4X data & deterministic mechanics, no dependencies on UI/peripherals.
local M={}
M.civs={
 {id="verdant",name="VERDANT LEAGUE",bonus="Farms +1 food"},
 {id="iron",name="IRON DOMINION",bonus="Mines +1 production"},
 {id="scholar",name="ASTRAL ACADEMY",bonus="Libraries +1 science"},
 {id="nomad",name="DUST NOMADS",bonus="Scouts move 2 hexes"},
}
M.techs={
 agriculture={name="AGRICULTURE",cost=8,requires={},unlock="farm"},
 mining={name="MINING",cost=8,requires={},unlock="mine"},
 writing={name="WRITING",cost=10,requires={"agriculture"},unlock="library"},
 bronze={name="BRONZE WORKING",cost=12,requires={"mining"},unlock="spearman"},
 masonry={name="MASONRY",cost=12,requires={"mining"},unlock="walls"},
 horseback={name="HORSEBACK RIDING",cost=15,requires={"agriculture"},unlock="horseman"},
 engineering={name="ENGINEERING",cost=18,requires={"bronze","masonry"},unlock="workshop"},
 philosophy={name="PHILOSOPHY",cost=18,requires={"writing"},unlock="academy"},
}
M.techOrder={"agriculture","mining","writing","bronze","masonry","horseback","engineering","philosophy"}
M.units={
 warrior={food=0,wood=5,move=1,strength=2},
 settler={food=8,wood=8,move=1,strength=0},
 scout={food=2,wood=4,move=2,strength=1},
 spearman={food=2,wood=9,move=1,strength=3,tech="bronze"},
 horseman={food=5,wood=12,move=2,strength=4,tech="horseback"},
}
M.buildings={
 farm={wood=6,tech="agriculture",description="+2 food"},
 mine={wood=7,tech="mining",description="+2 wood"},
 library={wood=9,tech="writing",description="+2 science"},
 walls={wood=8,tech="masonry",description="+1 defense"},
 workshop={wood=12,tech="engineering",description="+1 wood / city"},
 academy={wood=15,tech="philosophy",description="+3 science"},
}
M.jobs={"food","wood","science"}
function M.civ(id)
 for _,v in ipairs(M.civs)do if v.id==id then return v end end
 return M.civs[1]
end
function M.migrate(state)
 for i,p in ipairs(state.players or {})do
  p.civ=p.civ or M.civs[(i-1)%#M.civs+1].id
  p.techs=p.techs or {}
  p.ai=p.ai or false
  p.food=p.food or 0;p.wood=p.wood or 0;p.science=p.science or 0
 end
 for _,c in ipairs(state.cities or {})do
  c.population=c.population or 2;c.foodStore=c.foodStore or 0
  c.jobs=c.jobs or {food=1,wood=1,science=0}
  c.buildings=c.buildings or {}
 end
 for _,u in ipairs(state.units or {})do u.movesLeft=u.movesLeft or (u.moved and 0 or 1)end
 state.version=2
 return state
end
function M.canResearch(p,id)
 local t=M.techs[id]
 if not t or p.techs[id]then return false end
 for _,prereq in ipairs(t.requires)do if not p.techs[prereq]then return false end end
 return p.science>=t.cost
end
function M.research(p,id)
 if not M.canResearch(p,id)then return false,"Technology locked or insufficient science"end
 p.science=p.science-M.techs[id].cost;p.techs[id]=true
 return true
end
function M.canBuild(p,c,id)
 local b=M.buildings[id]
 return b and (not b.tech or p.techs[b.tech]) and
 not c.buildings[id] and p.wood>=b.wood
end
function M.build(p,c,id)
 if not M.canBuild(p,c,id)then return false,"Building locked, owned or too expensive"end
 p.wood=p.wood-M.buildings[id].wood;c.buildings[id]=true
 return true
end
function M.canRecruit(p,id)
 local u=M.units[id]
 return u and (not u.tech or p.techs[u.tech]) and
 p.food>=u.food and p.wood>=u.wood
end
function M.assign(c,from,to)
 if not c.jobs[from] or c.jobs[from]<=0 or not c.jobs[to] or from==to then
  return false,"Invalid worker assignment"
 end
 c.jobs[from]=c.jobs[from]-1;c.jobs[to]=c.jobs[to]+1
 return true
end
function M.production(state)
 for _,p in ipairs(state.players)do
  for _,c in ipairs(state.cities)do
   if c.owner==p.id then
    local jobs=c.jobs
    local bonus=M.civ(p.civ).id
    local food=1+jobs.food*2+(c.buildings.farm and 2 or 0)+
     (bonus=="verdant" and c.buildings.farm and 1 or 0)
    local wood=1+jobs.wood*2+(c.buildings.mine and 2 or 0)+
     (c.buildings.workshop and 1 or 0)+
     (bonus=="iron" and c.buildings.mine and 1 or 0)
    local science=jobs.science*2+(c.buildings.library and 2 or 0)+
     (c.buildings.academy and 3 or 0)+
     (bonus=="scholar" and c.buildings.library and 1 or 0)
    p.food=p.food+food;p.wood=p.wood+wood;p.science=p.science+science
    -- Growth consumes food; stores persist per settlement.
    c.foodStore=c.foodStore+math.max(0,food-2)
    local threshold=5+c.population*3
    if c.foodStore>=threshold then
     c.foodStore=c.foodStore-threshold;c.population=c.population+1
     c.jobs.food=c.jobs.food+1
    end
   end
  end
 end
end
-- Stable AI heuristics. AI turns are always processed by the authority.
function M.aiTurn(state,p,hex)
 if p.ready then return end
 local city
 for _,c in ipairs(state.cities)do if c.owner==p.id then city=c;break end end
 if city then
  for _,id in ipairs(M.techOrder)do
   if M.canResearch(p,id)then M.research(p,id);break end
  end
  for _,id in ipairs({"farm","mine","library","walls","workshop","academy"})do
   if M.canBuild(p,city,id)then M.build(p,city,id);break end
  end
  -- Grow science capacity to unlock higher-tier technology.
  if city.jobs.food>1 and city.jobs.science<2 then
   M.assign(city,"food","science")
  end
  local occupied=false
  for _,u in ipairs(state.units)do
   if u.x==city.x and u.y==city.y then occupied=true end
  end
  if not occupied then
   local ownCities=0
   for _,settlement in ipairs(state.cities)do
    if settlement.owner==p.id then ownCities=ownCities+1 end
   end
   local kind=(ownCities<5 and p.food>=8 and p.wood>=8) and
    "settler" or "warrior"
   if M.canRecruit(p,kind) then
    p.food=p.food-M.units[kind].food
    p.wood=p.wood-M.units[kind].wood
    state.units[#state.units+1]={id=state.nextId,owner=p.id,
     x=city.x,y=city.y,kind=kind,moved=false,movesLeft=0}
    state.nextId=state.nextId+1
   end
  end
 end
 -- Move one unit a turn; settlers expand, warriors approach other empires.
 for _,u in ipairs(state.units)do
  if u.owner==p.id and not u.moved then
   local choices=hex.reachable(state,u,p.id)
   if u.kind=="settler" then
    local canFound=true
    for _,c in ipairs(state.cities)do
     if hex.distance(c.x,c.y,u.x,u.y)<3 then canFound=false end
    end
    if canFound and hex.passable(u.x,u.y)then
     state.cities[#state.cities+1]={id=state.nextId,owner=p.id,
      x=u.x,y=u.y,level=1,population=2,foodStore=0,
      jobs={food=1,wood=1,science=0},buildings={}}
     state.nextId=state.nextId+1
     u.consumed=true
    end
   end
   if not u.consumed and #choices>0 then
    local target
    for _,c in ipairs(state.cities)do
     if c.owner~=p.id then target=c;break end
    end
    table.sort(choices,function(a,b)
     if u.kind=="settler" then
      local function settlementDistance(tile)
       local closest=100
       for _,c in ipairs(state.cities)do
        closest=math.min(closest,hex.distance(tile.x,tile.y,c.x,c.y))
       end
       return closest
      end
      return settlementDistance(a)>settlementDistance(b)
     end
     if not target then return a.x+a.y>b.x+b.y end
     return hex.distance(a.x,a.y,target.x,target.y)<
      hex.distance(b.x,b.y,target.x,target.y)
    end)
    local choice=choices[1]
    if choice.attack then
     for j=#state.units,1,-1 do
      local rival=state.units[j]
      if rival.owner~=p.id and rival.x==choice.x and rival.y==choice.y then
       table.remove(state.units,j)
      end
     end
    end
    for _,c in ipairs(state.cities)do
     if c.x==choice.x and c.y==choice.y and c.owner~=p.id and
        M.units[u.kind].strength>0 then c.owner=p.id end
    end
    u.x=choice.x;u.y=choice.y;u.moved=true;u.movesLeft=0
   end
  end
 end
 for i=#state.units,1,-1 do
  if state.units[i].consumed then table.remove(state.units,i)end
 end
 p.ready=true
end
return M
