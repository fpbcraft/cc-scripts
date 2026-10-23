-- TIDEBOUND: KINGDOMS v2.1
-- Two-player touch-screen empire game for CC:Tweaked Advanced Monitors.
-- Usage: tidebound [monitor-name]  OR  texlua tidebound.lua --self-test
local argv = {...}
if #argv == 0 and type(arg) == "table" and arg[1] then argv[1] = arg[1] end
local RED, BLUE = 1, 2
local MAX_TURNS, AP = 26, 3
local MIN_W, MIN_H = 45, 34
local MAX_RES = 50
local COST = {
  claim = {food=1, wood=1},
  found = {wood=4, stone=2},
  upgrade = {wood=4, stone=4},
  recruit = {food=3, stone=1},
  fort = {wood=2, stone=2},
  attack = {food=1},
}
local DIRS = {{1,0},{0,1},{-1,0},{0,-1}}
local function clamp(x,a,b) return math.max(a, math.min(b, x)) end
local function copy(t)
  if type(t) ~= "table" then return t end
  local n = {}; for k,v in pairs(t) do n[k] = copy(v) end; return n
end
local function clock()
  return (os.epoch and os.epoch("utc")) or (os.clock() * 1000)
end
local function coord(x,y) return x .. ":" .. y end
local function inside(g,x,y) return x >= 1 and y >= 1 and x <= g.w and y <= g.h end
local function tile(g,x,y) return inside(g,x,y) and g.map[y][x] or nil end
local function adjacent(a,b,c,d) return math.abs(a-c) + math.abs(b-d) == 1 end
local function namesafe(s)
  return (tostring(s or ""):gsub("[^%w _%-]", ""):sub(1,12))
end
local function other(p) return 3-p end
local function mapSize(w,h)
  -- Character dimensions, NOT monitor block dimensions: covers 3x3, 4x4, 5x5.
  -- Keep provinces legible (at least ~5x3 characters) on every layout.
  return clamp(math.floor(w/5.4),10,18), clamp(math.floor(h/3.5),9,17)
