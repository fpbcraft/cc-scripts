-- The Shattered Expanse: deterministic, UI-independent turn simulation.
local C=dofile((_G.EXPANSE_ROOT or '/tidebound/expanse')..'/content.lua')
local E=dofile((_G.EXPANSE_ROOT or '/tidebound/expanse')..'/events.lua')
local M={VERSION=4,content=C,events=E}
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
local function seedstep(g)g.rng=(g.rng*48271)%2147483647;return g.rng/2147483647 end
local function roll(g,n)return 1+math.floor(seedstep(g)*n)end
local function shuffled(a,g)for i=#a,2,-1 do local j=roll(g,i);a[i],a[j]=a[j],a[i]end;return a end
local function price(f,cost)
 local r={};for k,v in pairs(cost)do r[k]=v end
 if f.tech.engineering>=2 and r.materials then r.materials=math.max(1,math.floor(r.materials*.8))end
 if f.archetype==4 and r.credits then r.credits=math.max(1,r.credits-1)end
 return r
end
local function canAfford(f,cost)
 for key,n in pairs(cost)do if (f[key] or 0)<n then return false,key end end
 return true
end
local function pay(f,cost) for key,n in pairs(cost)do f[key]=(f[key] or 0)-n end end
local function link(g,a,b)
 for _,e in ipairs(g.links)do if (e[1]==a and e[2]==b) or (e[1]==b and e[2]==a)then return true end end
 return false
