local Panels=dofile('/games/civcraft/panels.lua')
local E={}
function E.draw(ui,rect)
 local r=ui.r;local model=ui.empire or {category='units',offset=0};ui.empire=model
 r:fill(rect.x,rect.y,rect.w,rect.h,1);r:outline(rect.x,rect.y,rect.w,rect.h,8)
 r:text(rect.x+4,rect.y+4,'YOUR EMPIRE',8,1,rect.w-45)
 r:button(rect.x+rect.w-39,rect.y+1,36,11,'CLOSE',function()ui.panel='context'end)
 local width=math.floor((rect.w-10)/2)
 for i,category in ipairs({'units','cities'})do
  r:button(rect.x+3+(i-1)*(width+3),rect.y+13,width,11,category:upper(),function()
   model.category=category;model.offset=0
  end,{selected=model.category==category})
 end
 local rows={}
 local list=model.category=='cities' and ui.state.cities or ui.state.units
 for _,item in ipairs(list or {})do if item.owner==ui.playerID then
  local kind=model.category=='cities' and 'city' or 'unit'
  local label=kind=='city' and ('CITY '..item.x..','..item.y..' POP '..(item.population or 2)) or
   (item.kind:upper()..' '..item.x..','..item.y..' '..(item.standby and 'ZZ' or ('M'..(item.movesLeft or 0))))
  rows[#rows+1]={buttons={{label=label,run=function()ui:focus(kind,item)end}}}
 end end
 if #rows==0 then rows[1]={text='NONE OWNED'}end
 Panels.rows(r,{x=rect.x+3,y=rect.y+26,w=rect.w-6,h=rect.h-30},rows,model)
end
return E
