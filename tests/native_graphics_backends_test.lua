package.path="./?.lua;./?/init.lua;"..package.path
local paths={"cogworks/display.lua","railbreak/display.lua","tidebound/display.lua"}
local native={getSize=function(mode)if mode==2 then return 612,342 end return 102,38 end,
 setGraphicsMode=function()end,drawPixels=function()end}
local basic={getSize=function()return 51,19 end}
local monitor={getSize=function()return 100,70 end}
for _,path in ipairs(paths)do
 local D=assert(loadfile(path))()
 assert(D.hasPixels(native),"CraftOS-PC pixel graphics detected")
 assert(not D.hasPixels(basic),"Plain text terminal not incorrectly classified")
 local viewport={new=function(term,w,h)
  assert(term==basic and w>0 and h>0)
  return {terminal=true,virtual=true,present=function()end,
   mouse=function(x,y)return x+5,y+9 end,close=function()end}
 end}
 local display,mode=D.select(nil,native,viewport,80,54)
 assert(display==native and mode=="native-pixels",
  path..": computer graphics must bypass virtual text wrapper")
 local x,y=D.click(display,mode,50,100)
 assert(x==50 and y==100,"Pixel touch coordinates must be unchanged")
 local attached,where=D.select(monitor,native,viewport,80,54)
 assert(attached==monitor and where=="monitor","Attached monitor still preferred")
 local fallback,typeName=D.select(nil,basic,viewport,80,54)
 assert(typeName=="virtual-text" and fallback.virtual,"Text fallback preserved")
 local bx,by=D.click(fallback,typeName,2,3)
 assert(bx==7 and by==12,"Character input pans correctly")
 D.present(fallback,typeName);D.close(fallback,typeName)
end
-- Exercise COGWORKS renderer with actual CraftOS-PC graphics dimensions.
local E=require("cogworks.engine")
local Render=require("cogworks.render")
local oldColors=colors
colors={black=32768,gray=128,white=1,lightGray=256,orange=2,
 lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local screen={mode=0,last=nil}
function screen.getSize(mode)if mode==2 then return 612,342 end return 102,38 end
function screen.setGraphicsMode(mode)screen.mode=mode end
function screen.getPaletteColor()return 0,0,0 end
function screen.setPaletteColor()end
function screen.drawPixels(x,y,color,w,h)
 assert(x>=0 and y>=0 and x+w<=612 and y+h<=342)
end
local r=Render.new(screen)
assert(r.mode=="graphics")
local progress={awards={},unlocked=30}
r:draw({scene="title",progress=progress,slots={{empty=true},{empty=true},{empty=true}},
 settings={animations=true,showPorts=true},message=""})
local b
for _,button in ipairs(r.targets)do if button.action=="slots"then b=button end end
assert(b,"Title screen has interactive save slot target")
local x=r.ox+(b.x+b.w/2)*r.scale
local y=r.oy+(b.y+b.h/2)*r.scale
assert(r:hit(x,y)=="slots","Native pixel click activates correct title button")
r:resize()
assert(r.scale==math.min(612/200,342/120),"Resize retains correct virtual resolution")
r:close()
assert(screen.mode==0,"Native graphics mode restored on exit")
-- TIDEBOUND: graphics must retain geometric proportions and centered
-- mouse hitboxes even when the CraftOS text-cell and pixel ratios differ.
local TideRender=assert(loadfile("tidebound/expanse-v5/render.lua"))()
local tideScreen={mode=0,draws=0}
function tideScreen.getSize(which)
 if which==2 then return 612,342 end
 return 102,38
end
function tideScreen.setGraphicsMode(mode)tideScreen.mode=mode end
function tideScreen.setPaletteColor()end
function tideScreen.drawPixels(x,y,color,w,h)
 assert(x>=0 and y>=0 and w>0 and h>0,"Invalid Tidebound pixel rectangle")
 assert(x+w<=612 and y+h<=342,"Tidebound drawing beyond display")
 tideScreen.draws=tideScreen.draws+1
end
local tr=TideRender.new(tideScreen,false)
assert(tr.kind=="gfx" and tr.px==tr.py,"Tidebound must preserve pixel proportions")
assert(tr.oy>0,"Tidebound should center the game within its letterbox")
tr:beginFrame()
tr:rect(5,5,6,6,7)
tr:text(6,7,"SPACE",7)
tr:endFrame()
assert(tideScreen.draws>8,"Tidebound native renderer must draw pixels")
assert(tideScreen.mode==2,"Tidebound graphics mode activated")
tideScreen.setGraphicsMode(0)
colors=oldColors
print("Graphics backends: CraftOS native pixels, monitors, text fallback and touch passed.")
