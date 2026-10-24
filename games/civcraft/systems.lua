-- CIVCRAFT 4X data & deterministic mechanics, no dependencies on UI/peripherals.
local M={}
local Content=dofile("/games/civcraft/content.lua")
M.civs=Content.civs
M.techs=Content.techs
M.techOrder=Content.techOrder
M.units=Content.units
M.buildings=Content.buildings
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
  p.explored=p.explored or {}
  p.food=p.food or 0;p.wood=p.wood or 0;p.science=p.science or 0
 end
 for _,c in ipairs(state.cities or {})do
  c.population=c.population or 2;c.foodStore=c.foodStore or 0
  c.jobs=c.jobs or {food=1,wood=1,science=0}
  c.buildings=c.buildings or {}
 end
 for _,u in ipairs(state.units or {})do
  local stats=M.units[u.kind] or M.units.warrior
  if u.movesLeft==nil then u.movesLeft=u.moved and 0 or stats.move end
 end
 state.version=3
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
     (bonus=="verdant" and c.buildings.farm and 1 or 0)+
     (c.buildings.market and 2 or 0)+
     (bonus=="merchant" and c.buildings.market and 2 or 0)
    local wood=1+jobs.wood*2+(c.buildings.mine and 2 or 0)+
     (c.buildings.workshop and 1 or 0)+
     (c.buildings.bazaar and 3 or 0)+(c.buildings.bank and 3 or 0)+
     (bonus=="forge" and c.buildings.workshop and 2 or 0)+
     (bonus=="iron" and c.buildings.mine and 1 or 0)
    local science=jobs.science*2+(c.buildings.library and 2 or 0)+
     (c.buildings.academy and 3 or 0)+
     (c.buildings.university and 4 or 0)+(c.buildings.observatory and 4 or 0)+
     (c.buildings.grandacademy and 6 or 0)+
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
  for _,id in ipairs({"farm","mine","library","walls","market","workshop","academy","university","bazaar","observatory"})do
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
    "settler" or (M.canRecruit(p,"scout") and "scout" or "warrior")
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
   local choices=hex.reachable(state,u,p.id,M)
   if u.kind=="settler" then
    local canFound=true
    for _,c in ipairs(state.cities)do
     if hex.distance(c.x,c.y,u.x,u.y)<3 then canFound=false end
    end
    if canFound and hex.passable(u.x,u.y,state,u,M)then
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
     if c.owner~=p.id and ((p.explored or {})[c.x..":"..c.y] or
       (p.visible or {})[c.x..":"..c.y]) then target=c;break end
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
       local offensive=M.units[u.kind].strength or 0
       local defensive=(M.units[rival.kind] or M.units.warrior).defense or 1
       if u.kind=="spearman" and rival.kind=="horseman"then offensive=offensive+2 end
       if offensive>=defensive then table.remove(state.units,j)
       else u.consumed=true end
       break
      end
     end
    end
    if not u.consumed then
     for _,c in ipairs(state.cities)do
      if c.x==choice.x and c.y==choice.y and c.owner~=p.id and
         M.units[u.kind].strength>0 and not choice.ranged then c.owner=p.id end
     end
     if not choice.ranged then u.x=choice.x;u.y=choice.y end
     u.moved=true;u.movesLeft=0
    end
   end
  end
 end
 for i=#state.units,1,-1 do
  if state.units[i].consumed then table.remove(state.units,i)end
 end
 p.ready=true
end
return M
