-- CC: Graphics emulator tests; no Minecraft environment required.
package.path="./factory/?.lua;"..package.path
colors={black=32768,gray=128,lightGray=256,white=1,cyan=512,
  orange=2,lime=32,lightBlue=8,pink=64,yellow=16,red=16384,purple=1024}
local Viewer=require("pixel_view")
local width,height=340,348
local state={mode=false,changed=0,filled=0,pixels=0,palette={},frozen=false}
local surface={
  getGraphicsMode=function()return state.mode end,
  setGraphicsMode=function(mode)
    state.mode=mode
    state.changed=state.changed+1
  end,
  drawPixels=function(x,y,col,w,h)
    assert(state.mode~=false)
    assert(x>=0 and y>=0 and w>0 and h>0)
    assert(x+w<=width and y+h<=height)
    assert(type(col)=="number")
    state.filled=state.filled+1
  end,
  getSize=function(mode)
    assert(mode==2)
    return width,height
  end,
  setPixel=function(x,y,col)
    assert(x>=0 and y>=0 and x<width and y<height)
    assert(type(col)=="number")
    state.pixels=state.pixels+1
  end,
  setPaletteColor=function(index,color)
    state.palette[index]=color
  end,
  setFrozen=function(value)state.frozen=value end,
}
assert(Viewer.supported(surface))
assert(not Viewer.supported({getSize=function()return width,height end}))
local renderer=Viewer.new(surface)
assert(renderer:start() and state.mode==2)
local t=1000
local samples={}
for i=1,60 do
  samples[#samples+1]={time=t-300+i*5,stress=40+i/2,
    rpm=(i%13==0) and nil or i*3,
    stock=math.floor(i/7)*64,
    rate_iron=math.sin(i/8)*20}
end
local metrics={
  {"stress","Kinetic Stress","%",colors.orange},
  {"rpm","Shaft RPM","RPM",colors.cyan},
  {"stock","Storage Total","items",colors.lime},
  {"rate_iron","Iron Farm Rate","items/min",colors.pink}
}
local selected=Viewer.series(samples,"stress",60,t)
assert(#selected==13,"60-second view should include 13 points at 5s interval")
assert(Viewer.series(samples,"stock",300,t)[1].time==705)
local ok,err=renderer:render(samples,metrics,{range=300,clock=t})
assert(ok,err)
assert(state.filled>50 and state.pixels>0 and renderer.drawCount==1)
assert(#renderer.cards==4)
local firstCard=renderer.cards[1]
assert(renderer:hitTest(firstCard.x+1,firstCard.y+1)=="stress")
assert(renderer:hitTest(0,0)==nil)
assert(not state.frozen)
local before=state.pixels
ok,err=renderer:render(samples,metrics,{range=60,detail="stress",
  overlay=true,clock=t})
assert(ok,err)
assert(state.pixels>before,"Multi-series rendering should update plot")
assert(#renderer.cards==1)
assert(renderer:hitTest(renderer.cards[1].x+3,renderer.cards[1].y+3)=="stress")
-- Short companion monitors must page through selected charts.
height=180
renderer.h=180
assert(renderer:render(samples,metrics,{range=300,clock=t,page=2}))
assert(#renderer.cards==2 and renderer.cards[1].key=="stock")
local action=renderer:hitAction(width-117,10)
assert(action=="next","Short pixel screens need on-display paging")
height=348
renderer.h=348
width,height=960,740
renderer.w,renderer.h=width,height
local expanded={}
for i=1,12 do
  expanded[i]={"metric_"..i,"Metric "..i,"U",colors.cyan}
end
assert(renderer:render(samples,expanded,{range=300,clock=t,page=1}))
assert(#renderer.cards==12,"Large pixel displays should show twelve charts")
assert(renderer:hitAction(width-70,10)=="exit")
width,height=340,348
renderer.w,renderer.h=width,height
local missing=renderer:render(samples,{{"missing","No Data","W"}},{range=60,clock=t})
assert(missing)
renderer:stop()
assert(state.mode==false and state.frozen==false)
assert(renderer.active==false)
local fallbackState={mode=false}
local fallback={
  getGraphicsMode=function()return fallbackState.mode end,
  setGraphicsMode=function(mode)
    if mode==2 then error("8-bit palette unsupported") end
    fallbackState.mode=mode
  end,
  drawPixels=function()end,
  setPixel=function()end,
  getSize=function()return width,height end,
}
local f=Viewer.new(fallback)
assert(f:start() and f.mode==1)
f:stop()
assert(fallbackState.mode==false)
print("CC Graphics pixel rendering, time windows, detail and safe-mode tests passed")
