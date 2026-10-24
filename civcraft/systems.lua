-- CIVCRAFT 4X data & deterministic mechanics, no dependencies on UI/peripherals.
local M={}
local Content=dofile("/civcraft/content.lua")
M.civs=Content.civs
M.techs=Content.techs
M.techOrder=Content.techOrder
M.units=Content.units
M.buildings=Content.buildings
M.jobs={"food","wood","science"}
local Hex=dofile("/civcraft/hex.lua")
local World=dofile("/civcraft/world.lua")
function M.workable(state,city)
 local tiles={}
 if not state.world or not city then return tiles end
 for yy=math.max(1,city.y-2),math.min(state.world.height,city.y+2)do
  for xx=math.max(1,city.x-2),math.min(state.world.width,city.x+2)do
   if not(xx==city.x and yy==city.y) and
     Hex.distance(xx,yy,city.x,city.y)<=2 and
     World.territoryCity(state,Hex,xx,yy)==city then
    local yield=World.yields(state.world,xx,yy)
    tiles[#tiles+1]={x=xx,y=yy,key=World.key(xx,yy),yield=yield}
   end
  end
 end
 table.sort(tiles,function(a,b)
  local aa=a.yield.food+a.yield.industry+a.yield.science*2
  local bb=b.yield.food+b.yield.industry+b.yield.science*2
  if aa~=bb then return aa>bb end
  return a.y==b.y and a.x<b.x or a.y<b.y
 end)
 return tiles
end
function M.ensureWorkers(state,city)
 if not state.world or not city then return end
 local tiles=M.workable(state,city)
 local had=city.worked~=nil
 city.worked=city.worked or {}
 local available={}
 for _,t in ipairs(tiles)do available[t.key]=true end
 local count=0
 for k in pairs(city.worked)do
  if not available[k] or count>=(city.population or 2)then
   city.worked[k]=nil
  else count=count+1 end
 end
 if not had then
  for _,tile in ipairs(tiles)do
   if count>=city.population then break end
   if not city.worked[tile.key]then city.worked[tile.key]=true;count=count+1 end
  end
 end
end
function M.workTile(state,city,x,y)
 if not city or not state.world or type(x)~="number" or type(y)~="number"then
  return false,"Invalid city or hex"
 end
 M.ensureWorkers(state,city)
 local k=World.key(x,y)
 local allowed=false
 for _,tile in ipairs(M.workable(state,city))do
  if tile.key==k then allowed=true;break end
 end
 if not allowed then return false,"Hex is outside this city's workable land"end
 if city.worked[k]then city.worked[k]=nil;return true end
 local count=0;for _ in pairs(city.worked)do count=count+1 end
 if count>=city.population then return false,"No idle population; unwork a hex first"end
 city.worked[k]=true;return true
end
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
  p.researchProgress=p.researchProgress or {}
 end
 for _,c in ipairs(state.cities or {})do
  c.population=c.population or 2;c.foodStore=c.foodStore or 0
  c.jobs=c.jobs or {food=1,wood=1,science=0}
  c.buildings=c.buildings or {}
  c.projectProgress=c.projectProgress or {}
  M.ensureWorkers(state,c)
 end
 for _,u in ipairs(state.units or {})do
  local stats=M.units[u.kind] or M.units.warrior
  if u.movesLeft==nil then u.movesLeft=u.moved and 0 or stats.move end
 end
 state.version=4
 return state
end
function M.canResearch(p,id)
 local t=M.techs[id]
 if not t or p.techs[id] then return false end
 for _,req in ipairs(t.requires)do if not p.techs[req] then return false end end
 return true
end
-- Research selects a project. Science arrives at the global turn boundary.
function M.research(p,id)
 if not M.canResearch(p,id)then return false,"Technology prerequisites unmet"end
 p.researchTarget=id
 p.researchProgress=p.researchProgress or {}
 p.researchProgress[id]=p.researchProgress[id]or 0
 return true
end
function M.canBuild(p,c,id)
 local b=M.buildings[id]
 return b and (not b.tech or p.techs[b.tech]) and not c.buildings[id]
end
function M.canRecruit(p,id,state,hex)
 local u=M.units[id]
 if not u or (u.tech and not p.techs[u.tech])then return false end
 if u.unique and p.civ~=u.unique then return false end
 if u.resource and (not state or not hex or not World.strategic(state,p,hex,u.resource))then return false end
 return true
end
-- Retain familiar action names as pure queue selection (no purchases).
function M.queue(p,c,kind,id,state,hex)
 if kind=="building" then
  if not M.canBuild(p,c,id)then return false,"Building locked or already completed"end
 elseif kind=="unit" then
  if not M.canRecruit(p,id,state,hex)then
   return false,"Unit locked or missing strategic resource"
  end
 else return false,"Unknown project category"end
 c.project={kind=kind,id=id,progress=(c.projectProgress or {})[kind..":"..id]or 0}
 return true
end
function M.build(p,c,id,state,hex)return M.queue(p,c,"building",id,state,hex)end
function M.assign(c,from,to)
 if not c.jobs[from] or c.jobs[from]<=0 or c.jobs[to]==nil or from==to then
  return false,"Invalid citizen assignment"
 end
 c.jobs[from]=c.jobs[from]-1;c.jobs[to]=c.jobs[to]+1
 return true
end
function M.techCost(id)
 local tech=M.techs[id]
 return tech and tech.cost or nil
end
function M.projectCost(kind,id)
 local record=(kind=="unit" and M.units or M.buildings)[id]
 if not record then return nil end
 return record.production or record.wood or 8
end
function M.yields(p,c,state,hex,owned)
 local jobs=c.jobs
 local civ=p.civ
 local food=1+jobs.food*2+(c.buildings.farm and 2 or 0)+
  (c.buildings.market and 2 or 0)
 local industry=1+jobs.wood*2+(c.buildings.mine and 2 or 0)+
  (c.buildings.workshop and 1 or 0)+(c.buildings.bazaar and 3 or 0)+
  (c.buildings.bank and 3 or 0)
 local science=jobs.science*2+(c.buildings.library and 2 or 0)+
  (c.buildings.academy and 3 or 0)+(c.buildings.university and 4 or 0)+
  (c.buildings.observatory and 4 or 0)+(c.buildings.grandacademy and 6 or 0)
 if civ=="verdant"then food=food+(c.buildings.farm and 2 or 1)end
 if civ=="iron"then industry=industry+(c.buildings.mine and 2 or 1)end
 if civ=="scholar"then science=science+2 end
 if civ=="forge"then industry=industry+(c.buildings.workshop and 3 or 1)end
 if civ=="merchant"then food=food+(c.buildings.market and 3 or 1)end
 if civ=="highland"then industry=industry+1 end
 if civ=="sentinel"then industry=industry+(c.buildings.walls and 2 or 0)end
 if civ=="wild"then food=food+1 end
 if civ=="mariner"then food=food+1 end
 if civ=="nomad"then food=food+1 end
 if state and state.world then
  -- Replace abstract F/W/S worker counters with owned worked hexes.
  M.ensureWorkers(state,c)
  food,industry,science=2,1,1 -- city center is worked automatically
  for _,tile in ipairs(M.workable(state,c))do
   if c.worked and c.worked[tile.key]then
    food=food+tile.yield.food
    industry=industry+tile.yield.industry
    science=science+tile.yield.science
   end
  end
  food=food+(c.buildings.farm and 2 or 0)+(c.buildings.market and 2 or 0)
  industry=industry+(c.buildings.mine and 2 or 0)+
   (c.buildings.workshop and 1 or 0)+(c.buildings.bazaar and 3 or 0)+
   (c.buildings.bank and 3 or 0)
  science=science+(c.buildings.library and 2 or 0)+
   (c.buildings.academy and 3 or 0)+(c.buildings.university and 4 or 0)+
   (c.buildings.observatory and 4 or 0)+(c.buildings.grandacademy and 6 or 0)
  if civ=="verdant" and c.buildings.farm then food=food+1 end
  if civ=="iron" and c.buildings.mine then industry=industry+1 end
  if civ=="scholar" then science=science+2 end
  if civ=="forge" and c.buildings.workshop then industry=industry+2 end
  if civ=="merchant" and c.buildings.market then food=food+2 end
  -- Each assigned citizen specializes the worked land's output.
  -- This makes staffing changes affect the projected turn yields.
  food=food+(jobs.food or 0)
  industry=industry+(jobs.wood or 0)
  science=science+(jobs.science or 0)
 end
 return {food=food,industry=industry,science=science}
end
-- Stable city yield entry point for UI, AI and regression tests.
function M.cityYield(state,city)
 for _,p in ipairs(state.players or {})do
  if p.id==city.owner then return M.yields(p,city,state,Hex) end
 end
 return nil
end
local function spawn(state,p,c,id,hex)
 local stats=M.units[id]
 if not stats then return false end
 local function available(x,y)
  for _,u in ipairs(state.units)do if u.x==x and u.y==y then return false end end
  return hex.passable(x,y,state,{kind=id,owner=p.id},M)
 end
 local x,y=c.x,c.y
 if stats.naval or not available(x,y)then
  x=nil
  for _,n in ipairs(hex.neighbours(c.x,c.y,state))do
   if available(n.x,n.y)then x,y=n.x,n.y;break end
  end
 end
 if not x then return false end
 state.units[#state.units+1]={id=state.nextId,owner=p.id,x=x,y=y,
  kind=id,moved=true,movesLeft=0}
 state.nextId=state.nextId+1
 return true
end
function M.production(state,hex)
 local owned=state.world and hex and World.territory(state,hex) or {}
 for _,p in ipairs(state.players)do
  p.researchProgress=p.researchProgress or {}
  local totalScience=0
  for _,c in ipairs(state.cities)do
   if c.owner==p.id then
    local yield=M.yields(p,c,state,hex,owned)
    totalScience=totalScience+yield.science
    p.food=(p.food or 0)+yield.food
    p.wood=(p.wood or 0)+yield.industry
    c.foodStore=(c.foodStore or 0)+math.max(0,yield.food-2)
    local threshold=5+c.population*3
    if c.foodStore>=threshold then
     c.foodStore=c.foodStore-threshold
     c.population=c.population+1
     c.jobs.food=c.jobs.food+1
    end
    if c.project then
     local pr=c.project
     local valid=pr.kind=="building" and M.canBuild(p,c,pr.id) or
      pr.kind=="unit" and M.canRecruit(p,pr.id,state,hex)
     if valid then
      pr.progress=pr.progress+yield.industry
      local cost=M.projectCost(pr.kind,pr.id)
      if pr.progress>=cost then
       local completed
       if pr.kind=="building"then c.buildings[pr.id]=true;completed=true
       else completed=spawn(state,p,c,pr.id,hex)end
       if completed then
        c.project=nil;c.projectProgress=c.projectProgress or {}
        c.projectProgress[pr.kind..":"..pr.id]=nil
       end
      end
     end
     if c.project then
      c.projectProgress=c.projectProgress or {}
      c.projectProgress[pr.kind..":"..pr.id]=pr.progress
     end
    end
   end
  end
  p.scienceRate=totalScience
  p.science=(p.science or 0)+totalScience
  local id=p.researchTarget
  if id and M.canResearch(p,id)then
   local progress=(p.researchProgress[id]or 0)+totalScience
   p.researchProgress[id]=progress
   if progress>=M.techs[id].cost then
    p.techs[id]=true;p.researchTarget=nil
   end
  end
 end
end
-- AI plays by the same research and production queue rules as humans.
function M.aiTurn(state,p,hex)
 if p.ready then return end
 if not p.researchTarget then
  for _,id in ipairs(M.techOrder)do
   if M.canResearch(p,id)then M.research(p,id);break end
  end
 end
 for _,city in ipairs(state.cities)do
  if city.owner==p.id then
   if not city.project then
    for _,id in ipairs({"farm","mine","library","workshop","walls","market"})do
     if M.canBuild(p,city,id)then M.build(p,city,id,state,hex);break end
    end
    if not city.project then
     for _,id in ipairs({"settler","scout","warrior","spearman"})do
      if M.canRecruit(p,id,state,hex)then
       M.queue(p,city,"unit",id,state,hex);break
      end
     end
    end
   end
   if city.jobs.food>1 and city.jobs.science<2 then
    M.assign(city,"food","science")
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
