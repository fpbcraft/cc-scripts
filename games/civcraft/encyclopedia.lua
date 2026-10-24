-- Content-derived entries stay in sync with the simulation's costs and unlocks.
local Systems=dofile('/games/civcraft/systems.lua')
local Panels=dofile('/games/civcraft/panels.lua')
local E={}
local mechanics={
 {id='turns',name='TURNS AND VICTORY',text='Issue orders, then end your turn. Production, research and movement reset after every player is ready. Own eight cities to win, or lead the score after round 90. Score is 20 per city, 8 per technology, plus accumulated science.'},
 {id='population',name='POPULATION AND JOBS',text='Jobs and worked hexes share one population pool. Minus unworks a tile of that type. Plus assigns an idle citizen to an available owned tile of that type. Food, industry and science jobs follow the tile\'s strongest yield. No free matching tile means no new assignment. Population grows from surplus food.'},
 {id='tiles',name='WORKED HEXES',text='A city works its center automatically. Each additional citizen can work one owned hex within two steps. Open TILES and tap a worked hex to unassign it, or an available hex to work it. The JOBS controls automatically choose tiles; TILES lets you pick them manually. Both change the same assignments.'},
 {id='territory',name='CITY TERRITORY',text='City borders claim nearby land within two hexes. The nearest city claims each hex, with stable ties. Borders trace the actual sides of hexes. A new city must be at least three hexes from another city. Strategic deposits must connect to your territory.'},
 {id='yields',name='FOOD INDUSTRY SCIENCE',text='Worked terrain and deposits provide yields. Buildings and civilization bonuses add to them. Food above two per turn fills city food storage. Growth requires 5 plus 3 times current population. New citizens automatically work an available owned tile. If none is free, they stay idle.'},
 {id='production',name='CITY PRODUCTION',text='Open an owned city, choose PROD, then UNITS or BUILDS. Select an unlocked project. Industry is added each round; stored industry is not spent to buy it instantly. Switching retains project progress. A finished unit waits if no valid spawn hex is free.'},
 {id='research',name='RESEARCH',text='Select a technology in TECH TREE, then start research. Required technologies must be completed first. Your cities add science every round until the cost is met. Selecting a different target retains earlier progress.'},
 {id='movement',name='MOVEMENT',text='Select an owned unit, then press MOVE / ATTACK in the inspector to show legal destinations. Green bars mark movement; red bars mark attacks. Choose a destination, then confirm. Clicking the unit again deselects it. Cancel leaves your orders unchanged. Plains cost one movement point; forests and hills cost two, or three for horsemen. Scouts and rangers cross forests for one. Mountains block land units.'},
 {id='combat',name='COMBAT AND RANGE',text='Only highlighted enemy hexes can be attacked. Strength, defense, city defenses, terrain and unit abilities affect deterministic combat. Ranged attacks do not move the attacker into the target hex and consume its remaining movement. A defeated attacker is removed.'},
 {id='naval',name='NAVAL UNITS',text='Ships travel on water rather than land. Build them in a city beside a free water hex. Some ships require an owned strategic deposit and research. Mariner ships receive one extra movement point each round.'},
 {id='fog',name='EXPLORATION AND FOG',text='Visible hexes show current units. Explored hexes retain terrain but hide unseen enemies. Unexplored terrain and deposits stay concealed. Vision comes from cities and units. Hotseat handoffs conceal the previous player, and network views filter private information.'},
 {id='maps',name='MAP TYPES',text='Choose Compact, Standard or Large in the lobby. Continents, Archipelago, Pangaea and Highlands create different terrain distributions. A fixed seed reproduces the same world. Scouts reveal land; settlers expand into new territory.'},
 {id='saving',name='SAVES AND MULTIPLAYER',text='Local hotseat uses three campaign slots and a private handoff screen. Network hosting and joining use modem connections and a separate match save. Save from the pause menu. Updating code preserves campaigns. Main Menu returns to the title; Exit closes the game.'},
 {id='controls',name='MAP AND INSPECTOR',text='Click the narrow map edges, or drag or scroll inside the map, to pan. Use + and - to zoom. Click the fog-aware minimap to jump to a region. Resources, yields and territory are independent overlay toggles, off by default. TERRAIN clears overlays. YIELDS zooms in for readable labels; the tile inspector always gives a numeric breakdown. The right inspector stays visible. Use its scrollbar or PREV and NEXT to reach long lists. INSPECT opens a larger version. Modal screens block map input until closed.'},
}
mechanics[#mechanics+1]={id='standby',name='SLEEP AND TURN CHECKS',text='SLEEP UNIT keeps a unit on standby across rounds. Wake it with WAKE UNIT before issuing orders. Ending a turn asks for confirmation when awake units have movement left, cities lack production, or research is unassigned. END ANYWAY deliberately skips these orders.'}
mechanics[#mechanics+1]={id='reports',name='TURN REPORTS',text='Each turn begins with a private report of your economy, completed research and buildings, city growth, recruited or lost units, and damaged units. REPORT opens it again. Hotseat camera and selection reset when passing the screen to another player.'}
mechanics[#mechanics+1]={id='empire',name='EMPIRE AND IDLE UNITS',text='The city icon in the bottom bar opens EMPIRE. Its unit and city lists center the map on your selection. The shield/arrow icon jumps to the next awake unit with movement left. These controls only select; MOVE / ATTACK still activates orders. CITY and UNIT in the inspector switch between a city and its garrison.'}
mechanics[#mechanics+1]={id='icons',name='ACTION BAR ICONS',text='Bottom icons: magnifier opens INSPECT; connected nodes open TECH TREE; city opens EMPIRE; shield/arrow selects NEXT IDLE UNIT; triangle ends the turn. Top-right icons: book opens CODEX; clipboard opens REPORT; pause opens the pause menu.'}
local function title(id)return id:gsub('_',' '):upper()end
function E.entries(category)
 if category=='mechanics'then return mechanics end
 local source=category=='units' and Systems.units or category=='buildings' and Systems.buildings or Systems.techs
 local result={}
 for id,record in pairs(source)do result[#result+1]={id=id,name=record.name or title(id),record=record}end
 table.sort(result,function(a,b)return a.name<b.name end)
 return result
end
function E.describe(category,entry)
 if entry.text then return {entry.text}end
 local record=entry.record;local lines={}
 if category=='units'then
  lines={'Industry cost: '..Systems.projectCost('unit',entry.id),
   'Attack '..record.strength..' / defense '..record.defense,
   'Movement '..record.move..' / vision '..record.vision..' / range '..record.range,
   record.naval and 'Domain: water' or 'Domain: land',record.ability or ''}
 elseif category=='buildings'then lines={'Industry cost: '..Systems.projectCost('building',entry.id),
  record.description or '', 'One of this building per city.'}
 else
  lines={'Science cost: '..record.cost,'Unlock: '..title(record.unlock or 'none')}
  local needs={};for _,id in ipairs(record.requires or {})do needs[#needs+1]=(Systems.techs[id]or {}).name or title(id)end
  lines[#lines+1]='Prerequisites: '..(#needs>0 and table.concat(needs,', ') or 'none')
 end
 if record.tech then lines[#lines+1]='Research: '..Systems.techs[record.tech].name end
 if record.resource then lines[#lines+1]='Owned deposit: '..title(record.resource)end
 if record.unique then lines[#lines+1]='Civilization: '..Systems.civ(record.unique).name end
 return lines
end
function E.draw(ui,rect)
 local r=ui.r;local model=ui.codex or {category='units'};ui.codex=model
 local x,y,w,h=rect.x,rect.y,rect.w,rect.h
 r:fill(x,y,w,h,1);r:outline(x,y,w,h,8)
 r:text(x+4,y+3,'ENCYCLOPEDIA',8,1,w-46)
 r:button(x+w-37,y+1,35,11,'CLOSE',function()ui.panel='context'end)
 local categories={'units','buildings','techs','mechanics'}
 local labels={'UNITS','BUILDS','TECH','HELP'}
 local width=math.floor((w-10)/4)
 for i,category in ipairs(categories)do
  r:button(x+2+(i-1)*(width+2),y+13,width,11,labels[i],function()
   model.category=category;model.entry=nil;model.offset=0
  end,{selected=model.category==category})
 end
 local body={x=x+3,y=y+24,w=w-6,h=h-26};local rows={}
 if model.entry then
  rows[#rows+1]={buttons={{label='BACK TO LIST',run=function()model.entry=nil;model.offset=0 end}}}
  for _,line in ipairs(Panels.wrap(r,model.entry.name,body.w-4))do rows[#rows+1]={text=line,color=8}end
  for _,paragraph in ipairs(E.describe(model.category,model.entry))do
   for _,line in ipairs(Panels.wrap(r,paragraph,body.w-4))do rows[#rows+1]={text=line}end
  end
 else
  for _,entry in ipairs(E.entries(model.category))do
   rows[#rows+1]={buttons={{label=entry.name,run=function()model.entry=entry;model.offset=0 end}}}
  end
 end
 Panels.rows(r,body,rows,model)
end
return E
