local Map=dofile('/games/civcraft/map_view.lua')
local Inspector=dofile('/games/civcraft/inspector.lua')
local Codex=dofile('/games/civcraft/encyclopedia.lua')
local TechTree=dofile('/games/civcraft/tech_tree.lua')
local Systems=dofile('/games/civcraft/systems.lua')
local Panels=dofile('/games/civcraft/panels.lua')
local Reports=dofile('/games/civcraft/reports.lua')
local Minimap=dofile('/games/civcraft/minimap.lua')
local G={}
local modes={'terrain','territory','resources','yields'}
local function modal(ui,rect,preserve)
 ui.modalBounds=rect;ui.lastDrag=nil;ui.r.buttons={};ui.r.scrollbars={}
 if preserve then ui.r:fill(rect.x,rect.y,rect.w,rect.h,1);ui.r:outline(rect.x,rect.y,rect.w,rect.h,8)
 else ui.r:fill(0,0,ui.r.w,ui.r.h,0)end
end
function G.draw(ui,state,player)
 local r=ui.r;local w,h=r.w,r.h
 local wide=w>=220 and h>=140
 local header=wide and 20 or 13
 local bottom=h-26
 local left=wide and 48 or 16
 local right=wide and math.max(92,math.floor(w*.32)) or math.max(48,math.min(72,math.floor(w*.42)))
 ui.inputMode='map'
 r:fill(0,0,w,h,0)
 r:fill(0,0,w,header,1)
 r:text(4,3,'CIVCRAFT',8,1,40)
 r:text(48,3,'ROUND '..state.round..'  '..(player and player.name or ''),7,1,w-52)
 if not wide then
  r:text(4,header-5,(ui.notice~='' and ui.notice or ('VIEW: '..ui.mapMode)):upper(),6,1,w-8)
 end
 Map.draw(ui,state,player,{x=left+4,y=header+2,w=w-left-right-10,h=bottom-header-4})
 local y=header+3
 local modeStep=math.min(14,math.floor((bottom-y-26)/4))
 for i,mode in ipairs(modes)do
  local icon=({'map','station','ore','food'})[i]
  local x=2;local width=left-4
  ui.overlays=ui.overlays or {}
  r:button(x,y,width,modeStep-2,wide and mode:upper() or nil,function()
   if mode=='terrain'then ui.overlays={}
   else ui.overlays[mode]=not ui.overlays[mode]
    if mode=='yields' and ui.overlays.yields then
     local steps=(32-ui.mapViewport.tile)/4;ui:zoom(steps)
    end
   end
  end,{selected=mode=='terrain' and not next(ui.overlays) or ui.overlays[mode]})
  if not wide then
   if modeStep<11 then r:text(x+math.floor(width/2)-1,y+2,({'T','B','R','Y'})[i],7)
   else r:icon(icon,x+math.floor((width-9)/2),y+2,1)end
   r.buttons[#r.buttons].label=mode:upper()
  end
  y=y+modeStep
 end
 r:button(2,y,left-4,11,'+',function()ui:zoom(1)end)
 r.buttons[#r.buttons].label='ZOOM IN'
 r:button(2,y+13,left-4,11,'-',function()ui:zoom(-1)end)
 r.buttons[#r.buttons].label='ZOOM OUT'
 local miniHeight=math.max(18,math.min(28,bottom-header-83))
 Inspector.draw(ui,state,player,{x=w-right-2,y=header+1,w=right,h=bottom-header-miniHeight-5})
 Minimap.draw(ui,state,player,{x=w-right,y=bottom-miniHeight-2,w=right-4,h=miniHeight})

 local actions={
  {'INSPECT',function()ui.panel='inspector';ui.inspectorOffset=0;ui.lastDrag=nil end},
  {'TECH TREE',function()ui.panel='tech';ui.source=nil;ui.reachable={};ui.workCity=nil;ui.lastDrag=nil end},
  {'CODEX',function()ui.panel='encyclopedia';ui.lastDrag=nil end},
  {'REPORT',function()ui.panel='report';ui.reportOffset=0 end},
  {'END TURN',function()ui:command('end')end},
  {'PAUSE',function()ui:command('pause')end}}
 local width=math.floor((w-8)/3)
 r:fill(0,bottom,w,26,1)
 for i,action in ipairs(actions)do
  r:button(2+((i-1)%3)*(width+2),bottom+1+math.floor((i-1)/3)*12,
   width,11,action[1],action[2],{primary=i==5})
 end
 if wide and ui.notice~=''then
  r:text(4,header-6,ui.notice,8,1,w-8)
 end
 local rect={x=3,y=3,w=w-6,h=h-6}
 if ui.endConfirm then
  modal(ui,rect)
  r:text(8,7,'END TURN?',8,1,w-16)
  r:button(7,19,math.floor((w-18)/2),11,'GO BACK',function()ui.endConfirm=nil end)
  r:button(math.floor(w/2)+2,19,math.floor((w-18)/2),11,'END ANYWAY',function()
   ui.endConfirm=nil;ui:command('end',{confirmed=true})
  end)
  local rows={}
  for _,entry in ipairs(ui.endConfirm)do
   for _,line in ipairs(Panels.wrap(r,entry,w-22))do rows[#rows+1]={text=line}end
  end
  Panels.rows(r,{x=8,y=34,w=w-16,h=h-42},rows,ui,'endOffset')
 elseif ui.pendingMove then
  modal(ui,rect)
  local order=ui.pendingMove
  r:outline(rect.x,rect.y,rect.w,rect.h,8)
  r:text(8,7,order.attack and 'CONFIRM ATTACK' or 'CONFIRM MOVE',8,1,w-16)
  local rows={}
  local description=(order.kind or 'UNIT'):upper()..' FROM '..order.sx..','..order.sy..
   ' TO '..order.x..','..order.y..'. COST '..order.cost..' MOVEMENT.'
  for _,line in ipairs(Panels.wrap(r,description,w-16))do rows[#rows+1]={text=line}end
  rows[#rows+1]={buttons={
   {label='CANCEL',run=function()ui.pendingMove=nil end},
   {label='CONFIRM',run=function()ui:confirmMove()end,style={primary=true}}}}
  Panels.rows(r,{x=7,y=20,w=w-14,h=h-26},rows,ui,'moveOffset')
 elseif ui.panel=='report'then
  local dw,dh=math.min(w-20,280),math.min(math.floor(h*.7),140)
  local box={x=math.floor((w-dw)/2),y=math.floor((h-dh)/2),w=dw,h=dh}
  modal(ui,box,true)
  r:text(box.x+5,box.y+5,'ROUND '..state.round..' REPORT',8,1,dw-50)
  r:button(box.x+dw-41,box.y+2,36,11,'CLOSE',function()ui.panel='context'end)
  local rows={}
  local lines=player.reportRound==state.round and player.turnReport or Reports.build(state,player)
  for _,entry in ipairs(lines or {})do
   for _,line in ipairs(Panels.wrap(r,entry,dw-22))do rows[#rows+1]={text=line}end
  end
  Panels.rows(r,{x=box.x+5,y=box.y+17,w=dw-10,h=dh-22},rows,ui,'reportOffset')
 elseif ui.panel=='tech'then
  modal(ui,rect);ui.techModel=ui.techModel or {}
  r:withClip(rect,function()
   TechTree.draw(r,Systems,player,rect,ui.techModel,
    function(id)ui:command('researchTech',{id=id})end,function()ui.panel='context'end)
  end)
 elseif ui.panel=='inspector'then
  modal(ui,rect);Inspector.draw(ui,state,player,rect,true)
 elseif ui.panel=='encyclopedia'then
  modal(ui,rect);Codex.draw(ui,rect)
 end
end
return G
