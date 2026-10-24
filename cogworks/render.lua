-- Compact graphics-mode renderer with playable vanilla text-mode fallback.
-- Graphics uses CC: Graphics / CraftOS-PC mode 2, not a third-party library.
local R={};R.__index=R
local palette={
 [0]=0x101B25,[1]=0x1A2B36,[2]=0x28414D,[3]=0x375764,
 [4]=0x69858A,[5]=0xE6EDCE,[6]=0xEAB85E,[7]=0xC87A45,
 [8]=0xBD6354,[9]=0x7FC99B,[10]=0x427F68,[11]=0x79AFC2,
 [12]=0x33677C,[13]=0xD9C390,[14]=0x8D679B,[15]=0xFFF5DF,
}
local F={
 A={"010","101","111","101","101"},B={"110","101","110","101","110"},
 C={"011","100","100","100","011"},D={"110","101","101","101","110"},
 E={"111","100","110","100","111"},F={"111","100","110","100","100"},
 G={"011","100","101","101","011"},H={"101","101","111","101","101"},
 I={"111","010","010","010","111"},J={"001","001","001","101","010"},
 K={"101","101","110","101","101"},L={"100","100","100","100","111"},
 M={"101","111","111","101","101"},N={"101","111","111","111","101"},
 O={"010","101","101","101","010"},P={"110","101","110","100","100"},
 Q={"010","101","101","111","011"},R={"110","101","110","101","101"},
 S={"011","100","010","001","110"},T={"111","010","010","010","010"},
 U={"101","101","101","101","111"},V={"101","101","101","101","010"},
 W={"101","101","111","111","101"},X={"101","101","010","101","101"},
 Y={"101","101","010","010","010"},Z={"111","001","010","100","111"},
 ["0"]={"111","101","101","101","111"},["1"]={"010","110","010","010","111"},
 ["2"]={"110","001","010","100","111"},["3"]={"110","001","010","001","110"},
 ["4"]={"101","101","111","001","001"},["5"]={"111","100","110","001","110"},
 ["6"]={"011","100","110","101","010"},["7"]={"111","001","010","010","010"},
 ["8"]={"010","101","010","101","010"},["9"]={"010","101","011","001","110"},
 [" "]={"000","000","000","000","000"},["-"]={"000","000","111","000","000"},
 ["+"]={"000","010","111","010","000"},["/"]={"001","001","010","100","100"},
 [":"]={"000","010","000","010","000"},["!"]={"010","010","010","000","010"},
 ["."]={"000","000","000","000","010"},["?"]={"110","001","010","000","010"},
 ["="]={"000","111","000","111","000"},
}
local function fillText(m,x,y,w,fg,bg,s)
 m.setCursorPos(x,y);m.setTextColor(fg);m.setBackgroundColor(bg)
 m.write((s..(" "):rep(w)):sub(1,w))
end
function R.new(mon)
 local self=setmetatable({m=mon,mode="text",frame=0,original={}},R)
 self:enable()
 return self
end
function R:enable()
 local m=self.m
 self.tw,self.th=m.getSize()
 if m.setGraphicsMode and m.drawPixels and m.getSize then
  local ok=pcall(m.setGraphicsMode,2)
  if ok then
   local good,w,h=pcall(m.getSize,2)
   if good and type(w)=="number" and w>=128 and h>=88 then
    self.mode="graphics";self.pw,self.ph=w,h
    self.scale=math.min(w/128,h/88)
    self.ox=math.floor((w-128*self.scale)/2)
    self.oy=math.floor((h-88*self.scale)/2)
    if m.setPaletteColor then
     for i,c in pairs(palette)do
      if m.getPaletteColor then
       local good2,r,g,b=pcall(m.getPaletteColor,i)
       if good2 then self.original[i]={r,g,b} end
      end
      pcall(m.setPaletteColor,i,c)
     end
    end
    return
   end
   pcall(m.setGraphicsMode,0)
  end
 end
 self.mode="text"
end
function R:resize()
 if self.mode=="graphics"then
  local ok,w,h=pcall(self.m.getSize,2)
  if ok and type(w)=="number" then
   self.pw,self.ph=w,h;self.scale=math.min(w/128,h/88)
   self.ox=math.floor((w-128*self.scale)/2)
   self.oy=math.floor((h-88*self.scale)/2)
  end
 else self.tw,self.th=self.m.getSize()end
end
function R:close()
 if self.mode=="graphics"then
  if self.m.setFrozen then pcall(self.m.setFrozen,false)end
  if self.m.setPaletteColor then
   for i,rgb in pairs(self.original)do
    pcall(self.m.setPaletteColor,i,rgb[1],rgb[2],rgb[3])
   end
  end
  pcall(self.m.setGraphicsMode,0)
 end
