-- TIDEBOUND: STELLAR FRONTIER v3.0
-- Local 2-player CC:Tweaked space 4X. Optional CC: Graphics v0.2+ pixel-mode renderer.
-- Run: tidebound [monitor-name] | texlua tidebound.lua --self-test
local argv={...}
if #argv==0 and type(arg)=="table" and arg[1] then argv[1]=arg[1] end
local VERSION=3
local SHORT_NAMES={"SOL","NOVA"}
local KIND={"TERRAN","ORE","NEBULA","PLASMA","RELIC","ICE"}
local SYSNAMES={"ASTER","VEGA","DENEB","LYRA","NASH","ARCADIA","CYGNUS","PROXIMA","VESTA","KOR","RHEA","ZENITH","HELIX","SIRIUS","ORION","ATLAS","NEXUS","ERIDAN","IONA","KHEPRI","TALOS","MERIDIAN","KEPLER","TITAN","PHOBOS","MIRA","ELARA","XENON","DRACO","AEGIS"}
local PALETTE={
  [0]=0x090E1D,[1]=0x111B30,[2]=0x1A2A40,[3]=0x294058,[4]=0x435A72,[5]=0x819BB5,
  [6]=0xD5E5F1,[7]=0xF9FBFF,[8]=0x36B9C4,[9]=0x5BEEE3,[10]=0x305EAA,[11]=0x78A9FF,
  [12]=0x9852BD,[13]=0xDDA9FA,[14]=0xA95B65,[15]=0xFF9A9A,[16]=0xCB9B4C,[17]=0xF4CC79,
  [18]=0x2D795C,[19]=0x7FE4A4,[20]=0xD36D37,[21]=0xF8AB64,[22]=0x6D729E,[23]=0xD4D0C2,
  [24]=0x142238,[25]=0x25354D,[26]=0xFFDBAA,[27]=0x4D899A,[28]=0x171429,[29]=0x5D3C73,
  [30]=0xA1B4C9,[31]=0x2B263F,
}
local TEXT_COLORS={
 [0]=32768,[1]=128,[2]=2048,[3]=1024,[4]=256,[5]=8,[6]=1,[7]=1,[8]=512,[9]=32,
 [10]=2048,[11]=8,[12]=8192,[13]=1024,[14]=16384,[15]=16384,[16]=4096,[17]=16,
 [18]=8192,[19]=32,[20]=2,[21]=2,[22]=1024,[23]=1,[24]=128,[25]=2048,[26]=16,
 [27]=512,[28]=32768,[29]=8192,[30]=8,[31]=128,
}
local FONT={
 A={"01110","10001","10001","11111","10001","10001","10001"},B={"11110","10001","10001","11110","10001","10001","11110"},
 C={"01111","10000","10000","10000","10000","10000","01111"},D={"11110","10001","10001","10001","10001","10001","11110"},
 E={"11111","10000","10000","11110","10000","10000","11111"},F={"11111","10000","10000","11110","10000","10000","10000"},
 G={"01111","10000","10000","10111","10001","10001","01111"},H={"10001","10001","10001","11111","10001","10001","10001"},
 I={"11111","00100","00100","00100","00100","00100","11111"},J={"00111","00010","00010","00010","10010","10010","01100"},
 K={"10001","10010","10100","11000","10100","10010","10001"},L={"10000","10000","10000","10000","10000","10000","11111"},
 M={"10001","11011","10101","10101","10001","10001","10001"},N={"10001","11001","10101","10011","10001","10001","10001"},
 O={"01110","10001","10001","10001","10001","10001","01110"},P={"11110","10001","10001","11110","10000","10000","10000"},
 Q={"01110","10001","10001","10001","10101","10010","01101"},R={"11110","10001","10001","11110","10100","10010","10001"},
 S={"01111","10000","10000","01110","00001","00001","11110"},T={"11111","00100","00100","00100","00100","00100","00100"},
 U={"10001","10001","10001","10001","10001","10001","01110"},V={"10001","10001","10001","10001","10001","01010","00100"},
 W={"10001","10001","10001","10101","10101","10101","01010"},X={"10001","10001","01010","00100","01010","10001","10001"},
 Y={"10001","10001","01010","00100","00100","00100","00100"},Z={"11111","00001","00010","00100","01000","10000","11111"},
 ["0"]={"01110","10011","10101","10101","11001","10001","01110"},["1"]={"00100","01100","00100","00100","00100","00100","01110"},
 ["2"]={"01110","10001","00001","00010","00100","01000","11111"},["3"]={"11110","00001","00001","00110","00001","00001","11110"},
 ["4"]={"00010","00110","01010","10010","11111","00010","00010"},["5"]={"11111","10000","11110","00001","00001","10001","01110"},
 ["6"]={"00111","01000","10000","11110","10001","10001","01110"},["7"]={"11111","00001","00010","00100","01000","01000","01000"},
 ["8"]={"01110","10001","10001","01110","10001","10001","01110"},["9"]={"01110","10001","10001","01111","00001","00010","11100"},
 ["-"]={"00000","00000","00000","11111","00000","00000","00000"},["+"]={"00000","00100","00100","11111","00100","00100","00000"},
 ["."]={"00000","00000","00000","00000","00000","00110","00110"},[":"]={"00000","00110","00110","00000","00110","00110","00000"},
 ["/"]={"00001","00001","00010","00100","01000","10000","10000"},["?"]={"01110","10001","00001","00010","00100","00000","00100"},
 ["!"]={"00100","00100","00100","00100","00100","00000","00100"},["("]={"00010","00100","01000","01000","01000","00100","00010"},
 [")"]={"01000","00100","00010","00010","00010","00100","01000"},["="]={"00000","11111","00000","11111","00000","00000","00000"},
 ["'"]={"00100","00100","00000","00000","00000","00000","00000"},["#"]={"01010","11111","01010","11111","01010","00000","00000"},
 [" "]={"00000","00000","00000","00000","00000","00000","00000"},
}
local ICON={
 star={"00100","00100","11111","01110","11011","10001","00000"},
 planet={"01110","11011","10101","11101","10101","11011","01110"},
 ship={"00100","01110","11111","10101","11111","01010","10001"},
 scan={"11111","10001","10101","10101","10101","10001","11111"},
 flag={"10000","11110","11011","11110","10000","10000","10000"},
 colony={"00100","01110","11111","11111","10101","10101","11111"},
 mine={"10001","01010","00100","11111","01110","01110","00100"},
 forge={"00100","01110","11111","10111","01110","01110","00100"},
 lab={"00100","01110","01110","00100","01110","11111","11111"},
 dock={"10101","11111","01110","01110","01110","10101","10001"},
 fort={"10101","11111","11111","11111","01110","01110","00100"},
 energy={"00110","01100","11111","00110","01100","11000","10000"},
 alloy={"00100","01110","11111","11111","11111","01110","00100"},
 science={"10001","01010","00100","01110","01110","11111","01110"},
 influence={"00100","01110","10101","11111","01110","00100","00100"},
 research={"11011","01010","01110","00100","01110","01010","11011"},
 move={"00100","00110","11111","00110","00100","00000","00000"},
 war={"10001","01010","00100","01110","10101","10101","10001"},
 trade={"10010","11101","00100","10111","01001","00000","00000"},
 next={"10000","11000","11100","11110","11100","11000","10000"},
 back={"00001","00011","00111","01111","00111","00011","00001"},
 help={"01110","10001","00001","00110","00100","00000","00100"},
 trophy={"10001","11111","11111","01110","00100","01110","11111"},
 check={"00001","00011","10110","11100","01000","00000","00000"},
 close={"10001","01010","00100","01010","10001","00000","00000"},
 orbit={"01110","10001","10101","10101","10101","10001","01110"},
}
local function rng(seed)
 local s=(tonumber(seed) or 2026)%2147483647
 return function(n) s=(s*48271)%2147483647;return n and (1+s%n) or s/2147483647 end
end
local function clamp(n,l,h)return math.max(l,math.min(h,n)) end
local function deepcopy(t)
 if type(t)~="table" then return t end
 local a={};for k,v in pairs(t)do a[k]=deepcopy(v) end;return a
end
local function trunc(s,n)
 s=tostring(s or ""):upper();if #s>n then return s:sub(1,n-1).."." end;return s
end
local function properName(s)
 return tostring(s or ""):upper():gsub("[^A-Z0-9 _%-]",""):sub(1,13)
end
local function other(p)return 3-p end
local function findLink(g,a,b)
 for _,e in ipairs(g.links)do if (e[1]==a and e[2]==b) or (e[2]==a and e[1]==b) then return true end end
 return false