end
local function neighbors(g,a)
 local t={};for _,e in ipairs(g.links)do if e[1]==a then t[#t+1]=e[2] elseif e[2]==a then t[#t+1]=e[1] end end
 return t
end
local function bordered(g,a,p)
 for _,b in ipairs(neighbors(g,a))do if g.systems[b].owner==p then return true end end
 return false
end
M.neighbors=neighbors;M.link=link;M.bordered=bordered;M.price=price;M.canAfford=canAfford
local function log(g,message)
 table.insert(g.log,1,"Y"..g.round.." "..message)
 while #g.log>65 do table.remove(g.log)end
end
M.log=log
local function makeShip(g,p,kind,location)
 g.nextShip=g.nextShip+1
 local spec=C.shipClasses[kind]
 local ship={id=g.nextShip,owner=p,kind=kind,location=location,ap=spec.ap,veterancy=0,name=spec.name.." #"..g.nextShip}
 g.ships[#g.ships+1]=ship
 return ship
end
local function shipsAt(g,system,owner)
 local list={};for _,v in ipairs(g.ships)do if v.location==system and (not owner or v.owner==owner)then list[#list+1]=v end end
 return list
end
M.shipsAt=shipsAt
local function findShip(g,id)
 for _,ship in ipairs(g.ships)do if ship.id==id then return ship end end
 return nil
end
M.findShip=findShip
local function owns(g,p)
 local count=0;for _,s in ipairs(g.systems)do if s.owner==p then count=count+1 end end;return count
end
M.owns=owns
local function treatyKey(a,b,k)return math.min(a,b)..":"..math.max(a,b)..":"..k end
local function hasTreaty(g,a,b,k)return g.treaties[treatyKey(a,b,k)]~=nil end
local function atWar(g,a,b)return g.wars[treatyKey(a,b,"war")]~=nil end
M.hasTreaty=hasTreaty;M.atWar=atWar
local function relation(g,a,b)
 if a==b then return 100 end
 local fa=g.factions[a];return clamp(fa.relations[b] or 0,-100,100)
end
M.relation=relation
local function changeRelation(g,a,b,amount)
 for _,pair in ipairs({{a,b},{b,a}})do
  local f=g.factions[pair[1]];f.relations[pair[2]]=clamp((f.relations[pair[2]] or 0)+amount,-100,100)
 end
end
local function learn(g,p,s)
 g.factions[p].seen[s.id]=true
 for _,n in ipairs(neighbors(g,s.id))do g.factions[p].charted[n]=true end
end
local function reveal(g,p,count)
 local f=g.factions[p];local options={}
 for id=1,#g.systems do if not f.seen[id] then options[#options+1]=id end end
 for i=1,math.min(count,#options) do
  local ix=roll(g,#options);local id=table.remove(options,ix) -- approximate random draw is deliberately non-strategic
  learn(g,p,g.systems[id]);f.seen[id]=true
 end
end
local function queueEvent(g,p,key,system,chain)
 local f=g.factions[p];if f.eventSeen[key] and not chain then return false end
 local e=E.make(key,system,chain)
 if not e then return false end
 f.eventSeen[key]=true
 f.events[#f.events+1]=e
 log(g,f.name.." encounters: "..e.title)
 return true
end
local function exploreEvent(g,p,s)
 local f=g.factions[p];local context=s.kind=="RELIC" and "relic" or s.kind=="RIFT" and "rift" or s.neutral and "neutral" or "general"
 if (g.round-f.lastEvent)<2 and #f.events>0 then return end
 if roll(g,100)> ((context=="relic" or context=="rift") and 80 or 40) then return end
 local options=E.eligible(g,p,context)
 if #options==0 then options=E.eligible(g,p,"general")end
 if #options>0 and queueEvent(g,p,options[roll(g,#options)],s.id) then f.lastEvent=g.round end
end
local function typeOf(g,p)
 return C.archetypes[g.factions[p].archetype]
end
function M.new(config)
 config=config or {}
 local seed=tonumber(config.seed) or 827139
 if seed<=0 then seed=seed+2147483646 end
 local g={version=4,seed=seed,rng=seed%2147483647,round=1,limit=config.rounds or 24,
  systems={},links={},factions={},ships={},nextShip=0,treaties={},wars={},log={},order={1,2,3,4},turnIndex=1,
  ended=false,winner=nil,reason=nil,galactic={rift=false,aetherCrisis=false,awakening=false},queued={}}
 local n=40
 for i=1,n do
  local col=(i-1)%8;local row=math.floor((i-1)/8)
  local x=.07+.86*col/7+(seedstep(g)-.5)*.033
  local y=.11+.78*row/4+(seedstep(g)-.5)*.045
  local kind=C.systemTypes[roll(g,#C.systemTypes)]
  g.systems[i]={id=i,name=C.names[i],x=clamp(x,.035,.965),y=clamp(y,.04,.96),kind=kind,
   owner=0,colony=0,buildings={},construction=nil,shipQueue=nil,neutral=(kind=="FREEPORT" or kind=="SANCTUARY") and roll(g,5)==1,
   anomaly=(kind=="RELIC" or kind=="RIFT") and roll(g,5)~=1,
   investigated={},deposit=kind=="RIFT" and 2 or 0,stability=70}
 end
 local edges={};for i=1,n do for j=i+1,n do
  local a,b=g.systems[i],g.systems[j]
  edges[#edges+1]={i,j,(a.x-b.x)^2*1.25+(a.y-b.y)^2}
 end end
 table.sort(edges,function(a,b)return a[3]<b[3] end)
 local parent={};local degree={}
 for i=1,n do parent[i]=i;degree[i]=0 end
 local function root(i)while i~=parent[i]do i=parent[i] end;return i end
 local function add(a,b)g.links[#g.links+1]={a,b};degree[a]=degree[a]+1;degree[b]=degree[b]+1 end
 for _,e in ipairs(edges)do
  local a,b=root(e[1]),root(e[2]);if a~=b then parent[a]=b;add(e[1],e[2])end
 end
 for _,e in ipairs(edges)do
  if e[3]<.038 and degree[e[1]]<4 and degree[e[2]]<4 and not link(g,e[1],e[2]) and roll(g,10)<=6 then add(e[1],e[2])end
 end
 local home={1,8,33,40}
 local names=config.names or {}
 for p=1,4 do
  local arch=(config.archetypes and config.archetypes[p]) or p
  arch=clamp(math.floor(tonumber(arch) or p),1,4)
  local c=C.archetypes[arch]
  local f={id=p,name=tostring(names[p] or c.name):upper():gsub("[^%w _%-]",""):sub(1,16),
   archetype=arch,human=not (config.humans and config.humans[p]==false),credits=22,materials=18,research=4,aether=0,
   prestige=0,stability=68,tech={engineering=0,physics=0,society=0,exploration=0},seen={},charted={},events={},eventSeen={},
   delayed={},relations={},offers={},lastEvent=-10,policy="BALANCED",policyRound=0,marketRound=0,leader=C.leaders[((p-1)*2+roll(g,2)-1)%#C.leaders+1],
   ethics={compassion=0,authority=0,curiosity=0},
   personality=(arch==1 and "RUTHLESS" or c.trait),discovered=0,losses=0,kills=0,colonies=1,project=nil}
  if f.name=="" then f.name=c.name end
  g.factions[p]=f
  for q=1,4 do if q~=p then f.relations[q]=arch==2 and 14 or arch==1 and -7 or 3 end end
  local s=g.systems[home[p]];s.owner=p;s.name=({"CROWN","HARMONY","ORACLE","LIBERTY"})[p]
  s.kind="CORE";s.colony=1;s.buildings={shipyard=1};s.neutral=false;s.anomaly=false;s.stability=75
  learn(g,p,s)
  makeShip(g,p,"scout",s.id);makeShip(g,p,"builder",s.id);makeShip(g,p,"frigate",s.id)
  if arch==1 then makeShip(g,p,"frigate",s.id) end
  f.discovered=1
 end
 for p=1,4 do
  for q=1,4 do if p~=q then
   if g.factions[p].archetype==2 and g.factions[q].archetype==2 then changeRelation(g,p,q,6)end
  end end
 end
 log(g,"Four successor powers enter the Shattered Expanse.")
 return g
end
function M.current(g)return g.order[g.turnIndex] end
function M.stock(g,p)
 local f=g.factions[p];return string.format("C%d M%d R%d A%d",f.credits,f.materials,f.research,f.aether)
end
function M.score(g,p)
 local f=g.factions[p];local tech=0;for _,lv in pairs(f.tech)do tech=tech+lv end
 local military=0;for _,sh in ipairs(g.ships)do if sh.owner==p then military=military+C.shipClasses[sh.kind].power end end
 local pact=0;for key,_ in pairs(g.treaties)do if key:find("^"..p..":") or key:find(":"..p..":")then pact=pact+1 end end
 return owns(g,p)*8+f.colonies*5+tech*6+f.prestige+military+math.floor((f.credits+f.materials)/14)+f.aether*3+pact*5
end
function M.projectProgress(g,p)
 local f=g.factions[p];local colonized=0;for _,s in ipairs(g.systems)do if s.owner==p and s.colony>0 then colonized=colonized+1 end end
 local alliances=0;for q=1,4 do if q~=p and hasTreaty(g,p,q,"alliance")then alliances=alliances+1 end end
 return {systems=owns(g,p),colonies=colonized,alliances=alliances,score=M.score(g,p)}
end
function M.income(g,p)
 local f=g.factions[p];local inc={credits=1,materials=1,research=1,aether=0};local mine,exchange,laboratory=0,0,0
 for _,s in ipairs(g.systems)do if s.owner==p then
  if s.colony>0 then
   inc.credits=inc.credits+2+s.colony;inc.materials=inc.materials+1
   inc.research=inc.research+1
   if s.kind=="FORGE" then inc.materials=inc.materials+1 end
   if s.kind=="SANCTUARY" then inc.credits=inc.credits+1 end
   if f.tech.engineering>=4 then inc.materials=inc.materials+1 end
   if f.tech.society>=4 then inc.credits=inc.credits+2 end
  end
  mine=mine+(s.buildings.mine or 0);exchange=exchange+(s.buildings.exchange or 0);laboratory=laboratory+(s.buildings.lab or 0)
  inc.materials=inc.materials+(s.buildings.mine or 0)*(3+((s.kind=="FORGE" or s.kind=="MINERAL") and 1 or 0)+(f.tech.engineering>=1 and 1 or 0))
  inc.credits=inc.credits+(s.buildings.exchange or 0)*4
  inc.research=inc.research+(s.buildings.lab or 0)*(3+(s.kind=="RELIC" and 2 or 0))
  if s.kind=="RIFT" and not g.galactic.aetherCrisis then inc.aether=inc.aether+(s.buildings.extractor or 0) end
 end end
 if f.archetype==2 then inc.research=inc.research+2 end
 if f.archetype==4 then inc.credits=inc.credits+2 end
 if f.archetype==3 then inc.research=inc.research+1 end
 if f.personality=="PRAGMATIC" then inc.credits=inc.credits+1 end
 if f.personality=="CURIOUS" then inc.research=inc.research+1 end
 for q=1,4 do if q~=p then
  if hasTreaty(g,p,q,"trade")then inc.credits=inc.credits+2 end
  if hasTreaty(g,p,q,"research")then inc.research=inc.research+2 end
 end end
 local warships=0
 for _,sh in ipairs(g.ships)do if sh.owner==p and C.shipClasses[sh.kind].power>0 then warships=warships+1 end end
 inc.credits=inc.credits-math.floor(warships/3)
 if f.policy=="INDUSTRY" then inc.materials=inc.materials+3;inc.research=inc.research-1
 elseif f.policy=="SCHOLARSHIP" then inc.research=inc.research+3;inc.credits=inc.credits-2
 elseif f.policy=="MERCANTILE" then inc.credits=inc.credits+4;inc.materials=inc.materials-1 end
 return inc
end
local function applyEffect(g,p,e)
 local f=g.factions[p]
 for _,key in ipairs({"credits","materials","research","aether","prestige","stability"})do
  if e[key] then
   local v=(f[key] or 0)+e[key]
   f[key]= key=="stability" and clamp(v,5,100) or math.max(0,v)
  end
 end
 if e.trust then for q=1,4 do if q~=p then changeRelation(g,p,q,e.trust)end end end
 if e.visibility then reveal(g,p,e.visibility)end
end
local function popEvents(g,p)
 local f=g.factions[p]
 local ready={}
 for i=#f.delayed,1,-1 do
  if f.delayed[i].round<=g.round then table.insert(ready,1,f.delayed[i]);table.remove(f.delayed,i)end
 end
 for _,t in ipairs(ready)do queueEvent(g,p,t.key,t.system,true)end
end
local function researchCosts(f,branch)
 if type(branch)~="string" or not f.tech[branch] then return nil end
 local rank=f.tech[branch]+1
 local t=C.tech[branch]
 if not t or not t[rank] then return nil end
 local price=t[rank].cost
 if f.archetype==3 and (branch=="physics" or branch=="exploration") then price=math.max(5,price-2)end
 return price
end
M.researchCost=researchCosts
function M.validate(g,p,kind,a)
 a=a or {};if g.ended then return false,"Game has ended" end
 if M.current(g)~=p then return false,"Not your turn" end
 local f=g.factions[p]
 if #f.events>0 and kind~="choose"then return false,"Resolve your pending event first" end
 local s=a.system and g.systems[a.system] or nil
 local ship=a.ship and findShip(g,a.ship) or nil
 local function requireShip(typeKind)
  if not ship or ship.owner~=p then return false,"Select one of your ships" end
  if typeKind and ship.kind~=typeKind then return false,"Wrong ship type" end
  if ship.ap<1 then return false,"This ship has no orders remaining" end
  return true
 end
 if kind=="choose"then
  if not f.events[1] then return false,"No decision pending"end
  local eventChoice=f.events[1].choices[a.choice]
  if not eventChoice then return false,"Invalid decision"end
  for _,resource in ipairs({"credits","materials","research","aether"})do
   local delta=(eventChoice.effect or {})[resource] or 0
   if delta<0 and f[resource]<-delta then return false,"Requires "..(-delta).." "..resource end
  end
  return true
 elseif kind=="move"then
  local ok,why=requireShip();if not ok then return false,why end
  if not s or ship.location==s.id or not link(g,ship.location,s.id) then return false,"Destination must be a connected neighboring star" end
  if ship.kind=="builder" and s.owner>0 and s.owner~=p then return false,"Builders cannot enter hostile territory"end
  if atWar(g,p,s.owner or 0)==false and s.owner>0 and s.owner~=p and ship.kind~="scout" and ship.kind~="builder" then
   if not hasTreaty(g,p,s.owner,"alliance") then return false,"Foreign space is closed without an alliance or war"end
  end
  return true
 elseif kind=="survey"then
  local ok,why=requireShip("scout");if not ok then return false,why end
  if not s or ship.location~=s.id then return false,"Science ship must be in this system"end
  if f.seen[s.id] then return false,"This star has already been surveyed"end
  return true
 elseif kind=="anomaly"then
  local ok,why=requireShip("scout");if not ok then return false,why end
  if not s or ship.location~=s.id or not s.anomaly or s.investigated[p] then return false,"No new anomaly for this vessel to study"end
  return true
 elseif kind=="claim"then
  local ok,why=requireShip("builder");if not ok then return false,why end
  if not s or ship.location~=s.id or s.owner~=0 then return false,"Builder must be at an unclaimed system"end
  if not bordered(g,s.id,p) then return false,"Outpost must border your territory"end
  if not f.seen[s.id] then return false,"Survey system with a science ship first"end
  if s.neutral then return false,"This inhabited system requires peaceful integration"end
  local cost=price(f,{credits=5,materials=f.tech.exploration>=3 and 4 or 7})
  if not canAfford(f,cost)then return false,"Not enough Credits or Materials for the outpost"end
  return true
 elseif kind=="integrate"then
  if not s or not s.neutral or s.owner~=0 or not bordered(g,s.id,p) or not f.seen[s.id] then return false,"Explore a neighboring independent settlement first"end
  if f.tech.society<1 then return false,"Requires EMBASSIES research"end
  if not canAfford(f,price(f,{credits=16,materials=5}))then return false,"Requires 16 Credits and 5 Materials"end
  return true
 elseif kind=="colonize"then
  local ok,why=requireShip("builder");if not ok then return false,why end
  if not s or ship.location~=s.id or s.owner~=p or s.colony~=0 then return false,"Builder must be at one of your undeveloped outposts"end
  if not canAfford(f,price(f,{credits=9,materials=9}))then return false,"Requires 9 Credits and 9 Materials"end
  return true
 elseif kind=="upgrade"then
  if not s or s.owner~=p or s.colony==0 then return false,"Select a colony you control"end
  if s.colony>=3 then return false,"Colony is fully developed"end
  if s.construction then return false,"Finish the existing construction first"end
  if not canAfford(f,price(f,{credits=11*s.colony,materials=9*s.colony}))then return false,"Insufficient funds for colony expansion"end
  return true
 elseif kind=="build"then
  local b=C.buildings[a.building]
  if not b then return false,"Unknown structure"end
  if not s or s.owner~=p or s.colony==0 then return false,"A colony you own is required"end
  if s.construction then return false,"A construction project is already underway here"end
  local slots=2+s.colony+ (f.tech.engineering>=3 and 1 or 0)+(f.tech.society>=2 and 1 or 0)+(f.tech.exploration>=3 and 1 or 0)
  local used=0;for _,n in pairs(s.buildings)do used=used+n end
  if used>=slots then return false,"No free building slots; upgrade this colony"end
  if b.id=="extractor" or a.building=="extractor" then if s.kind~="RIFT" then return false,"Aether extraction requires a Rift World" end end
  if s.buildings[a.building] and s.buildings[a.building]>=2 then return false,"Maximum of two per structure type"end
  if not canAfford(f,price(f,b.cost))then return false,"Insufficient resources: "..M.stock(g,p)end
  return true
 elseif kind=="shipbuild"then
  local spec=C.shipClasses[a.class]
  if not spec then return false,"Unknown ship class"end
  if not s or s.owner~=p or not s.buildings.shipyard or s.buildings.shipyard<1 then return false,"Requires a shipyard in your territory"end
  if s.shipQueue then return false,"Shipyard is already constructing a vessel"end
  if a.class=="cruiser" and f.tech.physics<2 then return false,"Requires CRUISER HULLS"end
  if a.class=="capital" and f.tech.physics<3 then return false,"Requires AETHER DRIVES"end
  if not canAfford(f,price(f,spec.cost))then return false,"Insufficient Credits, Materials, or Aether"end
  return true
 elseif kind=="research"then
  local cost=researchCosts(f,a.branch)
  if not cost then return false,"Research branch is complete"end
  if f.research<cost then return false,"Requires "..cost.." Research"end
  return true
 elseif kind=="market" then
  if a.item~="aether" then return false,"Only Aether is traded at this exchange"end
  if f.marketRound==g.round then return false,"Aether exchange limited to one purchase per year"end
  local cost=g.galactic.aetherCrisis and 32 or 20
  if f.credits<cost then return false,"Requires "..cost.." Credits"end
  return true
 elseif kind=="policy"then
  if a.policy~="BALANCED" and a.policy~="INDUSTRY" and a.policy~="SCHOLARSHIP" and a.policy~="MERCANTILE" then return false,"Unknown civic policy"end
  if f.policyRound==g.round then return false,"Civic policy may change once per round"end
  if f.credits<4 then return false,"Changing policy costs 4 Credits"end
  return true
 elseif kind=="diplomacy"then
  local to=a.to;local k=a.pact
  if type(to)~="number" or to<1 or to>4 or to==p then return false,"Select a rival civilization"end
  if not C.pacts[k] or k=="peace" then return false,"Unknown diplomatic accord"end
  if atWar(g,p,to)then return false,"Diplomatic agreements are suspended during war"end
  if hasTreaty(g,p,to,k)then return false,"Agreement already exists"end
  if k=="alliance" and relation(g,p,to)<10 then return false,"Relations must be at least +10 to propose an alliance"end
  if f.credits<3 then return false,"Diplomacy requires 3 Credits"end
  for _,o in ipairs(g.factions[to].offers)do if o.from==p and o.pact==k then return false,"Offer is awaiting a response"end end
  return true
 elseif kind=="war"then
  if not a.to or a.to==p or not g.factions[a.to] then return false,"Choose a rival"end
  if atWar(g,p,a.to)then return false,"Already at war"end
  return true
 elseif kind=="peace"then
  if not a.to or not atWar(g,p,a.to)then return false,"No ongoing war with that rival"end
  for _,o in ipairs(g.factions[a.to].offers)do if o.from==p and o.pact=="peace" then return false,"Peace offer already pending" end end
  return true
 elseif kind=="assault"then
  local ok,why=requireShip();if not ok then return false,why end
  if C.shipClasses[ship.kind].power<=0 then return false,"Only warships can assault"end
  if not s or ship.location~=s.id or s.owner==0 or s.owner==p then return false,"Must attack an enemy-held system"end
  if not atWar(g,p,s.owner)then return false,"Declare war before an assault"end
  local enemy=shipsAt(g,s.id,s.owner)
  if #enemy>0 then return false,"Destroy enemy fleet before occupation"end
  return true
 elseif kind=="project"then
  if f.project then return false,"A grand project is already active"end
  local target=a.victory
  if target=="science"then
   if f.tech.physics<4 or f.tech.exploration<4 then return false,"Requires completed Physics and Exploration trees"end
   if not canAfford(f,{credits=35,materials=40,aether=4})then return false,"Needs C35 M40 A4"end
  elseif target=="economic"then
   if f.credits<125 or f.materials<65 or f.colonies<5 then return false,"Needs C125 M65 and 5 developed colonies"end
  elseif target=="diplomatic"then
   local alliances=0;for q=1,4 do if q~=p and hasTreaty(g,p,q,"alliance")then alliances=alliances+1 end end
   if f.tech.society<3 or alliances<2 then return false,"Needs GALACTIC CHARTER and two defensive alliances"end
   if not canAfford(f,{credits=45,materials=18})then return false,"Needs C45 M18"end
  else return false,"Unknown victory project"end
  return true
 elseif kind=="offer_reply"then
  if not f.offers[1] then return false,"No diplomatic proposal to answer"end
  return true
 end
 return false,"Unknown order: "..tostring(kind)
end
local function battle(g,loc,attacker)
 local enemy=0
 for _,v in ipairs(g.ships)do if v.location==loc and v.owner~=attacker and atWar(g,attacker,v.owner) and C.shipClasses[v.kind].power>0 then enemy=v.owner;break end end
 if enemy==0 then return end
 local a,b=0,0;local aa,bb={},{ }
 for _,v in ipairs(g.ships)do if v.location==loc and C.shipClasses[v.kind].power>0 then
  local power=C.shipClasses[v.kind].power+(g.factions[v.owner].tech.physics>=1 and 1 or 0)+(g.factions[v.owner].archetype==1 and 2 or 0)+math.floor(v.veterancy/2)
  if v.owner==attacker then a=a+power;aa[#aa+1]=v elseif v.owner==enemy then b=b+power;bb[#bb+1]=v end
 end end
 b=b+(g.systems[loc].owner==enemy and (g.systems[loc].buildings.bastion or 0)*4 or 0)
 a=a+roll(g,4)-1;b=b+roll(g,4)-1
 local victorious=a>=b and attacker or enemy
 local losers=victorious==attacker and bb or aa
 local survivors=victorious==attacker and aa or bb
 for _,sh in ipairs(losers)do
  for i=#g.ships,1,-1 do if g.ships[i].id==sh.id then table.remove(g.ships,i);break end end
 end
 for _,sh in ipairs(survivors)do sh.veterancy=sh.veterancy+1 end
 local damaged= #survivors>1 and roll(g,5)==1
 if damaged then
  local sh=survivors[#survivors];for i=#g.ships,1,-1 do if g.ships[i].id==sh.id then table.remove(g.ships,i);break end end
 end
 g.factions[victorious].kills=g.factions[victorious].kills+#losers
 g.factions[victorious==attacker and enemy or attacker].losses=g.factions[victorious==attacker and enemy or attacker].losses+#losers
 log(g,g.factions[victorious].name.." wins the battle at "..g.systems[loc].name)
end
function M.command(g,p,kind,a)
 a=a or {}
 local ok,why=M.validate(g,p,kind,a)
 if not ok then return false,why end
 local f=g.factions[p];local s=a.system and g.systems[a.system] or nil
 local sh=a.ship and findShip(g,a.ship) or nil
 local msg="Order completed"
 if kind=="choose"then
  local ev=table.remove(f.events,1);local option=ev.choices[a.choice]
  applyEffect(g,p,option.effect or {})
  if option.follow then f.delayed[#f.delayed+1]={key=option.follow.key,round=g.round+option.follow.delay,system=ev.system}end
  f.prestige=f.prestige+1
  local fx=option.effect or {}
  if (fx.trust or 0)>0 or (fx.stability or 0)>6 then f.ethics.compassion=f.ethics.compassion+2 end
  if (fx.trust or 0)<0 or (fx.stability or 0)<0 then f.ethics.authority=f.ethics.authority+2 end
  if (fx.research or 0)>5 or fx.visibility then f.ethics.curiosity=f.ethics.curiosity+2 end
  msg=ev.title..": "..option.label
  log(g,f.name.." chooses "..option.label)
 elseif kind=="move"then
  sh.ap=sh.ap-1;sh.location=s.id
  f.charted[s.id]=true
  if sh.kind=="scout" and not f.seen[s.id] then
   learn(g,p,s);f.discovered=f.discovered+1
   exploreEvent(g,p,s)
  end
  if sh.kind~="scout" and not f.seen[s.id] and s.owner==p then learn(g,p,s)end
  if C.shipClasses[sh.kind].power>0 then battle(g,s.id,p)end
  msg=sh.name.." enters "..s.name
 elseif kind=="survey"then
  sh.ap=sh.ap-1;learn(g,p,s);f.discovered=f.discovered+1;exploreEvent(g,p,s)
  msg="Surveys completed at "..s.name
 elseif kind=="anomaly"then
  sh.ap=sh.ap-1;s.investigated[p]=true
  local reward=(f.tech.exploration>=2 and 13 or 8)+(f.personality=="CURIOUS" and 2 or 0)
  f.research=f.research+reward
  if s.kind=="RIFT" and roll(g,3)==1 then f.aether=f.aether+1 end
  exploreEvent(g,p,s);msg="Anomaly studied: +"..reward.." Research"
 elseif kind=="claim"then
  pay(f,price(f,{credits=5,materials=f.tech.exploration>=3 and 4 or 7}));sh.ap=sh.ap-1;s.owner=p;f.prestige=f.prestige+2
  msg="Outpost established at "..s.name
 elseif kind=="integrate"then
  pay(f,price(f,{credits=16,materials=5}));s.owner=p;s.neutral=false;s.colony=1;f.colonies=f.colonies+1;f.prestige=f.prestige+8
  msg=s.name.." joins "..f.name.." peacefully"
 elseif kind=="colonize"then
  pay(f,price(f,{credits=9,materials=9}));sh.ap=sh.ap-1;s.colony=1;f.colonies=f.colonies+1;f.prestige=f.prestige+2
  msg=s.name.." becomes a colony"
 elseif kind=="upgrade"then
  pay(f,price(f,{credits=11*s.colony,materials=9*s.colony}));s.construction={type="upgrade",remaining=2}
  msg="Colony development queued (2 years)"
 elseif kind=="build"then
  local spec=C.buildings[a.building];pay(f,price(f,spec.cost))
  s.construction={type="building",id=a.building,remaining=spec.time}
  msg=spec.name.." queued ("..spec.time.." years)"
 elseif kind=="shipbuild"then
  local spec=C.shipClasses[a.class];pay(f,price(f,spec.cost))
  s.shipQueue={id=a.class,remaining=a.class=="capital" and 3 or a.class=="cruiser" and 2 or 1}
  msg=spec.name.." ordered at "..s.name
 elseif kind=="research"then
  local t=C.tech[a.branch][f.tech[a.branch]+1];f.research=f.research-researchCosts(f,a.branch)
  f.tech[a.branch]=f.tech[a.branch]+1;f.prestige=f.prestige+2
  msg="Research complete: "..t.name
 elseif kind=="market"then
  local cost=g.galactic.aetherCrisis and 32 or 20
  f.credits=f.credits-cost;f.aether=f.aether+1;f.marketRound=g.round
  msg="Purchased 1 Aether on the exchange"
 elseif kind=="policy"then
  f.credits=f.credits-4;f.policy=a.policy;f.policyRound=g.round
  msg="Civic policy is now "..a.policy
 elseif kind=="diplomacy"then
  f.credits=f.credits-3
  g.factions[a.to].offers[#g.factions[a.to].offers+1]={from=p,pact=a.pact}
  msg=C.pacts[a.pact].name.." offered to "..g.factions[a.to].name
 elseif kind=="offer_reply"then
  local offer=table.remove(f.offers,1)
  if a.accept then
   if offer.pact=="peace" then
    g.wars[treatyKey(p,offer.from,"war")]=nil
    changeRelation(g,p,offer.from,15)
   else
    g.treaties[treatyKey(p,offer.from,offer.pact)]={since=g.round}
    changeRelation(g,p,offer.from,7)
   end
   msg="Agreement signed: "..C.pacts[offer.pact].name
  else
   changeRelation(g,p,offer.from,-2);msg="Proposal declined"
  end
 elseif kind=="war"then
  local q=a.to;g.wars[treatyKey(p,q,"war")]={since=g.round}
  for k,_ in pairs(C.pacts)do g.treaties[treatyKey(p,q,k)]=nil end
  changeRelation(g,p,q,-40)
  f.prestige=f.prestige-3
  msg=f.name.." declares war on "..g.factions[q].name
 elseif kind=="peace"then
  local q=a.to;g.factions[q].offers[#g.factions[q].offers+1]={from=p,pact="peace"}
  msg="Ceasefire offered to "..g.factions[q].name
 elseif kind=="assault"then
  sh.ap=sh.ap-1
  local power=0;for _,u in ipairs(shipsAt(g,s.id,p))do power=power+C.shipClasses[u.kind].power end
  local defense=2+s.colony*2+(s.buildings.bastion or 0)*5
  if power+roll(g,4)>=defense then
   local previous=s.owner;s.owner=p
   if s.colony>0 then
    g.factions[previous].colonies=math.max(0,g.factions[previous].colonies-1);f.colonies=f.colonies+1
   end
   f.prestige=f.prestige+5;msg=""..s.name.." occupied by "..f.name
  else
   msg="Assault repelled by planetary defenses"
   f.materials=math.max(0,f.materials-2)
  end
 elseif kind=="project"then
  if a.victory=="science"then pay(f,{credits=35,materials=40,aether=4})
  elseif a.victory=="economic"then pay(f,{credits=125,materials=65})
  elseif a.victory=="diplomatic"then pay(f,{credits=45,materials=18}) end
  f.project={type=a.victory,remaining=3}
  msg="Grand project launched. Complete in three years."
 end
 if kind~="choose" and kind~="offer_reply" then log(g,f.name..": "..msg)end
 return true,msg
end
local function progress(g)
 for p=1,4 do
  local f=g.factions[p];local income=M.income(g,p)
  for k,v in pairs(income)do f[k]=math.max(0,(f[k] or 0)+v)end
  f.prestige=f.prestige+(f.stability>75 and 1 or 0)
  for _,s in ipairs(g.systems)do if s.owner==p then
   if s.construction then
    s.construction.remaining=s.construction.remaining-1
    if s.construction.remaining<=0 then
     local job=s.construction;s.construction=nil
     if job.type=="upgrade"then s.colony=s.colony+1
     elseif job.type=="building"then s.buildings[job.id]=(s.buildings[job.id] or 0)+1 end
     log(g,s.name.." completes "..(job.id or "colony expansion"))
    end
   end
   if s.shipQueue then
    s.shipQueue.remaining=s.shipQueue.remaining-1
    if s.shipQueue.remaining<=0 then local kind=s.shipQueue.id;s.shipQueue=nil;makeShip(g,p,kind,s.id)
     log(g,f.name.." launches a "..kind.." at "..s.name) end
   end
  end end
  if f.project then
   f.project.remaining=f.project.remaining-1
   if f.project.remaining<=0 then
    g.ended=true;g.winner=p;g.reason=string.upper(f.project.type).." VICTORY"
   end
  end
  for _,ship in ipairs(g.ships)do if ship.owner==p then
   ship.ap=C.shipClasses[ship.kind].ap+(ship.kind=="scout" and f.tech.exploration>=1 and 1 or 0)
  end end
 end
 if g.round==9 then g.galactic.aetherCrisis=true;log(g,"GALACTIC EVENT: Aether supplies collapse for two years.")end
 if g.round==11 then g.galactic.aetherCrisis=false;log(g,"Aether shipping routes stabilize.")end
 if g.round==15 then g.galactic.awakening=true;log(g,"GALACTIC EVENT: Ancient sentinels stir across the frontier.")end
 if g.round==18 then g.galactic.rift=true;log(g,"GALACTIC EVENT: Rift storms destabilize travel lanes.")end
 if g.round==20 then g.galactic.rift=false;log(g,"Rift storms subside.")end
 local totalOwned=0;for _,s in ipairs(g.systems)do if s.owner>0 then totalOwned=totalOwned+1 end end
 for p=1,4 do if owns(g,p)>=22 then g.ended=true;g.winner=p;g.reason="DOMINATION VICTORY" end end
 if g.round>=g.limit and not g.ended then
  local best=-1;for p=1,4 do local score=M.score(g,p);if score>best then best=score;g.winner=p end end
  g.ended=true;g.reason="LEGACY VICTORY"
 end
end
function M.endTurn(g,p)
 if M.current(g)~=p then return false,"Not your turn"end
 if #g.factions[p].events>0 then return false,"Resolve your pending decision"end
 if #g.factions[p].offers>0 then return false,"Answer your diplomatic messages"end
 g.turnIndex=g.turnIndex+1
 if g.turnIndex>4 then
  g.turnIndex=1;g.round=g.round+1
  local first=table.remove(g.order,1);g.order[#g.order+1]=first
  progress(g)
  for q=1,4 do popEvents(g,q)end
 end
 return true,"Turn ended"
end
function M.canAccept(g,p,offer)
 local from=g.factions[offer.from];local to=g.factions[p]
 local score=relation(g,p,offer.from)
 if offer.pact=="peace" then return g.round>3 end
 if to.archetype==2 then score=score+15 end
 if to.archetype==1 then score=score-12 end
 if offer.pact=="alliance" then score=score-20 end
 if offer.pact=="trade" and to.archetype==4 then score=score+15 end
 if offer.pact=="research" and to.archetype==3 then score=score+15 end
 if to.personality=="RUTHLESS" then
  score=score-10
  if offer.pact=="nonaggression" and score<30 then return false end
 end
 if to.ethics.compassion>to.ethics.authority then score=score+8 end
 return score>=-5
end
function M.aiTurn(g,p)
 local f=g.factions[p];if f.human or M.current(g)~=p then return false end
 local safety=0
 while #f.events>0 and safety<20 do
  safety=safety+1;local e=f.events[1];local choice=1
  if f.personality=="RUTHLESS" and #e.choices>=2 then choice=2 elseif f.personality=="CAUTIOUS" then choice=math.min(#e.choices,3)end
  for i=1,#e.choices do
   if M.validate(g,p,"choose",{choice=choice}) then break end
   choice=choice%#e.choices+1
  end
  M.command(g,p,"choose",{choice=choice})
 end
 while #f.offers>0 do local offer=f.offers[1];M.command(g,p,"offer_reply",{accept=M.canAccept(g,p,offer)})end
 -- Economy and research decisions are resource-limited, not action-limited.
 local priorities=f.archetype==3 and {"exploration","physics","engineering","society"}
   or f.archetype==2 and {"society","exploration","engineering","physics"}
   or f.archetype==1 and {"physics","engineering","society","exploration"}
   or {"engineering","society","exploration","physics"}
 -- Scholarly empires complete their two key branches instead of broadly spreading research.
 if f.archetype==3 then
  priorities=(f.tech.exploration<=f.tech.physics) and {"exploration","physics","engineering","society"} or {"physics","exploration","engineering","society"}
 end
 for _,branch in ipairs(priorities)do
  local ok=M.validate(g,p,"research",{branch=branch});if ok then M.command(g,p,"research",{branch=branch});break end
 end
 local colonies={};for _,s in ipairs(g.systems)do if s.owner==p and s.colony>0 then colonies[#colonies+1]=s end end
 local saveForScience=f.archetype==3 and f.tech.physics>=3 and f.tech.exploration>=3
 local saveForEconomy=f.archetype==4 and g.round>=16 and f.colonies>=4
 for _,s in ipairs(colonies)do
  local inc=M.income(g,p)
  local priority= inc.materials<6 and "mine" or inc.research<5 and "lab" or inc.credits<7 and "exchange" or "lab"
  if f.archetype==3 and inc.research<16 and inc.materials>=5 then priority="lab" end
  if f.archetype==4 and inc.credits<25 then priority="exchange" end
  if f.archetype==1 and inc.materials<8 then priority="mine" end
  if f.credits<30 or inc.credits<7 then priority="exchange" end
  if s.kind=="RIFT" and (s.buildings.extractor or 0)<2 then priority="extractor"end
  if not s.construction and not (saveForScience or saveForEconomy) then
   local tried={priority,"mine","exchange","lab","shipyard","extractor"}
   local built=false
   for _,id in ipairs(tried)do
    if M.validate(g,p,"build",{system=s.id,building=id}) then
     M.command(g,p,"build",{system=s.id,building=id});built=true;break
    end
   end
   if not built and M.validate(g,p,"upgrade",{system=s.id}) then M.command(g,p,"upgrade",{system=s.id})end
  end
  if s.buildings.shipyard and not s.shipQueue and #g.ships<110 and not (saveForScience or saveForEconomy) then
   local fleetCount=0;for _,sh in ipairs(g.ships)do if sh.owner==p and C.shipClasses[sh.kind].power>0 then fleetCount=fleetCount+1 end end
   local scouts,builders=0,0
   for _,sh in ipairs(g.ships)do if sh.owner==p then
    if sh.kind=="scout"then scouts=scouts+1 elseif sh.kind=="builder"then builders=builders+1 end
   end end
   local wanted=nil
   if g.round>=4 and scouts<2 and f.materials>=8 then wanted="scout"
   elseif g.round>=6 and builders<2 and f.materials>=8 then wanted="builder"
   elseif fleetCount<(f.archetype==1 and 5 or 2)+math.floor(g.round/(f.archetype==1 and 3 or 6)) and f.materials>10 and f.credits>=24 then
    wanted=(f.tech.physics>=2 and g.round>10 and f.credits>35) and "cruiser" or "frigate"
   end
   if wanted and M.validate(g,p,"shipbuild",{system=s.id,class=wanted}) then
    M.command(g,p,"shipbuild",{system=s.id,class=wanted})
   end
  end
 end
 -- Scouts push toward uncharted systems and gather events.
 for _,sh in ipairs(g.ships)do if sh.owner==p and sh.kind=="scout"then
  for _=1,sh.ap do
   local sys=g.systems[sh.location]
   if sys.anomaly and not sys.investigated[p] then M.command(g,p,"anomaly",{ship=sh.id,system=sys.id})
   else
    local options=neighbors(g,sh.location);local target=nil
    for _,id in ipairs(options)do if not f.seen[id] and bordered(g,id,p)then target=id;break end end
    if not target then for _,id in ipairs(options)do if not f.seen[id] then target=id;break end end end
    if not target then for _,id in ipairs(options)do if g.systems[id].owner==0 then target=id;break end end end
    if target then M.command(g,p,"move",{ship=sh.id,system=target}) else break end
   end
  end
 end end
 -- Construction ships expand surveyed borders and settle outposts.
 for _,sh in ipairs(g.ships)do if sh.owner==p and sh.kind=="builder"then
  if sh.ap>=1 then
   local here=g.systems[sh.location]
   if here.owner==p and here.colony==0 and M.validate(g,p,"colonize",{ship=sh.id,system=here.id}) then
    M.command(g,p,"colonize",{ship=sh.id,system=here.id})
   elseif here.owner==0 and f.seen[here.id] and bordered(g,here.id,p) and M.validate(g,p,"claim",{ship=sh.id,system=here.id})then
    M.command(g,p,"claim",{ship=sh.id,system=here.id})
   else
    local moved=false
    for _,id in ipairs(neighbors(g,sh.location))do
     local dest=g.systems[id]
     if dest.owner==0 and f.seen[id] and bordered(g,id,p) and not dest.neutral then
      if M.validate(g,p,"move",{ship=sh.id,system=id})then
       M.command(g,p,"move",{ship=sh.id,system=id});moved=true
      end
      if M.validate(g,p,"claim",{ship=sh.id,system=id})then M.command(g,p,"claim",{ship=sh.id,system=id})end
      break
     end
    end
    if not moved and g.systems[sh.location].owner==p then
     -- Navigate through owned systems toward any still-claimable frontier.
     local queue={sh.location};local head=1;local parent={[sh.location]=false};local goal=nil
     while queue[head] and not goal do
      local at=queue[head];head=head+1
      for _,id in ipairs(neighbors(g,at))do
       local dest=g.systems[id]
       if dest.owner==0 and f.seen[id] and bordered(g,id,p) and not dest.neutral then
        goal=at;break
       elseif dest.owner==p and parent[id]==nil then parent[id]=at;queue[#queue+1]=id end
      end
     end
     if goal and goal~=sh.location then
      local next=goal
      while parent[next] and parent[next]~=sh.location do next=parent[next]end
      if M.validate(g,p,"move",{ship=sh.id,system=next})then M.command(g,p,"move",{ship=sh.id,system=next})end
     end
    end
   end
  end
 end end
 -- Specialists conserve late-game rare resources for a scientific or economic finish.
 if f.archetype==3 and f.tech.physics>=2 and f.tech.exploration>=2 and f.aether<4 and f.credits>=25 then
  if M.validate(g,p,"market",{item="aether"})then M.command(g,p,"market",{item="aether"})end
 end
 -- Diplomats seek cooperation before starting wars.
 if g.round%4==0 and f.credits>=8 then
  local other=nil;for q=1,4 do if q~=p and not atWar(g,p,q) then
    if not hasTreaty(g,p,q,"trade") and M.validate(g,p,"diplomacy",{to=q,pact="trade"}) then other=q;break end
  end end
  if other then M.command(g,p,"diplomacy",{to=other,pact="trade"}) end
 end
 -- Personality-led diplomacy: peaceful AI creates trust, empire-builders consider military force.
 if g.round>=6 and f.credits>=8 then
  for q=1,4 do if q~=p and not atWar(g,p,q) then
   local proposed=nil
   if f.tech.society>=3 and relation(g,p,q)>12 and not hasTreaty(g,p,q,"alliance") then
    proposed="alliance"
   elseif relation(g,p,q)>=0 and not hasTreaty(g,p,q,"nonaggression") then
    proposed="nonaggression"
   elseif relation(g,p,q)>4 and not hasTreaty(g,p,q,"research") then proposed="research" end
   if proposed and M.validate(g,p,"diplomacy",{to=q,pact=proposed})then
    M.command(g,p,"diplomacy",{to=q,pact=proposed});break
   end
  end end
 end
 if g.round>6 and (f.personality=="RUTHLESS" or f.archetype==1) then
  for q=1,4 do if q~=p and not atWar(g,p,q) and not hasTreaty(g,p,q,"nonaggression") and not hasTreaty(g,p,q,"alliance") then
   local border=false;local aPower,bPower=0,0
   for _,ss in ipairs(g.systems)do if ss.owner==q and bordered(g,ss.id,p) then border=true end end
   for _,ship in ipairs(g.ships)do
    if ship.owner==p then aPower=aPower+C.shipClasses[ship.kind].power end
    if ship.owner==q then bPower=bPower+C.shipClasses[ship.kind].power end
   end
   if border and aPower>bPower*.85 and relation(g,p,q)<25 and g.round>=11 then
    M.command(g,p,"war",{to=q});break
   end
  end end
 end
 -- Warships opportunistically reinforce borders, but do not declare random wars.
 for _,sh in ipairs(g.ships)do if sh.owner==p and C.shipClasses[sh.kind].power>0 and sh.ap>0 then
  local target=nil
  for _,n in ipairs(neighbors(g,sh.location))do
   local s=g.systems[n]
   if s.owner>0 and s.owner~=p and atWar(g,p,s.owner) then target=n;break end
  end
  if not target then
   -- Find a shortest route through friendly territory to an active enemy border.
   local queue={sh.location};local head=1;local prev={[sh.location]=false};local frontier=nil
   while queue[head] and not frontier do
    local at=queue[head];head=head+1
    for _,n in ipairs(neighbors(g,at))do
     local system=g.systems[n]
     if system.owner>0 and system.owner~=p and atWar(g,p,system.owner) then frontier=at;break end
     if system.owner==p and prev[n]==nil then prev[n]=at;queue[#queue+1]=n end
    end
   end
   if frontier and frontier~=sh.location then
    local cursor=frontier
    while prev[cursor] and prev[cursor]~=sh.location do cursor=prev[cursor]end
    target=cursor
   end
  end
  if target and M.validate(g,p,"move",{ship=sh.id,system=target})then
   M.command(g,p,"move",{ship=sh.id,system=target})
   if M.validate(g,p,"assault",{ship=sh.id,system=target})then M.command(g,p,"assault",{ship=sh.id,system=target})end
  end
 end end
 if not f.project and g.round<=g.limit-3 then
  if M.validate(g,p,"project",{victory="economic"}) then M.command(g,p,"project",{victory="economic"})
  elseif M.validate(g,p,"project",{victory="science"}) then M.command(g,p,"project",{victory="science"}) end
 end
 if g.round<=g.limit-3 and f.archetype==2 and f.tech.society>=3 then
  if M.validate(g,p,"project",{victory="diplomatic"})then M.command(g,p,"project",{victory="diplomatic"})end
 end
 -- AI must resolve anything discovered during its orders before yielding.
 local final=0
 while #f.events>0 and final<24 do
  final=final+1
  local event=f.events[1]
  local ix=(f.personality=="RUTHLESS" and #event.choices>=2) and 2 or 1
  for i=1,#event.choices do
   if M.validate(g,p,"choose",{choice=ix})then break end
   ix=ix%#event.choices+1
  end
  M.command(g,p,"choose",{choice=ix})
 end
 while #f.offers>0 do
  M.command(g,p,"offer_reply",{accept=M.canAccept(g,p,f.offers[1])})
 end
 return M.endTurn(g,p)
end
function M.advanceAI(g)
 local n=0
 while not g.ended and not g.factions[M.current(g)].human and n<12 do
  local p=M.current(g);local ok=M.aiTurn(g,p);if not ok then break end;n=n+1
 end
 return n
end
function M.validateState(g)
 if type(g)~="table" or g.version~=4 or #g.systems~=40 or #g.factions~=4 then return false,"Invalid save/version"end
 if type(g.order)~="table" or #g.order~=4 or g.turnIndex<1 or g.turnIndex>4 then return false,"Invalid turn"end
 for _,f in ipairs(g.factions)do
  if type(f.seen)~="table" or type(f.tech)~="table" or f.credits<0 or f.materials<0 or f.research<0 or f.aether<0 then return false,"Corrupted economy"end
 end
 return true
end
return M