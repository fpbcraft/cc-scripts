local Systems=dofile('/games/civcraft/systems.lua')
local Icons=dofile('/games/civcraft/icons.lua')
local Panels=dofile('/games/civcraft/panels.lua')
local H={}
local function compact(value)
 value=math.floor(value or 0)
 if math.abs(value)>=1000 then return math.floor(value/1000)..'K'end
 return tostring(value)
end
function H.resources(ui,state,player)
 local r=ui.r;local economy=Systems.economy(player,state);ui.economy=economy
 local x=4
 r:withClip({x=4,y=14,w=r.w-8,h=7},function()
  for _,entry in ipairs({{'gold',player.gold or 20,economy.net},{'science',player.science,economy.science},
   {'food',player.food,economy.food},{'wood',player.wood,economy.industry}})do
   local value=compact(entry[2])..(entry[3]>=0 and '+'or '')..compact(entry[3])
   local width=Icons.yieldValue(r,entry[1],value,x,15)
   x=x+width+3
  end
  for _,kind in ipairs({'iron','horses','saltpeter'})do
   Icons.resource(r,kind,x,15)
   local value=compact((player.stockpile or {})[kind])..'+'..economy.strategic[kind];r:text(x+6,15,value,7)
   x=x+7+r:textWidth(value)+3
  end
 end)
 r.buttons[#r.buttons+1]={x=4,y=14,w=r.w-8,h=7,label='RESOURCE LEDGER',fn=function()ui.panel='resources';ui.resourceOffset=0 end}
end
function H.ledger(ui,rect,player)
 local r=ui.r;local e=Systems.economy(player,ui.state)
 r:fill(rect.x,rect.y,rect.w,rect.h,1);r:outline(rect.x,rect.y,rect.w,rect.h,8)
 r:text(rect.x+4,rect.y+4,'EMPIRE RESOURCES',8,1,rect.w-48)
 r:button(rect.x+rect.w-41,rect.y+1,38,11,'CLOSE',function()ui.panel='context'end)
 local rows={}
 for _,entry in ipairs({{'GOLD',player.gold or 20,e.net},{'SCIENCE',player.science or 0,e.science},
  {'FOOD',player.food or 0,e.food},{'INDUSTRY',player.wood or 0,e.industry},
  {'GOLD INCOME',e.income,0},{'UNIT UPKEEP',e.upkeep,0}})do
  for _,line in ipairs(Panels.wrap(r,entry[1]..' '..entry[2]..' ('..(entry[3]>=0 and '+'or '')..entry[3]..'/TURN)',rect.w-20))do rows[#rows+1]={text=line}end
 end
 for _,kind in ipairs({'iron','horses','saltpeter'})do rows[#rows+1]={text=kind:upper()..' '..((player.stockpile or {})[kind]or 0)..' (+'..e.strategic[kind]..'/TURN)'}end
 rows[#rows+1]={text='Gold pays unit upkeep each round.'}
 rows[#rows+1]={text='Unpaid units are disbanded.'}
 Panels.rows(r,{x=rect.x+4,y=rect.y+16,w=rect.w-8,h=rect.h-21},rows,ui,'resourceOffset')
end
return H