end
local function costText(action)
  local c = COST[action] or {}; local txt = {}
  for _,r in ipairs({"food", "wood", "stone"}) do
    if c[r] then txt[#txt+1] = ({food="F",wood="W",stone="S"})[r] .. c[r] end
  end
  return table.concat(txt," ")
end
local function afford(g,p,action)
  local cost = COST[action] or {}
  for r,n in pairs(cost) do if g.stock[p][r] < n then return false end end
  return true
end
local function pay(g,p,action)
  for r,n in pairs(COST[action] or {}) do g.stock[p][r] = g.stock[p][r]-n end
end
local function isLand(t) return t ~= nil and t.kind ~= "water" end
local function isNeighborOwned(g,x,y,p)
  for _,d in ipairs(DIRS) do
    local n = tile(g,x+d[1],y+d[2])
    if n and n.owner == p then return true end
  end
  return false
end
local function terrain(seed, style, x, y, w, h)
  local v = math.random()
  local shore = x == 1 or y == 1 or x == w or y == h
  if v < (style == "isles" and (shore and .48 or .22) or (shore and .28 or .10)) then return "water" end
  v = math.random()
  if v < .31 then return "forest"
  elseif v < .53 then return "hill"
  elseif v < .59 then return "mountain"
  else return "plain" end
end
local function makeGame(seed,w,h,names,style,target)
  math.randomseed(seed)
  w,h = math.max(9, math.floor(w)), math.max(9, math.floor(h))
  local g = {
    version=2, seed=seed, w=w, h=h, map={},
    names={namesafe(names[1]),namesafe(names[2])}, style=style or "land", target=target or 30,
    round=1, turn=RED, ap=AP, score={0,0}, winner=nil, log="Choose a tile to begin.",
    stock={{food=6,wood=6,stone=4},{food=6,wood=6,stone=4}},
    lastBattle=nil,
  }
  for y=1,h do
    g.map[y] = {}
    for x=1,w do g.map[y][x] = {kind="plain",owner=0,city=0,army=0,fort=0,relic=false,capital=false} end
  end
  -- Rotational symmetry ensures that both opening positions have equal potential.
  for y=1,h do for x=1,w do
    local rx,ry = w+1-x,h+1-y
    if y < ry or (y == ry and x <= rx) then
      local k = terrain(seed,g.style,x,y,w,h)
      g.map[y][x].kind=k; g.map[ry][rx].kind=k
    end
  end end
  -- Two navigable central corridors; the archipelago cannot block expansion entirely.
  local my = math.floor((h+1)/2)
  for x=2,w-1 do
    for _,y in ipairs({my,h+1-my}) do
      if tile(g,x,y).kind == "water" then tile(g,x,y).kind = "plain" end
    end
  end
  -- Paired ancient sites provide a Carcassonne-like incentive to reach special land.
  local sites=0
  for y=2,h-1 do for x=2,math.floor(w/2) do
    local a,b=tile(g,x,y),tile(g,w+1-x,h+1-y)
    if sites < math.max(2,math.floor(w*h/32)) and a.kind ~= "water" and math.random() < .08
       and x>3 then a.relic=true; b.relic=true; sites=sites+1 end
  end end
  if sites == 0 then
    local ax=math.floor(w/2); tile(g,ax,2).kind="plain"; tile(g,ax,2).relic=true
    tile(g,w+1-ax,h-1).kind="plain"; tile(g,w+1-ax,h-1).relic=true
  end
  local cy=math.floor((h+1)/2)
  local function start(p,cx,yy,sgn,vsgn)
    local a=tile(g,cx,yy); a.kind="plain"; a.owner=p; a.city=2; a.army=5; a.capital=true; a.relic=false
    local f=tile(g,cx+sgn,yy); f.kind="forest"; f.owner=p; f.relic=false
    local s=tile(g,cx,yy+vsgn); s.kind="hill"; s.owner=p; s.relic=false
    local v=tile(g,cx,yy-vsgn); v.kind="plain"; v.relic=false
  end
  start(RED,2,cy,1,-1)
  start(BLUE,w-1,h+1-cy,-1,1)
  return g
end
local function income(g,p)
  local i={food=0,wood=0,stone=0,score=0,tiles=0}
  for y=1,g.h do for x=1,g.w do
    local t=g.map[y][x]
    if t.owner == p then
      i.tiles=i.tiles+1
      if t.kind == "forest" then i.wood=i.wood+2
      elseif t.kind == "hill" then i.stone=i.stone+2
      elseif t.kind == "mountain" then i.stone=i.stone+1
      elseif t.kind == "plain" then i.food=i.food+2 end
      if t.city > 0 then i.score=i.score+(t.capital and 2 or t.city) end
      if t.relic then i.score=i.score+1 end
    end
  end end
  return i
end
local function countHoldings(g,p)
  local total=0
  for _,r in ipairs(g.map) do for _,t in ipairs(r) do if t.owner == p then total=total+1 end end end
  return total
end
local function legal(g,action,x,y,tx,ty)
  if g.winner or g.ap <= 0 then return false end
  local p=g.turn
  local a=tile(g,x,y)
  if not a or not isLand(a) then return false end
  if action == "claim" then
    return a.owner == 0 and isNeighborOwned(g,x,y,p) and afford(g,p,action)
  elseif action == "found" then
    return a.owner == p and a.city == 0 and not a.relic and afford(g,p,action)
  elseif action == "upgrade" then
    return a.owner == p and a.city >= 1 and a.city < 3 and afford(g,p,action)
  elseif action == "recruit" then
    return a.owner == p and a.city >= 1 and a.army <= 7 and afford(g,p,action)
  elseif action == "fort" then
    return a.owner == p and a.fort < 2 and afford(g,p,action)
  elseif action == "march" or action == "attack" then
    local b=tile(g,tx,ty)
    if a.owner ~= p or a.army <= 1 or not b or not isLand(b) or not adjacent(x,y,tx,ty) then return false end
    if action == "march" then return b.owner == p and b.army < 9 end
    return b.owner == other(p) and afford(g,p,action)
  end
  return false
end
local function randomDie() return math.random(1,3) end
local function act(g,action,x,y,tx,ty)
  if not legal(g,action,x,y,tx,ty) then return false,"Unavailable action" end
  local p=g.turn
  local a=tile(g,x,y)
  local message,fxkind,tx0,ty0= "",action,x,y
  if action == "claim" then
    pay(g,p,action); a.owner=p
    message="Province annexed. "..g.names[p].." expands."
  elseif action == "found" then
    pay(g,p,action); a.city=1; message="New village founded."
  elseif action == "upgrade" then
    pay(g,p,action); a.city=a.city+1; message="Settlement upgraded to level "..a.city.."."
  elseif action == "recruit" then
    pay(g,p,action); a.army=math.min(9,a.army+2); message="Two armies recruited."
  elseif action == "fort" then
    pay(g,p,action); a.fort=a.fort+1; message="Fortifications strengthened."
  elseif action == "march" then
    local b=tile(g,tx,ty)
    local n=math.min(b.army >= 9 and 0 or 9-b.army, math.max(1,math.floor(a.army/2)))
    a.army=a.army-n; b.army=b.army+n; message=n.." armies marched."
    tx0,ty0=tx,ty
  elseif action == "attack" then
    local b=tile(g,tx,ty)
    pay(g,p,action)
    local force=a.army-1
    local ra,rd=randomDie(),randomDie()
    local defense=b.army + (b.fort*2) + (b.city>0 and b.city or 0)
    -- Always evaluate the terrain modifier as a number.
    if b.kind=="hill" then defense=defense+1 end
    if b.kind=="mountain" then defense=defense+2 end
    local won=force+ra > defense+rd
    if won then
      local losses=math.min(force-1,math.floor(b.army/2))
      a.army=1; b.army=math.max(1,force-losses)
      b.owner=p; b.fort=0
      if b.capital then g.winner=p end
      if b.city > 1 and not b.capital then b.city=b.city-1 end
      message="VICTORY! "..force.." + "..ra.." vs "..defense.." + "..rd
    else
      local losses=math.max(1,math.ceil(force/2))
      a.army=math.max(1,a.army-losses)
      message="Repelled! "..force.." + "..ra.." vs "..defense.." + "..rd
    end
    g.lastBattle={attack=force+ra,defend=defense+rd,won=won}
    tx0,ty0=tx,ty
  end
  g.ap=g.ap-1; g.log=message
  return true,{kind=fxkind,x=x,y=y,tx=tx0,ty=ty0,ms=clock(),duration=760,message=message}
end
local function endTurn(g)
  if g.winner then return end
  if g.turn == RED then
    g.turn=BLUE; g.ap=AP; g.log=g.names[BLUE].."'s turn."
    return
  end
  -- Simultaneous production/scoring avoids a player-two opening resource advantage.
  for p=RED,BLUE do
    local inc=income(g,p)
    for _,r in ipairs({"food","wood","stone"}) do g.stock[p][r]=math.min(MAX_RES,g.stock[p][r]+inc[r]) end
    g.score[p]=g.score[p]+inc.score
  end
  if g.score[RED] >= g.target or g.score[BLUE] >= g.target or g.round>=MAX_TURNS then
    if g.score[RED]>g.score[BLUE] then g.winner=RED
    elseif g.score[BLUE]>g.score[RED] then g.winner=BLUE
    elseif countHoldings(g,RED)>countHoldings(g,BLUE) then g.winner=RED
    elseif countHoldings(g,BLUE)>countHoldings(g,RED) then g.winner=BLUE
    else g.winner=3 end
    return
  end
  g.round=g.round+1; g.turn=RED; g.ap=AP
  g.log="Harvest complete. New round begins."
end

-- 16-colour indexed, custom palette (all monitor output uses blit).
local C={white="0",gold="1",magenta="2",sky="3",yellow="4",grass="5",pink="6",slate="7",stone="8",cyan="9",purple="a",water="b",earth="c",forest="d",red="e",night="f"}
local PALETTE={
  white=0xF3E9CE, orange=0xF2A65A, magenta=0xB27ACC, lightBlue=0x82C6E6,
  yellow=0xF4D06D, lime=0x688C57, pink=0xDEB2A0, gray=0x344851,
  lightGray=0x97A7AC, cyan=0x67CDD3, purple=0x74638D, blue=0x1B5366,
  brown=0x9B8165, green=0x315E46, red=0xE57A65, black=0x142832,
}
local B={}; B.__index=B
function B.new(w,h)
  local self=setmetatable({w=w,h=h,rows={}},B)
  for y=1,h do
    local ch,fg,bg={},{},{}
    for x=1,w do ch[x]=" "; fg[x]=C.white; bg[x]=C.night end
    self.rows[y]={ch,fg,bg}
  end
  return self
end
function B:put(x,y,s,fg,bg)
  if y<1 or y>self.h then return end
  local row=self.rows[y]; s=tostring(s or "")
  for i=1,#s do
    local xx=x+i-1
    if xx>=1 and xx<=self.w then
      row[1][xx]=s:sub(i,i); if fg then row[2][xx]=fg end; if bg then row[3][xx]=bg end
    end
  end
end
function B:fill(x,y,w,h,bg,ch,fg)
  for yy=math.max(1,y),math.min(self.h,y+h-1) do
    local r=self.rows[yy]
    for xx=math.max(1,x),math.min(self.w,x+w-1) do
      r[1][xx]=ch or " "; r[2][xx]=fg or C.white; r[3][xx]=bg
    end
  end
end
function B:center(y,s,fg,bg) self:put(math.floor((self.w-#s)/2)+1,y,s,fg,bg) end
function B:flush(m,prev)
  local nextRows={}
  for y=1,self.h do
    local r=self.rows[y]
    local c,f,b=table.concat(r[1]),table.concat(r[2]),table.concat(r[3])
    local packed=c..f..b
    nextRows[y]=packed
    if not prev or prev[y]~=packed then
      m.setCursorPos(1,y); m.blit(c,f,b)
    end
  end
  return nextRows
end
local function teamColor(p) return p==RED and C.red or p==BLUE and C.cyan or C.white end
local function shorten(s,max)
  if #s > max then return s:sub(1,math.max(0,max-1)).."." end
  return s
end
local function hit(ui,x,y,w,h,fn,tag)
  ui.buttons[#ui.buttons+1]={x=x,y=y,w=w,h=h,fn=fn,tag=tag}
end
local function button(b,ui,x,y,w,h,label,fn,opts)
  if w<3 or h<1 then return end
  opts=opts or {}
  local enabled=not opts.disabled
  local color=opts.active and C.gold or (enabled and (opts.color or C.slate) or C.night)
  local text=opts.active and C.night or (enabled and C.white or C.stone)
  b:fill(x,y,w,h,color)
  b:put(x,y,string.rep(opts.active and "=" or "-",w),opts.active and C.white or C.stone,color)
  if h>=3 then b:put(x,y+h-1,string.rep("-",w),C.stone,color) end
  b:put(x+math.max(0,math.floor((w-#label)/2)),y+math.floor(h/2),shorten(label,w),text,color)
  if enabled then hit(ui,x,y,w,h,fn,label) end
end
local function rect(g,x,y,w,h)
  return math.floor((x-1)*w/g.w)+1,math.floor((y-1)*h/g.h)+1,
    math.floor(x*w/g.w),math.floor(y*h/g.h)
end
local function tcenter(g,x,y,w,h)
  local ax,ay,bx,by=rect(g,x,y,w,h)
  return math.floor((ax+bx)/2),math.floor((ay+by)/2)
end
local function legalTargets(g,ui)
  local ret={}
  if ui.mode and ui.sel then
    for _,d in ipairs(DIRS) do
      local x,y=ui.sel.x+d[1],ui.sel.y+d[2]
      if legal(g,ui.mode,ui.sel.x,ui.sel.y,x,y) then ret[coord(x,y)]=true end
    end
  end
  return ret
end
local function drawBoard(b,ui,g,when)
  local targets=legalTargets(g,ui)
  local wave=math.floor(when/420)
  for y=1,g.h do for x=1,g.w do
    local t=g.map[y][x]
    local ax,ay,bx,by=rect(g,x,y,b.w,b.h)
    local cw,ch=bx-ax+1,by-ay+1
    local bg=({water=C.water,plain=C.grass,forest=C.forest,hill=C.earth,mountain=C.stone})[t.kind]
    local chosen=ui.sel and ui.sel.x==x and ui.sel.y==y
    local target=targets[coord(x,y)]
    if target then bg=ui.mode=="attack" and C.red or C.gold end
    if chosen then bg=C.purple end
    b:fill(ax,ay,cw,ch,bg)
    -- Thin cadastral boundaries are vital when neighbouring tiles share a biome.
    local edge=t.kind=="water" and C.sky or t.kind=="forest" and C.grass
      or t.kind=="plain" and C.forest or C.slate
    if cw>=4 then
      for yy=ay+1,by do
        if yy%2==0 then b:put(bx,yy,".",edge,bg) end
      end
    end
    if ch>=3 then
      for xx=ax+1,bx-1,2 do b:put(xx,by,".",edge,bg) end
    end
    local ownerColor=teamColor(t.owner)
    if t.owner>0 and ch>1 then
      b:put(ax,ay,string.rep("=",cw),ownerColor,bg)
      if cw>3 then b:put(ax+cw-1,math.min(by,ay+1),"|",ownerColor,bg) end
    end
    local midx,midy=tcenter(g,x,y,b.w,b.h)
    local texture=t.kind=="water" and ((x+y+wave)%3==0 and "~" or ".")
      or t.kind=="forest" and "*" or t.kind=="hill" and "^"
      or t.kind=="mountain" and "M" or "."
    local mark=t.city>0 and (t.capital and "K" or t.city==1 and "V" or t.city==2 and "T" or "C")
      or t.relic and "#" or target and "+" or texture
    b:put(midx,midy,mark, t.city>0 and ownerColor or target and C.night
      or t.relic and C.yellow or (t.kind=="water" and C.sky or C.white),bg)
    if t.army>0 then
      local s=t.army.."A"
      b:put(midx-math.floor(#s/2), math.min(by,midy+1),s,ownerColor,bg)
    elseif t.fort>0 then
      b:put(midx, math.min(by,midy+1),t.fort.."",C.gold,bg)
    end
    if t.owner>0 and t.city==0 and t.army==0 then
      b:put(ax,by,t.owner==RED and ":" or ";",ownerColor,bg)
    end
  end end
  local fx=ui.fx
  if fx then
    local t=(when-fx.ms)/fx.duration
    if t>=1 then ui.fx=nil
    elseif t>=0 then
      local ex,ey=tcenter(g,fx.tx,fx.ty,b.w,b.h)
      local sx,sy=tcenter(g,fx.x,fx.y,b.w,b.h)
      if fx.kind=="march" or fx.kind=="attack" then
        local z=t*t*(3-2*t) -- smoothstep, not a fixed per-cell jump
        local px=math.floor(sx+(ex-sx)*z+.5)
        local py=math.floor(sy+(ey-sy)*z+.5)
        local pulse=(math.floor(t*12)%2==0) and C.yellow or C.white
        b:fill(px-1,py-1,3,3,fx.kind=="attack" and C.red or pulse)
        b:put(px,py,fx.kind=="attack" and "!" or ">",C.night)
        if fx.kind=="attack" and t>.55 then
          local r=math.floor((t-.55)*9)
          b:put(ex-r,ey,"<",C.white);b:put(ex+r,ey,">",C.white)
        end
      elseif fx.kind~="turn" then
        local r=math.floor(t*5)
        local flash=(math.floor(t*13)%2==0) and C.yellow or C.white
        b:put(ex-r,ey,"<"..string.rep("-",r),flash)
        b:put(ex+1,ey,string.rep("-",r)..">",flash)
      end
    end
  end
end
local function hud(b,ui,g)
  local p=g.turn; local stock=g.stock[p]
  b:fill(1,1,b.w,3,C.night)
  local right=b.w-24
  local scoreboard=shorten(g.names[RED],11).." "..g.score[RED].." : "..shorten(g.names[BLUE],11).." "..g.score[BLUE]
  b:put(2,1,shorten(scoreboard,right-3),C.white,C.night)
  b:put(2,2,shorten(g.names[p],11).." | "..g.ap.." AP | ROUND "..g.round.."/"..MAX_TURNS,teamColor(p),C.night)
  b:put(2,3,"F:"..stock.food.."  W:"..stock.wood.."  S:"..stock.stone.."  GOAL:"..g.target,C.gold,C.night)
  button(b,ui,b.w-24,1,10,3,"MENU",function()
    ui.page="menu"; ui.sel=nil;ui.mode=nil;ui.fx=nil
  end)
  button(b,ui,b.w-13,1,13,3,"END TURN",function()
    endTurn(g); ui.sel=nil; ui.mode=nil;ui.changed=true
    ui.fx={kind="turn",x=math.ceil(g.w/2),y=math.ceil(g.h/2),
      tx=math.ceil(g.w/2),ty=math.ceil(g.h/2),ms=clock(),duration=660}
  end,{color=C.slate})
end
local function selectedLabel(g,t,x,y)
  local titles={water="SEA",plain="MEADOW",forest="FOREST",hill="HIGHLANDS",mountain="MOUNTAIN"}
  local o=t.owner==0 and "NEUTRAL" or g.names[t.owner]
  local settlement=t.capital and " CAPITAL" or t.city>0 and (" LV"..t.city.." TOWN") or ""
  local ruins=t.relic and " *ANCIENT SITE*" or ""
  return (titles[t.kind] or "LAND").." ("..x..","..y..")  "..shorten(o,11)..settlement..ruins
end
local function overlay(b,ui,g)
  local sel=ui.sel
  if ui.mode then
    local pw,ph=math.min(b.w-4,52),4
    local x=math.floor((b.w-pw)/2)+1
    local y=4
    b:fill(x,y,pw,ph,C.night)
    b:put(x+2,y,shorten("SELECT "..string.upper(ui.mode).." DESTINATION",pw-4),C.gold,C.night)
    b:put(x+2,y+1,shorten(ui.mode=="attack" and "Choose a highlighted enemy province." or
      "Choose a highlighted allied province.",pw-4),C.white,C.night)
    button(b,ui,x+pw-18,y+2,17,2,"CANCEL",function()ui.mode=nil end)
    return
  end
  local oh=9; local y=b.h-oh+1
  b:fill(1,y,b.w,oh,C.night)
  b:put(2,y,sel and selectedLabel(g,tile(g,sel.x,sel.y),sel.x,sel.y) or "",C.gold,C.night)
  button(b,ui,b.w-8,y,8,2,"CLOSE",function() ui.sel=nil;ui.mode=nil end)
  local t=tile(g,sel.x,sel.y)
  if not isLand(t) then
    b:put(3,y+3,"Open water cannot be settled.",C.white)
    return
  end
  local p=g.turn
  local actions={}
  local function add(label,action,x,y,tx,ty)
    actions[#actions+1]={label=label,action=action,x=x,y=y,tx=tx,ty=ty}
  end
  if legal(g,"claim",sel.x,sel.y) then add("CLAIM", "claim",sel.x,sel.y) end
  if t.owner==p then
    for _,action in ipairs({"found","upgrade","recruit","fort"}) do
      if legal(g,action,sel.x,sel.y) then add(string.upper(action),action,sel.x,sel.y) end
    end
    for _,action in ipairs({"march","attack"}) do
      for _,d in ipairs(DIRS) do
        if legal(g,action,sel.x,sel.y,sel.x+d[1],sel.y+d[2]) then
          add(string.upper(action),action,sel.x,sel.y); break
        end
      end
    end
  end
  if #actions==0 then
    b:put(2,y+3,t.owner==other(p) and "Rival territory. Attack it from your adjacent army." or "No orders available here. Select another province.",C.white)
  else
    local widths=math.max(12,math.floor((b.w-3)/3)-1)
    for i,a in ipairs(actions) do
      local col=(i-1)%3; local row=math.floor((i-1)/3)
      local bx=2+col*(widths+1); local by=y+2+row*3
      local label=a.label
      if COST[a.action] then label=label.." "..costText(a.action) end
      button(b,ui,bx,by,widths,3,label,function()
        if a.action=="march" or a.action=="attack" then ui.mode=a.action
        else
          local ok,fx=act(g,a.action,a.x,a.y)
          if ok then ui.fx=fx; ui.sel=nil; ui.mode=nil end
        end
      end)
    end
  end
  if t.army>0 or t.fort>0 then
    b:put(2,b.h,"ARMY "..t.army.."    FORT "..t.fort,C.stone,C.night)
  end
end
local function gameDraw(b,ui,g,now)
  drawBoard(b,ui,g,now)
  hud(b,ui,g)
  if ui.sel then overlay(b,ui,g)
  else
    -- Information is confined to a small top overlay: bottom map rows stay tappable.
    b:put(2,4,shorten(g.log,b.w-4),C.gold,C.night)
  end
  if ui.fx and ui.fx.kind=="turn" and now-ui.fx.ms<660 then
    local label=shorten(g.names[g.turn].."'S TURN",b.w-8)
    local w=math.min(b.w-4,math.max(24,#label+8))
    local x=math.floor((b.w-w)/2)+1; local y=math.floor(b.h/2)-2
    b:fill(x,y,w,5,C.night)
    b:put(x+math.floor((w-#label)/2),y+2,label,teamColor(g.turn),C.night)
  end
  if not ui.saveOK then b:put(2,5,"SAVE FAILED",C.red,C.night) end
end
local FONT={
 T={"###",".#.",".#.",".#.",".#."}, I={"###",".#.",".#.",".#.","###"},
 D={"##.","#.#","#.#","#.#","##."}, E={"###","#..","##.","#..","###"},
 B={"##.","#.#","##.","#.#","##."}, O={"###","#.#","#.#","#.#","###"},
 U={"#.#","#.#","#.#","#.#","###"}, N={"#.#","###","###","###","#.#"},
}
local function bigTitle(b,y)
  local title="TIDEBOUND"; local width=#title*4-1
  local x=math.floor((b.w-width)/2)+1
  for i=1,#title do
    local glyph=FONT[title:sub(i,i)]
    for dy=1,5 do
      local s=glyph[dy]
      for dx=1,3 do
        if s:sub(dx,dx)=="#" then b:put(x+(i-1)*4+dx-1,y+dy-1,"#",dy==1 and C.white or C.gold,C.night) end
      end
    end
  end
end
local function frame(b,x,y,w,h,title)
  b:fill(x,y,w,h,C.night)
  b:put(x,y,"+"..string.rep("-",w-2).."+",C.gold,C.night)
  b:put(x,y+h-1,"+"..string.rep("-",w-2).."+",C.gold,C.night)
  for dy=1,h-2 do
    b:put(x,y+dy,"|",C.gold,C.night)
    b:put(x+w-1,y+dy,"|",C.gold,C.night)
  end
  if title then b:put(x+2,y,"[ "..title.." ]",C.white,C.night) end
end
local function backboard(b,ui,now)
  drawBoard(b,ui,ui.demo,now)
  b:fill(1,1,b.w,2,C.night)
  b:put(2,1,"TIDEBOUND / KINGDOMS",C.gold,C.night)
end
local function menuDraw(b,ui,now)
  backboard(b,ui,now)
  local pw=math.min(51,b.w-4); local ph=math.min(27,b.h-4)
  local x=math.floor((b.w-pw)/2)+1; local y=math.floor((b.h-ph)/2)+1
  frame(b,x,y,pw,ph,"KINGDOMS OF THE INNER SEA")
  bigTitle(b,y+3)
  b:center(y+10,"BUILD  /  EXPAND  /  CONQUER",C.white,C.night)
  b:center(y+12,"A TWO-PLAYER TOUCHSCREEN EMPIRE GAME",C.stone,C.night)
  local twinkle=math.floor(now/450)%3
  b:put(x+3,y+4,twinkle==0 and "+" or ".",C.gold,C.night)
  b:put(x+pw-4,y+8,twinkle==1 and "+" or ".",C.sky,C.night)
  local bw=math.min(pw-8,28); local bx=math.floor((b.w-bw)/2)+1
  button(b,ui,bx,y+15,bw,3,"NEW KINGDOMS",function()ui.page="setup" end,{active=true})
  button(b,ui,bx,y+19,bw,3,"CONTINUE",function()ui.page="game" end,{disabled=ui.game==nil})
  button(b,ui,bx,y+23,bw,3,"RULES",function()ui.returnPage="menu";ui.page="rules" end)
  b:put(x+2,y+ph-2,"V2.1  /  TOUCH TO BUILD YOUR EMPIRE",C.stone,C.night)
end
local function keyboard(b,ui,x,y,w,active,compact)
  local keys={{"Q","W","E","R","T","Y","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"Z","X","C","V","B","N","M","-","<"}}
  local stepY=compact and 2 or 3
  for line,row in ipairs(keys) do
    local bw=math.max(3,math.min(5,math.floor((w+1)/10)-1))
    local step=bw+1
    local start=x+math.floor((w-(#row*step-1))/2)
    for i,k in ipairs(row) do
      button(b,ui,start+(i-1)*step,y+(line-1)*stepY,bw,2,k,function()
        if k=="<" then ui.setup.names[active]=ui.setup.names[active]:sub(1,-2)
        elseif #ui.setup.names[active]<12 then ui.setup.names[active]=ui.setup.names[active]..k end
      end)
    end
  end
  local bw=math.floor((w-4)/3)
  button(b,ui,x+1,y+(compact and 7 or 9),bw,2,"SPACE",function()
    if #ui.setup.names[active]<12 then ui.setup.names[active]=ui.setup.names[active].." " end
  end)
  button(b,ui,x+2+bw,y+(compact and 7 or 9),bw,2,"CLEAR",function()ui.setup.names[active]="" end)
  button(b,ui,x+3+bw*2,y+(compact and 7 or 9),bw,2,"NEXT",function()ui.setup.active=other(ui.setup.active) end)
end
local function setupDraw(b,ui,now)
  backboard(b,ui,now)
  local pw,ph=math.min(b.w-4,64),math.min(b.h-2,39)
  local x=math.floor((b.w-pw)/2)+1;local y=math.floor((b.h-ph)/2)+1
  frame(b,x,y,pw,ph,"FOUND YOUR KINGDOMS")
  b:put(x+2,y+2,"TWO RULERS. ONE CONTINENT.",C.gold)
  b:put(x+2,y+4,"PLAYER ONE",C.red)
  button(b,ui,x+2,y+5,pw-4,2,ui.setup.names[1]~="" and ui.setup.names[1] or "(tap keyboard)",function()ui.setup.active=RED end,{active=ui.setup.active==RED})
  b:put(x+2,y+8,"PLAYER TWO",C.cyan)
  button(b,ui,x+2,y+9,pw-4,2,ui.setup.names[2]~="" and ui.setup.names[2] or "(tap keyboard)",function()ui.setup.active=BLUE end,{active=ui.setup.active==BLUE})
  b:put(x+2,y+12,"WORLD",C.stone)
  local half=math.floor((pw-5)/2)
  button(b,ui,x+2,y+13,half,2,"CONTINENT",function()ui.setup.style="land" end,{active=ui.setup.style=="land"})
  button(b,ui,x+3+half,y+13,half,2,"ISLANDS",function()ui.setup.style="isles" end,{active=ui.setup.style=="isles"})
  b:put(x+2,y+16,"MATCH",C.stone)
  button(b,ui,x+2,y+17,half,2,"SWIFT / 20",function()ui.setup.target=20 end,{active=ui.setup.target==20})
  button(b,ui,x+3+half,y+17,half,2,"EPIC / 40",function()ui.setup.target=40 end,{active=ui.setup.target==40})
  keyboard(b,ui,x+1,y+20,pw-2,ui.setup.active,b.h<38)
  local btnW=math.floor((pw-5)/2)
  button(b,ui,x+2,y+ph-3,btnW,2,"BACK",function()ui.page="menu" end)
  button(b,ui,x+3+btnW,y+ph-3,btnW,2,"START GAME",function()
    local a=namesafe(ui.setup.names[1]);local z=namesafe(ui.setup.names[2])
    if a=="" then a="CRIMSON" end; if z=="" then z="AZURE" end
    local seed=math.floor(clock()%2000000000)+1
    local ww,hh=ui.size[1],ui.size[2]
    local mw,mh=mapSize(ww,hh)
    ui.pendingGame=makeGame(seed,mw,mh,{a,z},ui.setup.style,ui.setup.target)
    if ui.game and not ui.game.winner then
      ui.page="confirm"
    else
      ui.game=ui.pendingGame; ui.pendingGame=nil
      ui.page="game";ui.sel=nil;ui.mode=nil;ui.fx=nil;ui.changed=true
    end
  end,{active=true})
end
local function confirmDraw(b,ui,now)
  backboard(b,ui,now)
  local w,h=math.min(b.w-4,45),16
  local x,y=math.floor((b.w-w)/2)+1,math.floor((b.h-h)/2)+1
  frame(b,x,y,w,h,"REPLACE SAVED CAMPAIGN?")
  b:put(x+3,y+4,"An unfinished match already exists.",C.white)
  b:put(x+3,y+6,"Replacing it cannot be undone.",C.gold)
  button(b,ui,x+3,y+10,math.floor((w-7)/2),3,"KEEP SAVE",function()
    ui.pendingGame=nil;ui.page="setup"
  end)
  button(b,ui,x+4+math.floor((w-7)/2),y+10,math.floor((w-7)/2),3,"REPLACE",function()
    ui.game=ui.pendingGame;ui.pendingGame=nil;ui.page="game"
    ui.sel=nil;ui.mode=nil;ui.fx=nil;ui.changed=true
  end,{active=true})
end
local RULES={
  "TIDEBOUND is a territory-building strategy game.",
  "Both players act on the SAME touch monitor.",
  "", "Each turn: 3 actions. Tap a province for orders.",
  "CLAIM    Capture neutral land next to your border.",
  "FOUND    Build a village on an owned province.",
  "UPGRADE  Improve villages into cities.",
  "RECRUIT  Add 2 armies to a city (max 9).",
  "FORT     Increase defense on owned land.",
  "MARCH    Move half an army to allied land.",
  "ATTACK   From an army, select an adjacent rival.",
  "", "After BOTH turns, provinces harvest resources:",
  "MEADOW +2 FOOD   FOREST +2 WOOD",
  "HILLS +2 STONE   MOUNTAIN +1 STONE",
  "", "Cities and ancient sites generate prestige each",
  "round. First to the selected goal wins.",
  "Capturing the enemy CAPITAL wins immediately.",
  "", "Attack: committed armies + D3 vs enemy armies,",
  "forts, settlement/terrain bonus + D3.",
  "You must leave 1 army behind to invade.",
  "", "Tap a field, then action, then highlighted tile.",
  "MENU keeps your saved match for later.",
  "Tap END TURN in the top-right to pass play.",
}
local function rulesDraw(b,ui,now)
  backboard(b,ui,now)
  local w,h=math.min(b.w-4,62),math.min(b.h-4,34)
  local x,y=math.floor((b.w-w)/2)+1,math.floor((b.h-h)/2)+1
  frame(b,x,y,w,h,"FIELD MANUAL")
  for i,s in ipairs(RULES) do
    if i<=h-6 then b:put(x+2,y+i+1,shorten(s,w-4),i==1 and C.gold or C.white,C.night) end
  end
  button(b,ui,x+math.floor((w-18)/2),y+h-4,18,3,"BACK",function()ui.page=ui.returnPage or "menu" end)
end
local function overDraw(b,ui,now)
  gameDraw(b,ui,ui.game,now)
  local g=ui.game; local w,h=math.min(b.w-4,45),18
  local x,y=math.floor((b.w-w)/2)+1,math.floor((b.h-h)/2)+1
  frame(b,x,y,w,h,"THE CAMPAIGN IS OVER")
  local champion=g.winner==3 and "DRAW" or (g.winner and g.names[g.winner].." REIGNS!") or "CAMPAIGN IN PROGRESS"
  b:put(x+math.floor((w-#champion)/2),y+4,champion,C.gold)
  b:put(x+4,y+7,g.names[RED].." - "..g.score[RED].." PRESTIGE",C.red)
  b:put(x+4,y+9,g.names[BLUE].." - "..g.score[BLUE].." PRESTIGE",C.cyan)
  b:put(x+4,y+11,"AFTER "..g.round.." ROUNDS",C.stone)
  button(b,ui,x+3,y+14,math.floor((w-7)/2),3,"MENU",function()ui.page="menu" end)
  button(b,ui,x+4+math.floor((w-7)/2),y+14,math.floor((w-7)/2),3,"PLAY AGAIN",function()ui.page="setup" end,{active=true})
end
local function newUI(w,h)
  local ui={page="menu",game=nil,sel=nil,mode=nil,fx=nil,buttons={},saveOK=true,
    changed=false,prev=nil,size={w,h},returnPage="menu",setup={names={"",""},active=RED,style="land",target=40}}
  local mw,mh=mapSize(w,h)
  ui.demo=makeGame(23111,mw,mh,{"CRIMSON","AZURE"},"isles",40)
  return ui
end
local function render(m,ui,when)
  local w,h=m.getSize()
  if ui.size[1]~=w or ui.size[2]~=h then
    ui.size={w,h}
    local mw,mh=mapSize(w,h)
    ui.demo=makeGame(23111,mw,mh,{"CRIMSON","AZURE"},"isles",40)
    ui.prev=nil
  end
  local b=B.new(w,h);ui.buttons={}
  if w<MIN_W or h<MIN_H then
    b:center(math.max(2,math.floor(h/2)-2),"MONITOR TOO SMALL",C.red)
    b:center(math.max(3,math.floor(h/2)),"Use a 3x3 or larger Advanced Monitor",C.white)
    b:center(math.max(4,math.floor(h/2)+2),"at text scale 0.5",C.stone)
  elseif ui.page=="game" and ui.game and ui.game.winner then ui.page="over";overDraw(b,ui,when)
  elseif ui.page=="game" and ui.game then gameDraw(b,ui,ui.game,when)
  elseif ui.page=="setup" then setupDraw(b,ui,when)
  elseif ui.page=="confirm" then confirmDraw(b,ui,when)
  elseif ui.page=="rules" then rulesDraw(b,ui,when)
  elseif ui.page=="over" and ui.game then overDraw(b,ui,when)
  else menuDraw(b,ui,when) end
  ui.prev=b:flush(m,ui.prev)
  return b
end
local function touch(ui,x,y)
  for i=#ui.buttons,1,-1 do
    local bt=ui.buttons[i]
    if x>=bt.x and y>=bt.y and x<bt.x+bt.w and y<bt.y+bt.h then
      bt.fn(); return bt.tag or "button"
    end
  end
  if ui.page=="game" and ui.game and not ui.game.winner then
    local g=ui.game
    local tx=clamp(math.floor((x-1)*g.w/ui.size[1])+1,1,g.w)
    local ty=clamp(math.floor((y-1)*g.h/ui.size[2])+1,1,g.h)
    -- Overlay is modal only over its exact footprint.
    if ui.sel and not ui.mode and y>=ui.size[2]-8 then return "panel" end
    if y<=3 then return "header" end
    if ui.sel and ui.mode and y>=4 and y<=7 and x>=math.floor((ui.size[1]-math.min(ui.size[1]-4,52))/2)+1 and
      x < math.floor((ui.size[1]-math.min(ui.size[1]-4,52))/2)+1+math.min(ui.size[1]-4,52) then return "prompt" end
    if ui.mode and ui.sel and legal(g,ui.mode,ui.sel.x,ui.sel.y,tx,ty) then
      local ok,fx=act(g,ui.mode,ui.sel.x,ui.sel.y,tx,ty)
      if ok then ui.fx=fx;ui.sel=nil;ui.mode=nil;ui.changed=true end
      return "move"
    end
    ui.sel={x=tx,y=ty};ui.mode=nil
    return "select"
  end
end
local function savePath()
  local script=shell and shell.getRunningProgram and shell.getRunningProgram() or "tidebound.lua"
  return fs.combine(fs.getDir(script),"tidebound-kingdoms.save")
end
local function validSave(g)
  if type(g)~="table" or g.version~=2 or type(g.w)~="number" or type(g.h)~="number"
    or g.w<9 or g.h<9 or g.w>30 or g.h>25 or type(g.map)~="table" or
    type(g.names)~="table" or type(g.stock)~="table" or type(g.score)~="table" or
    (g.turn~=RED and g.turn~=BLUE) then return false end
  for y=1,g.h do
    if type(g.map[y])~="table" then return false end
    for x=1,g.w do
      local t=g.map[y][x]
      if type(t)~="table" or not ({water=true,plain=true,forest=true,hill=true,mountain=true})[t.kind]
        or type(t.owner)~="number" or t.owner<0 or t.owner>2 or type(t.army)~="number"
        or type(t.city)~="number" then return false end
    end
  end
  for p=1,2 do
    if type(g.names[p])~="string" or type(g.stock[p])~="table" or type(g.score[p])~="number" then return false end
    for _,r in ipairs({"food","wood","stone"}) do if type(g.stock[p][r])~="number" then return false end end
  end
  return true
end
local function saveGame(g)
  if not fs or not textutils then return false end
  return pcall(function()
    local path=savePath();local tmp=path..".tmp";local bak=path..".bak"
    local f=assert(fs.open(tmp,"w"));f.write(textutils.serialize(g));f.close()
    if fs.exists(bak) then fs.delete(bak) end
    if fs.exists(path) then fs.move(path,bak) end
    local ok,err=pcall(fs.move,tmp,path)
    if not ok then
      if fs.exists(bak) and not fs.exists(path) then fs.move(bak,path) end
      error(err)
    end
    if fs.exists(bak) then fs.delete(bak) end
  end)
end
local function loadGame()
  if not fs or not textutils then return nil end
  for _,path in ipairs({savePath(),savePath()..".bak"}) do
    local ok,g=pcall(function()
      if not fs.exists(path) then return nil end
      local f=assert(fs.open(path,"r"));local s=f.readAll();f.close()
      return textutils.unserialize(s)
    end)
    if ok and validSave(g) then return g end
  end
end
local function monitorSelect(requested)
  if not peripheral then return nil,nil end
  if requested then
    local m=peripheral.wrap(requested)
    if not m or peripheral.getType(requested)~="monitor" or (m.isColor and not m.isColor()) then
      error("Monitor unavailable or monochrome: "..requested)
    end
    return m,requested
  end
  local best,name,area=nil,nil,-1
  for _,n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n)=="monitor" then
      local m=peripheral.wrap(n)
      if not m.isColor or m.isColor() then
        local ok,sz=pcall(function()
          local prior=m.getTextScale();m.setTextScale(.5)
          local w,h=m.getSize();m.setTextScale(prior);return w*h
        end)
        if ok and sz>area then best,name,area=m,n,sz end
      end
    end
  end
  return best,name
end
local function tests()
  local n=0
  local function check(ok,s)
    n=n+1; if not ok then error("TEST FAILURE #"..n..": "..s) end
  end
  local function mock(w,h)
    local m={writes=0}
    m.getSize=function()return w,h end
    m.setCursorPos=function(x,y)check(y>=1 and y<=h,"cursor bounds") end
    m.blit=function(a,c,d)
      check(#a==w and #c==w and #d==w,"blit dimensions")
      m.writes=m.writes+1
    end
    return m
  end
  for i=1,50 do
    local g=makeGame(i*71,11,12,{"A","B"},i%2==0 and "isles" or "land",20)
    check(g.map[math.floor((g.h+1)/2)][2].capital,"P1 capital missing")
    check(countHoldings(g,1)==3 and countHoldings(g,2)==3,"opening land imbalance")
    for y=1,g.h do for x=1,g.w do
      local a=tile(g,x,y); local b=tile(g,g.w+1-x,g.h+1-y)
      -- Starting settlements modify a couple of tiles, otherwise the map remains symmetric.
      if a.owner==0 and b.owner==0 then check(a.kind==b.kind,"world symmetry") end
    end end
  end
  local g=makeGame(777,11,12,{"ALICE","BOB"},"land",20)
  local cy=math.floor((g.h+1)/2)
  check(legal(g,"claim",3,cy+1),"claim next to starter province")
  check(act(g,"claim",3,cy+1),"claim execution")
  check(g.ap==2 and tile(g,3,cy+1).owner==RED,"claim state")
  check(act(g,"found",3,cy+1),"found execution")
  check(tile(g,3,cy+1).city==1,"settlement")
  check(act(g,"recruit",2,cy),"recruit execution")
  check(tile(g,2,cy).army==7,"recruit increase")
  check(g.ap==0,"AP limiting")
  check(not legal(g,"upgrade",3,cy+1),"can't act without AP")
  endTurn(g);check(g.turn==BLUE and g.round==1,"turn exchange")
  endTurn(g);check(g.turn==RED and g.round==2,"full round")
  check(g.score[RED]>=3 and g.stock[RED].food>=4,"score/resources")
  -- Deterministic combat: source and destination must be adjacent and have ownership.
  g.ap=3;g.stock[RED].food=10
  local source,dest=tile(g,5,cy),tile(g,6,cy)
  source.kind="plain";source.owner=RED;source.army=9
  dest.kind="plain";dest.owner=BLUE;dest.army=0;dest.city=0;dest.fort=0
  check(legal(g,"attack",5,cy,6,cy),"adjacent enemy target")
  local ok=act(g,"attack",5,cy,6,cy)
  check(ok and dest.owner==RED and source.army==1,"victorious attack")
  check(not legal(g,"march",5,cy,8,cy),"non-adjacent march blocked")
  for _,sz in ipairs({{48,35},{57,38},{65,50},{78,52},{82,63},{98,68}}) do
    local m=mock(sz[1],sz[2]);local ui=newUI(sz[1],sz[2]);ui.game=g
    for _,page in ipairs({"menu","setup","rules","game","over"}) do
      ui.page=page;render(m,ui,clock())
      check(#ui.buttons>0,"touch buttons on "..page)
    end
    ui.page="setup";render(m,ui,clock());local editBefore=#ui.setup.names[1]
    for _,bt in ipairs(ui.buttons) do
      if bt.tag=="Q" then touch(ui,bt.x+1,bt.y);break end
    end
    check(#ui.setup.names[1]==editBefore+1,"on-screen keyboard")
    ui.page="game";render(m,ui,clock())
    local xx,yy=tcenter(g,2,cy,sz[1],sz[2]);touch(ui,xx,yy)
    check(ui.sel and ui.sel.x==2 and ui.sel.y==cy,"map tap mapping")
    local prev=m.writes;render(m,ui,clock());check(m.writes>prev,"render after selection")
    local prev2=m.writes;render(m,ui,clock());check(m.writes>=prev2,"buffered render")
  end
  local bad=copy(g);bad.version=1;check(not validSave(bad),"reject old format")
  check(validSave(g),"v2 save integrity")
  print("TIDEBOUND KINGDOMS v2.1: "..n.." checks passed")
end
local function run()
  local monitor,name=monitorSelect(argv[1])
  if not monitor then
    print("TIDEBOUND needs an Advanced Monitor (3x3 or larger).")
    print("Usage: tidebound [monitor-name]")
    return
  end
  local priorScale=monitor.getTextScale and monitor.getTextScale() or 1
  local original={}
  local function restore()
    for c,v in pairs(original) do pcall(monitor.setPaletteColor,c,v[1],v[2],v[3]) end
    pcall(monitor.setTextScale,priorScale)
  end
  local ok,err=pcall(function()
    monitor.setTextScale(.5)
    if colors and monitor.getPaletteColor and monitor.setPaletteColor then
      for name,hex in pairs(PALETTE) do
        local c=colors[name]
        if c then original[c]={monitor.getPaletteColor(c)};monitor.setPaletteColor(c,hex) end
      end
    end
    local w,h=monitor.getSize();local ui=newUI(w,h)
    ui.game=loadGame();ui.setup.names=ui.game and copy(ui.game.names) or ui.setup.names
    local speaker=peripheral.find and peripheral.find("speaker")
    local function sound()
      if speaker and speaker.playNote then pcall(speaker.playNote,"harp",.25,13) end
    end
    render(monitor,ui,clock())
    local timer=os.startTimer(.08)
    while true do
      local ev,a,b,c=os.pullEvent()
      if ev=="monitor_touch" and a==name then
        local before=ui.page
        local feedback=touch(ui,b,c)
        if feedback and feedback~="panel" and feedback~="footer" then sound() end
        if ui.changed then ui.saveOK=saveGame(ui.game);ui.changed=false end
        render(monitor,ui,clock())
      elseif ev=="char" and ui.page=="setup" then
        local p=ui.setup.active;local s=namesafe(a:upper())
        if #s==1 and #ui.setup.names[p]<12 then ui.setup.names[p]=ui.setup.names[p]..s end
        render(monitor,ui,clock())
      elseif ev=="paste" and ui.page=="setup" then
        local p=ui.setup.active;ui.setup.names[p]=namesafe(ui.setup.names[p]..a:upper())
        render(monitor,ui,clock())
      elseif ev=="key" and ui.page=="setup" and keys and a==keys.backspace then
        local p=ui.setup.active;ui.setup.names[p]=ui.setup.names[p]:sub(1,-2)
        render(monitor,ui,clock())
      elseif ev=="timer" and a==timer then
        render(monitor,ui,clock())
        -- 12.5 FPS during an effect, otherwise avoid expensive idle repaints.
        timer=os.startTimer(ui.fx and .08 or ui.page=="menu" and .20 or .35)
      elseif ev=="monitor_resize" and a==name then
        ui.prev=nil;render(monitor,ui,clock())
      end
    end
  end)
  restore()
  if not ok then error(err,0) end
end
if argv[1]=="--test-api" then
  return {makeGame=makeGame, mapSize=mapSize, tile=tile, legal=legal, act=act,
    endTurn=endTurn, income=income, newUI=newUI, render=render, touch=touch,
    validSave=validSave, copy=copy, clock=clock, tcenter=tcenter}
elseif argv[1]=="--self-test" then tests() else run() end