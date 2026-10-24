-- CIVCRAFT research canvas: connected prerequisite DAG with icon/name nodes
-- and a dedicated detail inspector. Coordinates are renderer virtual pixels.
local T={}
local function clip(s,n)return tostring(s or ""):upper():sub(1,math.max(0,n))end
local function clamp(v,lo,hi)return math.max(lo,math.min(hi,v))end
local icons={"food","map","ore","bolt","wrench","train"}
local function symbol(tech)
 return icons[math.max(1,math.min(#icons,tech.lane or 1))]
end
local function prerequisites(player,tech)
 local missing={}
 for _,req in ipairs(tech.requires or {})do
  if not (player.techs or {})[req]then missing[#missing+1]=req end
 end
 return missing
end
local Panels=dofile('/games/civcraft/panels.lua')
local function compact(r,systems,player,rect,model,research,onClose)
 local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
 r:text(x+3,y+3,'TECHNOLOGY',8,1,w-42)
 r:button(x+w-37,y+1,35,11,'CLOSE',onClose)
 local rows={};local tier=clamp(model.tier or 1,1,6)
 if model.detail then
  local chosen=systems.techs[model.selected]
  rows[#rows+1]={buttons={{label='BACK TO TREE',run=function()model.detail=false;model.offset=0 end}}}
  local paragraphs={chosen.name,'UNLOCK: '..chosen.unlock,
   'SCIENCE '..((player.researchProgress or {})[model.selected]or 0)..'/'..chosen.cost,
   'REQUIRES: '..(#chosen.requires>0 and table.concat(chosen.requires,', ') or 'NONE')}
  for _,paragraph in ipairs(paragraphs)do
   for _,line in ipairs(Panels.wrap(r,paragraph,w-12))do rows[#rows+1]={text=line}end
  end
  local allowed=systems.canResearch(player,model.selected)
  rows[#rows+1]={buttons={{label=allowed and 'RESEARCH' or (player.techs[model.selected] and 'COMPLETED' or 'LOCKED'),
   run=function()if allowed then research(model.selected)end end,style={primary=allowed}}}}
 else
  rows[#rows+1]={buttons={
   {label='PREV TIER',run=function()model.tier=clamp(tier-1,1,6);model.offset=0 end},
   {label='NEXT TIER',run=function()model.tier=clamp(tier+1,1,6);model.offset=0 end}}}
  for _,id in ipairs(systems.techOrder)do
   if systems.techs[id].tier==tier then
    rows[#rows+1]={buttons={{label=id,run=function()model.selected=id;model.detail=true;model.offset=0 end,
     style={selected=player.techs[id],primary=player.researchTarget==id}}}}
   end
  end
 end
 Panels.rows(r,{x=x+3,y=y+14,w=w-6,h=h-17},rows,model)
 return model
end
function T.draw(r,systems,player,rect,model,research,onClose)
 model=model or {};model.zoom=model.zoom or 1
 model.panX=model.panX or 0;model.panY=model.panY or 0
 model.selected=model.selected or systems.techOrder[1]
 local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 if r.mode=='text' or w<300 or h<210 then return compact(r,systems,player,rect,model,research,onClose)end
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
 local header=math.max(15,math.min(21,math.floor(h*.13)))
 r:fill(x+1,y+1,w-2,header,2)
 r:text(x+6,y+6,"TECHNOLOGY",8,1,w-52)
 r:button(x+w-40,y+3,35,14,"CLOSE",onClose)
 local graphX,graphY=x+5,y+header+6
 local graphH=math.max(26,h-header-29)
 local wide=w>=155
 local inspectorW=wide and math.max(62,math.floor(w*.34)) or 0
 local graphW=w-10-inspectorW-(wide and 6 or 0)
 local tier=math.max(1,math.min(6,model.tier or 1))
 local chosen=systems.techs[model.selected]
 if r.mode=="text"then
  graphW=w-10;graphH=math.max(20,h-header-65)
  r:fill(graphX,graphY,graphW,graphH,0)
  local row=0
  for _,id in ipairs(systems.techOrder)do
   local item=systems.techs[id]
   if item.tier==tier then
    local sy=graphY+2+row*13;row=row+1
    if sy+11<graphY+graphH then
     r:button(graphX+2,sy,graphW-4,11,item.name,function()
      model.selected=id
     end,{selected=model.selected==id})
    end
   end
  end
  r:text(x+7,graphY+graphH+3,clip(chosen.name,22),7)
  r:text(x+7,graphY+graphH+10,"COST "..systems.techCost(model.selected)..
   " / "..((player.researchProgress or {})[model.selected] or 0),6)
  r:button(x+4,y+h-15,math.floor(w/4)-4,12,"PREV",
   function()model.tier=clamp(tier-1,1,6)end)
  r:button(x+math.floor(w/4),y+h-15,math.floor(w/4)-4,12,"NEXT",
   function()model.tier=clamp(tier+1,1,6)end)
  r:button(x+math.floor(w/2),y+h-15,math.floor(w/4)-4,12,"RESEARCH",
   function()research(model.selected)end)
  r:button(x+math.floor(3*w/4),y+h-15,math.floor(w/4)-4,12,"CLOSE",onClose)
  return model
 end
 r:fill(graphX,graphY,graphW,graphH,0);r:outline(graphX,graphY,graphW,graphH,3)
 local zoom=clamp(model.zoom,.65,1.5)
 local nw,nh=math.floor(76*zoom),math.floor(23*zoom)
 local sx,sy=math.floor(96*zoom),math.floor(37*zoom)
 local maxX=math.max(0,6*sx+nw-graphW+8)
 local maxY=math.max(0,5*sy+nh-graphH+10)
 model.panX=clamp(model.panX,0,maxX)
 model.panY=clamp(model.panY,0,maxY)
 local function pos(id)
  local t=systems.techs[id]
  return graphX+7+(t.tier-1)*sx-model.panX,
   graphY+7+(t.lane-1)*sy-model.panY
 end
 local function stroke(ax,ay,bx,by,color)
  -- Per-pixel clipping: links never draw across sidebar or controls.
  local n=math.max(1,math.ceil(math.max(math.abs(bx-ax),math.abs(by-ay))))
  for i=0,n do
   local xx=ax+(bx-ax)*i/n;local yy=ay+(by-ay)*i/n
   if xx>graphX+1 and yy>graphY+1 and
     xx<graphX+graphW-2 and yy<graphY+graphH-2 then
    r:fill(xx,yy,1,1,color)
   end
  end
 end
 for _,id in ipairs(systems.techOrder)do
  local item=systems.techs[id];local x2,y2=pos(id)
  for _,req in ipairs(item.requires)do
   local x1,y1=pos(req)
   local color=(player.techs or {})[req] and 11 or 4
   local startX=x1+nw;local split=math.floor((startX+x2)/2)
   local h1=y1+nh/2;local h2=y2+nh/2
   stroke(startX,h1,split,h1,color)
   stroke(split,h1,split,h2,color)
   stroke(split,h2,x2,h2,color)
  end
 end
 for _,id in ipairs(systems.techOrder)do
  local tech=systems.techs[id]
  local px,py=pos(id)
  if px>graphX and py>graphY and
    px+nw<graphX+graphW and py+nh<graphY+graphH then
   local learned=(player.techs or {})[id]
   local selected=model.selected==id
   local active=player.researchTarget==id
   local allowed=systems.canResearch(player,id)
   local border=selected and 9 or learned and 11 or active and 8 or allowed and 6 or 4
   r:fill(px,py,nw,nh,selected and 3 or learned and 12 or active and 2 or 1)
   r:outline(px,py,nw,nh,border)
   r:fill(px+2,py+2,2,nh-4,border)
   r:icon(symbol(tech),px+6,py+math.max(3,math.floor((nh-9)/2)),1)
   r:text(px+19,py+math.max(3,math.floor((nh-5)/2)),
    clip(tech.name,math.floor((nw-22)/4)),7,1,nw-23)
   r.buttons[#r.buttons+1]={x=px,y=py,w=nw,h=nh,label=id,
    fn=function()model.selected=id end}
  end
 end
 if wide then
  local dx=graphX+graphW+5;local dw=w-(dx-x)-5
  r:fill(dx,graphY,dw,graphH,2)
  r:outline(dx,graphY,dw,graphH,3)
  r:fill(dx+3,graphY+3,3,13,9)
  r:text(dx+9,graphY+5,clip(chosen.name,math.floor((dw-14)/4)),7,1,dw-14)
  r:icon(symbol(chosen),dx+7,graphY+23,1)
  local researched=(player.techs or {})[model.selected]
  local active=player.researchTarget==model.selected
  local req=prerequisites(player,chosen)
  local prereq=#chosen.requires>0 and table.concat(chosen.requires,", ") or "NONE"
  local status=researched and "COMPLETED" or active and "RESEARCHING" or
    #req==0 and "AVAILABLE" or "LOCKED"
  r:text(dx+20,graphY+24,status,researched and 11 or active and 8 or 9,1,dw-24)
  r:text(dx+7,graphY+42,"PREREQUISITES",9,1,dw-13)
  r:text(dx+7,graphY+51,clip(prereq,math.floor((dw-14)/4)),7,1,dw-13)
  r:text(dx+7,graphY+69,"UNLOCKS",9,1,dw-13)
  r:text(dx+7,graphY+78,clip(chosen.unlock,math.floor((dw-14)/4)),7,1,dw-13)
  local cost=systems.techCost(model.selected)
  local progress=(player.researchProgress or {})[model.selected] or 0
  local rate=player.scienceRate or 0
  r:text(dx+7,graphY+97,"PROGRESS "..progress.."/"..cost,7,1,dw-13)
  local bar=math.max(8,dw-16)
  r:fill(dx+7,graphY+108,bar,5,4)
  r:fill(dx+7,graphY+108,bar*clamp(progress/cost,0,1),5,8)
  local estimate=rate>0 and (math.max(1,math.ceil((cost-progress)/rate)).." TURNS") or "NO SCIENCE"
  r:text(dx+7,graphY+119,"EST "..estimate,6,1,dw-13)
  if not researched then
   r:button(dx+5,graphY+graphH-20,dw-10,16,
    active and "IN PROGRESS" or #req==0 and "RESEARCH" or "LOCKED",
    function()if #req==0 then research(model.selected)end end,
    {primary=#req==0})
  end
 else
  r:fill(graphX,graphY+graphH-1,graphW,1,9)
  r:text(graphX+3,y+h-23,clip(chosen.name.." -> "..chosen.unlock,
   math.floor((w-12)/4)),7)
  if systems.canResearch(player,model.selected) then
   r:button(x+w-73,y+h-23,68,14,"RESEARCH",
    function()research(model.selected)end,{primary=true})
  end
 end
 -- Pan/zoom controls remain on the screen for touch-only clients.
 local controls={
  {"LEFT",function()model.panX=clamp(model.panX-75,0,maxX)end},
  {"RIGHT",function()model.panX=clamp(model.panX+75,0,maxX)end},
  {"UP",function()model.panY=clamp(model.panY-64,0,maxY)end},
  {"DOWN",function()model.panY=clamp(model.panY+64,0,maxY)end},
  {"ZOOM+",function()model.zoom=clamp(model.zoom+.2,.65,1.5)end},
  {"ZOOM-",function()model.zoom=clamp(model.zoom-.2,.65,1.5)end},
 }
 local cw=math.max(19,math.floor((w-12)/6))
 for i,action in ipairs(controls)do
  r:button(x+4+(i-1)*cw,y+h-19,cw-2,15,action[1],action[2])
 end
 return model
end
return T
