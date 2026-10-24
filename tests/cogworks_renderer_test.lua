package.path="./?.lua;./?/init.lua;"..package.path
-- Graphics API compatibility / hit-testing smoke tests. No Minecraft instance needed.
local E=require("cogworks.engine")
local R=require("cogworks.render")
local g=E.new(3,true)
local result=E.evaluate(g)

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
 assert(x==math.floor(x) and y==math.floor(y),"Fractional pixel location")
 assert(w>0 and h>0 and w==math.floor(w) and h==math.floor(h),"Invalid pixel span")
 assert(color>=0 and color<16,"Invalid graphics palette index")
 graphics.pixels=graphics.pixels+1
end
local draw=R.new(graphics)
assert(draw.mode=="graphics" and graphics.mode==2,"Graphics mode detection")
draw:draw(g,result,3)
assert(graphics.pixels>100 and graphics.flushes==1,"Graphics should draw and flush")
local kind,x,y=draw:hit(2*(8+7),2*(16+16+7))
assert(kind=="rotate" and x==1 and y==2,"Zero-based graphics touch mapping")
assert(draw:hit(2*105,2*37)=="hint","Graphics sidebar buttons")
assert(draw:hit(2*105,2*57)=="prev","Graphics previous button")
draw:resize()
draw:close()
assert(graphics.mode==0,"Graphics mode restored")

-- Vanilla Advanced Monitor / no CC: Graphics support.
colors={black=32768,white=1,gray=128,lightGray=256,orange=2,
 lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384}
local text={w=55,h=35,chars=0}
function text.getSize()return text.w,text.h end
function text.setBackgroundColor(_)end
function text.setTextColor(_)end
function text.setCursorPos(x,y)
 assert(x>=1 and y>=1 and x<=text.w and y<=text.h,"Invalid text cursor")
end
function text.write(s)text.chars=text.chars+#s end
function text.clear()end
local fallback=R.new(text)
assert(fallback.mode=="text","Vanilla text fallback selected")
fallback:draw(g,result,3)
assert(text.chars>0,"Text fallback should draw")
local action,c,r=fallback:hit(fallback.bx+6+2,fallback.by+3+1)
assert(action=="rotate" and c==2 and r==2,"One-based monitor touch mapping")
assert(fallback:hit(2,text.h-1)=="prev","Text footer button mapping")
fallback:close()
print("COGWORKS: graphics and text renderer smoke tests passed.")