end
function R:rect(x,y,w,h,color)
 if w<=0 or h<=0 then return end
 local s=self.scale
 local x1=math.floor(self.ox+x*s);local y1=math.floor(self.oy+y*s)
 local x2=math.floor(self.ox+(x+w)*s);local y2=math.floor(self.oy+(y+h)*s)
 x1=math.max(0,x1);y1=math.max(0,y1)
 x2=math.min(self.pw,x2);y2=math.min(self.ph,y2)
 if x2>x1 and y2>y1 then self.m.drawPixels(x1,y1,color,x2-x1,y2-y1) end
end
function R:font(x,y,str,color)
 str=tostring(str):upper()
 for n=1,#str do
  local glyph=F[str:sub(n,n)] or F["?"]
  for cy=1,5 do for cx=1,3 do
   if glyph[cy]:sub(cx,cx)=="1" then self:rect(x+(n-1)*4+cx-1,y+cy-1,1,1,color)end
  end end
 end
end
function R:line(x1,y1,x2,y2,color)
 local n=math.max(1,math.ceil(math.max(math.abs(x2-x1),math.abs(y2-y1))))
 for j=0,n do
  local t=j/n;self:rect(math.floor(x1+(x2-x1)*t),math.floor(y1+(y2-y1)*t),1,1,color)
 end
end
function R:gear(cx,cy,lit,frame)
 local tint=lit and 6 or 4
 for n=0,11 do
  local a=n*math.pi/6+frame*(lit and 0.20 or 0)
  local x=math.floor(cx+5*math.cos(a));local y=math.floor(cy+5*math.sin(a))
  self:rect(x,y,2,2,tint)
 end
 self:rect(cx-3,cy-3,7,7,tint)
 self:rect(cx-2,cy-2,5,5,2)
 self:rect(cx-1,cy-1,3,3,lit and 15 or 4)
end
function R:part(tile,light,frame)
 local x=8+(tile.x-1)*16;local y=16+(tile.y-1)*16
 local on=light and light.powered
 local active=on and 6 or 4
 local body=tile.kind=="S" and 10 or (tile.kind=="M" and 12 or 2)
 self:rect(x,y,14,14,3)
 self:rect(x+1,y+1,12,12,body)
 if on then self:rect(x+1,y+1,12,1,6)end
 local cx,cy=x+7,y+7
 local E=require("cogworks.engine")
 for dir=0,3 do
  if E.hasPort(tile,dir)then
   if dir==0 then self:rect(cx-1,y,3,7,active)
   elseif dir==1 then self:rect(cx,cy-1,7,3,active)
   elseif dir==2 then self:rect(cx-1,cy,3,7,active)
   else self:rect(x,cy-1,7,3,active)end
   if on and tile.kind~="M"then
    local step=(frame%4)+2
    local dx=dir==1 and 1 or (dir==3 and -1 or 0)
    local dy=dir==2 and 1 or (dir==0 and -1 or 0)
    self:rect(cx+dx*step,cy+dy*step,2,2,15)
   end
  end
 end
 if tile.kind=="G" then self:gear(cx-1,cy-1,on,frame)
 elseif tile.kind=="M"then
  self:rect(x+3,y+3,8,8,light.correct and 9 or 11)
  self:rect(x+4,y+4,6,6,1)
  self:font(x+4,y+5,(tile.sign<0 and "-" or "+")..tile.speed,
   light.correct and 9 or 15)
 elseif tile.kind=="S" then
  self:rect(x+3,y+3,8,8,7);self:rect(x+4,y+4,6,6,6)
  self:font(x+5,y+5,"S",0)
 else
  self:rect(x+4,y+4,7,7,active)
  self:rect(x+5,y+5,5,5,1)
  self:font(x+6,y+5,tile.kind=="B" and "2" or
   (tile.kind=="T" and "T" or (tile.kind=="L" and "L" or "+")),15)
  if tile.kind=="B"then
   local dx=tile.r==1 and 1 or (tile.r==3 and -1 or 0)
   local dy=tile.r==2 and 1 or (tile.r==0 and -1 or 0)
   self:rect(cx+dx*5,cy+dy*5,2,2,9)
  end
 end
end
function R:button(y,title,enabled)
 self:rect(95,y,30,9,enabled and 3 or 1)
 self:rect(95,y,2,9,enabled and 6 or 4)
 self:font(100,y+2,title,enabled and 15 or 4)
