-- CIVCRAFT pixel canvas technology DAG, shared node data from systems.lua.
-- No browser/Basalt dependency: works in CraftOS-PC graphics and text fallback.
local T={}
local function clamp(a,lo,hi)return math.max(lo,math.min(hi,a))end
function T.draw(r,system,player,rect,model,research,onClose)
 local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 model=model or {}
 model.panX=model.panX or 0;model.panY=model.panY or 0
 model.zoom=model.zoom or 1
 if r.mode=="text" then
  r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
  model.tier=math.max(1,math.min(6,model.tier or 1))
  r:text(x+5,y+4,"TECH TREE - ERA "..model.tier,8)
  local found=0
  for _,id in ipairs(system.techOrder)do
   local tech=system.techs[id]
   if tech.tier==model.tier then
    local row=y+16+found*13
    found=found+1
    if row+11<y+h-16 then
     local learned=player.techs and player.techs[id]
     local can=system.canResearch(player,id)
     r:button(x+5,row,w-11,11,tech.name..
      (learned and " DONE" or can and " READY" or " LOCKED"),
      function()
       model.selected=id
       if can then research(id)end
      end,{primary=can})
    end
   end
  end
  r:button(x+4,y+h-14,math.floor(w/3)-5,11,"PREV",function()
   model.tier=math.max(1,model.tier-1)
  end)
  r:button(x+math.floor(w/3),y+h-14,math.floor(w/3)-5,11,
   "NEXT",function()model.tier=math.min(6,model.tier+1)end)
  r:button(x+math.floor(2*w/3),y+h-14,math.floor(w/3)-5,11,
   "CLOSE",onClose)
  return model
 end
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
 r:fill(x+2,y+2,w-4,17,2)
 r:text(x+6,y+6,"RESEARCH / TECH TREE",8,1,w-70)
 r:button(x+w-38,y+3,34,13,"CLOSE",onClose,{icon="back"})
 local inspectorW=math.max(57,math.floor(w*.30))
 local vx,vy=x+5,y+22
 local vw,vh=w-inspectorW-12,math.max(36,h-48)
 local ix=vx+vw+4
 local iw=x+w-ix-4
 r:fill(vx,vy,vw,vh,0);r:outline(vx,vy,vw,vh,3)
 r:fill(ix,vy,iw,vh,2);r:outline(ix,vy,iw,vh,3)
 local z=math.max(.65,math.min(1.4,model.zoom))
 local nodeW,nodeH=math.floor(82*z),math.floor(20*z)
 local strideX,strideY=math.floor(104*z),math.floor(35*z)
 local contentW=5*strideX+nodeW+8
 local contentH=4*strideY+nodeH+8
 local maxX,maxY=math.max(0,contentW-vw),math.max(0,contentH-vh)
 model.panX=clamp(model.panX,0,maxX);model.panY=clamp(model.panY,0,maxY)
 local function node(id)
  local item=system.techs[id]
  return vx+7+(item.tier-1)*strideX-model.panX,
   vy+7+(item.lane-1)*strideY-model.panY
 end
 local function segment(ax,ay,bx,by,c)
  local count=math.max(1,math.ceil(math.max(math.abs(ax-bx),math.abs(ay-by))))
  for i=0,count do
   local sx=ax+(bx-ax)*i/count;local sy=ay+(by-ay)*i/count
   if sx>vx+2 and sx<vx+vw-2 and sy>vy+2 and sy<vy+vh-2 then
    r:fill(sx,sy,1,1,c)
   end
  end
 end
 -- Directed prerequisite graph. Lines are clipped to its viewport.
 for _,id in ipairs(system.techOrder)do
  local t=system.techs[id];local tx,ty=node(id)
  for _,pre in ipairs(t.requires)do
   local px,py=node(pre)
   local color=(player.techs and player.techs[pre]) and 11 or 4
   local middle=math.floor((px+nodeW+tx)/2)
   segment(px+nodeW,py+nodeH/2,middle,py+nodeH/2,color)
   segment(middle,py+nodeH/2,middle,ty+nodeH/2,color)
   segment(middle,ty+nodeH/2,tx,ty+nodeH/2,color)
  end
 end
 model.selected=model.selected or system.techOrder[1]
 local iconFor={agriculture="food",mining="ore",sailing="map",
  bronze="wrench",masonry="station",writing="contract",horseback="train",
  navigation="map",engineering="foundry",philosophy="star",
  archery="right",currency="coin",cartography="map",fortification="station",
  education="contract",tactics="danger",commerce="coin",shipbuilding="train",
  metallurgy="foundry",astronomy="star",logistics="train",economics="coin",
  navalwarfare="danger",enlightenment="star"}
 for _,id in ipairs(system.techOrder)do
  local t=system.techs[id];local tx,ty=node(id)
  if tx>=vx+2 and ty>=vy+2 and
     tx+nodeW<vx+vw-2 and ty+nodeH<vy+vh-2 then
   local learned=player.techs and player.techs[id]
   local available=system.canResearch(player,id)
   local current=player.researchTarget==id
   local color=learned and 12 or current and 13 or available and 3 or 1
   r:fill(tx,ty,nodeW,nodeH,color)
   r:outline(tx,ty,nodeW,nodeH,model.selected==id and 8 or
     learned and 11 or 4)
   r:icon(iconFor[id] or "star",tx+3,ty+math.max(1,math.floor((nodeH-9)/2)),1)
   r:text(tx+15,ty+math.max(2,math.floor((nodeH-6)/2)),
     t.name,7,1,nodeW-19)
   r.buttons[#r.buttons+1]={x=tx,y=ty,w=nodeW,h=nodeH,label=id,
    fn=function()model.selected=id end}
  end
 end
 local t=system.techs[model.selected]
 if t then
  local yy=vy+5
  r:text(ix+4,yy,t.name,8,1,iw-7);yy=yy+16
  r:text(ix+4,yy,"COST "..t.cost.." SCI",7,1,iw-8);yy=yy+13
  local progress=(player.researchProgress or {})[model.selected] or 0
  local ratio=math.min(1,progress/math.max(1,t.cost))
  r:fill(ix+4,yy,iw-9,5,1)
  r:fill(ix+4,yy,math.floor((iw-9)*ratio),5,11)
  yy=yy+12
  r:text(ix+4,yy,math.floor(progress).."/"..t.cost,6,1,iw-8)
  yy=yy+14
  local req=#t.requires==0 and "NONE" or table.concat(t.requires,", ")
  r:text(ix+4,yy,"REQUIRES",8,1,iw-8);yy=yy+9
  r:text(ix+4,yy,req,6,1,iw-8);yy=yy+17
  r:text(ix+4,yy,"UNLOCKS",8,1,iw-8);yy=yy+10
  r:text(ix+4,yy,t.unlock or "-",11,1,iw-8)
  yy=yy+20
  local learned=player.techs and player.techs[model.selected]
  local can=system.canResearch(player,model.selected)
  local label=learned and "COMPLETED" or
    player.researchTarget==model.selected and "RESEARCHING" or
    can and "RESEARCH" or "LOCKED"
  if yy+16<vy+vh then
   r:button(ix+4,yy,iw-8,16,label,function()
    if can then research(model.selected)end
   end,{icon="bolt",primary=can})
  end
 end
 local cw=math.max(18,math.floor((vw-6)/6))
 local controls={
  {"LEFT",function()model.panX=clamp(model.panX-70,0,maxX)end},
  {"RIGHT",function()model.panX=clamp(model.panX+70,0,maxX)end},
  {"UP",function()model.panY=clamp(model.panY-55,0,maxY)end},
  {"DOWN",function()model.panY=clamp(model.panY+55,0,maxY)end},
  {"ZOOM+",function()model.zoom=clamp(model.zoom+.2,.65,1.4)end},
  {"ZOOM-",function()model.zoom=clamp(model.zoom-.2,.65,1.4)end}
 }
 for i,control in ipairs(controls)do
  r:button(vx+(i-1)*cw,vy+vh+3,cw-2,13,control[1],control[2])
 end
 return model
end
return T
