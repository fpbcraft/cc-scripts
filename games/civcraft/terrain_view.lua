-- Deterministic pixel detail; no random shimmer when the camera moves.
local Hex=dofile('/games/civcraft/hex.lua')
local T={}
function T.color(land,explored)
 if explored then return 14 end
 return ({water=19,mountain=4,forest=12,hills=28,plains=11,grassland=11,desert=29})[land] or 11
end
function T.draw(r,land,x,y,size,tx,ty)
 if size<12 then return end
 local function dot(dx,dy,w,h,c)
  if Hex.contains(x,y,size,x+dx,y+dy) and Hex.contains(x,y,size,x+dx+w-1,y+dy+h-1)then
   r:fill(x+dx,y+dy,w,h,c)
  end
 end
 local seed=tx*37+ty*67
 local count=size>=24 and 16 or size>=16 and 8 or 3
 for n=1,count do
  local dx=(seed+n*17)%math.max(1,size-4)+2
  local dy=(seed*3+n*11)%math.max(1,size-4)+2
  if land=='water'then dot(dx,dy,size>=20 and 3 or 2,1,n%2==0 and 13 or 25)
  elseif land~='mountain'then dot(dx,dy,1,1,land=='forest' and 21 or 28)end
 end
 if size<16 then return end
 local cx=x+size/2;local cy=y+size/2
 if land=='mountain' or land=='hills'then
  local height=land=='mountain' and math.floor(size*.55) or math.floor(size*.25)
  local top=cy-height/2
  for row=0,height do
   local span=math.floor(row*(land=='mountain' and .65 or 1.1))
   r:fill(cx-span,top+row,span+1,1,land=='mountain' and 17 or 28)
   r:fill(cx+1,top+row,math.max(1,span),1,land=='mountain' and 4 or 12)
   if land=='mountain' and row<height*.28 then r:fill(cx-span,top+row,span*2+1,1,30)end
  end
 elseif land=='forest'then
  local trees=size>=24 and 3 or 1
  for n=1,trees do
   local px=cx+(n-2)*(size/5);local py=cy+(n%2)*2
   if trees==1 then px=cx end
   r:fill(px,py+2,1,4,16)
   for row=0,4 do local half=math.floor(row/2)
    r:fill(px-half,py-3+row,half+1,1,21);r:fill(px+1,py-3+row,math.max(1,half),1,12)
   end
  end
 end
end
return T
