-- Seeded hex geography, strategic deposits, private discovery and territory.
-- World state is authoritative and saved; map presets never reroll on reload.
local W={}
W.sizes={compact={18,12},standard={28,18},large={40,26}}
W.types={"continents","archipelago","pangaea","highlands"}
local function key(x,y)return x..":"..y end
W.key=key
local function noise(seed,x,y,salt)
 local n=(seed*1103515245+x*110351+y*143417+salt*7193)%2147483647
 return ((n*48271+17)%2147483647)/2147483647
end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function deposit(seed,x,y,t)
 local v=noise(seed,x,y,19)
 if t=="water" then return v>.88 and "fish" or nil end
 if t=="forest" and v>.54 then return "timber" end
 if t=="hills" or t=="mountain" then
  if v>.78 then return "iron" end
  if v>.40 then return "stone" end
 end
 if t=="plains" then
  if v>.85 then return "horses" end
  if v>.57 then return "grain" end
 end
end
function W.generate(seed,size,count,mapType)
 size=W.sizes[size] and size or "standard"
 local dims=W.sizes[size]
 seed=math.floor(tonumber(seed) or 12345)%1000000
 mapType=mapType or "continents"
 if not ({continents=true,archipelago=true,pangaea=true,highlands=true})[mapType] then
  mapType="continents"
 end
 local world={width=dims[1],height=dims[2],seed=seed,size=size,
  mapType=mapType,tiles={},resources={},starts={}}
 local w,h=world.width,world.height
 for y=1,h do for x=1,w do
  local nx=(x-(w+1)/2)/(w/2)
  local ny=(y-(h+1)/2)/(h/2)
  local d=math.sqrt(nx*nx+ny*ny)
  local macro=noise(seed,math.floor(x/5),math.floor(y/5),7)
  local detail=noise(seed,x,y,1)
  local v=.58*macro+.42*detail
  local waterLimit
  if mapType=="pangaea"then waterLimit=.11+d*.40
  elseif mapType=="archipelago"then waterLimit=.43+d*.11
  elseif mapType=="highlands"then waterLimit=.09+d*.12
  else waterLimit=.22+d*.17 end
  local t
  if v<waterLimit then t="water"
  elseif (mapType=="highlands" and v>.68) or v>.84 then t="mountain"
  elseif v>.57 then t="forest"
  elseif v>.40 then t="hills"
  else t="plains" end
  world.tiles[key(x,y)]=t
  world.resources[key(x,y)]=deposit(seed,x,y,t)
 end end
 local starts={{3,3},{w-2,h-2},{w-2,3},{3,h-2}}
 for i=1,math.min(4,count or 4)do
  local x,y=starts[i][1],starts[i][2]
  world.starts[i]={x=x,y=y}
  for yy=y-1,y+1 do for xx=x-1,x+1 do
   if xx>=1 and xx<=w and yy>=1 and yy<=h then
    world.tiles[key(xx,yy)]="plains"
    world.resources[key(xx,yy)]=deposit(seed,xx,yy,"plains")
   end
  end end
 end
 return world
end
function W.terrain(world,x,y)
 if not world or x<1 or y<1 or x>world.width or y>world.height then return nil end
 return world.tiles[key(x,y)] or "plains"
end
function W.deposit(world,x,y)
 if not world or not world.resources then return nil end
 return world.resources[key(x,y)]
end
-- Migrate pre-v0.5 legacy maps without changing existing city terrain.
function W.migrate(state)
 if not state.world and state.phase=="game" then
  local world={width=12,height=8,seed=0,size="legacy",mapType="legacy",
   tiles={},resources={},starts={}}
  for y=1,8 do for x=1,12 do
   local v=(x*37+y*61+x*y*13)%19
   local t=v<=1 and "water" or v<=3 and "mountain" or
    v<9 and "forest" or "plains"
   world.tiles[key(x,y)]=t
  end end
  state.world=world
  state.mapSize="compact";state.mapSeed=0
 end
 if state.world then
  local world=state.world
  world.mapType=world.mapType or "continents"
  world.resources=world.resources or {}
  for y=1,world.height do for x=1,world.width do
   local k=key(x,y)
   if world.resources[k]==nil then
    world.resources[k]=deposit(world.seed or 0,x,y,world.tiles[k])
   end
  end end
 end
 state.mapType=state.mapType or state.world and state.world.mapType or "continents"
 return state
end
local function radius(city)
 return city.population and city.population>=6 and 2 or 1
end
-- Hex territory nearest owner; deterministic tie break by city ID.
function W.territory(state,hex)
 local w=state.world
 local result={}
 if not w then return result end
 for y=1,w.height do for x=1,w.width do
  local best,bestDist
  for _,c in ipairs(state.cities or {})do
   local dist=hex.distance(x,y,c.x,c.y)
   if dist<=radius(c) and (not best or dist<bestDist or
    (dist==bestDist and (c.id or 0)<(best.id or 0)))then
    best,bestDist=c,dist
   end
  end
  if best then result[key(x,y)]=best.owner end
 end end
 return result
end
function W.strategic(state,player,hex,res)
 local owned=W.territory(state,hex)
 for k,id in pairs(owned)do
  if id==player.id and state.world.resources and
   state.world.resources[k]==res then return true end
 end
 return false
end
function W.reveal(state,hex,systems)
 local world=state.world
 if not world then return end
 for _,p in ipairs(state.players or {})do
  p.explored=p.explored or {}
  local visible={}
  local function reveal(x,y,r)
   for yy=math.max(1,y-r),math.min(world.height,y+r)do
    for xx=math.max(1,x-r),math.min(world.width,x+r)do
     if hex.distance(x,y,xx,yy)<=r then
      local k=key(xx,yy);visible[k]=true;p.explored[k]=true
     end
    end
   end
  end
  for _,c in ipairs(state.cities or {})do
   if c.owner==p.id then reveal(c.x,c.y,2)end
  end
  for _,unit in ipairs(state.units or {})do
   if unit.owner==p.id then
    local stat=systems.units[unit.kind] or systems.units.warrior
    reveal(unit.x,unit.y,stat.vision or 2)
   end
  end
  p.visible=visible
 end
end
function W.known(player,x,y)
 if not player then return "hidden"end
 local k=key(x,y)
 if player.visible and player.visible[k]then return "visible"end
 if player.explored and player.explored[k]then return "explored"end
 return "hidden"
end
return W
