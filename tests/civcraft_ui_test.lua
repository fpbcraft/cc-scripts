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
ui:draw(state,11,{localMode=true})
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
touchLabel("+ PLAYER")
assert(calls[#calls].action=="addPlayer")
touchLabel("START GAME")
assert(calls[#calls].action=="start")
state.phase="game"
state.players[1].food=12;state.players[1].wood=12
state.players[1].science=0;state.players[1].tech=0
state.cities={{x=2,y=2,owner=11}}
state.units={{x=3,y=2,owner=11,kind="warrior"}}
ui:draw(state,11,{localMode=true})
local tile=ui.hexTargets[1]
assert(tile,"A hexagonal tile hitbox is available")
local tx=math.floor(ui.r.ox+(tile.x+tile.w/2)*ui.r.sx)
local ty=math.floor(ui.r.oy+(tile.y+tile.h/2)*ui.r.sy)
assert(ui:tap(tx,ty),"Map accepts touch")
touchLabel("END TURN")
assert(calls[#calls].action=="end","End-turn handler wired")
ui:draw(state,12,{handoff=true,localMode=true})
touchLabel("READY TO PLAY")
assert(calls[#calls].action=="reveal","Handoff hides map until ready")
ui:close()
assert(m.mode==0 and m.pixels>500,"Native graphics restored after play")
print("CIVCRAFT: graphics, menus, map, turn action and hotseat handoff passed.")
