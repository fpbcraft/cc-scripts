-- COGWORKS core: port-accurate, inventory-limited construction and simulation.
-- Pure Lua, no peripheral dependencies. Coordinates are 1-based.
local levels=require("cogworks.levels")
local E={levels=levels,WIDTH=7,HEIGHT=6}
local vectors={{0,-1},{1,0},{0,1},{-1,0}}
local ports={S={0},M={0},I={0,2},L={0,1},T={0,1,3},
 G={0,2},B={0,2},Q={0,1,2,3},O={0,2},V={0,2},D={0,2}}
E.parts={
 I={name="SHAFT",description="STRAIGHT POWER LINE",color=11},
 L={name="ELBOW",description="TURNS POWER 90 DEGREES",color=11},
 T={name="SPLITTER",description="SENDS POWER THREE WAYS",color=11},
 G={name="GEAR",description="REVERSES ROTATION",color=14},
 B={name="2X DRIVE",description="DOUBLES RPM: IN TO OUT",color=6},
 Q={name="GEARBOX",description="FOUR WAY POWER DISTRIBUTOR",color=13},
 O={name="LARGE COG",description="REVERSE SPIN AND DOUBLE RPM",color=14},
 V={name="BELT",description="SPAN ONE EMPTY CELL",color=7},
 D={name="CHAIN",description="SPAN ONE OR TWO CELLS",color=11},
}
E.order={"I","L","T","G","B","Q","O","V","D"}
local function index(x,y)return (y-1)*E.WIDTH+x end
function E.inside(x,y)
 return type(x)=="number" and type(y)=="number" and
  x>=1 and x<=E.WIDTH and y>=1 and y<=E.HEIGHT and
  x%1==0 and y%1==0
end
function E.hasPort(tile,dir)
 for _,p in ipairs(ports[tile.kind] or {})do
  if (p+tile.r)%4==dir then return true end
 end
 return false
end
function E.get(g,x,y)
 return E.inside(x,y) and g.map[index(x,y)] or nil
