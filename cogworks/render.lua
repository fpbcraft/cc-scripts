-- COGWORKS / CC: Graphics pixel renderer with text fallback.
-- Coordinates in the pixel renderer are 128x88 logical units. Touch events
-- from Graphics mode 2 are zero-based PIXELS; vanilla monitor touch is 1-based.
local E=require("cogworks.engine")
local R={};R.__index=R
local palette={
 [0]=0x0E1A23,[1]=0x172B37,[2]=0x284250,[3]=0x355866,
 [4]=0x688993,[5]=0xE6EBD7,[6]=0xF3BC59,[7]=0xC97E4E,
 [8]=0xD35F51,[9]=0x89D79F,[10]=0x39745B,[11]=0x83C2D7,
 [12]=0x365E8D,[13]=0xD9C391,[14]=0xBE91E3,[15]=0xFFF6E0,
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
 ["="]={"000","111","000","111","000"},["<"]={"001","010","100","010","001"},
 [">"]={"100","010","001","010","100"},["#"]={"101","111","101","111","101"},
 ["("]={"001","010","010","010","001"},[")"]={"100","010","010","010","100"},
}
local function fillText(m,x,y,w,fg,bg,text)
 m.setCursorPos(x,y);m.setTextColor(fg);m.setBackgroundColor(bg)
 m.write((tostring(text)..(" "):rep(w)):sub(1,w))
end
function R.new(m)
 local self=setmetatable({m=m,mode="text",frame=0,original={},
  boardX=5,boardY=16,cell=10},R)
 self:enable()
 return self
end
function R:enable()
 local m=self.m
 self.tw,self.th=m.getSize()
 if m.setGraphicsMode and m.drawPixels then
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
       local success,r,g,b=pcall(m.getPaletteColor,i)
       if success then self.original[i]={r,g,b}end
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
  if ok and type(w)=="number"then
   self.pw,self.ph=w,h
   self.scale=math.min(w/128,h/88)
   self.ox=math.floor((w-128*self.scale)/2)
   self.oy=math.floor((h-88*self.scale)/2)
  end
 else self.tw,self.th=self.m.getSize()end
end
function R:close()
 if self.mode=="graphics"then
  if self.m.setFrozen then pcall(self.m.setFrozen,false)end
  if self.m.setPaletteColor then
   for i,c in pairs(self.original)do
    pcall(self.m.setPaletteColor,i,c[1],c[2],c[3])
   end
  end
  pcall(self.m.setGraphicsMode,0)
 end
end
function R:rect(x,y,w,h,color)
 if self.mode~="graphics" or w<=0 or h<=0 then return end
 local s=self.scale
 local x1=math.max(0,math.floor(self.ox+x*s))
 local y1=math.max(0,math.floor(self.oy+y*s))
 local x2=math.min(self.pw,math.floor(self.ox+(x+w)*s))
 local y2=math.min(self.ph,math.floor(self.oy+(y+h)*s))
 if x2>x1 and y2>y1 then
  self.m.drawPixels(x1,y1,color,x2-x1,y2-y1)
 end
end
function R:font(x,y,str,color)
 str=tostring(str):upper()
 for n=1,#str do
  local g=F[str:sub(n,n)] or F["?"]
  for row=1,5 do for col=1,3 do
   if g[row]:sub(col,col)=="1" then
    self:rect(x+(n-1)*4+col-1,y+row-1,1,1,color)
   end
  end end
 end
end
function R:line(x1,y1,x2,y2,color)
 local count=math.ceil(math.max(math.abs(x2-x1),math.abs(y2-y1)))
 for i=0,math.max(1,count)do
  local t=i/math.max(1,count)
  self:rect(math.floor(x1+(x2-x1)*t),math.floor(y1+(y2-y1)*t),1,1,color)
 end
