-- CIVCRAFT pixel canvas technology DAG, shared node data from systems.lua.
-- No browser/Basalt dependency: works in CraftOS-PC graphics and text fallback.
local T={}
local function clamp(a,lo,hi)return math.max(lo,math.min(hi,a))end
function T.draw(r,system,player,rect,model,research,onClose)
 local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 model=model or {}
 model.panX=model.panX or 0;model.panY=model.panY or 0
 model.zoom=model.zoom or 1
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
 r:fill(x+2,y+2,w-4,18,2)
 r:text(x+7,y+7,"CIVCRAFT  /  TECHNOLOGY",8,1,w-90)
 r:button(x+w-36,y+3,32,14,"CLOSE",onClose)
 local vx,vy=x+5,y+23
 local vw,vh=w-10,math.max(10,h-61)
 r:fill(vx,vy,vw,vh,0);r:outline(vx,vy,vw,vh,3)
 local sx=math.max(.6,model.zoom)
 local nodeW,nodeH=math.floor(99*sx),math.floor(25*sx)
 local strideX,strideY=math.floor(115*sx),math.floor(37*sx)
 local contentW=6*strideX+nodeW
 local contentH=5*strideY+nodeH
 local maxX=math.max(0,contentW-vw)
 local maxY=math.max(0,contentH-vh)
 model.panX=clamp(model.panX,0,maxX)
 model.panY=clamp(model.panY,0,maxY)
 local function node(id)
  local item=system.techs[id]
  return vx+7+(item.tier-1)*strideX-model.panX,
   vy+7+(item.lane-1)*strideY-model.panY
 end
 -- Edges first, so tech cards visually sit over connecting prerequisite lines.
 for _,id in ipairs(system.techOrder)do
  local t=system.techs[id]
  local tx,ty=node(id)
  for _,prereq in ipairs(t.requires)do
   local px,py=node(prereq)
   local edge=(player.techs and player.techs[prereq]) and 11 or 4
   local x1=px+nodeW;local x2=tx
   local yy=py+math.floor(nodeH/2);local yy2=ty+math.floor(nodeH/2)
   -- Clip strokes in view: never paint controls or inspector with graph lines.
   local mx=math.floor((x1+x2)/2)
   local function segment(ax,ay,bx,by)
    local distance=math.max(1,math.ceil(math.max(math.abs(ax-bx),math.abs(ay-by))))
    for n=0,distance do
     local dx=ax+(bx-ax)*n/distance
     local dy=ay+(by-ay)*n/distance
     if dx>vx+1 and dx<vx+vw-1 and dy>vy+1 and dy<vy+vh-1 then
      r:fill(dx,dy,1,1,edge)
     end
    end
   end
   segment(x1,yy,mx,yy);segment(mx,yy,mx,yy2);segment(mx,yy2,x2,yy2)
  end
 end
 for _,id in ipairs(system.techOrder)do
  local t=system.techs[id]
  local tx,ty=node(id)
  if tx>=vx+2 and ty>=vy+2 and tx+nodeW<vx+vw-2 and ty+nodeH<vy+vh-2 then
   local learned=player.techs and player.techs[id]
   local can=system.canResearch(player,id)
   local prereqs=true
   for _,pre in ipairs(t.requires)do if not (player.techs and player.techs[pre])then prereqs=false end end
   local base=learned and 12 or can and 3 or prereqs and 2 or 1
   r:fill(tx,ty,nodeW,nodeH,base)
   r:outline(tx,ty,nodeW,nodeH,learned and 11 or can and 8 or 4)
   r:fill(tx+2,ty+2,3,nodeH-4,learned and 11 or can and 8 or 4)
   r:text(tx+8,ty+4,t.name,7,1,nodeW-11)
   local status=learned and "RESEARCHED" or
    (prereqs and (t.cost.." SCIENCE") or "LOCKED")
   r:text(tx+8,ty+math.max(11,nodeH-10),status,learned and 6 or can and 8 or 5,1,nodeW-11)
   r.buttons[#r.buttons+1]={x=tx,y=ty,w=nodeW,h=nodeH,label=id,
    fn=function()model.selected=id end}
  end
 end
 local selected=model.selected and system.techs[model.selected]
 r:fill(x+2,y+h-35,w-4,33,2)
 local summary=selected and (selected.name.." / "..selected.cost.." SCI / "..selected.unlock) or
  "SELECT A TECHNOLOGY TO INSPECT IT"
 r:text(x+7,y+h-31,summary,7,1,w-85)
 if selected then
  local req=#selected.requires>0 and table.concat(selected.requires,",")or"START"
  r:text(x+7,y+h-21,"NEEDS: "..req,5,1,w-95)
  if system.canResearch(player,model.selected)then
   r:button(x+w-80,y+h-31,74,24,"RESEARCH",function()
    research(model.selected)
   end,{primary=true})
  end
 end
 local cw=math.max(19,math.floor((w-14)/6))
 local controls={
  {"LEFT",function()model.panX=clamp(model.panX-80,0,maxX)end},
  {"RIGHT",function()model.panX=clamp(model.panX+80,0,maxX)end},
  {"UP",function()model.panY=clamp(model.panY-70,0,maxY)end},
  {"DOWN",function()model.panY=clamp(model.panY+70,0,maxY)end},
  {"ZOOM+",function()model.zoom=clamp(model.zoom+.2,.6,1.4)end},
  {"ZOOM-",function()model.zoom=clamp(model.zoom-.2,.6,1.4)end},
 }
 local cy=y+h-57
 if cy>vy+vh then cy=vy+vh+2 end
 for i,control in ipairs(controls)do
  r:button(x+5+(i-1)*cw,cy,cw-2,15,control[1],control[2])
 end
 return model
end
return T