end
local function neighbors(g,id)
 local t={};for _,edge in ipairs(g.links) do if edge[1]==id then t[#t+1]=edge[2] elseif edge[2]==id then t[#t+1]=edge[1] end end
 return t
end
local function border(g,id,p)
 for _,n in ipairs(neighbors(g,id))do if g.systems[n].owner==p then return true end end
 return false
end
local function fleetReach(g,from,to,p)
 if findLink(g,from,to) then return true end
 if g.tech[p].NAVIGATION==0 then return false end
 for _,step in ipairs(neighbors(g,from))do
  if g.systems[step].owner==p and findLink(g,step,to) then return true end
 end
 return false
end
local function newGame(a,b,shape,rounds,seed)
 local random=rng(seed);local g={version=VERSION,seed=seed or 44821,round=1,limit=rounds or 18,turn=1,ap=3,
  names={properName(a)~="" and properName(a) or SHORT_NAMES[1],properName(b)~="" and properName(b) or SHORT_NAMES[2]},
  shape=shape or "CLUSTER",systems={},links={},capital={},resources={},tech={},logs={},pact=false,offer=0,conquests={0,0},result=nil}
 local pos={}
 local number=24
 for i=1,number do
  local col=(i-1)%6;local row=math.floor((i-1)/6)
  local x=.09+.82*col/5+(random()-.5)*.047
  local y=.105+.79*row/3+(random()-.5)*.068
  if shape=="SPIRAL" then
   local theta=math.atan2 and math.atan2(y-.5,x-.5) or math.atan(y-.5,x-.5)
   y=clamp(y+math.sin(theta*1.5)*.034,.07,.93)
  end
  pos[i]={x=clamp(x,.055,.945),y=clamp(y,.075,.925)}
  g.systems[i]={id=i,name=SYSNAMES[i],x=pos[i].x,y=pos[i].y,kind=KIND[random(#KIND)],
   owner=0,known=false,colony=false,buildings={mine=0,forge=0,lab=0,dock=0,fort=0},ships={0,0}}
 end
 local edges={};for i=1,number do for j=i+1,number do
  local dx=(pos[i].x-pos[j].x)*1.1;local dy=pos[i].y-pos[j].y
  edges[#edges+1]={i,j,dx*dx+dy*dy}
 end end
 table.sort(edges,function(a,b)return a[3]<b[3] end)
 local parent={};for i=1,number do parent[i]=i end
 local function root(i)while parent[i]~=i do i=parent[i] end;return i end
 local degree={};for i=1,number do degree[i]=0 end
 local function add(a,b)
  g.links[#g.links+1]={a,b};degree[a]=degree[a]+1;degree[b]=degree[b]+1
 end
 for _,e in ipairs(edges)do
  local aa,bb=root(e[1]),root(e[2]);if aa~=bb then parent[aa]=bb;add(e[1],e[2]) end
 end
 for _,e in ipairs(edges)do
  if e[3]<.053 and degree[e[1]]<4 and degree[e[2]]<4 and random()<.56 and not findLink(g,e[1],e[2]) then add(e[1],e[2]) end
 end
 g.capital[1]=7;g.capital[2]=18
 for p=1,2 do
  local s=g.systems[g.capital[p]];s.name=p==1 and "SOL PRIME" or "NOVA PRIME";s.kind="TERRAN";
  s.owner=p;s.known=true;s.colony=true;s.buildings.dock=1;s.ships[p]=3
  g.resources[p]={energy=14,alloy=12,science=7,influence=10}
  g.tech[p]={NAVIGATION=0,REACTORS=0,WEAPONS=0,UNITY=0}
  for _,id in ipairs(neighbors(g,s.id))do g.systems[id].known=true end
 end
 return g
end
local function addLog(g,message)
 table.insert(g.logs,1,("Y%02d %s"):format(g.round,tostring(message)))
 while #g.logs>24 do table.remove(g.logs)end
end
local ACTIONS={
 scan={title="SURVEY",icon="scan",desc="Reveal a neighboring unsurveyed system. May find salvage.",cost={energy=2},ap=1},
 annex={title="ANNEX",icon="flag",desc="Add a surveyed neutral system to your empire.",cost={influence=3},ap=1},
 colonize={title="COLONIZE",icon="colony",desc="Found a colony. It grows your income and victory score.",cost={alloy=5,energy=2},ap=1},
 mine={title="EXTRACTORS",icon="mine",desc="Build mines: +2 alloy/year on ORE; +2 energy elsewhere.",cost={alloy=4,energy=1},ap=1},
 forge={title="FOUNDRY",icon="forge",desc="Build a foundry: +2 alloy production each year.",cost={alloy=5,energy=1},ap=1},
 lab={title="LABORATORY",icon="lab",desc="Build a lab: +2 science production each year.",cost={alloy=4,energy=1},ap=1},
 dock={title="SHIPYARD",icon="dock",desc="Build an orbital shipyard to unlock fleet construction.",cost={alloy=6,energy=2},ap=1},
 build={title="BUILD FLEET",icon="ship",desc="Add two frigates at this system (maximum eight).",cost={alloy=4,energy=1},ap=1},
 dispatch={title="DISPATCH",icon="move",desc="Send ships along a starlane. Hostile systems trigger battle.",cost={energy=1},ap=1},
 fort={title="STARBASE",icon="fort",desc="Add +3 defense power against enemy fleet invasions.",cost={alloy=4,energy=1},ap=1},
}
local TECH={
 {key="NAVIGATION",icon="move",title="HYPERDRIVES",desc="Ships can cross two starlanes via a friendly midpoint."},
 {key="REACTORS",icon="energy",title="REACTORS",desc="Each colony generates +1 energy per level every year."},
 {key="WEAPONS",icon="war",title="ARMAMENTS",desc="Each ship gains +1 battle power per level."},
 {key="UNITY",icon="influence",title="CIVIC UNITY",desc="Gain +1 influence each year per level."},
}
local function costString(cost)
 local a={};for _,k in ipairs({"energy","alloy","science","influence"})do
  if cost[k] then a[#a+1]=k:sub(1,1):upper()..cost[k] end
 end
 return #a>0 and table.concat(a," ") or "FREE"
end
local function owns(g,p)
 local c=0;for _,s in ipairs(g.systems)do if s.owner==p then c=c+1 end end;return c
end
local function points(g,p)
 local score=g.conquests[p]*2
 for _,s in ipairs(g.systems)do if s.owner==p then score=score+1+(s.colony and 2 or 0) end end
 for _,v in pairs(g.tech[p])do score=score+v*2 end
 return score
end
local function techCost(g,p,key)return 6+g.tech[p][key]*5 end
local function actionReason(g,key,id)
 local s=g.systems[id];local p=g.turn;local a=ACTIONS[key]
 if not a then return "Unknown order" end
 if g.ap<a.ap then return "No command points left" end
 local r=g.resources[p];for k,v in pairs(a.cost)do if r[k]<v then return "Need "..v.." "..k end end
 if key=="scan" then
  if s.known then return "Already surveyed" end
  if not border(g,id,p) then return "Requires a bordering owned system" end
 elseif key=="annex" then
  if not s.known or s.owner~=0 then return "Needs a surveyed neutral system" end
  if not border(g,id,p) and s.ships[p]==0 then return "Requires adjacent territory or fleet" end
 elseif key=="colonize" then
  if s.owner~=p then return "Select your own system" end
  if s.colony then return "Already colonized" end
 elseif key=="dispatch" then
  if s.ships[p]<1 then return "No ships to dispatch" end
 elseif key=="build" then
  if s.owner~=p or not s.colony or s.buildings.dock==0 then return "Needs a colony with shipyard" end
  if s.ships[p]>6 then return "Fleet capacity eight" end
 else
  if s.owner~=p or not s.colony then return "Needs your colonized system" end
  if (s.buildings[key] or 0)>=((key=="mine" or key=="forge" or key=="lab") and 2 or 1) then return "Building limit reached" end
 end
 return nil
end
local function pay(g,cost,ap)
 local p=g.turn;local r=g.resources[p]
 for k,v in pairs(cost)do r[k]=r[k]-v end
 g.ap=g.ap-(ap or 1)
end
local function updateWinner(g)
 if owns(g,1)==0 then g.result=2 elseif owns(g,2)==0 then g.result=1 end
 if points(g,1)>=40 or points(g,2)>=40 then
  if points(g,1)~=points(g,2)then g.result=points(g,1)>points(g,2) and 1 or 2 end
 end
end
local function execute(g,key,id)
 local why=actionReason(g,key,id);if why then return false,why end
 local p=g.turn;local s=g.systems[id]
 if key=="dispatch" then return false,"Choose a route on the map" end
 pay(g,ACTIONS[key].cost)
 if key=="scan" then
  s.known=true
  local event=(id*7+g.round+g.seed)%5
  if event==0 then g.resources[p].science=g.resources[p].science+3;addLog(g,"Archive found at "..s.name.." (+3 science)")
  elseif event==1 then g.resources[p].alloy=g.resources[p].alloy+3;addLog(g,"Salvage found at "..s.name.." (+3 alloy)")
  elseif event==2 then g.resources[p].energy=g.resources[p].energy+3;addLog(g,"Energy cache found at "..s.name.." (+3 energy)")
  else addLog(g,s.name.." fully surveyed")end
 elseif key=="annex" then s.owner=p;addLog(g,g.names[p].." annexed "..s.name)
 elseif key=="colonize" then s.colony=true;addLog(g,"Colony founded on "..s.name)
 elseif key=="build" then s.ships[p]=s.ships[p]+2;addLog(g,"2 frigates constructed at "..s.name)
 else s.buildings[key]=s.buildings[key]+1;addLog(g,ACTIONS[key].title.." built at "..s.name) end
 updateWinner(g);return true,ACTIONS[key].title.." completed"
end
local function sendFleet(g,from,to,count)
 local p=g.turn;local a=g.systems[from];local b=g.systems[to]
 if not a or not b or a.owner~=p or a.ships[p]<1 then return false,"Choose a fleet at an owned system" end
 if g.ap<1 or g.resources[p].energy<1 then return false,"Need 1 command and 1 energy" end
 if not fleetReach(g,from,to,p) then return false,"Destination is not in jump range" end
 count=clamp(math.floor(tonumber(count) or 1),1,a.ships[p])
 if g.pact and b.owner==other(p) then return false,"Break the trade accord before attacking" end
 if b.owner==p and b.ships[p]+count>8 then return false,"Destination fleet capacity is eight" end
 pay(g,{energy=1})
 a.ships[p]=a.ships[p]-count
 local combat=nil
 if b.owner==other(p) or b.ships[other(p)]>0 then
  local enemy=other(p);local attack=count*(2+g.tech[p].WEAPONS)
  local defend=b.ships[enemy]*(2+g.tech[enemy].WEAPONS)+(b.owner==enemy and (b.colony and 2 or 0)+b.buildings.fort*3 or 0)
  local rollA=(g.round*7+from*3+to)%4;local rollD=(g.round*5+from+to*3)%4
  if attack+rollA>defend+rollD then
   local lost=clamp(math.floor(defend/math.max(2,2+g.tech[p].WEAPONS)),0,count-1)
   b.ships[enemy]=0;b.ships[p]=clamp(b.ships[p]+count-lost,0,8)
   if b.owner==enemy then b.owner=p;b.colony=false;b.buildings={mine=0,forge=0,lab=0,dock=0,fort=0};g.conquests[p]=g.conquests[p]+1 end
   b.known=true;combat={win=true,lost=lost,attacker=count,defender=defend,name=b.name}
   addLog(g,g.names[p].." seized "..b.name.." (lost "..lost.." ships)")
  else
   local lost=math.max(1,math.floor(attack/math.max(2,2+g.tech[enemy].WEAPONS)))
   b.ships[enemy]=math.max(0,b.ships[enemy]-lost)
   combat={win=false,lost=count,attacker=count,defender=defend,name=b.name}
   addLog(g,"Invasion repelled at "..b.name)
  end
 else
  b.ships[p]=clamp(b.ships[p]+count,0,8)
  addLog(g,count.." ships warped to "..b.name)
 end
 updateWinner(g);return true,combat
end
local function research(g,key)
 local p=g.turn;local level=g.tech[p][key]
 if level==nil then return false,"Unknown technology" end
 if level>=3 then return false,"Already at maximum level" end
 if g.ap<1 then return false,"No command points left" end
 local cost=techCost(g,p,key)
 if g.resources[p].science<cost then return false,"Need "..cost.." science" end
 pay(g,{science=cost});g.tech[p][key]=level+1;addLog(g,g.names[p].." discovered "..key.." "..(level+1))
 updateWinner(g);return true,"Research complete"
end
local function income(g,p)
 local v={energy=1,alloy=1,science=1,influence=2+g.tech[p].UNITY}
 local totalShips=0
 for _,s in ipairs(g.systems)do
  totalShips=totalShips+s.ships[p]
  if s.owner==p then
   v.energy=v.energy+1
   if s.colony then
    v.energy=v.energy+g.tech[p].REACTORS
    if s.kind=="ORE" then v.alloy=v.alloy+1 end
    if s.kind=="RELIC" or s.kind=="NEBULA" then v.science=v.science+1 end
    if s.kind=="PLASMA" or s.kind=="TERRAN" then v.energy=v.energy+1 end
    v.energy=v.energy+s.buildings.mine*(s.kind=="ORE" and 0 or 2)
    v.alloy=v.alloy+s.buildings.mine*(s.kind=="ORE" and 2 or 0)+s.buildings.forge*2
    v.science=v.science+s.buildings.lab*2
   end
  end
 end
 v.energy=v.energy-math.floor(totalShips/4)
 return v
end
local function endTurn(g)
 if g.result then return end
 if g.turn==1 then g.turn=2;g.ap=3;addLog(g,g.names[2].." takes command")
 else
  for p=1,2 do
   local v=income(g,p);for k,n in pairs(v)do g.resources[p][k]=clamp(g.resources[p][k]+n,0,99) end
   if g.pact then
    g.resources[p].energy=clamp(g.resources[p].energy+2,0,99)
    g.resources[p].science=clamp(g.resources[p].science+1,0,99)
   end
  end
  g.round=g.round+1;g.turn=1;g.ap=3
  addLog(g,"Year "..g.round.." - resources collected")
  if g.round>g.limit then
   local a,b=points(g,1),points(g,2);g.result=a==b and 0 or (a>b and 1 or 2)
  end
 end
 updateWinner(g)
end
local function offerPact(g)
 if g.pact then return false,"Trade pact already active" end
 if g.offer==g.turn then return false,"Proposal already pending" end
 if g.ap<1 or g.resources[g.turn].influence<2 then return false,"Need 1 command and 2 influence" end
 pay(g,{influence=2});g.offer=g.turn;addLog(g,g.names[g.turn].." proposed a trade accord")
 return true,"Proposal sent. Rival can accept on their turn."
end
local function answerPact(g,accept)
 if g.offer==0 or g.offer==g.turn then return false,"No incoming offer" end
 if accept then g.pact=true;addLog(g,"Trade accord signed: +2 energy and +1 science each year")
 else addLog(g,"Trade accord rejected") end
 g.offer=0;return true,accept and "Accord signed" or "Offer declined"
end
local function endPact(g)
 if not g.pact then return false,"No current pact" end
 g.pact=false;g.resources[g.turn].influence=math.max(0,g.resources[g.turn].influence-3)
 addLog(g,"Trade accord broken; -3 influence")
 return true,"Pact cancelled"
end
-- graphics canvas: logical units are the monitor's text cells; pixel mode expands each cell
local Renderer={};Renderer.__index=Renderer
function Renderer.new(mon,forceText)
 local self=setmetatable({m=mon,kind="text",buttons={},frame=0},Renderer)
 if mon.setTextScale then pcall(mon.setTextScale,0.5) end
 self.w,self.h=mon.getSize();self.px,self.py=1,1
 if not forceText and type(mon.setGraphicsMode)=="function" and type(mon.drawPixels)=="function" then
  local ok=pcall(mon.setGraphicsMode,2)
  if ok then
   local success,pw,ph=pcall(mon.getSize,2)
   if success and pw and ph and pw>self.w and ph>self.h then
    self.kind="gfx";self.px=pw/self.w;self.py=ph/self.h
    if mon.setPaletteColor then for c,rgb in pairs(PALETTE)do pcall(mon.setPaletteColor,c,rgb)end end
   else pcall(mon.setGraphicsMode,0) end
  end
 end
 return self
end
function Renderer:resize()
 self.w,self.h=self.m.getSize()
 if self.kind=="gfx" then
  local ok,pw,ph=pcall(self.m.getSize,2)
  if ok and pw and ph then self.px=pw/self.w;self.py=ph/self.h end
 end
end
function Renderer:rect(x,y,w,h,c)
 x=math.floor(x);y=math.floor(y);w=math.ceil(w);h=math.ceil(h)
 if w<=0 or h<=0 then return end
 local ex=math.min(self.w,x+w);local ey=math.min(self.h,y+h)
 x=math.max(0,x);y=math.max(0,y);if ex<=x or ey<=y then return end
 if self.kind=="gfx" then
  local px=math.floor(x*self.px);local py=math.floor(y*self.py)
  self.m.drawPixels(px,py,c,math.max(1,math.floor(ex*self.px)-px),math.max(1,math.floor(ey*self.py)-py))
 else
  self.m.setBackgroundColor(TEXT_COLORS[c] or 32768)
  for iy=y,ey-1 do self.m.setCursorPos(x+1,iy+1);self.m.write(string.rep(" ",ex-x))end
 end
end
function Renderer:pixel(px,py,c,size)
 if self.kind=="gfx" then
  size=size or 1;self.m.drawPixels(math.floor(px),math.floor(py),c,math.max(1,math.floor(size)),math.max(1,math.floor(size)))
 else
  local x=math.floor(px/self.px);local y=math.floor(py/self.py)
  if x>=0 and y>=0 and x<self.w and y<self.h then
   self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1);self.m.write(".")
  end
 end
end
function Renderer:line(x1,y1,x2,y2,c)
 if self.kind=="gfx" then
  x1=x1*self.px;y1=y1*self.py;x2=x2*self.px;y2=y2*self.py
  local d=math.max(math.abs(x2-x1),math.abs(y2-y1))
  for i=0,d,2 do local t=i/math.max(1,d);self:pixel(x1+(x2-x1)*t,y1+(y2-y1)*t,c,1)end
 else
  local d=math.max(math.abs(x2-x1),math.abs(y2-y1))*1.3
  for i=0,d,1 do local t=i/math.max(1,d);local x=math.floor(x1+(x2-x1)*t+.5);local y=math.floor(y1+(y2-y1)*t+.5)
   if x>=0 and y>=0 and x<self.w and y<self.h then
    self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1);self.m.write(".")
   end
  end
 end
end
function Renderer:disc(cx,cy,r,c)
 if self.kind=="gfx" then
  local x=cx*self.px;local y=cy*self.py;local rp=r*math.min(self.px,self.py)
  for yy=-math.ceil(rp),math.ceil(rp) do
   local dx=math.sqrt(math.max(0,rp*rp-yy*yy));local ax=math.floor(x-dx)
   local length=math.max(1,math.floor(x+dx)-ax)
   self.m.drawPixels(ax,math.floor(y+yy),c,length,1)
  end
 else
  self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1)
  self.m.setCursorPos(math.floor(cx)+1,math.floor(cy)+1);self.m.write("O")
 end
end
function Renderer:text(x,y,str,c,maxlen)
 x=math.floor(x);y=math.floor(y);str=trunc(str,maxlen or 255)
 if y<0 or y>=self.h or x>=self.w then return end
 if x<0 then str=str:sub(1-x);x=0 end
 str=str:sub(1,math.max(0,self.w-x));if #str==0 then return end
 if self.kind=="text" then
  self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1)
  self.m.write(str);return
 end
 for i=1,#str do
  local pattern=FONT[str:sub(i,i)] or FONT["?"]
  local left=(x+i-1)*self.px;local top=y*self.py
  for ry=1,7 do
   local row=pattern[ry];local col=1
   while col<=5 do
    if row:sub(col,col)=="1" then
     local start=col;while col<=5 and row:sub(col,col)=="1" do col=col+1 end
     local px=math.floor(left+(start-1)*self.px/6);local xx=math.floor(left+col*self.px/6)
     local py=math.floor(top+(ry-1)*self.py/9);local yy=math.floor(top+ry*self.py/9)
     self.m.drawPixels(px,py,c,math.max(1,xx-px),math.max(1,yy-py))
    else col=col+1 end
   end
  end
 end
end
function Renderer:bigText(x,y,word,c,scale)
 scale=scale or 2
 if self.kind=="text" then return self:text(x,y,word,c) end
 word=tostring(word):upper()
 for i=1,#word do
  local pattern=FONT[word:sub(i,i)] or FONT["?"]
  local left=(x+(i-1)*scale)*self.px;local top=y*self.py
  for ry=1,7 do
   local line=pattern[ry];local k=1
   while k<=5 do
    if line:sub(k,k)=="1" then
     local start=k;while k<=5 and line:sub(k,k)=="1" do k=k+1 end
     local px=math.floor(left+(start-1)*scale*self.px/6);local xx=math.floor(left+k*scale*self.px/6)
     local py=math.floor(top+(ry-1)*scale*self.py/9);local yy=math.floor(top+ry*scale*self.py/9)
     self.m.drawPixels(px,py,c,math.max(1,xx-px),math.max(1,yy-py))
    else k=k+1 end
   end
  end
 end
end
function Renderer:key(x,y,w,h,label,fn)
 self:rect(x,y,w,h,2);self:rect(x,y,1,h,4)
 self:text(x+math.floor((w-1)/2),y+1,label,7,1)
 self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,fn=fn}
end
function Renderer:icon(x,y,name,c)
 local data=ICON[name] or ICON.star
 if self.kind=="text" then
  local fallback={star="*",planet="@",ship="^",scan="?",flag="F",colony="H",mine="M",forge="A",lab="S",dock="D",fort="#",energy="E",alloy="A",science="S",influence="I",research="R",move=">",war="X",trade="$",next=">",back="<",help="?",trophy="*",check="+",close="X",orbit="O"}
  return self:text(x,y,fallback[name] or "*",c)
 end
 local left=x*self.px;local top=y*self.py
 for ry=1,7 do local row=data[ry];local k=1
  while k<=5 do
   if row:sub(k,k)=="1" then
    local start=k;while k<=5 and row:sub(k,k)=="1" do k=k+1 end
    local xx=math.floor(left+(start-1)*self.px/6);local endx=math.floor(left+k*self.px/6)
    local yy=math.floor(top+(ry-1)*self.py/9);local endy=math.floor(top+ry*self.py/9)
    self.m.drawPixels(xx,yy,c,math.max(1,endx-xx),math.max(1,endy-yy))
   else k=k+1 end
  end
 end
end
function Renderer:button(x,y,w,h,title,icon,tint,fn,detail,disabled)
 self:rect(x,y,w,h,disabled and 1 or 2)
 self:rect(x,y,1,h,disabled and 3 or tint)
 self:icon(x+2,y+math.max(0,math.floor((h-1)/2)),icon,disabled and 4 or tint)
 self:text(x+4,y+1,trunc(title,w-5),disabled and 4 or 7)
 if detail and h>=4 then self:text(x+4,y+2,trunc(detail,w-5),disabled and 4 or 5) end
 if not disabled and fn then self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,fn=fn}end
