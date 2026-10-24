local Systems=dofile('/games/civcraft/systems.lua')
local Hex=dofile('/games/civcraft/hex.lua')
local World=dofile('/games/civcraft/world.lua')
local Panels=dofile('/games/civcraft/panels.lua')
local Combat=dofile('/games/civcraft/combat.lua')
local I={}
local function at(list,x,y)
 for _,item in ipairs(list or {})do if item.x==x and item.y==y then return item end end
end
function I.draw(ui,state,player,rect,modal)
 local r=ui.r;local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 ui.inspectorBounds=rect
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,3)
 r:text(x+3,y+3,'INSPECTOR',8,1,w-(modal and 40 or 6))
 if modal then r:button(x+w-36,y+1,34,11,'CLOSE',function()ui.panel='context'end)end
 local city=not ui.selected.empty and at(state.cities,ui.selected.x,ui.selected.y)
 local unit=not ui.selected.empty and at(state.units,ui.selected.x,ui.selected.y)
 local rows={};local function text(value,color)
  for _,line in ipairs(Panels.wrap(r,value,w-17))do rows[#rows+1]={text=line,color=color}end
 end
 local bodyY=y+13
 local controlsY=y+13
 local stacked=false
 if city and unit and city.owner==ui.playerID and unit.owner==ui.playerID then
  stacked=true
  local width=math.floor((w-6)/2)
  for i,kind in ipairs({'city','unit'})do
   r:button(x+2+(i-1)*(width+2),controlsY,width,11,kind:upper(),function()
    ui.selected.kind=kind;ui.inspectorOffset=0;ui.source=nil;ui.reachable={};ui.workCity=nil
   end,{selected=(ui.selected.kind or 'unit')==kind})
  end
  controlsY=controlsY+12;bodyY=controlsY
  if (ui.selected.kind or 'unit')=='unit'then city=nil else unit=nil end
 end
 if ui.selected.empty then
  text('NO SELECTION',7);text('Click a hex to inspect it.')
 elseif city and city.owner==ui.playerID then
  local tabs=w<80 and {'JOBS','HEX','PROD'} or {'JOBS','TILES','PROD'};local values={'jobs','tiles','production'}
  local width=math.floor((w-8)/3)
  local tabButtons={}
  for i,label in ipairs(tabs)do
   local mode=values[i]
   local function choose()
    ui.cityPanel=mode;ui.inspectorOffset=0;ui.cityStrikeSource=nil;ui.source=nil;ui.reachable={};ui.pendingMove=nil
    ui.workCity=mode=='tiles' and {x=city.x,y=city.y} or nil
    if mode=='tiles' and modal then ui.panel='context'end
   end
   if stacked and h<64 then
    tabButtons[#tabButtons+1]={label=label,run=choose,style={selected=(ui.cityPanel or 'jobs')==mode}}
   else r:button(x+2+(i-1)*(width+2),controlsY,width,11,label,choose,{selected=(ui.cityPanel or 'jobs')==mode})end
  end
  if #tabButtons>0 then rows[#rows+1]={buttons=tabButtons};bodyY=controlsY
  else bodyY=controlsY+11 end
  Combat.city(city)
  local yields=Systems.yields(player,city,state,Hex)
  text('POP '..(city.population or 2)..'  IDLE '..Systems.idle(city),7)
  rows[#rows+1]={yields=yields}
  local growth=Systems.growth(player,city,state)
  text(growth.status=='GROWING' and ('POP +1 IN '..growth.turns..'T')or growth.status=='STARVING' and (growth.canShrink and ('POP -1 IN '..growth.turns..'T')or 'STARVING - MIN POP')or 'POP STAGNANT',growth.status=='STARVING'and 31 or 13)
  text('FOOD '..math.floor(growth.stored)..'/'..growth.threshold..' ('..(growth.surplus>=0 and '+'or '')..growth.surplus..')')
  text('CITY HP '..city.hp..'/200')
  if city.maxWalls>0 then text('WALLS '..city.wallHP..'/'..city.maxWalls,13)end
  if city.wallHP>0 and city.struckRound~=state.round then rows[#rows+1]={buttons={{label='CITY STRIKE',run=function()ui:armCityStrike(city)end}}}end
  if ui.cityPanel=='production'then
   local project=city.project
   text(project and ('MAKING '..project.id:upper()) or 'NO PRODUCTION',8)
   rows[#rows+1]={buttons={
    {label='UNITS',run=function()ui.productionCategory='unit';ui.inspectorOffset=0 end,
     style={selected=ui.productionCategory~='building'}},
    {label='BUILDS',run=function()ui.productionCategory='building';ui.inspectorOffset=0 end,
     style={selected=ui.productionCategory=='building'}}}}
   local kind=ui.productionCategory=='building' and 'building' or 'unit'
   local source=kind=='building' and Systems.buildings or Systems.units
   local list={}
   for id in pairs(source)do
    local allowed
    if kind=='unit'then allowed=Systems.canRecruit(player,id,state,Hex,city)
    else allowed=Systems.canBuild(player,city,id,state)end
    if allowed then list[#list+1]={id=id,allowed=true}end
   end
   table.sort(list,function(a,b)
    if a.allowed~=b.allowed then return a.allowed end
    return a.id<b.id
   end)
   for _,item in ipairs(list)do
    local id=item.id;local allowed=item.allowed
    local active=city.project and city.project.kind==kind and city.project.id==id
    local progress=active and city.project.progress or (city.projectProgress or {})[kind..':'..id] or 0
    local turns=math.max(1,math.ceil((Systems.projectCost(kind,id)-progress)/math.max(1,yields.industry)))
    rows[#rows+1]={project={label=id:upper()..' '..turns..'T',selected=active,
     run=function()ui:command('queue',{cityX=city.x,cityY=city.y,kind=kind,id=id})end,
     info=function()ui:openCodex(kind=='unit'and 'units'or 'buildings',id)end,id=id}}
   end
  elseif ui.cityPanel=='tiles'then
   local count=0;for _ in pairs(city.worked or {})do count=count+1 end
   text('WORKED '..count..'/'..(city.population or 2),8)
   text('TAP LAND HEXES')
   text('Tap a worked hex to free it.')
   rows[#rows+1]={buttons={{label='DONE WORK',run=function()ui.workCity=nil;ui.cityPanel='jobs';ui.inspectorOffset=0 end}}}
  else
   for _,job in ipairs(Systems.jobs)do
    rows[#rows+1]={adjust={icon=job,label=tostring(city.jobs[job]or 0),
     minus=function()ui:command('assign',{x=city.x,y=city.y,from=job,to='idle'})end,
     plus=function()
      if Systems.idle(city)>0 then ui:command('assign',{x=city.x,y=city.y,from='idle',to=job})
      else ui:feedback('No idle citizens. Use - to free one first.')end
     end}}
   end
   text('- frees a citizen; + uses idle.')
  end
 elseif unit and unit.owner==ui.playerID then
  local stats=Systems.units[unit.kind] or Systems.units.warrior
  Combat.unit(unit)
  text(unit.kind:upper()..' LV'..unit.level,7)
  text('HP '..unit.hp..'/100',unit.hp<35 and 31 or 13)
  text('ATK '..Combat.power(unit,Systems,false,state)..' DEF '..Combat.power(unit,Systems,true,state))
  text('XP '..unit.xp..'/'..(unit.level*10))
  text('MOVE '..(unit.movesLeft or 0)..'/'..stats.move)
  text('UPKEEP '..(stats.upkeep or 1)..' GOLD')
  if not stats.naval and Hex.terrain(unit.x,unit.y,state)=='water'then text('EMBARKED',13)end
  text('RANGE '..stats.range..' VISION '..stats.vision)
  for _,line in ipairs(Panels.wrap(r,stats.ability or '',w-10))do text(line)end
  rows[#rows+1]={buttons={{label='MOVE / ATTACK',run=function()
   ui.cityStrikeSource=nil
   if unit.standby then ui:feedback('Wake this unit before issuing orders.');return end
   if ui.mapViewport and ui.mapViewport.tile<16 then ui:zoom((16-ui.mapViewport.tile)/4)end
   ui.source={x=unit.x,y=unit.y};ui.reachable=Hex.reachable(state,unit,ui.playerID,Systems)
   ui.pendingMove=nil;ui:feedback('CYAN RINGS MOVE / RED CROSSES ATTACK');if modal then ui.panel='context'end
  end}}}
  rows[#rows+1]={buttons={{label=unit.standby and 'WAKE UNIT' or 'SLEEP UNIT',run=function()
   ui.source=nil;ui.reachable={};ui.pendingMove=nil
   ui:command('standby',{x=unit.x,y=unit.y,value=not unit.standby})
  end}}}
  rows[#rows+1]={buttons={{label='FORTIFY / HEAL',run=function()ui.source=nil;ui.reachable={};ui.pendingMove=nil;ui:command('heal',{x=unit.x,y=unit.y})end}}}
  if unit.kind=='scout' or unit.kind=='explorer'then rows[#rows+1]={buttons={{label=unit.autoExplore and 'STOP EXPLORING' or 'AUTO EXPLORE',run=function()ui:command('autoExplore',{x=unit.x,y=unit.y,value=not unit.autoExplore})end}}}end
  if ui.source then rows[#rows+1]={buttons={{label='CANCEL MOVE',run=function()ui.source=nil;ui.reachable={};ui.pendingMove=nil end}}}end
  rows[#rows+1]={buttons={{label='DISBAND',run=function()ui:command('disband',{x=unit.x,y=unit.y,unitID=unit.id})end}}}
  rows[#rows+1]={buttons={{label='DESELECT',run=function()ui:deselect()end}}}
  if unit.kind=='settler' and not at(state.cities,unit.x,unit.y)then rows[#rows+1]={buttons={{label='FOUND CITY',run=function()ui:command('found',{x=unit.x,y=unit.y})end}}}end
 elseif (city or unit)and World.known(player,ui.selected.x,ui.selected.y)=='visible'then
  if city then
   Combat.city(city);text('ENEMY CITY',31);text('HP '..city.hp..'/200');text('WALLS '..city.wallHP..'/'..city.maxWalls);text('DEF '..Combat.cityPower(state,city,Systems))
  else
   Combat.unit(unit);text(unit.kind:upper()..' LV'..unit.level,31);text('HP '..unit.hp..'/100');text('ATK '..Combat.power(unit,Systems,false,state));text('DEF '..Combat.power(unit,Systems,true,state))
  end
 else
  local known=World.known(player,ui.selected.x,ui.selected.y)
  text('HEX '..ui.selected.x..','..ui.selected.y,7)
  text(known=='hidden' and 'UNEXPLORED' or Hex.terrain(ui.selected.x,ui.selected.y,state))
  if known~='hidden'then
   local yields=World.yields(state.world,ui.selected.x,ui.selected.y)
   rows[#rows+1]={yields=yields}
   text(World.deposit(state.world,ui.selected.x,ui.selected.y)or 'NO DEPOSIT')
  end
 end
 if unit and unit.owner==ui.playerID then
  local ordered={};local used={}
  for i,row in ipairs(rows)do if i==1 or row.text and (row.text:match('^HP ')or row.text:match('^MOVE '))then ordered[#ordered+1]=row;used[i]=true end end
  for i,row in ipairs(rows)do if row.buttons then ordered[#ordered+1]=row;used[i]=true end end
  for i,row in ipairs(rows)do if not used[i]then ordered[#ordered+1]=row end end
  rows=ordered
 end
 Panels.rows(r,{x=x+3,y=bodyY,w=w-6,h=y+h-bodyY-2},rows,ui,'inspectorOffset')
end
return I
