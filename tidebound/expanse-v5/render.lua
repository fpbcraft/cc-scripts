-- TIDEBOUND shared 256-color pixel renderer from Stellar Frontier.
local Theme=dofile((_G.EXPANSE_V5_ROOT or "/tidebound/expanse-v5").."/theme.lua")
local PALETTE=Theme.palette
local TEXT_COLORS={
 [0]=32768,[1]=128,[2]=2048,[3]=1024,[4]=256,[5]=8,[6]=1,[7]=1,[8]=512,[9]=32,
 [10]=2048,[11]=8,[12]=8192,[13]=1024,[14]=16384,[15]=16384,[16]=4096,[17]=16,
 [18]=8192,[19]=32,[20]=2,[21]=2,[22]=1024,[23]=1,[24]=128,[25]=2048,[26]=16,
 [27]=512,[28]=32768,[29]=8192,[30]=8,[31]=128,
}
local FONT={
 A={"01110","10001","10001","11111","10001","10001","10001"},B={"11110","10001","10001","11110","10001","10001","11110"},
 C={"01111","10000","10000","10000","10000","10000","01111"},D={"11110","10001","10001","10001","10001","10001","11110"},
 E={"11111","10000","10000","11110","10000","10000","11111"},F={"11111","10000","10000","11110","10000","10000","10000"},
 G={"01111","10000","10000","10111","10001","10001","01111"},H={"10001","10001","10001","11111","10001","10001","10001"},
 I={"11111","00100","00100","00100","00100","00100","11111"},J={"00111","00010","00010","00010","10010","10010","01100"},
 K={"10001","10010","10100","11000","10100","10010","10001"},L={"10000","10000","10000","10000","10000","10000","11111"},
 M={"10001","11011","10101","10101","10001","10001","10001"},N={"10001","11001","10101","10011","10001","10001","10001"},
 O={"01110","10001","10001","10001","10001","10001","01110"},P={"11110","10001","10001","11110","10000","10000","10000"},
 Q={"01110","10001","10001","10001","10101","10010","01101"},R={"11110","10001","10001","11110","10100","10010","10001"},
 S={"01111","10000","10000","01110","00001","00001","11110"},T={"11111","00100","00100","00100","00100","00100","00100"},
 U={"10001","10001","10001","10001","10001","10001","01110"},V={"10001","10001","10001","10001","10001","01010","00100"},
 W={"10001","10001","10001","10101","10101","10101","01010"},X={"10001","10001","01010","00100","01010","10001","10001"},
 Y={"10001","10001","01010","00100","00100","00100","00100"},Z={"11111","00001","00010","00100","01000","10000","11111"},
 ["0"]={"01110","10011","10101","10101","11001","10001","01110"},["1"]={"00100","01100","00100","00100","00100","00100","01110"},
 ["2"]={"01110","10001","00001","00010","00100","01000","11111"},["3"]={"11110","00001","00001","00110","00001","00001","11110"},
 ["4"]={"00010","00110","01010","10010","11111","00010","00010"},["5"]={"11111","10000","11110","00001","00001","10001","01110"},
 ["6"]={"00111","01000","10000","11110","10001","10001","01110"},["7"]={"11111","00001","00010","00100","01000","01000","01000"},
 ["8"]={"01110","10001","10001","01110","10001","10001","01110"},["9"]={"01110","10001","10001","01111","00001","00010","11100"},
 ["-"]={"00000","00000","00000","11111","00000","00000","00000"},["+"]={"00000","00100","00100","11111","00100","00100","00000"},
 ["."]={"00000","00000","00000","00000","00000","00110","00110"},[":"]={"00000","00110","00110","00000","00110","00110","00000"},
 ["/"]={"00001","00001","00010","00100","01000","10000","10000"},["?"]={"01110","10001","00001","00010","00100","00000","00100"},
 ["!"]={"00100","00100","00100","00100","00100","00000","00100"},["("]={"00010","00100","01000","01000","01000","00100","00010"},
 [")"]={"01000","00100","00010","00010","00010","00100","01000"},["="]={"00000","11111","00000","11111","00000","00000","00000"},
 ["'"]={"00100","00100","00000","00000","00000","00000","00000"},["#"]={"01010","11111","01010","11111","01010","00000","00000"},
 [" "]={"00000","00000","00000","00000","00000","00000","00000"},
}
local ICON={
 star={"00100","00100","11111","01110","11011","10001","00000"},
 planet={"01110","11011","10101","11101","10101","11011","01110"},
 ship={"00100","01110","11111","10101","11111","01010","10001"},
 scan={"11111","10001","10101","10101","10101","10001","11111"},
 flag={"10000","11110","11011","11110","10000","10000","10000"},
 colony={"00100","01110","11111","11111","10101","10101","11111"},
 mine={"10001","01010","00100","11111","01110","01110","00100"},
 forge={"00100","01110","11111","10111","01110","01110","00100"},
 lab={"00100","01110","01110","00100","01110","11111","11111"},
 dock={"10101","11111","01110","01110","01110","10101","10001"},
 fort={"10101","11111","11111","11111","01110","01110","00100"},
 energy={"00110","01100","11111","00110","01100","11000","10000"},
 alloy={"00100","01110","11111","11111","11111","01110","00100"},
 science={"10001","01010","00100","01110","01110","11111","01110"},
 influence={"00100","01110","10101","11111","01110","00100","00100"},
 research={"11011","01010","01110","00100","01110","01010","11011"},
 move={"00100","00110","11111","00110","00100","00000","00000"},
 war={"10001","01010","00100","01110","10101","10101","10001"},
 trade={"10010","11101","00100","10111","01001","00000","00000"},
 next={"10000","11000","11100","11110","11100","11000","10000"},
 back={"00001","00011","00111","01111","00111","00011","00001"},
 help={"01110","10001","00001","00110","00100","00000","00100"},
 trophy={"10001","11111","11111","01110","00100","01110","11111"},
 check={"00001","00011","10110","11100","01000","00000","00000"},
 close={"10001","01010","00100","01010","10001","00000","00000"},
 orbit={"01110","10001","10101","10101","10101","10001","01110"},
}
-- v5 adds distinct symbols for the three-resource strategy layer.
ICON.coin={"01110","10001","10111","10101","11101","10001","01110"}
ICON.alloy={"00100","01110","11111","10101","11111","01110","00100"}
ICON.shield={"11111","10001","10001","01010","01110","00100","00100"}
ICON.book={"11011","10001","10001","10101","10101","10001","11011"}
ICON.council={"00100","01110","11111","00100","01110","10101","11111"}
ICON.home={"00100","01110","11111","10001","10101","10001","11111"}
ICON.ark={"00100","01110","11111","11111","10101","10101","10001"}
ICON.pause={"11011","11011","11011","11011","11011","11011","11011"}
ICON.scroll={"11111","10001","11111","10001","11111","10001","11111"}
local function trunc(s,n) s=tostring(s or ""):upper();if #s>n then return s:sub(1,n-1).."."end;return s end
local Renderer={};Renderer.__index=Renderer
function Renderer.new(mon,forceText)
 local self=setmetatable({m=mon,kind="text",buttons={},frame=0},Renderer)
 if mon.setTextScale then pcall(mon.setTextScale,0.5) end
 self.w,self.h=mon.getSize();self.px,self.py=1,1
 if not forceText and type(mon.setGraphicsMode)=="function" and type(mon.drawPixels)=="function" then
  local ok=pcall(mon.setGraphicsMode,2)
  if ok then
   local success,pw,ph=pcall(mon.getSize,2)
   if success and pw and ph and pw>self.w and ph>self.h then
    self.kind="gfx";self:fitGraphics(pw,ph)
    if mon.setPaletteColor then for c,rgb in pairs(PALETTE)do pcall(mon.setPaletteColor,c,rgb)end end
   else pcall(mon.setGraphicsMode,0) end
  end
 end
 return self