end
local DX={0,1,0,-1}
local DY={-1,0,1,0}
function R:piece(x,y,size,tile,light)
 local running=light and light.powered
 local core=running and 6 or 4
 if tile.kind=="X"then
  self:rect(x,y,size,size,2)
  for k=1,size-1,3 do
   self:line(x+k,y+1,x+1,y+k,3)
  end
  self:rect(x+3,y+3,size-6,size-6,1)
  self:font(x+4,y+3,"X",4)
  return
 end
 local bg=tile.kind=="S" and 10 or (tile.kind=="M" and 12 or 2)
 self:rect(x,y,size,size,3)
 self:rect(x+1,y+1,size-2,size-2,bg)
 if running then self:rect(x+1,y+1,size-2,1,6)end
 local cx=x+math.floor(size/2);local cy=y+math.floor(size/2)
 if tile.kind=="M"then
  local active=light and light.correct
  self:rect(x+2,y+2,size-4,size-4,active and 9 or 8)
  self:rect(x+3,y+3,size-6,size-6,1)
  local requirement=(tile.sign<0 and "-" or "+")..tostring(tile.speed)
  self:font(x+1,y+math.floor(size/2)-2,requirement,active and 9 or 15)
 elseif tile.kind=="S"then
  self:rect(x+3,y+3,size-6,size-6,6)
  self:font(x+4,y+math.floor(size/2)-2,"S",0)
 else
  -- Different mechanisms have different centerpieces, not just letter changes.
  if tile.kind=="G"then
   for i=0,7 do
    local a=(i*math.pi/4)+(running and self.frame*.25 or 0)
    self:rect(math.floor(cx+3*math.cos(a)),math.floor(cy+3*math.sin(a)),
     2,2,14)
   end
   self:rect(cx-2,cy-2,5,5,14)
   self:rect(cx-1,cy-1,3,3,1)
  elseif tile.kind=="B"then
   self:rect(cx-3,cy-3,7,7,7)
   self:rect(cx-2,cy-2,5,5,1)
   self:font(cx-1,cy-2,"2",15)
   -- Green tick indicates the speed controller input direction.
   self:rect(cx+DX[tile.r+1]*4,cy+DY[tile.r+1]*4,2,2,9)
  else
   self:rect(cx-2,cy-2,5,5,core)
   self:rect(cx-1,cy-1,3,3,1)
   self:rect(cx,cy,1,1,15)
  end
 end
 -- Port markings are consistent on all devices, including fixed terminals.
 for dir=0,3 do
  if E.hasPort(tile,dir)then
   local dx,dy=DX[dir+1],DY[dir+1]
   local sx=cx+dx*(math.floor(size/2)-1)
   local sy=cy+dy*(math.floor(size/2)-1)
   if dx~=0 then self:rect(math.min(cx,sx),cy-1,math.abs(sx-cx)+1,3,core)
   else self:rect(cx-1,math.min(cy,sy),3,math.abs(sy-cy)+1,core)end
   -- Moving bright dash denotes powered outlets.
   if running and tile.kind~="M"then
    local shift=2+(self.frame%3)
    self:rect(cx+dx*shift,cy+dy*shift,2,2,15)
   end
  end
 end
 -- Redraw terminal labels above shaft outlets so +1 / -2 stays readable.
 if tile.kind=="M"then
  local active=light and light.correct
  self:rect(x+2,y+2,size-4,size-4,active and 9 or 8)
  self:rect(x+3,y+3,size-6,size-6,1)
  self:font(x+1,y+math.floor(size/2)-2,
   (tile.sign<0 and "-" or "+")..tostring(tile.speed),active and 9 or 15)
 elseif tile.kind=="S"then
  self:rect(x+3,y+3,size-6,size-6,6)
  self:font(x+4,y+math.floor(size/2)-2,"S",0)
 elseif tile.kind=="B"then
  self:rect(cx+DX[tile.r+1]*4,cy+DY[tile.r+1]*4,2,2,9)
 end
end
function R:paletteRow(y,kind,count,selected)
 local chosen=selected==kind
 local enabled=kind=="erase" or count>0
 self:rect(81,y,45,8,chosen and 6 or 2)
 self:rect(82,y+1,43,6,chosen and 1 or 3)
 if kind=="erase"then
  self:font(84,y+2,"X",8);self:font(94,y+2,"REMOVE",15)
 else
  local label=({T="SPLIT",B="2X RPM"})[kind] or E.parts[kind].name
  self:rect(84,y+1,8,6,enabled and E.parts[kind].color or 4)
  self:font(86,y+2,kind=="B" and "2" or kind,0)
  self:font(94,y+2,label,enabled and 15 or 4)
  self:font(118,y+2,tostring(count),enabled and 9 or 4)
 end