end
function Renderer:beginFrame()
 self.buttons={};self.frame=self.frame+1
 if self.kind=="gfx" and self.m.setFrozen then pcall(self.m.setFrozen,true) end
 self:rect(0,0,self.w,self.h,0)
end
function Renderer:endFrame()
 if self.kind=="gfx" and self.m.setFrozen then pcall(self.m.setFrozen,false) end
end
function Renderer:hit(x,y)
 for i=#self.buttons,1,-1 do local b=self.buttons[i]
  if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then b.fn();return true end
 end
 return false
end
local Game={};Game.__index=Game
function Game.new(mon,txt)
 local self=setmetatable({},Game);self.r=Renderer.new(mon,txt);self.screen="title";self.selected=nil
 self.g=nil;self.names={"SOL","NOVA"};self.shape="CLUSTER";self.rounds=18;self.editing=1
 self.modal=nil;self.toast=nil;self.waiting=nil;self.fleetCount=1;self.tick=0;self.anim=nil
 self.stars={};local rand=rng(44581)
 for i=1,130 do self.stars[i]={x=rand(),y=rand(),brightness=rand(4)} end
 return self
end
function Game:save()
 if not fs or not textutils or not self.g then return end
 local path="/tidebound/save.dat";if not fs.exists("/tidebound") then path="tidebound-save.dat" end
 local tmp=path..".tmp";local h=fs.open(tmp,"w");if not h then return end
 h.write(textutils.serialize(self.g));h.close()
 if fs.exists(path)then fs.delete(path)end;fs.move(tmp,path)
