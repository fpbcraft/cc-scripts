package.path="./?.lua;./?/init.lua;"..package.path
-- Simulated CC: Graphics and vanilla monitor; no Minecraft needed.
local E=require("cogworks.engine")
local R=require("cogworks.render")
local game=E.new(10,true)
local result=E.evaluate(game)
local graphics={mode=0,pixels=0,flushes=0}
function graphics.getSize(kind)
 if kind==2 then return 256,176 end
 return 55,35
end
function graphics.setGraphicsMode(mode)graphics.mode=mode end
function graphics.getPaletteColor(_)return 0,0,0 end
function graphics.setPaletteColor(_,...)end
function graphics.setFrozen(frozen)
 if not frozen then graphics.flushes=graphics.flushes+1 end
end
function graphics.drawPixels(x,y,color,w,h)
 assert(x>=0 and y>=0 and x+w<=256 and y+h<=176,"Pixel outside screen")
 assert(x==math.floor(x) and y==math.floor(y),"Fractional drawing coordinate")
 assert(w>0 and h>0 and w==math.floor(w) and h==math.floor(h),"Invalid rectangle")
 assert(color>=0 and color<16,"Invalid palette index")
 graphics.pixels=graphics.pixels+1
end
local draw=R.new(graphics)
assert(draw.mode=="graphics" and graphics.mode==2,"Graphics mode detection")
draw:draw(game,result,10,"I","",false)
assert(graphics.pixels>150 and graphics.flushes==1,"Draw the kinetic board and sidebar")
local kind,x,y=draw:hit(2*(5+6),2*(16+10+5))
assert(kind=="cell" and x==1 and y==2,"Pixel touch maps to logical cell")
local action,tool=draw:hit(2*110,2*24)
assert(action=="tool" and tool=="I","First stock button")
local action2,tool2=draw:hit(2*110,2*59)
assert(action2=="tool" and tool2=="B","Last stock button")
assert(draw:hit(2*110,2*69)=="tool","Delete button")
assert(draw:hit(2*84,2*5)=="prev","Previous level")
assert(draw:hit(2*94,2*5)=="next","Next level")
assert(draw:hit(2*113,2*5)=="reset","Reset")
draw:draw(game,result,10,"erase","",true)
assert(draw:hit(2*13,2*22,true)=="back","Touch exits help")
draw:resize();draw:close()
assert(graphics.mode==0,"Graphics mode restored")

colors={black=32768,white=1,gray=128,lightGray=256,orange=2,
 lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local text={w=55,h=35,chars=0}
function text.getSize()return text.w,text.h end
function text.setBackgroundColor(_)end
function text.setTextColor(_)end
function text.setCursorPos(x,y)
 assert(x>=1 and y>=1 and x<=text.w and y<=text.h,"Cursor out of bounds")
end
function text.write(s)text.chars=text.chars+#s end
function text.clear()end
local fallback=R.new(text)
assert(fallback.mode=="text","Vanilla text mode selected")
fallback:draw(game,result,10,"T","",false)
assert(text.chars>0,"Text mode draws")
local c,cx,cy=fallback:hit(fallback.tx+6+2,fallback.ty+3+1)
assert(c=="cell" and cx==2 and cy==2,"Text monitor coordinates")
assert(fallback:hit(2,text.h-1)=="prev","Previous text footer")
fallback:draw(game,result,10,"I","",true)
assert(fallback:hit(2,text.h-1,true)=="back","Text help back")
fallback:close()
print("COGWORKS: graphics, stock selection, touch and text fallback passed.")
