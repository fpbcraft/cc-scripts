-- CIVCRAFT uses the Railbreak pixel renderer and real clickable UI elements.
local oldDofile=dofile
dofile=function(path)
 if path:sub(1,10)=="/civcraft/"then return oldDofile(path:sub(2))end
 return oldDofile(path)
end
colors={black=32768,white=1,gray=128,lightGray=256,orange=2,
 lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local m={w=80,h=45,mode=0,pixels=0}
function m.getSize(mode)
 if mode==2 then return 480,270 end
 return m.w,m.h
end
function m.setGraphicsMode(mode)m.mode=mode end
function m.drawPixels(x,y,color,w,h)
 assert(x>=0 and y>=0 and x+w<=480 and y+h<=270,
  "CIVCRAFT draw beyond screen")
 m.pixels=m.pixels+1
end
function m.getPaletteColor()return 0,0,0 end
function m.setPaletteColor()end
local UI=oldDofile("civcraft/ui.lua")
dofile=oldDofile
local calls={}
local ui=UI.new(m,function(action,data)
 calls[#calls+1]={action=action,data=data}
end)
assert(ui.r.mode=="graphics","Native pixel mode enabled")
local state={phase="lobby",round=1,players={{id=11,name="P1"},{id=12,name="P2"}},
 cities={},units={}}
ui:draw(state,11,{localMode=true,screen="game"})
local function touchLabel(label)
 for _,b in ipairs(ui.r.buttons)do
  if b.label==label then
   local x=math.floor(ui.r.ox+(b.x+b.w/2)*ui.r.sx)
   local y=math.floor(ui.r.oy+(b.y+b.h/2)*ui.r.sy)
   assert(ui:tap(x,y),"Pixel button hit: "..label)
   return
  end
 end
 error("Button not found: "..label)
end
ui:draw(state,11,{localMode=true,screen="title",slot=2,slots={
 {occupied=true,name="EMPIRE ALPHA",round=4},
 {occupied=false,name="EMPTY SLOT 2"},
 {occupied=true,name="EMPIRE BETA",round=9}
}})
touchLabel("SLOT 3  EMPIRE BETA  R9")
assert(calls[#calls].action=="selectSlot" and calls[#calls].data.slot==3,
 "Touchscreen title must switch between saved campaigns")
ui:draw(state,11,{localMode=true,screen="title",slot=2,slots={
 {occupied=true,name="A",round=1},{occupied=false,name="B"},{occupied=false,name="C"}
}})
touchLabel("NEW CAMPAIGN")
assert(calls[#calls].action=="newGame","Main menu starts a new game")
state.mapSize="standard";state.mapSeed=137
ui:draw(state,11,{localMode=true,screen="game"})
touchLabel("MAP SIZE")
assert(calls[#calls].action=="mapSize","Map size control works by touch")
touchLabel("MAP TYPE")
assert(calls[#calls].action=="mapType","Map type chooser by touch")
touchLabel("REROLL SEED")
assert(calls[#calls].action=="mapSeed","Map reroll control works by touch")
touchLabel("+ PLAYER")
assert(calls[#calls].action=="addPlayer")
touchLabel("START GAME")
assert(calls[#calls].action=="start")
state.phase="game"
state.players[1].food=12;state.players[1].wood=12
state.players[1].science=0;state.players[1].tech=0;state.players[1].techs={}
state.players[1].civ="verdant"
state.cities={}
state.units={}
state.cities={{x=2,y=2,owner=11,jobs={food=1,wood=1,science=0},buildings={}}}
state.units={{x=3,y=2,owner=11,kind="warrior"}}
ui:draw(state,11,{localMode=true})
local tile=ui.hexTargets[1]
assert(tile,"A hexagonal tile hitbox is available")
local tx=math.floor(ui.r.ox+(tile.x+tile.w/2)*ui.r.sx)
local ty=math.floor(ui.r.oy+(tile.y+tile.h/2)*ui.r.sy)
assert(ui:tap(tx,ty),"Map accepts touch")
-- Selecting an owned unit exposes precisely the legal hex destinations.
local function tapHex(hx,hy)
 local hit
 for _,hex in ipairs(ui.hexTargets or {})do
  if hex.tx==hx and hex.ty==hy then hit=hex;break end
 end
 assert(hit,"Hex "..hx..","..hy.." has a hitbox")
 return ui:tap(math.floor(ui.r.ox+(hit.x+hit.w/2)*ui.r.sx),
  math.floor(ui.r.oy+(hit.y+hit.h/2)*ui.r.sy))
end
assert(tapHex(3,2),"Unit can be selected")
assert(ui.source and ui.source.x==3 and #ui.reachable>0,
 "Selecting owned unit immediately shows reachable hexes")
ui:draw(state,11,{localMode=true})
local legal=ui.reachable[1]
assert(tapHex(legal.x,legal.y),"Highlighted move is clickable")
assert(calls[#calls].action=="move" and
 calls[#calls].data.sx==3 and calls[#calls].data.sy==2,
 "Hex movement emits the same command accepted by simulation")
-- Selecting a city exposes its specific actions, not a generic build bar.
assert(tapHex(2,2),"Select owned city")
ui:draw(state,11,{localMode=true})
local actions={}
for _,btn in ipairs(ui.r.buttons)do actions[btn.label]=true end
assert(actions.UNITS and actions.BUILDS and actions["WORK HEXES"] and actions["TECH TREE"],
 "Production categories, directly worked city tiles and technology controls")
assert(not actions["MOVE UNIT"],"City should not expose unit movement")
assert(ui.mapViewport and ui.mapViewport.w>0,"Central map viewport")
local oldPan=ui.panX
ui:pan(45,0)
assert(ui.panX>=oldPan,"Pan control clamps within world")
touchLabel("WORK HEXES")
assert(ui.workCity and ui.workCity.x==2,"Worker assignment uses map tiles")
ui:draw(state,11,{localMode=true})
touchLabel("DONE WORK")
assert(not ui.workCity,"Exit worker mode")
touchLabel("TECH TREE")
ui:draw(state,11,{localMode=true})
local techNode=false
for _,button in ipairs(ui.r.buttons)do
 if button.label=="agriculture" then techNode=true end
end
assert(techNode,"City tech tab opens connected technology graph canvas")
touchLabel("CLOSE")
ui:draw(state,11,{localMode=true})
touchLabel("END TURN")
assert(calls[#calls].action=="end","End-turn handler wired")
ui:draw(state,12,{handoff=true,localMode=true})
touchLabel("READY TO PLAY")
assert(calls[#calls].action=="reveal","Handoff hides map until ready")
ui:close()
assert(m.mode==0 and m.pixels>500,"Native graphics restored after play")
print("CIVCRAFT: graphics, menus, map, turn action and hotseat handoff passed.")