end
function Game:load()
 if not fs or not textutils then return false end
 local path=fs.exists("/tidebound/save.dat") and "/tidebound/save.dat" or "tidebound-save.dat"
 if not fs.exists(path)then return false end
 local h=fs.open(path,"r");if not h then return false end
 local raw=h.readAll();h.close();local ok,g=pcall(textutils.unserialize,raw)
 if not ok or type(g)~="table" or g.version~=VERSION or type(g.systems)~="table" or #g.systems<12 or #g.links<10 then return false end
 self.g=g;self.screen=g.result and "victory" or "map";self.selected=nil;return true
end
function Game:newMatch()
 local seed=math.floor(((os.epoch and os.epoch("utc")) or os.clock()*1000)%900000)+7919
 self.g=newGame(self.names[1],self.names[2],self.shape,self.rounds,seed)
 self.screen="map";self.selected=nil;self.modal=nil;self.toast="Survey a neighboring star system to begin.";self:save()
end
function Game:change(action,system)
 local ok,msg=execute(self.g,action,system)
 self.toast=msg;self.anim=ok and {id=system,age=0} or nil
 if ok then self:save() end
end
function Game:notify(s)self.toast=s;self.tick=0 end
function Game:position(s)
 return math.floor(3+s.x*(self.r.w-7)), math.floor(6+s.y*(self.r.h-13))
