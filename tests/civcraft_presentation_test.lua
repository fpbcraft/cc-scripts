local native=dofile
dofile=function(path)return native(path:gsub('^/games/civcraft/','games/civcraft/'))end
local Icons=dofile('games/civcraft/icons.lua')
local Systems=dofile('games/civcraft/systems.lua')
local Content=dofile('games/civcraft/content.lua')
local UI=dofile('games/civcraft/ui.lua')
colors={black=32768,white=1,gray=128,lightGray=256,orange=2,lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local labels={};local pixels={}
local r={textWidth=function(_,text)return #text*4-1 end,fill=function(_,x,y,w,h,color)pixels[#pixels+1]={x=x,y=y,w=w,h=h,color=color}end,
 text=function(_,x,y,text)labels[#labels+1]=text end}
for count=1,5 do
 labels={};pixels={};Icons.yieldValue(r,'food',count,0,0)
 assert(#labels==0 and #pixels>0,'Small yields use icons without numbers')
 local max=0;for _,p in ipairs(pixels)do max=math.max(max,p.x+p.w)end
 assert(max==count*6-1,'One spaced food icon per yield')
end
labels={};Icons.yieldValue(r,'industry',6,0,0);assert(labels[1]=='6','Large yields use a number')
pixels={};Icons.yieldValue(r,'food',0,0,0);assert(#pixels==0,'Zero yields do not create misleading icons')
pixels={};Icons.yieldValue(r,'food',5,0,0,11)
for _,p in ipairs(pixels)do assert(p.x+p.w<=11,'Wrapped icon groups respect narrow widths')end
local state={players={},cities={},units={}}
for i,civ in ipairs(Systems.civs)do
 state.players[#state.players+1]={id=i,civ=civ.id,techs={}}
 for n=1,14 do state.cities[#state.cities+1]={id=#state.cities+1,owner=i,x=n,y=i,population=2,buildings={}}end
end
Systems.migrate(state)
local used={};for _,city in ipairs(state.cities)do
 assert(#city.name<=8 and not used[city.name],'Names stay short and unique after exhausting a pool')
 used[city.name]=true
 local old=city.name;city.owner=city.owner%#Systems.civs+1;assert(Systems.nameCity(state,city)==old,'Conquest preserves the established name')
end
for _,civ in ipairs(Systems.civs)do
 local sample={players={{id=1,civ=civ.id}},cities={},mapSeed=123}
 local city={id=1,owner=1,x=2,y=2};sample.cities[1]=city
 local name=Systems.nameCity(sample,city);local themed=false
 for _,candidate in ipairs(Content.cityNames[civ.id])do if candidate==name then themed=true end end
 assert(themed,'New settlements use their civilization pool')
 city.name=nil;assert(Systems.nameCity(sample,city)==name,'Seeded naming is reproducible')
end
local function monitor(w,h,graphics)
 local m={getSize=function(mode)if mode==2 then return w*6,h*9 end;return w,h end,
 getPaletteColor=function()return 0,0,0 end,setPaletteColor=function()end}
 if graphics then m.setGraphicsMode=function()end;m.drawPixels=function()end
 else m.setCursorPos=function()end;m.setBackgroundColor=function()end;m.setTextColor=function()end;m.write=function()end end
 return m
end
local game={phase='game',round=1,players={{id=1,name='ONE',civ='verdant',techs={}}},cities={},units={}}
for _,graphics in ipairs({true,false})do
 local ui=UI.new(monitor(graphics and 200 or 57,graphics and 110 or 28,graphics),function()error('Dragging must not issue research orders')end)
 ui:draw(game,1,{})
 ui.panel='tech';ui.techModel={selected='engineering',detail=not graphics}
 ui:draw(game,1,{})
 local model=ui.techModel;local area=model.dragArea;assert(area)
 local function point(x,y)
  if graphics then return ui.r.ox+x*ui.r.sx,ui.r.oy+y*ui.r.sy end
  return x/2+1,y/3+1
 end
 if graphics then
  for _,button in ipairs(ui.r.buttons)do if button.label=='agriculture'then
   local bx,by=point(button.x+button.w/2,button.y+button.h/2)
   ui:pointerDown(bx,by);ui:pointerUp()
   assert(model.selected=='agriculture','A click still selects a research node')
   model.selected='engineering';break
  end end
 end
 local x,y=point(area.x+area.w/2,area.y+area.h/2)
 local ex,ey=point(area.x+area.w/2-24,area.y+area.h/2-24)
 local mapX,mapY=ui.panX,ui.panY
 assert(ui:pointerDown(x,y));assert(ui:drag(ex,ey));ui:pointerUp()
 if graphics then assert(model.panX>0,'Research graph pans by dragging')
 else assert(model.offset>0,'Compact research details scroll by dragging')end
 assert(model.selected=='engineering' and ui.panX==mapX and ui.panY==mapY,'Research drag never selects nodes or pans the map behind it')
 ui:draw(game,1,{});ui:close()
end
print('CIVCRAFT: repeated yields, themed persistent city names, yield icons and research dragging passed.')
