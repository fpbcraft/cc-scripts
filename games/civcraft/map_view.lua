-- World geometry, painting and pointer targets use the same pointy hex polygons.
local Hex=dofile('/games/civcraft/hex.lua')
local World=dofile('/games/civcraft/world.lua')
local Icons=dofile('/games/civcraft/icons.lua')
local Terrain=dofile('/games/civcraft/terrain_view.lua')
local V={}
local colors={8,13,11,21}
local function at(list,x,y)
 for _,item in ipairs(list or {})do if item.x==x and item.y==y then return item end end
end
local function ownerColor(state,id)
 for i,p in ipairs(state.players)do if p.id==id then return colors[i] or 8 end end
 return 8
end
function V.draw(ui,state,player,rect)
 local frame=rect
 rect={x=frame.x+4,y=frame.y+4,w=frame.w-8,h=frame.h-8}
 ui.mapFrame=frame
 local r=ui.r;local world=state.world;local overlays=ui.overlays or {}
 local width,height=world and world.width or Hex.width,world and world.height or Hex.height
 local size=ui.zoomLevel or math.max(12,math.min(24,math.floor(rect.h/32)*4))
 local step=size*.75
 local maxX=math.max(0,(width+.5)*size-rect.w)
 local maxY=math.max(0,(height-1)*step+size-rect.h)
 if not ui.worldReady or ui.lastWorldKey~=ui.worldKey then
  ui.worldReady=true;ui.lastWorldKey=ui.worldKey;ui.panX=0;ui.panY=0
  local focus={}
  for _,c in ipairs(state.cities or {})do focus[#focus+1]=c end
  for _,u in ipairs(state.units or {})do focus[#focus+1]=u end
  for _,c in ipairs(focus)do if c.owner==ui.playerID then
   ui.selected={x=c.x,y=c.y}
   ui.panX=(c.x-.5)*size-rect.w/2;ui.panY=(c.y-.5)*step-rect.h/2;break
  end end
 end
 ui.panX=math.max(0,math.min(maxX,ui.panX or 0));ui.panY=math.max(0,math.min(maxY,ui.panY or 0))
 ui.mapViewport={x=rect.x,y=rect.y,w=rect.w,h=rect.h,tile=size,maxX=maxX,maxY=maxY}
 local claims={}
 for y=1,height do for x=1,width do claims[World.key(x,y)]=World.territoryCity(state,Hex,x,y)end end
 local tiles={};ui.hexTargets={}
 r:fill(rect.x-1,rect.y-1,rect.w+2,rect.h+2,1)
 r:withClip(rect,function()
  for y=1,height do for x=1,width do
   local px=rect.x+(x-1)*size+((y-1)%2)*size/2-ui.panX
   local py=rect.y+(y-1)*step-ui.panY
   if px+size>rect.x and px<rect.x+rect.w and py+size>rect.y and py<rect.y+rect.h then
    local visibility=World.known(player,x,y);local hidden=visibility=='hidden'
    local land=Hex.terrain(x,y,state);local claim=claims[World.key(x,y)]
    local owner=claim and claim.owner
    if owner~=ui.playerID and visibility~='visible'then owner=nil end
    local deposit=not hidden and World.deposit(world,x,y)
    local yields=not hidden and World.yields(world,x,y)
    local base=hidden and 15 or Terrain.color(land,visibility=='explored')
    if visibility=='visible'then
     if overlays.territory then base=owner and ownerColor(state,owner) or base end
    end
    for dy=0,size-1 do
     local inset=dy<size/4 and size/2-2*dy or dy>=size*3/4 and 2*(dy+1)-size*1.5 or 0
     r:fill(px+inset,py+dy,math.max(1,size-inset*2),1,base)
    end
    if not hidden and visibility=='visible' and not overlays.territory then Terrain.draw(r,land,px,py,size,x,y)end
    local vertices=Hex.vertices(px,py,size)
    for i,a in ipairs(vertices)do local b=vertices[i%6+1];r:line(a.x,a.y,b.x,b.y,hidden and 14 or 3)end
    tiles[#tiles+1]={x=x,y=y,px=px,py=py,owner=owner,claim=claim,visibility=visibility,
     land=land,deposit=deposit,yields=yields}
    ui.hexTargets[#ui.hexTargets+1]={x=px,y=py,w=size,h=size,tx=x,ty=y}
   end
  end end
  -- Paint borders after all terrain, so neighbouring fills cannot erase them.
  for _,t in ipairs(tiles)do
   local x,y,px,py=t.x,t.y,t.px,t.py
   if t.owner and t.visibility~='hidden'then
    local vertices=Hex.vertices(px,py,size)
    for side,n in ipairs(Hex.edgeNeighbours(x,y))do
     if claims[World.key(n.x,n.y)]~=t.claim then
      local a,b=vertices[side],vertices[side%6+1]
      r:line(a.x,a.y,b.x,b.y,ownerColor(state,t.owner))
     end
    end
   end
   if t.visibility~='hidden'then
    if t.deposit and overlays.resources then
     if size>=16 then Icons.draw(r,t.deposit,px+size/2-4,py+2,9,9)
     else r:fill(px+size/2-1,py+2,3,2,8)end
    end
    if ui.workCity then
     local city=at(state.cities,ui.workCity.x,ui.workCity.y)
     if city and city==t.claim and not (x==city.x and y==city.y)then
      r:fill(px+size/4,py+size-4,size/2,2,city.worked and city.worked[World.key(x,y)] and 11 or 9)
     end
    end
   end
   for _,destination in ipairs(ui.reachable or {})do
    if destination.x==x and destination.y==y then
     r:fill(px+size/4,py+size-3,size/2,2,destination.attack and 10 or 11)
    end
   end
   local city=t.visibility~='hidden' and at(state.cities,x,y)
   if city and (city.owner==ui.playerID or t.visibility=='visible')then
    if size<16 then r:fill(px+size/2-1,py+size/2-1,3,3,ownerColor(state,city.owner))
    else Icons.draw(r,'city',px+size/2-5,py+size/2-5,11,ownerColor(state,city.owner))end
   end
   local unit=t.visibility=='visible' and at(state.units,x,y)
   if unit then
    if size<16 then r:fill(px+size/2,py+size/2,2,2,ownerColor(state,unit.owner))
    else Icons.draw(r,unit.kind,px+size/2-5,py+size/2-5,11,ownerColor(state,unit.owner))end
   end
   if overlays.yields and t.visibility~='hidden' and size<32 then
    local values={t.yields.food,t.yields.industry,t.yields.science};local best=1
    for i=2,3 do if values[i]>values[best]then best=i end end
    local label=tostring(values[best]);local width=r:textWidth(label)
    r:fill(px+size/2-width/2-1,py+size/2-3,width+2,7,1)
    r:text(px+size/2-width/2,py+size/2-2,label,({11,8,13})[best],1,width)
   end
   if overlays.yields and t.visibility~='hidden' and size>=32 then
    local top='F'..t.yields.food..' I'..t.yields.industry
    local width=r:textWidth(top)
    r:fill(px+size/2-width/2-1,py+6,width+2,7,1)
    r:text(px+size/2-width/2,py+7,top,7,1,width)
    local bottom='S'..t.yields.science;local bw=r:textWidth(bottom)
    r:fill(px+size/2-bw/2-1,py+24,bw+2,6,1)
    r:text(px+size/2-bw/2,py+25,bottom,13,1,bw)
   end
   if not ui.selected.empty and ui.selected.x==x and ui.selected.y==y then
    local vertices=Hex.vertices(px+1,py+1,size-2)
    for i,a in ipairs(vertices)do local b=vertices[i%6+1];r:line(a.x,a.y,b.x,b.y,7)end
   end
  end
 end)
 r:outline(rect.x-1,rect.y-1,rect.w+2,rect.h+2,3)
 -- Four narrow click strips belong to the map frame, never the side panels.
 local edges={
  {x=frame.x,y=frame.y,w=4,h=frame.h,dx=-3,dy=0,name='LEFT'},
  {x=frame.x+frame.w-4,y=frame.y,w=4,h=frame.h,dx=3,dy=0,name='RIGHT'},
  {x=frame.x+4,y=frame.y,w=frame.w-8,h=4,dx=0,dy=-3,name='UP'},
  {x=frame.x+4,y=frame.y+frame.h-4,w=frame.w-8,h=4,dx=0,dy=3,name='DOWN'}}
 for _,edge in ipairs(edges)do
  r:fill(edge.x,edge.y,edge.w,edge.h,3)
  local cx=math.floor(edge.x+edge.w/2);local cy=math.floor(edge.y+edge.h/2)
  if edge.dx~=0 then
   local sign=edge.dx<0 and -1 or 1
   r:line(cx-sign,cy-2,cx+sign,cy,7);r:line(cx+sign,cy,cx-sign,cy+2,7)
  else
   local sign=edge.dy<0 and -1 or 1
   r:line(cx-2,cy-sign,cx,cy+sign,7);r:line(cx,cy+sign,cx+2,cy-sign,7)
  end
  r.buttons[#r.buttons+1]={x=edge.x,y=edge.y,w=edge.w,h=edge.h,label='MAP '..edge.name..' EDGE',
   fn=function()ui:pan(edge.dx*size,edge.dy*size)end}
 end
end
return V
