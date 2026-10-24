package.path="./games/railbreak/?.lua;./games/railbreak/?/init.lua;"..package.path
local R=require("train.render")
local function simulate(width,height)
 local m={mode=0,draws={},w=80,h=54}
 function m.getSize(mode)if mode==2 then return width,height end return m.w,m.h end
 function m.setGraphicsMode(mode)m.mode=mode end
 function m.drawPixels(x,y,color,w,h)
  assert(x>=0 and y>=0 and x+w<=width and y+h<=height,"draw outside screen")
  m.draws[#m.draws+1]={x=x,y=y,color=color,w=w,h=h}
 end
 function m.getPaletteColor()return 0,0,0 end
 function m.setPaletteColor()end
 local r=R.new(m)
 assert(r.mode=="graphics","Should enable mode 2")
 assert(math.abs(r.sx-r.sy)<0.00001,"Must preserve pixel aspect ratio")
 assert(r.ox>=0 and r.oy>=0,"Offsets must be nonnegative")
 r:begin();r:fill(10,20,10,10,6)
 local x=math.floor(r.ox+15*r.sx)
 local y=math.floor(r.oy+25*r.sy)
 local vx,vy=r:touch(x,y)
 assert(vx and math.abs(vx-15)<=1 and math.abs(vy-25)<=1,"Touch respects letterboxing")
 assert(r:touch(-1,0)==nil,"Outside left viewport ignored")
 assert(m.draws[1].x==0 and m.draws[1].y==0 and m.draws[1].w==width
  and m.draws[1].h==height,"Frame clears full emulator screen")
 if r.ox>=2 then assert(r:touch(0,math.floor(height/2))==nil,
  "Touch in side margin ignored")end
 if r.oy>=2 then assert(r:touch(math.floor(width/2),0)==nil,
  "Touch in top margin ignored")end
 local priorX,priorY=r.ox,r.oy
 m.w,m.h=95,60
 r:resize()
 assert(math.abs(r.sx-r.sy)<0.00001,"Uniform scale after resize")
 assert(r.ox~=nil and r.oy~=nil)
 r:close()
 return priorX,priorY
end
local x,y=simulate(1280,720)
assert(x>0 or y>0,"Widescreen emulator should letterbox")
simulate(320,320)
simulate(480,270)
simulate(1024,768)
print("RAILBREAK: aspect-ratio correction, margins and touch mapping passed.")