end
function R:drawGraphics(g,result,unlocked)
 local m=self.m
 if m.setFrozen then pcall(m.setFrozen,true)end
 self:rect(0,0,128,88,0)
 self:rect(0,0,128,12,1)
 self:rect(0,11,128,1,7)
 self:font(6,3,"COGWORKS",6)
 self:font(48,3,"KINETIC LAB",11)
 self:font(99,3,string.format("%02d/%02d",g.number,#require("cogworks.levels")),15)
 self:rect(6,14,82,65,1)
 for row=0,3 do for col=0,4 do
  self:rect(7+col*16,15+row*16,15,15,2)
 end end
 for _,tile in ipairs(g.tiles)do self:part(tile,result.lights[tile.id],self.frame)end
 self:rect(93,14,34,65,1)
 self:font(97,17,"GOALS",11)
 self:font(98,24,result.correct.."/"..result.goals,result.win and 9 or 15)
 self:button(33,"HINT",not result.win)
 self:button(43,"RESET",true)
 self:button(53,"PREV",g.number>1)
 self:button(63,"NEXT",g.number<unlocked)
 self:rect(0,80,128,8,1)
 local status
 if result.win then status="COMPLETE! NEXT LEVEL"
 elseif result.jam then status="GEARS JAMMED! RESET"
 else status="MOVE "..g.moves.."  POWER "..result.correct.."/"..result.goals end
 self:font(6,82,status,result.win and 9 or (result.jam and 8 or 5))
 self.frame=self.frame+1
 if m.setFrozen then pcall(m.setFrozen,false)end
end
local function partChar(tile)
 return ({S="S",M="M",I="I",L="L",T="T",G="G",B="2"})[tile.kind]
end
function R:drawText(g,result,unlocked)
 local m=self.m;local w,h=m.getSize()
 m.setBackgroundColor(colors.black);m.setTextColor(colors.white);m.clear()
 fillText(m,1,1,w,colors.orange,colors.gray,
  " COGWORKS - KINETIC LAB  "..g.number.."/"..#require("cogworks.levels"))
 fillText(m,1,2,w,result.win and colors.lime or colors.lightGray,colors.black,
  (result.win and " COMPLETE! " or (result.jam and " JAMMED! " or " ROTATE PARTS "))..
  "GOALS "..result.correct.."/"..result.goals.."  MOVES "..g.moves)
 if w<32 or h<20 then
  fillText(m,1,4,w,colors.red,colors.black,"Need a 3x3 Advanced Monitor")
  return
 end
 self.bx=math.floor((w-30)/2)+1;self.by=4
 local E=require("cogworks.engine")
 for y=1,4 do for x=1,5 do
  local px=self.bx+(x-1)*6;local py=self.by+(y-1)*3
  local tile=g.map[(y-1)*5+x]
  local light=tile and result.lights[tile.id]
  local bg=tile and (tile.kind=="S" and colors.green or
   (tile.kind=="M" and colors.blue or colors.gray)) or colors.lightGray
  local fg=light and light.powered and colors.yellow or colors.white
  local n=tile and E.hasPort(tile,0) or false
  local e=tile and E.hasPort(tile,1) or false
  local s=tile and E.hasPort(tile,2) or false
  local west=tile and E.hasPort(tile,3) or false
  fillText(m,px,py,5,fg,bg,n and "  ^  " or "     ")
  fillText(m,px,py+1,5,fg,bg,
   (west and "<" or " ").." "..(tile and partChar(tile) or ".").." "..(e and ">" or " "))
  fillText(m,px,py+2,5,fg,bg,s and "  v  " or "     ")
 end end
 if h>=19 then
  fillText(m,1,h-2,w,colors.lightBlue,colors.black,g.tip)
 end
 local labels={"PREV","HINT","RESET","NEXT"}
 local size=math.floor(w/4)
 for n=1,4 do
  local enabled=(n~=1 or g.number>1) and (n~=4 or g.number<unlocked)
  fillText(m,1+(n-1)*size,h-1,size,enabled and colors.black or colors.gray,
   enabled and colors.orange or colors.lightGray,labels[n])
 end
end
function R:draw(g,result,unlocked)
 if self.mode=="graphics"then self:drawGraphics(g,result,unlocked)
 else self:drawText(g,result,unlocked)end
end
function R:hit(x,y)
 if self.mode=="graphics"then
  x=(x-self.ox)/self.scale;y=(y-self.oy)/self.scale
  if x>=8 and x<86 and y>=16 and y<78 then
   local col=math.floor((x-8)/16)+1
   local row=math.floor((y-16)/16)+1
   if col>=1 and col<=5 and row>=1 and row<=4 then
    if ((x-8)%16)<14 and ((y-16)%16)<14 then
     return "rotate",col,row
    end
   end
  end
  if x>=95 and x<125 then
   if y>=33 and y<42 then return "hint"
   elseif y>=43 and y<52 then return "reset"
   elseif y>=53 and y<62 then return "prev"
   elseif y>=63 and y<72 then return "next"end
  end
 else
  if x>=self.bx and y>=self.by and
   x<self.bx+30 and y<self.by+12 then
   local col=math.floor((x-self.bx)/6)+1
   local row=math.floor((y-self.by)/3)+1
   if ((x-self.bx)%6)<5 then return "rotate",col,row end
  end
  local w,h=self.m.getSize()
  if y==h-1 then
   local n=math.floor((x-1)/math.floor(w/4))+1
   return ({"prev","hint","reset","next"})[n]
  end
 end
 return nil
end
return R