end
-- Fit the game in a proportion-preserving centered viewport.
function Renderer:fitGraphics(pw,ph)
 self.gw,self.gh=pw,ph
 local scale=math.min(pw/self.w,ph/self.h)
 self.px,self.py=scale,scale
 self.ox=math.floor((pw-self.w*scale)/2)
 self.oy=math.floor((ph-self.h*scale)/2)
end
function Renderer:resize()
 self.w,self.h=self.m.getSize()
 if self.kind=="gfx" then
  local ok,pw,ph=pcall(self.m.getSize,2)
  if ok and pw and ph then self:fitGraphics(pw,ph)end
 end
end
function Renderer:rect(x,y,w,h,c)
 x=math.floor(x);y=math.floor(y);w=math.ceil(w);h=math.ceil(h)
 if w<=0 or h<=0 then return end
 local ex=math.min(self.w,x+w);local ey=math.min(self.h,y+h)
 x=math.max(0,x);y=math.max(0,y);if ex<=x or ey<=y then return end
 if self.kind=="gfx" then
  local px=math.floor(self.ox+x*self.px);local py=math.floor(self.oy+y*self.py)
  self.m.drawPixels(px,py,c,math.max(1,math.floor(self.ox+ex*self.px)-px),math.max(1,math.floor(self.oy+ey*self.py)-py))
 else
  self.m.setBackgroundColor(TEXT_COLORS[c] or 32768)
  for iy=y,ey-1 do self.m.setCursorPos(x+1,iy+1);self.m.write(string.rep(" ",ex-x))end
 end