end
function R:graphics(g,result,unlocked,selected,message)
 local m=self.m
 if m.setFrozen then pcall(m.setFrozen,true)end
 self:rect(0,0,128,88,0)
 self:rect(0,0,128,12,1);self:rect(0,11,128,1,7)
 self:font(4,3,"COGWORKS",6)
 self:font(42,3,"L"..g.number.."/"..#E.levels,11)
 self:rect(76,1,12,9,2);self:font(78,3,"<",15)
 self:rect(89,1,12,9,2);self:font(92,3,">",15)
 self:rect(103,1,24,9,2);self:font(107,3,"RESET",15)
 self:rect(3,14,76,64,1)
 for y=1,E.HEIGHT do for x=1,E.WIDTH do
  local left=self.boardX+(x-1)*self.cell
  local top=self.boardY+(y-1)*self.cell
  self:rect(left,top,9,9,2)
  self:rect(left+4,top+4,1,1,3)
  local tile=E.get(g,x,y)
  if tile then
   self:piece(left,top,9,tile,result.lights[tile.id])
  end
 end end
 self:rect(80,13,48,66,1)
 self:font(83,14,"PARTS",11)
 self:font(107,14,result.correct.."/"..result.goals,result.win and 9 or 15)
 for n,kind in ipairs(E.order)do
  self:paletteRow(20+(n-1)*9,kind,g.remaining[kind] or 0,selected)
 end
 self:paletteRow(65,"erase",0,selected)
 self:rect(81,74,21,5,3);self:font(83,74,"HINT",15)
 self:rect(104,74,22,5,3);self:font(107,74,"HELP",15)
 self:rect(0,80,128,8,1)
 local status=message
 if not status or status==""then
  if result.win then status="SOLVED! NEXT LEVEL AT TOP"
  elseif result.jam then status="JAM! CHECK GEARS AND DRIVES"
  elseif g.fullNetwork and result.correct==result.goals then
   if result.remaining>0 then status="USE "..result.remaining.." REMAINING PARTS"
   elseif result.openPorts>0 then status="CLOSE "..result.openPorts.." OPEN PORTS"
   elseif result.unpowered>0 then status="POWER EVERY PLACED PART"end
  elseif selected=="erase"then status="REMOVE: TAP A PLACED PART"
  elseif g.fullNetwork and self.frame%40<20 then
   status="STOCK "..result.remaining.."  OPEN "..result.openPorts.."  GOALS "..result.correct.."/"..result.goals
  else status=g.name end
 end
 self:font(3,82,status:sub(1,31),result.win and 9 or (result.jam and 8 or 5))
 self.frame=self.frame+1
 if m.setFrozen then pcall(m.setFrozen,false)end
end
function R:helpGraphics()
 local m=self.m
 if m.setFrozen then pcall(m.setFrozen,true)end
 self:rect(0,0,128,88,0)
 self:rect(0,0,128,11,1)
 self:font(5,3,"PARTS AND RULES",6)
 local rows={
  {"S","GENERATOR: +1 RPM SOURCE",9},
  {"M","MACHINE: MATCH + / - AND RPM",12},
  {"I","SHAFT: STRAIGHT TRANSMISSION",11},
  {"L","ELBOW: TURNS 90 DEGREES",11},
  {"T","SPLITTER: THREE CONNECTIONS",11},
  {"G","GEAR: REVERSES THE SPIN",14},
  {"2","2X DRIVE: GREEN PORT IS INPUT",7},
 }
 for i,row in ipairs(rows)do
  local y=13+(i-1)*9
  self:rect(4,y,12,8,2);self:rect(6,y+1,8,6,row[3])
  self:font(8,y+2,row[1],0)
  self:font(21,y+2,row[2],15)
 end
 self:rect(0,77,128,11,1)
 self:font(5,79,"ALL STOCK USED. NO LOOSE PORTS.",6)
 self:font(104,79,"BACK",9)
 if m.setFrozen then pcall(m.setFrozen,false)end
end
function R:text(g,result,unlocked,selected,message)
 local m=self.m;local w,h=m.getSize()
 m.setBackgroundColor(colors.black);m.setTextColor(colors.white);m.clear()
 fillText(m,1,1,w,colors.orange,colors.gray,
  " COGWORKS / "..g.number.."/"..#E.levels.." - "..g.name)
 fillText(m,1,2,w,result.win and colors.lime or colors.white,colors.black,
  result.win and " COMPLETE: press NEXT " or
   (" GOALS "..result.correct.."/"..result.goals.."  LEFT "..result.remaining.."  OPEN "..result.openPorts))
 if w<44 or h<26 then
  fillText(m,1,4,w,colors.red,colors.black,"Use a larger Advanced Monitor")
  return
 end
 self.tx=math.max(1,math.floor((w-E.WIDTH*6)/2)+1);self.ty=3
 for y=1,E.HEIGHT do for x=1,E.WIDTH do
  local px=self.tx+(x-1)*6;local py=self.ty+(y-1)*3
  local tile=E.get(g,x,y)
  local light=tile and result.lights[tile.id]
  local bg=tile and (tile.kind=="S" and colors.green or
    (tile.kind=="M" and colors.blue or (tile.kind=="X" and colors.brown or colors.gray)))
    or colors.lightGray
  local fg=light and light.powered and colors.yellow or colors.white
  local p={false,false,false,false}
  if tile then for d=0,3 do p[d+1]=E.hasPort(tile,d)end end
  local icon=tile and (tile.kind=="B" and "2" or tile.kind) or "."
  local center=tile and tile.kind=="M" and
   ((tile.sign<0 and "-" or "+")..tostring(tile.speed)) or (" "..icon)
  fillText(m,px,py,5,fg,bg,p[1] and "  ^  " or "     ")
  fillText(m,px,py+1,5,fg,bg,
   (p[4] and "<" or " ").." "..center..(p[2] and ">" or " "))
  fillText(m,px,py+2,5,fg,bg,p[3] and "  v  " or "     ")
 end end
 self.toolWidth=math.floor(w/5)
 for n,kind in ipairs(E.order)do
  fillText(m,1+(n-1)*self.toolWidth,h-5,self.toolWidth,
   selected==kind and colors.orange or colors.lightBlue,colors.black,
   n..":"..kind.." "..(g.remaining[kind] or 0))
 end
 fillText(m,1,h-4,w,colors.white,colors.black,
  " Tap cell to place/turn; 6 remove.")
 fillText(m,1,h-3,w,colors.orange,colors.black,
  (selected=="erase" and "REMOVE" or (E.parts[selected] and E.parts[selected].name or ""))..
  ": "..(message or g.tip))
 local labels={"PREV","RESET","NEXT","HELP"}
 self.footerWidth=math.floor(w/4)
 for i,label in ipairs(labels)do
  local active=i~=1 or g.number>1
  if i==3 then active=g.number<unlocked end
  fillText(m,1+(i-1)*self.footerWidth,h-1,self.footerWidth,
   active and colors.black or colors.gray,active and colors.orange or colors.lightGray,label)
 end
end
function R:helpText()
 local m=self.m;local w,h=m.getSize()
 m.setBackgroundColor(colors.black);m.clear()
 fillText(m,1,1,w,colors.orange,colors.gray," COGWORKS - HELP")
 local info={
  "S: generator, clockwise 1X",
  "M: goal, requires shown +/- RPM",
  "I: straight shaft",
  "L: right-angle elbow",
  "T: splitter, three output sides",
  "G: gear, reverses spin direction",
  "2: two-times speed controller",
  "X: stone, cannot build here",
  "",
  "Advanced: use every stock part",
  "Advanced: connect every open port",
  "Advanced: all parts must be powered",
  "Tap empty cell to place chosen part",
  "Tap placed part to rotate it",
  "Remove reclaims the part",
  "1-5: select parts; 6: remove",
  "H: hint  R: reset  Q: quit",
 }
 for i,str in ipairs(info)do if i+2<h then
  fillText(m,1,i+2,w,colors.white,colors.black,str)
 end end
 fillText(m,1,h-1,w,colors.orange,colors.black," TAP TO RETURN")
end
function R:draw(g,result,unlocked,selected,message,help)
 if help then
  if self.mode=="graphics"then self:helpGraphics()else self:helpText()end
 elseif self.mode=="graphics"then self:graphics(g,result,unlocked,selected,message)
 else self:text(g,result,unlocked,selected,message)end
end
function R:hit(x,y,help)
 if self.mode=="graphics"then
  x=(x-self.ox)/self.scale;y=(y-self.oy)/self.scale
  if help then return "back"end
  if x>=self.boardX and x<self.boardX+E.WIDTH*self.cell and
   y>=self.boardY and y<self.boardY+E.HEIGHT*self.cell then
   local col=math.floor((x-self.boardX)/self.cell)+1
   local row=math.floor((y-self.boardY)/self.cell)+1
   if (x-self.boardX)%self.cell<9 and (y-self.boardY)%self.cell<9 then
    return "cell",col,row
   end
  end
  if x>=81 and x<126 then
   if y>=20 and y<65 then
    local n=math.floor((y-20)/9)+1
    return "tool",E.order[n]
   elseif y>=65 and y<73 then return "tool","erase"
   elseif y>=74 and y<80 then
    if x<103 then return "hint"else return "help"end
   end
  end
  if y>=1 and y<10 then
   if x>=76 and x<88 then return "prev"
   elseif x>=89 and x<101 then return "next"
   elseif x>=103 and x<127 then return "reset"end
  end
 else
  if help then return "back"end
  if self.tx and self.ty and x>=self.tx and x<self.tx+E.WIDTH*6 and
   y>=self.ty and y<self.ty+E.HEIGHT*3 then
   local col=math.floor((x-self.tx)/6)+1
   local row=math.floor((y-self.ty)/3)+1
   if (x-self.tx)%6<5 then return "cell",col,row end
  end
  local w,h=self.m.getSize()
  if y==h-1 and self.footerWidth and self.footerWidth>0 then
   return ({"prev","reset","next","help"})[math.floor((x-1)/self.footerWidth)+1]
  end
  if y==h-5 then
   local n=math.floor((x-1)/math.max(1,self.toolWidth or 1))+1
   return "tool",E.order[n]
  end
 end
 return nil
end
return R