end
local function add(g,v,fixed)
 assert(E.inside(v.x,v.y),"Invalid level coordinates")
 local id=index(v.x,v.y)
 assert(not g.map[id],"Overlapping level part at "..id)
 local t={id=id,x=v.x,y=v.y,kind=v.kind,r=v.r or 0,
  fixed=not not fixed,speed=v.speed,sign=v.sign,enabled=v.enabled~=false}
 g.map[id]=t;g.tiles[#g.tiles+1]=t
 return t
end
local function copy(t)
 local result={};for k,v in pairs(t)do result[k]=v end;return result
end
function E.new(number,solved)
 local data=assert(levels[number],"Invalid level")
 local g={number=number,name=data.name,tip=data.tip,tiles={},map={},
  stock=copy(data.stock),remaining=copy(data.stock),moves=0,
  fullNetwork=data.fullNetwork or false}
 add(g,data.source,true)
 for _,goal in ipairs(data.goals)do add(g,goal,true)end
 for _,v in ipairs(data.blocks)do add(g,{kind="X",x=v[1],y=v[2]},true)end
 if solved then
  for _,v in ipairs(data.build)do
   assert(g.remaining[v.kind]>0,"Invalid reference inventory")
   g.remaining[v.kind]=g.remaining[v.kind]-1
   add(g,v,false)
  end
 end
 return g
end
function E.place(g,x,y,kind,r)
 if not E.inside(x,y) or not E.parts[kind] or E.get(g,x,y) then return false end
 if (g.remaining[kind] or 0)<1 then return false end
 g.remaining[kind]=g.remaining[kind]-1
 add(g,{kind=kind,x=x,y=y,r=(r or 0)%4},false)
 g.moves=g.moves+1
 return true
end
function E.remove(g,x,y)
 local tile=E.get(g,x,y)
 if not tile or tile.fixed then return false end
 g.map[tile.id]=nil
 for i,v in ipairs(g.tiles)do
  if v==tile then table.remove(g.tiles,i);break end
 end
 g.remaining[tile.kind]=g.remaining[tile.kind]+1
 g.moves=g.moves+1
 return true
end
function E.rotate(g,x,y)
 local tile=E.get(g,x,y)
 if not tile or tile.fixed then return false end
 tile.r=(tile.r+1)%4;g.moves=g.moves+1
 return true
end
-- Belt/chain endpoints may connect through clear space or non-conductive
-- stone without requiring a cable tile in each intermediate cell.
-- Returning the exact endpoint lets rendering, validation and simulation
-- share a single mechanical connection rule.
function E.connection(g,tile,dir)
 if not E.hasPort(tile,dir)then return nil end
 local delta=vectors[dir+1]
 local other=E.get(g,tile.x+delta[1],tile.y+delta[2])
 if other and E.hasPort(other,(dir+2)%4)then return other end
 if tile.kind~="V" and tile.kind~="D"then return nil end
 local limit=tile.kind=="V" and 3 or 4
 for distance=2,limit do
  local x,y=tile.x+delta[1]*distance,tile.y+delta[2]*distance
  if not E.inside(x,y)then return nil end
  local candidate=E.get(g,x,y)
  if candidate then
   if candidate.kind==tile.kind and
    E.hasPort(candidate,(dir+2)%4)then return candidate end
   if candidate.kind~="X"then return nil end
  end
 end
 return nil
end
function E.snapshot(g)
 local list={}
 for _,tile in ipairs(g.tiles)do
  if not tile.fixed then
   list[#list+1]={x=tile.x,y=tile.y,kind=tile.kind,r=tile.r,enabled=tile.enabled}
  end
 end
 table.sort(list,function(a,b) if a.y==b.y then return a.x<b.x end return a.y<b.y end)
 return list
end
function E.restore(g,list)
 if type(list)~="table" or #list>E.WIDTH*E.HEIGHT then return false end
 -- Validate everything before changing the live puzzle.
 local trial=E.new(g.number)
 for _,v in ipairs(list)do
  if type(v)~="table" or not E.inside(v.x,v.y) or
   type(v.r)~="number" or v.r%1~=0 or v.r<0 or v.r>3 or
   (v.enabled~=nil and type(v.enabled)~="boolean") or
   not E.place(trial,v.x,v.y,v.kind=="C" and "I" or v.kind,v.r)then return false end
  local restored=E.get(trial,v.x,v.y)
 end
 g.map,g.tiles,g.remaining=trial.map,trial.tiles,trial.remaining
 g.moves=0
 return true
end
local function transfer(t,from,to,rate,sign)
 if t.kind=="G" then return rate,-sign end
 if t.kind=="O"then
  local input=(from-t.r)%4
  local output=(to-t.r)%4
  if input==0 and output==2 then return rate*2,-sign end
  if input==2 and output==0 then return rate/2,-sign end
 end
 if t.kind=="B" then
  local input=(from-t.r)%4;local output=(to-t.r)%4
  if input==0 and output==2 then return rate*2,sign end
  if input==2 and output==0 then return rate/2,sign end
 end
 return rate,sign
end
function E.evaluate(g)
 local states,queue,first={}, {},1
 local jam=false
 local function assign(tile,port,rate,sign)
  local slots=states[tile.id]
  if not slots then slots={};states[tile.id]=slots end
  local existing=slots[port]
  if existing then
   if math.abs(existing.rate-rate)>0.001 or existing.sign~=sign then jam=true end
   return
  end
  local state={rate=rate,sign=sign}
  slots[port]=state
  queue[#queue+1]={tile=tile,port=port,info=state}
 end
 for _,tile in ipairs(g.tiles)do
  if tile.kind=="S" then assign(tile,tile.r,1,1)end
 end
 while first<=#queue do
  local event=queue[first];first=first+1
  local tile,port,info=event.tile,event.port,event.info
  for dir=0,3 do
   if tile.enabled and dir~=port and E.hasPort(tile,dir)then
    local rate,sign=transfer(tile,port,dir,info.rate,info.sign)
    assign(tile,dir,rate,sign)
   end
  end
  local neighbor=E.connection(g,tile,port)
  local opposite=(port+2)%4
  if neighbor then
   assign(neighbor,opposite,info.rate,info.sign)
  end
 end
 local lights,goals,correct,powered={},0,0,0
 local openPorts,unpowered=0,0
 for _,tile in ipairs(g.tiles)do
  local slots=states[tile.id] or {}
  local sample=slots[next(slots)]
  local light={powered=sample~=nil,rate=sample and sample.rate or 0,
   sign=sample and sample.sign or 0,ports=slots}
  if sample then powered=powered+1 end
  if E.parts[tile.kind] and not sample then unpowered=unpowered+1 end
  if tile.kind~="X"then
   for dir=0,3 do if E.hasPort(tile,dir)then
    if tile.kind~="Q" and not E.connection(g,tile,dir)then
     openPorts=openPorts+1
    end
   end end
  end
  if tile.kind=="M" then
   goals=goals+1
   local actual=slots[tile.r]
   light.correct=not not (actual and actual.sign==tile.sign and
    math.abs(actual.rate-tile.speed)<0.001)
   if light.correct then correct=correct+1 end
  end
  lights[tile.id]=light
 end
 local remaining=0
 for _,amount in pairs(g.remaining)do remaining=remaining+amount end
 local complete=not g.fullNetwork or
  (openPorts==0 and unpowered==0 and remaining==0)
 return {lights=lights,powered=powered,goals=goals,correct=correct,
  jam=jam,fullNetwork=g.fullNetwork,openPorts=openPorts,
  unpowered=unpowered,remaining=remaining,complete=complete,
  win=not jam and goals>0 and goals==correct}
end
-- Extra contracts are optional: standard level completion only needs the
-- machines powered at the right RPM and direction. Bonuses never lock NEXT.
function E.challenges(g,result)
 local list={}
 if g.number<2 then return list end
 local function add(id,name,description,earned)
  list[#list+1]={id=id,name=name,description=description,
   earned=result.win and earned or false}
 end
 add("sealed","SEALED LINES","NO OPEN PORTS OR IDLE PARTS",
  result.openPorts==0 and result.unpowered==0)
 if g.number>=3 then
  add("master","FULL FACTORY","STOCK USED, POWERED, SEALED",
   result.remaining==0 and result.openPorts==0 and result.unpowered==0)
 end
 if g.number>=5 then
  -- One optimal reference route is always achievable within this move limit:
  -- place every part at r=0, then turn clockwise to its authored rotation.
  local par=0
  for _,tile in ipairs(levels[g.number].build)do
   par=par+1+(tile.r or 0)
  end
  add("precision","PRECISION","AT MOST "..par.." MOVES",g.moves<=par)
 end
 return list
end
return E