end
function Renderer:pixel(px,py,c,size)
 if self.kind=="gfx" then
  size=size or 1;self.m.drawPixels(math.floor(px),math.floor(py),c,math.max(1,math.floor(size)),math.max(1,math.floor(size)))
 else
  local x=math.floor(px/self.px);local y=math.floor(py/self.py)
  if x>=0 and y>=0 and x<self.w and y<self.h then
   self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1);self.m.write(".")
  end
 end
end
function Renderer:line(x1,y1,x2,y2,c)
 if self.kind=="gfx" then
  x1=self.ox+x1*self.px;y1=self.oy+y1*self.py;x2=self.ox+x2*self.px;y2=self.oy+y2*self.py
  local d=math.max(math.abs(x2-x1),math.abs(y2-y1))
  for i=0,d,2 do local t=i/math.max(1,d);self:pixel(x1+(x2-x1)*t,y1+(y2-y1)*t,c,1)end
 else
  local d=math.max(math.abs(x2-x1),math.abs(y2-y1))*1.3
  for i=0,d,1 do local t=i/math.max(1,d);local x=math.floor(x1+(x2-x1)*t+.5);local y=math.floor(y1+(y2-y1)*t+.5)
   if x>=0 and y>=0 and x<self.w and y<self.h then
    self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1);self.m.write(".")
   end
  end
 end
end
function Renderer:disc(cx,cy,r,c)
 if self.kind=="gfx" then
  local x=self.ox+cx*self.px;local y=self.oy+cy*self.py;local rp=r*math.min(self.px,self.py)
  for yy=-math.ceil(rp),math.ceil(rp) do
   local dx=math.sqrt(math.max(0,rp*rp-yy*yy));local ax=math.floor(x-dx)
   local length=math.max(1,math.floor(x+dx)-ax)
   self.m.drawPixels(ax,math.floor(y+yy),c,length,1)
  end
 else
  self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1)
  if cx>=0 and cy>=0 and cx<self.w and cy<self.h then self.m.setCursorPos(math.floor(cx)+1,math.floor(cy)+1);self.m.write("O")end
 end
end
function Renderer:text(x,y,str,c,maxlen)
 x=math.floor(x);y=math.floor(y);str=trunc(str,maxlen or 255)
 if y<0 or y>=self.h or x>=self.w then return end
 if x<0 then str=str:sub(1-x);x=0 end
 str=str:sub(1,math.max(0,self.w-x));if #str==0 then return end
 if self.kind=="text" then
  self.m.setCursorPos(x+1,y+1);self.m.setBackgroundColor(TEXT_COLORS[0]);self.m.setTextColor(TEXT_COLORS[c] or 1)
  self.m.write(str);return
 end
 for i=1,#str do
  local pattern=FONT[str:sub(i,i)] or FONT["?"]
  local left=self.ox+(x+i-1)*self.px;local top=self.oy+y*self.py
  for ry=1,7 do
   local row=pattern[ry];local col=1
   while col<=5 do
    if row:sub(col,col)=="1" then
     local start=col;while col<=5 and row:sub(col,col)=="1" do col=col+1 end
     local px=math.floor(left+(start-1)*self.px/5);local xx=math.floor(left+col*self.px/5)
     local py=math.floor(top+(ry-1)*self.py/7);local yy=math.floor(top+ry*self.py/7)
     self.m.drawPixels(px,py,c,math.max(1,xx-px),math.max(1,yy-py))
    else col=col+1 end
   end
  end
 end
