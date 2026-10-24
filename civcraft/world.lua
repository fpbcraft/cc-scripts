-- Deterministic generated hex maps and player-private exploration.
local W={}
W.sizes={compact={12,8},standard={16,10},large={20,12}}
local function key(x,y)return x..":"..y end
W.key=key
local function hash(seed,x,y,salt)
 local n=(seed*1103515245+x*110351+y*143417+salt*7193)%2147483647
 n=(n*48271+17)%2147483647
 return n/2147483647
end
function W.generate(seed,size,count)
 size=W.sizes[size] and size or "standard"
 local dims=W.sizes[size]
 seed=math.floor(tonumber(seed) or 12345)%1000000
 local world={width=dims[1],height=dims[2],seed=seed,size=size,tiles={},starts={}}
 local w,h=world.width,world.height
 for y=1,h do for x=1,w do
  local v=hash(seed,x,y,1)*.55+hash(seed,math.floor(x/3),math.floor(y/3),7)*.45
  local latitude=math.abs(y-(h+1)/2)/(h/2)
  local t
  if v < .17+latitude*.12 then t="water"
  elseif v>.82 then t="mountain"
  elseif v>.52 then t="forest"
  elseif v>.37 then t="hills"
  else t="plains"end
  world.tiles[key(x,y)]=t
 end end
 local candidates={{2,2},{w-1,h-1},{w-1,2},{2,h-1}}
 for i=1,math.min(4,count or 4)do
  local x,y=candidates[i][1],candidates[i][2]
  world.starts[i]={x=x,y=y}
  world.tiles[key(x,y)]="plains"
  world.tiles[key(x+(x<w/2 and 1 or -1),y)]="plains"
  world.tiles[key(x,y+(y<h/2 and 1 or -1))]="plains"
 end
 return world
end
function W.terrain(world,x,y)
 if not world or x<1 or y<1 or x>world.width or y>world.height then return nil end
 return world.tiles[key(x,y)] or "plains"
end
function W.reveal(state,Hex,Systems)
 local world=state.world
 if not world then return end
 for _,player in ipairs(state.players or {})do
  player.explored=player.explored or {}
  local visible={}
  local function reveal(x,y,radius)
   for yy=math.max(1,y-radius),math.min(world.height,y+radius)do
    for xx=math.max(1,x-radius),math.min(world.width,x+radius)do
     if Hex.distance(x,y,xx,yy)<=radius then
      local k=key(xx,yy)
      visible[k]=true;player.explored[k]=true
     end
    end
   end
  end
  for _,c in ipairs(state.cities or {})do
   if c.owner==player.id then reveal(c.x,c.y,2)end
  end
  for _,unit in ipairs(state.units or {})do
   if unit.owner==player.id then
    local stats=Systems.units[unit.kind] or Systems.units.warrior
    reveal(unit.x,unit.y,stats.vision or 2)
   end
  end
  player.visible=visible
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
