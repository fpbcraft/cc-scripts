-- Pure Lua kinetic puzzle simulation. No peripheral or CraftOS dependencies.
local levels=require("cogworks.levels")
local E={levels=levels}
local DIR={{0,-1},{1,0},{0,1},{-1,0}}
local PORTS={
 S={0},M={0},I={0,2},L={0,1},T={0,1,3},
 G={0,2},B={0,2},
}
function E.hasPort(tile,dir)
 for _,p in ipairs(PORTS[tile.kind]) do
  if (p+tile.r)%4==dir then return true end
 end
 return false
end
local function id(x,y) return (y-1)*5+x end
function E.new(number,solved)
 assert(levels[number],"Invalid puzzle level")
 local src=levels[number]
 local g={number=number,name=src.name,tip=src.tip,moves=0,hints=0,tiles={},map={}}
 for i,p in ipairs(src.parts)do
  local r=p.solution
  if not solved and p.kind~="S" and p.kind~="M" then r=(r+p.offset)%4 end
  local tile={kind=p.kind,x=p.x,y=p.y,r=r,solution=p.solution,speed=p.speed,
   sign=p.sign,id=id(p.x,p.y)}
  assert(not g.map[tile.id],"Duplicate part in level "..number)
  g.tiles[#g.tiles+1]=tile
  g.map[tile.id]=tile
 end
 return g
end
-- Moving between two ports of a tile preserves RPM except at a controller.
-- On a gear, the sign reverses in either direction.
-- On a controller, north(local)->south(local) doubles; the return halves.
local function transfer(tile,from,to,rate,sign)
 if tile.kind=="G" then return rate,-sign end
 if tile.kind=="B" then
  local incoming=(from-tile.r)%4
  local outgoing=(to-tile.r)%4
  if incoming==0 and outgoing==2 then return rate*2,sign end
  if incoming==2 and outgoing==0 then return rate/2,sign end
 end
 return rate,sign
end
function E.evaluate(g)
 local states,queue,jam={}, {},false
 local start=1
 local function assign(tile,port,rate,sign)
  local slots=states[tile.id]
  if not slots then slots={};states[tile.id]=slots end
  local previous=slots[port]
  if previous then
   if math.abs(previous.rate-rate)>0.001 or previous.sign~=sign then jam=true end
   return
  end
  local info={rate=rate,sign=sign}
  slots[port]=info
  queue[#queue+1]={tile=tile,port=port,info=info}
 end
 for _,tile in ipairs(g.tiles)do
  if tile.kind=="S" then assign(tile,tile.r,1,1)end
 end
 while start<=#queue do
  local step=queue[start];start=start+1
  local tile,port,info=step.tile,step.port,step.info
  -- Conduct power through the component, respecting its gearing.
  for dir=0,3 do
   if dir~=port and E.hasPort(tile,dir)then
    local rate,sign=transfer(tile,port,dir,info.rate,info.sign)
    assign(tile,dir,rate,sign)
   end
  end
  -- Adjacent connected ports have the same physical rotation and RPM.
  local delta=DIR[port+1]
  local nx,ny=tile.x+delta[1],tile.y+delta[2]
  local neighbour=nx>=1 and nx<=5 and ny>=1 and ny<=4 and g.map[id(nx,ny)] or nil
  local opposite=(port+2)%4
  if neighbour and E.hasPort(neighbour,opposite)then
   assign(neighbour,opposite,info.rate,info.sign)
  end
 end
 local powered,goals,correct=0,0,0
 local lights={}
 for _,tile in ipairs(g.tiles)do
  local slots=states[tile.id]
  local sample=slots and next(slots) and slots[next(slots)] or nil
  local light={powered=sample~=nil,rate=sample and sample.rate or 0,
   sign=sample and sample.sign or 0,ports=slots or {}}
  if light.powered then powered=powered+1 end
  if tile.kind=="M" then
   goals=goals+1
   local value=slots and slots[tile.r]
   light.correct=not not (value and value.sign==tile.sign and math.abs(value.rate-tile.speed)<0.001)
   if light.correct then correct=correct+1 end
  end
  lights[tile.id]=light
 end
 return {lights=lights,powered=powered,goals=goals,correct=correct,
  jam=jam,win=not jam and goals>0 and goals==correct}
end
function E.rotate(g,x,y)
 local tile=g.map[id(x,y)]
 if not tile or tile.kind=="S" or tile.kind=="M" then return false end
 tile.r=(tile.r+1)%4
 g.moves=g.moves+1
 return true
end
function E.hint(g)
 for _,tile in ipairs(g.tiles)do
  if tile.kind~="S" and tile.kind~="M" and tile.r~=tile.solution then
   tile.r=tile.solution
   g.hints=g.hints+1
   g.moves=g.moves+1
   return true
  end
 end
 return false
end
return E