end
function Renderer:bigText(x,y,word,c,scale)
 scale=scale or 2
 if self.kind=="text" then return self:text(x,y,word,c) end
 word=tostring(word):upper()
 for i=1,#word do
  local pattern=FONT[word:sub(i,i)] or FONT["?"]
  local left=self.ox+(x+(i-1)*scale)*self.px;local top=self.oy+y*self.py
  for ry=1,7 do
   local line=pattern[ry];local k=1
   while k<=5 do
    if line:sub(k,k)=="1" then
     local start=k;while k<=5 and line:sub(k,k)=="1" do k=k+1 end
     local px=math.floor(left+(start-1)*scale*self.px/5);local xx=math.floor(left+k*scale*self.px/5)
     local py=math.floor(top+(ry-1)*scale*self.py/7);local yy=math.floor(top+ry*scale*self.py/7)
     self.m.drawPixels(px,py,c,math.max(1,xx-px),math.max(1,yy-py))
    else k=k+1 end
   end
  end
 end
end
function Renderer:key(x,y,w,h,label,fn)
 self:rect(x,y,w,h,2);self:rect(x,y,1,h,4)
 self:text(x+math.floor((w-1)/2),y+1,label,7,1)
 self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,fn=fn}
end
function Renderer:icon(x,y,name,c)
 local data=ICON[name] or ICON.star
 if self.kind=="text" then
  local fallback={coin="$",alloy="A",shield="S",book="B",council="C",home="H",ark="K",pause="|",scroll="=",star="*",planet="@",ship="^",scan="?",flag="F",colony="H",mine="M",forge="A",lab="S",dock="D",fort="#",energy="E",alloy="A",science="S",influence="I",research="R",move=">",war="X",trade="$",next=">",back="<",help="?",trophy="*",check="+",close="X",orbit="O"}
  return self:text(x,y,fallback[name] or "*",c)
 end
 local left=self.ox+x*self.px;local top=self.oy+y*self.py;local iconScale=2
 for ry=1,7 do local row=data[ry];local k=1
  while k<=5 do
   if row:sub(k,k)=="1" then
    local start=k;while k<=5 and row:sub(k,k)=="1" do k=k+1 end
    local xx=math.floor(left+(start-1)*self.px*iconScale/5);local endx=math.floor(left+k*self.px*iconScale/5)
    local yy=math.floor(top+(ry-1)*self.py*iconScale/7);local endy=math.floor(top+ry*self.py*iconScale/7)
    self.m.drawPixels(xx,yy,c,math.max(1,endx-xx),math.max(1,endy-yy))
   else k=k+1 end
  end
 end
end
function Renderer:button(x,y,w,h,title,icon,tint,fn,detail,disabled)
 self:rect(x,y,w,h,disabled and 1 or 2)
 self:rect(x,y,1,h,disabled and 3 or tint)
 self:icon(x+2,y+math.max(0,math.floor((h-1)/2)),icon,disabled and 4 or tint)
 self:text(x+4,y+1,trunc(title,w-5),disabled and 4 or 7)
 if detail and h>=4 then self:text(x+4,y+2,trunc(detail,w-5),disabled and 4 or 5) end
 if not disabled and fn then self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,fn=fn}end
end
function Renderer:beginFrame()
 self.buttons={};self.frame=self.frame+1
 if self.kind=="gfx" and self.m.setFrozen then pcall(self.m.setFrozen,true) end
 if self.kind=="gfx"then
  self.m.drawPixels(0,0,0,self.gw,self.gh)
 end
 self:rect(0,0,self.w,self.h,0)
end
function Renderer:endFrame()
 if self.kind=="gfx" and self.m.setFrozen then pcall(self.m.setFrozen,false) end
end
function Renderer:hit(x,y)
 for i=#self.buttons,1,-1 do local b=self.buttons[i]
  if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then b.fn();return true end
 end
 return false
end

return Renderer