end
function Game:background()
 local r=self.r
 if self.screen=="map" then
  local clouds={{.22,.29,6,24},{.74,.57,8,28},{.48,.82,5,31}}
  for _,cloud in ipairs(clouds) do
   local x=math.floor(cloud[1]*r.w);local y=math.floor(cloud[2]*r.h)
   r:disc(x,y,cloud[3],cloud[4])
  end
 end
 for _,s in ipairs(self.stars)do
  local x=math.floor(s.x*(r.w-1));local y=math.floor(s.y*(r.h-1))
  if (self.tick+s.brightness)%5==0 then r:rect(x,y,1,1,3) elseif s.brightness==4 then r:rect(x,y,1,1,1) end
 end
end
function Game:mapBase()
 local r=self.r;self:background()
 for _,edge in ipairs(self.g.links)do
  local a,b=self.g.systems[edge[1]],self.g.systems[edge[2]]
  local x,y=self:position(a);local xx,yy=self:position(b)
  r:line(x,y,xx,yy,(a.known and b.known) and 3 or 1)
 end
 for _,s in ipairs(self.g.systems)do
  local x,y=self:position(s)
  local isTarget=self.waiting and self.waiting.from~=s.id and fleetReach(self.g,self.waiting.from,s.id,self.g.turn)
  local starHue={TERRAN=19,ORE=17,NEBULA=12,PLASMA=9,RELIC=13,ICE=11}
  local col=s.owner==1 and 9 or (s.owner==2 and 13 or (s.known and starHue[s.kind] or 4))
  if s.id==self.selected then r:disc(x,y,2.15,3);r:disc(x,y,1.75,2) end
  if self.anim and self.anim.id==s.id then r:disc(x,y,1.3+(self.anim.age%5)*.4,8) end
  if isTarget then r:disc(x,y,1.3+(self.tick%3)*.14,18) end
  r:disc(x,y,s.colony and 1.25 or .85,col)
  if s.colony then r:disc(x-.15,y-.22,.4,7)end
  if s.owner~=0 then r:icon(x-2,y-1,"flag",s.owner==1 and 11 or 13) end
  if s.ships[1]+s.ships[2]>0 then
   local p=s.ships[1]>0 and 1 or 2
   r:icon(x+1,y-1,"ship",p==1 and 9 or 15)
   r:text(x+2,y,tostring(s.ships[p]),7)
  end
  if s.known then r:text(x-math.floor(#s.name/2),y+2,trunc(s.name,14),s.owner==0 and 5 or 6)
  else r:text(x,y+1,"?",4) end
 end
 if self.anim and self.anim.from and self.anim.id then
  local f=self.g.systems[self.anim.from];local t=self.g.systems[self.anim.id]
  local ax,ay=self:position(f);local bx,by=self:position(t)
  local progress=clamp((self.anim.age+1)/6,0,1)
  r:line(ax,ay,ax+(bx-ax)*progress,ay+(by-ay)*progress,9)
  r:disc(ax+(bx-ax)*progress,ay+(by-ay)*progress,.5,19)
 end
end
function Game:header()
 local r=self.r;local g=self.g;local p=g.turn;local c=p==1 and 9 or 13
 r:rect(0,0,r.w,5,1);r:rect(0,4,r.w,1,3)
 r:icon(2,1,"flag",c);r:text(4,1,trunc(g.names[p],16),c)
 r:button(1,0,math.min(26,r.w-46),3,g.names[p],"flag",c,function()self.modal="empire"end)
 r:text(2,3,"YEAR "..g.round.."/"..g.limit.."  COMMANDS "..g.ap.."/3",5)
 local x=math.max(27,r.w-42);local resource=g.resources[p]
 local list={{"energy",resource.energy,17},{"alloy",resource.alloy,21},{"science",resource.science,11},{"influence",resource.influence,13}}
 for i,item in ipairs(list)do local ix=x+(i-1)*10
  r:icon(ix,1,item[1],item[3]);r:text(ix+2,1,tostring(item[2]),7)
 end
end
function Game:bottom()
 local r=self.r;local w=r.w;local y=r.h-5;local narrow=w<94;local cmd=narrow and 15 or 18
 r:rect(0,y,w,5,1);r:rect(0,y,w,1,3)
 r:button(1,y+1,narrow and 12 or 15,4,"TECH","research",11,function()self.modal="tech"end)
 r:button(narrow and 14 or 17,y+1,narrow and 13 or 16,4,"DIPLOMACY","trade",13,function()self.modal="diplomacy"end)
 r:button(narrow and 28 or 35,y+1,narrow and 12 or 15,4,"JOURNAL","scan",17,function()self.modal="log"end)
 r:button(w-cmd-17,y+1,15,4,"GUIDE","help",8,function()self.modal="help"end)
 r:button(w-cmd-1,y+1,cmd,4,"END TURN","next",19,function()
  endTurn(self.g);self.selected=nil;self.waiting=nil;self:save();self:notify(self.g.result and "Game finished" or (self.g.names[self.g.turn].." - your move"))
  if self.g.result then self.screen="victory" end
 end)
end
function Game:overlay(x,y,w,h,heading)
 local r=self.r;r:rect(x,y,w,h,1);r:rect(x,y,w,1,3);r:rect(x,y,1,h,3)
 if heading then r:text(x+2,y+1,trunc(heading,w-5),7) end
end
function Game:systemInfo()
 local s=self.selected and self.g.systems[self.selected]
 if not s then return end
 local r=self.r;local p=self.g.turn
 local w=math.min(43,math.max(33,math.floor(r.w*.39)));local x=r.w-w-1;local y=6;local h=r.h-12
 self:overlay(x,y,w,h,s.known and s.name or "UNSURVEYED SYSTEM")
 r:button(x+w-7,y+1,6,3,"X","close",15,function()self.selected=nil;self.waiting=nil end)
 r:icon(x+2,y+3,"planet",s.owner==1 and 9 or (s.owner==2 and 13 or 17))
 r:text(x+5,y+3,s.known and s.kind or "UNKNOWN",5)
 local occup=s.owner==0 and "UNCLAIMED" or (s.owner==p and "YOUR TERRITORY" or "RIVAL TERRITORY")
 r:text(x+2,y+5,occup,s.owner==p and 9 or (s.owner==0 and 17 or 13))
 if s.known then
  r:icon(x+2,y+7,"ship",6);r:text(x+4,y+7,"FLEETS "..s.ships[1].." / "..s.ships[2].."     ("..self.g.names[1].." / "..self.g.names[2]..")",5,w-6)
  local col=s.colony and "COLONY" or "UNSETTLED"
  r:text(x+2,y+9,col.."  BUILDINGS "..(s.buildings.mine+s.buildings.forge+s.buildings.lab+s.buildings.dock+s.buildings.fort),5)
 end
 local keys
 if not s.known then keys={"scan"}
 elseif s.owner==0 then keys=s.ships[p]>0 and {"annex","dispatch"} or {"annex"}
 elseif s.owner==p then
  keys={"colonize","mine","forge","lab","dock","build","fort","dispatch"}
 else keys={"dispatch"} end
 local offset=y+11;local available=h-16;local per=4
 local maxButtons=math.max(1,math.floor(available/per));local page=self.actionPage or 1
 local pages=math.ceil(#keys/maxButtons);page=clamp(page,1,pages);self.actionPage=page
 for index=(page-1)*maxButtons+1,math.min(#keys,page*maxButtons)do
  local key=keys[index];local act=ACTIONS[key];local n=index-(page-1)*maxButtons;local yy=offset+(n-1)*per
  local why=actionReason(self.g,key,s.id)
  if key=="dispatch" and s.owner~=p and s.ships[p]==0 then
   why="Select a friendly fleet, then choose this as destination"
  end
  local detail=costString(act.cost).." | "..(why and trunc(why,w-14) or "READY")
  r:button(x+2,yy,w-4,4,act.title,act.icon,why and 4 or 9,function()
   self.order={key=key,id=s.id};self.modal="order"
  end,detail,false)
 end
 if pages>1 then
  r:button(x+2,y+h-5,math.floor((w-5)/2),3,"PREV","back",8,function()self.actionPage=clamp(page-1,1,pages)end,nil,page==1)
  r:button(x+math.floor(w/2),y+h-5,math.floor((w-5)/2),3,"NEXT","next",8,function()self.actionPage=clamp(page+1,1,pages)end,nil,page>=pages)
 else
  r:text(x+2,y+h-3,"TAP AN ORDER TO LEARN MORE",4,w-5)
 end
 -- Use the top toast as action explanation: tapping a disabled action never consumes a turn.
end
function Game:routeInfo()
 local r=self.r;local w=math.min(45,math.max(34,math.floor(r.w*.39)));local x=r.w-w-1;local y=7
 self:overlay(x,y,w,18,"FLEET TRANSFER")
 local s=self.g.systems[self.waiting.from]
 r:icon(x+2,y+4,"ship",9);r:text(x+5,y+4,"FROM "..s.name,7)
 r:text(x+2,y+6,"Ships available "..s.ships[self.g.turn],5)
 r:text(x+2,y+8,"FLEET SIZE: "..self.fleetCount,7)
 r:button(x+2,y+10,9,4,"LESS","back",11,function()self.fleetCount=clamp(self.fleetCount-1,1,s.ships[self.g.turn])end)
 r:button(x+13,y+10,9,4,"MORE","next",11,function()self.fleetCount=clamp(self.fleetCount+1,1,s.ships[self.g.turn])end)
 r:button(x+24,y+10,w-26,4,"CANCEL","close",15,function()self.waiting=nil end)
 r:text(x+2,y+15,"TAP HIGHLIGHTED STAR TO WARP",9,w-4)
end
function Game:drawMap()
 self:mapBase();self:header();self:bottom()
 if self.waiting then self:routeInfo() elseif self.selected then self:systemInfo() else
  local r=self.r;r:rect(1,6,math.min(38,r.w-3),4,1);r:icon(3,7,"orbit",8)
  r:text(6,7,"SELECT A STAR TO ISSUE ORDERS",6,30)
 end
 if self.toast then
  local r=self.r;local txt=trunc(self.toast,r.w-9);local x=math.max(2,math.floor((r.w-#txt-5)/2))
  r:rect(x,r.h-9,#txt+5,3,2);r:text(x+2,r.h-8,txt,7)
 end
end
function Game:clickMap(x,y)
 local nearest=nil;local dist=1e9
 for _,s in ipairs(self.g.systems)do local a,b=self:position(s);local d=((a-x)*1.1)^2+(b-y)^2
  if d<dist then dist=d;nearest=s end
 end
 if not nearest or dist>18 then self.selected=nil;return end
 if self.waiting then
  local from=self.waiting.from;if nearest.id==from then return end
  if not fleetReach(self.g,from,nearest.id,self.g.turn) then self:notify("No hyperlane route to that system");return end
  if nearest.owner==other(self.g.turn) and self.g.pact then
   self:notify("Break the trade accord in Diplomacy before attacking");return
  end
  local ok,result=sendFleet(self.g,from,nearest.id,self.fleetCount)
  if ok then
   self.waiting=nil;self.selected=nearest.id;self.actionPage=1;self.anim={id=nearest.id,from=from,age=0};self:save()
   if type(result)=="table" then self.modal="combat";self.combat=result
   else self:notify("Fleet arrived at "..nearest.name)end
   if self.g.result then self.screen="victory" end
  else self:notify(result) end
 else self.selected=nearest.id;self.actionPage=1;self.toast=nil end
end
function Game:window(heading,w,h)
 local r=self.r;w=math.min(w,r.w-4);h=math.min(h,r.h-7)
 local x=math.floor((r.w-w)/2);local y=math.floor((r.h-h)/2)
 self:overlay(x,y,w,h,heading)
 r:button(x+w-8,y+1,7,3,"X","close",15,function()self.modal=nil end)
 return x,y,w,h
end
local function wrapWords(input,limit)
 local lines={};local line=""
 for word in tostring(input or ""):gmatch("%S+")do
  if #line+#word+1>limit and #line>0 then lines[#lines+1]=line;line=word
  else line=(line=="" and word or line.." "..word) end
 end
 if line~=""then lines[#lines+1]=line end
 return lines
end
function Game:drawModal()
 if not self.modal then return end
 local r=self.r;local g=self.g;local p=g.turn
 if self.modal=="empire" then
  local x,y,w,h=self:window("EMPIRE SITUATION REPORT",57,32)
  r:icon(x+3,y+5,"flag",p==1 and 9 or 13);r:text(x+7,y+5,g.names[p].." - YEAR "..g.round,7)
  r:text(x+3,y+8,"VICTORY POINTS     "..points(g,p),17)
  r:text(x+3,y+10,"RIVAL POINTS       "..points(g,other(p)),13)
  r:text(x+3,y+12,"CONTROLLED SYSTEMS "..owns(g,p),6)
  r:text(x+3,y+14,"ANNUAL INCOME FORECAST",9)
  local v=income(g,p);local pos=16
  for _,key in ipairs({"energy","alloy","science","influence"})do
   r:icon(x+3,y+pos,key,17);r:text(x+7,y+pos,string.upper(key).."   "..(v[key]>=0 and "+" or "")..v[key],6);pos=pos+3
  end
  r:text(x+3,y+h-3,"TRADE ACCORD ADDS EXTRA E2 S1 PER YEAR",5,w-6)
 elseif self.modal=="order" then
  local a=self.order;local action=ACTIONS[a.key];local system=g.systems[a.id]
  local x,y,w,h=self:window(action.title.." - ORDER BRIEFING",61,23)
  r:icon(x+4,y+5,action.icon,9)
  r:text(x+8,y+5,"SYSTEM: "..system.name,7)
  local lines=wrapWords(action.desc,w-9)
  for i,line in ipairs(lines)do r:text(x+4,y+7+i,line,6)end
  local why=actionReason(g,a.key,a.id)
  r:text(x+4,y+13,"COST: "..costString(action.cost).." + "..action.ap.." COMMAND",17)
  r:text(x+4,y+15,why and ("UNAVAILABLE: "..trunc(why,w-18)) or "AVAILABLE: READY TO EXECUTE",why and 15 or 19)
  r:button(x+3,y+h-6,math.floor((w-8)/2),4,"CANCEL","back",8,function()self.modal=nil end)
  r:button(x+5+math.floor((w-8)/2),y+h-6,math.floor((w-8)/2),4,"CONFIRM","check",why and 4 or 19,function()
   self.modal=nil
   if a.key=="dispatch" then
    self.waiting={from=system.id};self.fleetCount=math.min(2,system.ships[p]);self.selected=nil
    self:notify("Choose a destination star on the map")
   else self:change(a.key,a.id)end
  end,nil,why~=nil)
 elseif self.modal=="tech" then
  local x,y,w,h=self:window("RESEARCH DIRECTORATE",57,34)
  r:icon(x+3,y+4,"science",11);r:text(x+6,y+4,"SCIENCE STOCKPILE: "..g.resources[p].science,11)
  for i,t in ipairs(TECH)do
   local yy=y+7+(i-1)*6;local level=g.tech[p][t.key];local cost=techCost(g,p,t.key)
   local reason=level>=3 and "MAX LEVEL" or (g.ap<1 and "NO COMMANDS" or (g.resources[p].science<cost and "INSUFFICIENT SCIENCE" or nil))
   r:button(x+3,yy,w-6,5,t.title.."  "..level.."/3",t.icon,11,function()
    local ok,msg=research(g,t.key);self:notify(msg);if ok then self:save()end
   end,"S"..cost.." | "..(reason or "UPGRADE AVAILABLE"),reason~=nil)
   r:text(x+4,yy+4,trunc(t.desc,w-8),5)
  end
 elseif self.modal=="diplomacy" then
  local x,y,w,h=self:window("DIPLOMATIC CHANNEL",56,27)
  r:icon(x+3,y+5,"trade",13);r:text(x+6,y+5,g.pact and "ACTIVE TRADE ACCORD" or "NO CURRENT ACCORD",7)
  r:text(x+3,y+7,"TRADE: BOTH SIDES GET +2 ENERGY",5)
  r:text(x+3,y+8,"AND +1 SCIENCE EACH YEAR",5)
  r:text(x+3,y+10,"ATTACKING IS BLOCKED WHILE ACCORD ACTIVE",5)
  if g.offer~=0 and g.offer~=p then
   r:text(x+3,y+12,g.names[g.offer].." IS OFFERING PEACEFUL TRADE",17)
   r:button(x+3,y+15,22,4,"ACCEPT","check",19,function()local ok,msg=answerPact(g,true);self:notify(msg);if ok then self:save()end end)
   r:button(x+27,y+15,22,4,"DECLINE","close",15,function()local ok,msg=answerPact(g,false);self:notify(msg);if ok then self:save()end end)
  elseif g.pact then
   r:button(x+3,y+15,37,4,"BREAK ACCORD","war",15,function()local ok,msg=endPact(g);self:notify(msg);if ok then self:save()end end,"COST: -3 INFLUENCE")
  elseif g.offer==p then r:text(x+3,y+15,"YOUR OFFER AWAITS A REPLY",17)
  else
   r:button(x+3,y+15,37,4,"OFFER TRADE","trade",19,function()local ok,msg=offerPact(g);self:notify(msg);if ok then self:save()end end,"1 COMMAND + 2 INFLUENCE")
  end
 elseif self.modal=="log" then
  local x,y,w,h=self:window("GALACTIC JOURNAL",64,38)
  for i=1,math.min(#g.logs,h-8)do r:text(x+3,y+3+i,trunc(g.logs[i],w-6),i==1 and 7 or 5)end
 elseif self.modal=="help" then
  local x,y,w,h=self:window("COMMANDER FIELD MANUAL",64,40)
  local lines={
   "GOAL: LEAD YOUR EMPIRE TO THE HIGHEST SCORE.",
   "EARN POINTS BY ANNEXING, COLONIZING,", "CONQUERING AND RESEARCHING.",
   "", "TAP A STAR SYSTEM TO SEE ITS AVAILABLE ORDERS.",
   "SURVEY: SCAN NEARBY UNKNOWN STARS.",
   "ANNEX: SPEND INFLUENCE TO CLAIM NEUTRAL LAND.",
   "COLONIZE: FOUND A SETTLEMENT FOR INCOME.",
   "EXTRACTORS: INCREASE ENERGY OR ALLOY INCOME.",
   "FOUNDRY: BOOST ALLOY PRODUCTION.",
   "LABORATORY: INCREASE ANNUAL SCIENCE.",
   "SHIPYARD: UNLOCK FRIGATE CONSTRUCTION.",
   "BUILD FLEET: BUILD TWO FRIGATES AT A SHIPYARD.",
   "STARBASE: BOOST DEFENSE AGAINST INVASION.",
   "DISPATCH: PICK SHIP COUNT AND TAP A DESTINATION.",
   "RESEARCH: SPEND SCIENCE TO UNLOCK BONUSES.",
   "DIPLOMACY: PROPOSE OR BREAK A TRADE ACCORD.",
   "", "EACH SIDE HAS THREE COMMANDS PER TURN.",
   "BOTH EMPIRES EARN INCOME AFTER PLAYER TWO.",
   "NO HIDDEN INFORMATION: SHARED TABLETOP MAP.",
   "END THE LAST YEAR TO COMPARE VICTORY SCORES."
  }
  for i,v in ipairs(lines)do r:text(x+3,y+2+i,trunc(v,w-6),i==1 and 9 or 6)end
 elseif self.modal=="combat" then
  local c=self.combat;local x,y,w,h=self:window(c.win and "VICTORY AT "..c.name or "DEFEAT AT "..c.name,55,23)
  r:icon(x+5,y+5,c.win and "trophy" or "war",c.win and 19 or 15)
  r:text(x+10,y+5,c.win and "ENEMY STAR SYSTEM SECURED" or "OUR FLEET WAS DEFEATED",7)
  r:text(x+5,y+9,"ATTACKING SHIPS: "..c.attacker,6)
  r:text(x+5,y+11,"DEFENSE POWER: "..c.defender,6)
  r:text(x+5,y+13,"OUR SHIPS LOST: "..c.lost,6)
  r:button(x+10,y+h-6,w-20,4,"RETURN TO MAP","next",9,function()self.modal=nil end)
 end
end
function Game:titleScreen()
 local r=self.r;self:background()
 local cx=math.floor(r.w/2);local cy=math.floor(r.h*.33)
 -- orbital title illustration, animated planetary rings
 r:disc(cx,cy,5.3,2);r:disc(cx,cy,4.2,10);r:disc(cx,cy,3.3,11)
 r:disc(cx+1,cy-1,1.5,9)
 for j=0,25 do
  local angle=j*math.pi/13+self.tick*.08;local x=cx+11*math.cos(angle);local y=cy+6*math.sin(angle)
  r:disc(x,y,.22,j%2==0 and 8 or 3)
 end
 local word="STELLAR FRONTIER";local titleScale=r.w>=92 and 3 or 2;local x=math.floor((r.w-#word*titleScale)/2)
 r:bigText(x,math.max(2,cy-14),word,7,titleScale)
 r:text(cx-11,cy+8,"TIDEBOUND / VERSION 3",5)
 local bw=math.min(38,r.w-12);local bx=math.floor((r.w-bw)/2)
 r:button(bx,cy+12,bw,5,"NEW GALAXY","star",9,function()self.screen="setup"end,"TWO COMMANDERS / ONE MAP")
 r:button(bx,cy+18,bw,5,"CONTINUE","next",11,function()
  if not self:load()then self:notify("NO SAVED CAMPAIGN FOUND")end
 end,nil,false)
 r:button(bx,cy+24,bw,4,"HOW TO PLAY","help",17,function()self.screen="guide"end)
 r:text(math.max(1,cx-23),r.h-3,"LOCAL TWO PLAYER STRATEGY FOR CC:TWEAKED",4)
 if self.toast then r:text(math.max(1,cx-17),cy+30,self.toast,15,36) end
end
function Game:keyboard(x,y,w)
 local r=self.r;local rows={"QWERTYUIOP","ASDFGHJKL","ZXCVBNM"};local step=math.max(4,math.floor((w-6)/10))
 for j,s in ipairs(rows)do local dx=x+math.floor((w-#s*step)/2)
  for i=1,#s do local ch=s:sub(i,i)
   r:key(dx+(i-1)*step,y+(j-1)*4,step-1,4,ch,function()
    self.names[self.editing]=properName(self.names[self.editing]..ch)
   end)
  end
 end
 r:button(x+2,y+12,math.floor((w-6)/3),4,"SPACE","next",11,function()self.names[self.editing]=properName(self.names[self.editing].." ")end)
 r:button(x+4+math.floor((w-6)/3),y+12,math.floor((w-6)/3),4,"DELETE","back",15,function()self.names[self.editing]=self.names[self.editing]:sub(1,-2)end)
 r:button(x+6+math.floor(2*(w-6)/3),y+12,math.floor((w-6)/3)-2,4,"SWITCH","trade",17,function()self.editing=other(self.editing)end)
end
function Game:setupScreen()
 local r=self.r;self:background();local w=math.min(80,r.w-6);local x=math.floor((r.w-w)/2)
 local off=math.max(0,math.floor((r.h-44)/2))
 r:bigText(math.floor((r.w-16*2)/2),off+1,"GALACTIC CONQUEST",7,2)
 r:button(1,off+1,12,3,"BACK","back",8,function()self.screen="title"end)
 r:icon(x+2,off+4,"flag",9);r:text(x+5,off+4,"EMPIRE A",6)
 r:button(x+2,off+6,math.floor(w/2)-3,3,trunc(self.names[1],13),"planet",self.editing==1 and 9 or 5,function()self.editing=1 end)
 r:icon(x+math.floor(w/2)+2,off+4,"flag",13);r:text(x+math.floor(w/2)+5,off+4,"EMPIRE B",6)
 r:button(x+math.floor(w/2)+2,off+6,math.floor(w/2)-3,3,trunc(self.names[2],13),"planet",self.editing==2 and 13 or 5,function()self.editing=2 end)
 local keyY=off+9;self:keyboard(x,keyY,w)
 r:text(x+3,off+26,"GALAXY TOPOLOGY",5)
 r:button(x+4,off+28,math.floor((w-10)/2),4,"CLUSTER","star",self.shape=="CLUSTER" and 9 or 4,function()self.shape="CLUSTER"end)
 r:button(x+6+math.floor((w-10)/2),off+28,math.floor((w-10)/2),4,"SPIRAL","orbit",self.shape=="SPIRAL" and 9 or 4,function()self.shape="SPIRAL"end)
 r:text(x+3,off+33,"GAME LENGTH",5)
 local options={{"SHORT",12},{"STANDARD",18},{"EPIC",26}}
 for i,o in ipairs(options)do local bw=math.floor((w-8)/3)
  r:button(x+2+(i-1)*(bw+1),off+34,bw,4,o[1],"next",self.rounds==o[2] and 19 or 4,function()self.rounds=o[2]end)
 end
 r:button(x+3,off+39,w-6,5,"LAUNCH CAMPAIGN","next",9,function()
  if properName(self.names[1])=="" or properName(self.names[2])=="" then self:notify("Enter both empire names") else self:newMatch()end
 end)
 if self.toast then r:text(x+4,off+38,trunc(self.toast,w-7),15)end
end
function Game:drawVictory()
 self:background();local r=self.r;local g=self.g;local cx=math.floor(r.w/2)
 r:icon(cx-1,math.floor(r.h/4),"trophy",17)
 r:bigText(cx-14,math.floor(r.h/4)+3,"CAMPAIGN ENDED",7,2)
 if g.result==0 then r:text(cx-8,math.floor(r.h/4)+7,"GALACTIC STALEMATE",17)
 else r:text(cx-13,math.floor(r.h/4)+7,trunc(g.names[g.result],14).." VICTORIOUS",g.result==1 and 9 or 13)end
 r:text(cx-10,math.floor(r.h/4)+12,g.names[1].." : "..points(g,1).." POINTS",9)
 r:text(cx-10,math.floor(r.h/4)+15,g.names[2].." : "..points(g,2).." POINTS",13)
 r:button(cx-16,math.floor(r.h/4)+21,32,5,"RETURN TO TITLE","back",11,function()self.screen="title"end)
end
function Game:draw()
 local r=self.r;r:beginFrame()
 if self.screen=="title"then self:titleScreen()
 elseif self.screen=="setup"then self:setupScreen()
 elseif self.screen=="map"then self:drawMap();if self.modal then self.r.buttons={};self:drawModal()end
 elseif self.screen=="victory"then self:drawVictory()
 elseif self.screen=="guide"then
  self:background();r:text(4,3,"STELLAR FRONTIER - QUICK START",7)
  local lines={"1. TWO EMPIRES SHARE ONE TOUCHSCREEN.","2. TAP A STAR. SURVEY UNKNOWN NEIGHBORS.","3. ANNEX NEUTRAL STARS USING INFLUENCE.",
   "4. COLONIZE YOUR STARS AND BUILD INDUSTRY.","5. PRODUCE ALLOY, SCIENCE AND ENERGY EACH YEAR.","6. BUILD SHIPS AT SHIPYARDS. MOVE VIA LANES.",
   "7. ENEMY FLEETS FIGHT AUTOMATICALLY.","8. RESEARCH FOR EMPIRE-WIDE BONUSES.","9. DIPLOMACY ALLOWS MUTUAL TRADE.",
   "10. THREE ACTION POINTS EACH TURN.","11. WIN BY MOST POINTS WHEN TIME RUNS OUT.","12. YOU CAN CONSULT THE IN-GAME GUIDE."}
  for i,v in ipairs(lines)do r:text(6,7+i*2,v,6,r.w-8)end
  r:button(5,r.h-7,25,5,"TITLE SCREEN","back",9,function()self.screen="title"end)
 end
 r:endFrame()
end
function Game:touch(x,y)
 x=x-1;y=y-1
 if self.r:hit(x,y)then return end
 if self.screen=="map"then
  if self.modal then return end
  self:clickMap(x,y)
 end
end
function Game:loop(name)
 self:load();self.screen="title";self:draw()
 local timer=os.startTimer(.3)
 while true do
  local ev,a,b,c=os.pullEvent()
  if ev=="monitor_touch" and (not name or a==name) then self:touch(b,c);self:draw()
  elseif ev=="mouse_click" and self.r.m==term.current() then self:touch(b,c);self:draw()
  elseif ev=="char" and self.screen=="setup" then self.names[self.editing]=properName(self.names[self.editing]..a);self:draw()
  elseif ev=="key" and self.screen=="setup" and keys and a==keys.backspace then self.names[self.editing]=self.names[self.editing]:sub(1,-2);self:draw()
  elseif ev=="monitor_resize" and (not name or a==name) then self.r:resize();self:draw()
  elseif ev=="timer" and a==timer then
   self.tick=self.tick+1
   if self.anim then self.anim.age=self.anim.age+1;if self.anim.age>5 then self.anim=nil end end
   self:draw();timer=os.startTimer(self.anim and .17 or .55)
  end
 end
end
local function selfTest()
 local checks=0;local function test(x,s)checks=checks+1;assert(x,s or "failed")end
 for shapeNo,shape in ipairs({"CLUSTER","SPIRAL"})do
  local g=newGame("ALPHA","BETA",shape,12,224+shapeNo)
  test(#g.systems==24);test(#g.links>=23);test(g.systems[g.capital[1]].owner==1)
  test(g.systems[g.capital[2]].owner==2);test(g.resources[1].alloy==12)
  local visit={[g.capital[1]]=true};local frontier={g.capital[1]};local k=1
  while frontier[k]do for _,n in ipairs(neighbors(g,frontier[k]))do
   if not visit[n]then visit[n]=true;frontier[#frontier+1]=n end
  end;k=k+1 end
  for i=1,24 do test(visit[i],"disconnected starlanes")end
  local id=nil;for _,v in ipairs(neighbors(g,g.capital[1]))do if g.systems[v].owner==0 then id=v;break end end
  test(id~=nil);test(actionReason(g,"annex",id)==nil)
  test(execute(g,"annex",id));test(g.systems[id].owner==1)
  test(execute(g,"colonize",id));test(g.systems[id].colony)
  test(actionReason(g,"colonize",id)~=nil)
  g.resources[1].alloy=99;g.resources[1].energy=99;g.ap=9
  test(execute(g,"mine",id));test(g.systems[id].buildings.mine==1)
  test(execute(g,"forge",id));test(execute(g,"lab",id))
  local before=g.resources[1].science;g.resources[1].science=99
  test(research(g,"NAVIGATION"));test(g.tech[1].NAVIGATION==1)
  test(g.resources[1].science<99);test(before>=0)
  g.ap=3;local money=deepcopy(g.resources[1]);endTurn(g);test(g.turn==2);test(g.round==1)
  endTurn(g);test(g.turn==1);test(g.round==2);test(g.resources[1].energy>=money.energy-4)
  test(type(points(g,1))=="number")
  local gp=newGame("ONE","TWO","CLUSTER",12,77)
  test(offerPact(gp));test(gp.offer==1);endTurn(gp);test(answerPact(gp,true));test(gp.pact)
  local baseE=gp.resources[1].energy
  endTurn(gp);test(gp.resources[1].energy>=baseE)
  test(endPact(gp));test(not gp.pact)
  gp.turn=2;gp.ap=3;local from=gp.capital[2];local to=neighbors(gp,from)[1]
  test(sendFleet(gp,from,to,1));test(gp.systems[from].ships[2]==2)
  -- Battle and capture deterministic with overwhelming force
  local ba=newGame("AAA","BBB","CLUSTER",12,100)
  local enemy=neighbors(ba,ba.capital[1])[1];ba.systems[enemy].owner=2;ba.systems[enemy].colony=true
  ba.systems[ba.capital[1]].ships[1]=8;ba.tech[1].WEAPONS=3
  local ok,battle=sendFleet(ba,ba.capital[1],enemy,8)
  test(ok);test(type(battle)=="table");test(battle.win);test(ba.systems[enemy].owner==1)
 end
 -- all supported layouts and touch areas, optional graphics and text
 for _,size in ipairs({{75,49},{106,70},{137,91}})do
  for _,graphic in ipairs({false,true})do
   local mon={calls=0,mode=0}
   function mon.setTextScale()end
   function mon.getSize(which) if which==2 then return size[1]*6,size[2]*9 end return size[1],size[2] end
   function mon.setGraphicsMode(v)mon.mode=v end
   function mon.drawPixels()mon.calls=mon.calls+1 end
   function mon.setPaletteColor()end
   function mon.setFrozen()end
   function mon.setBackgroundColor()end
   function mon.setTextColor()end
   function mon.setCursorPos()end
   function mon.write()mon.calls=mon.calls+1 end
   local game=Game.new(mon,not graphic);game.g=newGame("ONE","TWO","CLUSTER",12,300)
   test(game.r.kind==(graphic and "gfx" or "text"))
   game.screen="title";game:draw();test(mon.calls>0)
   game.screen="setup";game:draw();test(#game.r.buttons>10)
   local ox=math.floor((size[1]-math.min(80,size[1]-6))/2);local off=math.max(0,math.floor((size[2]-44)/2))
   local previous=game.names[1];game:touch(ox+6,off+11);test(game.names[1]~=previous,"keyboard touch input")
   game:draw()
   game.screen="map";game:draw();test(#game.r.buttons>=4)
   game.selected=game.g.capital[1];game:draw();test(#game.r.buttons>=5)
   local pw=math.min(43,math.max(33,math.floor(size[1]*.39)));game:touch(size[1]-pw+4,19)
   test(game.modal=="order","order briefing opens from tap")
   game:draw();test(#game.r.buttons>=2);game.modal=nil
   game.modal="tech";game:draw();test(#game.r.buttons>=5)
   game.modal=nil;game:draw();game:touch(2,size[2]-3);test(game.modal=="tech","tech button touch")
  end
 end
 print("STELLAR FRONTIER: "..checks.." assertions passed")
end
if argv[1]=="--self-test" then selfTest();return end
local function start()
 local name=nil;local mon=nil
 if peripheral then
  if argv[1] then name=argv[1];mon=peripheral.wrap(name)
  else mon=peripheral.find("monitor");if mon and peripheral.getName then name=peripheral.getName(mon) end end
 end
 if not mon then error("Connect an Advanced Monitor, or run tidebound <monitor name>.",0) end
 local game=Game.new(mon)
 if game.r.w<68 or game.r.h<44 then error("Monitor too small: use a 3x3, 4x4, or 5x5 Advanced Monitor at 0.5 scale.",0) end
 local ok,reason=xpcall(function()game:loop(name)end,function(err)return tostring(err).."\n"..(debug and debug.traceback and debug.traceback() or "")end)
 if game.r.kind=="gfx"then pcall(mon.setGraphicsMode,0)end
 if not ok then error(reason,0)end
end
start()