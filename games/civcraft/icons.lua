-- Small recognizable unit/settlement symbols (not font characters).
local I={}
local function rect(r,x,y,w,h,c)r:fill(x,y,math.max(1,w),math.max(1,h),c)end
function I.draw(r,kind,x,y,size,color)
 if kind=='food' or kind=='grain'then I.yield(r,'food',x,y,size);return end
 local a=math.max(1,math.floor(size/9))
 local cx=x+math.floor(size/2)
 if kind=="warrior"then
  -- Shield + sword crossing its edge.
  rect(r,cx-2*a,y+2*a,4*a,4*a,color)
  rect(r,cx-1*a,y+3*a,2*a,3*a,7)
  rect(r,cx+2*a,y, a,6*a,6)
  rect(r,cx+a,y+2*a,3*a,a,8)
  rect(r,cx+2*a,y+6*a,a,2*a,8)
 elseif kind=="scout"then
  -- Hooded explorer, walking staff and small pack.
  rect(r,cx-2*a,y+a,4*a,3*a,12)
  rect(r,cx-a,y+2*a,2*a,a,7)
  rect(r,cx-2*a,y+4*a,4*a,3*a,color)
  rect(r,cx-2*a,y+7*a,a,a,4)
  rect(r,cx+a,y+7*a,a,a,4)
  rect(r,cx+3*a,y+a,a,7*a,9)
 elseif kind=="spearman"then
  -- Upright long spear and round shield.
  rect(r,cx+2*a,y,a,8*a,7)
  rect(r,cx+a,y+a,3*a,a,9)
  rect(r,cx-2*a,y+2*a,3*a,5*a,color)
  rect(r,cx-3*a,y+3*a,3*a,3*a,8)
  rect(r,cx-2*a,y+7*a,a,a,4)
 elseif kind=="horseman"then
  -- Mounted rider and four-legged horse silhouette.
  rect(r,cx-3*a,y+4*a,7*a,3*a,16)
  rect(r,cx+2*a,y+2*a,2*a,3*a,16)
  rect(r,cx-2*a,y+7*a,a,a,4)
  rect(r,cx+2*a,y+7*a,a,a,4)
  rect(r,cx-a,y+2*a,3*a,3*a,color)
  rect(r,cx,y+a,a,a,7)
 elseif kind=="archer" or kind=="ranger"then
  rect(r,cx-2*a,y+3*a,3*a,4*a,color)
  rect(r,cx+a,y+a,a,7*a,7)
  rect(r,cx+2*a,y+2*a,a,5*a,9)
  rect(r,cx-2*a,y+a,2*a,2*a,6)
 elseif kind=="swordsman"then
  rect(r,cx-2*a,y+3*a,4*a,5*a,color)
  rect(r,cx+2*a,y,2*a,6*a,7)
  rect(r,cx+a,y+3*a,4*a,a,8)
  rect(r,cx-2*a,y+a,3*a,2*a,6)
 elseif kind=="explorer"then
  rect(r,cx-2*a,y+3*a,4*a,4*a,color)
  rect(r,cx-3*a,y+a,6*a,2*a,9)
  rect(r,cx+a,y+6*a,3*a,a,8)
 elseif kind=="galley" or kind=="navigator" or kind=="frigate" or kind=="flagship"then
  rect(r,cx-4*a,y+5*a,8*a,2*a,16)
  rect(r,cx-2*a,y+2*a,5*a,3*a,color)
  rect(r,cx,y,1*a,6*a,7)
  if kind=="frigate" or kind=="flagship"then
   rect(r,cx-4*a,y+4*a,8*a,1*a,8)
  end
 elseif kind=="settler"then
  -- Wagon with canvas roof, axle, wheels.
  rect(r,cx-3*a,y+3*a,6*a,3*a,9)
  rect(r,cx-3*a,y+2*a,6*a,a,7)
  rect(r,cx-2*a,y+a,4*a,a,6)
  rect(r,cx-3*a,y+6*a,2*a,2*a,2)
  rect(r,cx+a,y+6*a,2*a,2*a,2)
 elseif kind=="city"then
  -- Walled town with gate and three rooflines.
  rect(r,cx-4*a,y+3*a,8*a,5*a,color)
  rect(r,cx-4*a,y+2*a,2*a,2*a,7)
  rect(r,cx-a,y+a,2*a,3*a,7)
  rect(r,cx+2*a,y+2*a,2*a,2*a,7)
  rect(r,cx-a,y+5*a,2*a,3*a,1)
  rect(r,cx-3*a,y+4*a,a,a,6)
  rect(r,cx+2*a,y+4*a,a,a,6)
 elseif kind=="forest"then
  rect(r,cx-a,y+5*a,2*a,3*a,16)
  rect(r,cx-3*a,y+3*a,6*a,3*a,11)
  rect(r,cx-2*a,y+a,4*a,3*a,12)
 elseif kind=="mountain"then
  for j=1,6 do rect(r,cx-j*a,y+(j+1)*a,2*j*a,a,4)end
  rect(r,cx-a,y+2*a,2*a,a,7)
 elseif kind=="water"then
  for k=0,2 do rect(r,cx-3*a,y+(2+k*2)*a,6*a,a,13)end
 elseif kind=="grain"then
  rect(r,cx-a,y+3*a,2*a,5*a,9)
  rect(r,cx-3*a,y+3*a,2*a,3*a,11)
  rect(r,cx+a,y+a,2*a,4*a,11)
 elseif kind=="timber"then
  rect(r,cx-2*a,y+3*a,4*a,5*a,16)
  rect(r,cx-3*a,y+a,6*a,3*a,12)
 elseif kind=="stone"then
  rect(r,cx-3*a,y+4*a,6*a,3*a,4)
  rect(r,cx-a,y+2*a,3*a,2*a,7)
 elseif kind=="iron"then
  rect(r,cx-3*a,y+3*a,6*a,4*a,5)
  rect(r,cx-2*a,y+4*a,4*a,a,8)
  rect(r,cx-a,y+2*a,2*a,a,9)
 elseif kind=="horses"then
  rect(r,cx-3*a,y+4*a,6*a,3*a,16)
  rect(r,cx+a,y+2*a,2*a,3*a,16)
  rect(r,cx-2*a,y+7*a,a,a,7)
  rect(r,cx+2*a,y+7*a,a,a,7)
 elseif kind=="saltpeter"then
  rect(r,cx-3*a,y+4*a,6*a,3*a,7)
  rect(r,cx-a,y+a,2*a,4*a,8)
  rect(r,cx+2*a,y+3*a,a,2*a,9)
 elseif kind=="fish"then
  rect(r,cx-3*a,y+4*a,6*a,2*a,13)
  rect(r,cx+2*a,y+2*a,2*a,5*a,11)
  rect(r,cx-2*a,y+3*a,a,a,7)
 elseif kind=="food"then
  rect(r,cx-a,y+2*a,2*a,6*a,11)
  rect(r,cx-3*a,y+a,2*a,3*a,11)
  rect(r,cx+a,y+a,2*a,3*a,11)
 elseif kind=="wood"then
  rect(r,cx-3*a,y+2*a,6*a,5*a,16)
  rect(r,cx-3*a,y+a,6*a,a,9)
  rect(r,cx-3*a,y+7*a,6*a,a,9)
 elseif kind=="science"then
  rect(r,cx-a,y+a,2*a,4*a,13)
  rect(r,cx-3*a,y+5*a,6*a,2*a,8)
  rect(r,cx-2*a,y+7*a,4*a,a,7)
 end
end
local yieldGlyphs={
 food={'00100','01110','10101','00100','00100'},
 wood={'01110','00110','00100','01000','10000'},
 science={'01110','00100','01010','10001','11111'},
}
local yieldColors={food=18,wood=7,science=13}
function I.yield(r,kind,x,y,size)
 if kind=='industry'then kind='wood'end
 local glyph=yieldGlyphs[kind];if not glyph then return end
 local scale=math.max(1,math.floor((size or 5)/5))
 local offset=math.floor(((size or 5)-5*scale)/2)
 for row,bits in ipairs(glyph)do for col=1,5 do if bits:sub(col,col)=='1'then
  r:fill(x+offset+(col-1)*scale,y+offset+(row-1)*scale,scale,scale,yieldColors[kind])
 end end end
end
function I.yieldValue(r,kind,value,x,y,width,background)
 local text=tostring(value or 0);local total=7+r:textWidth(text)
 if background then r:fill(x-1,y-1,total+2,7,0)end
 I.yield(r,kind,x,y,5);r:text(x+7,y,text,7,1,math.max(0,(width or total)-7))
 return total
end
function I.marker(r,kind,x,y)
 if kind=='worked'then
  r:fill(x,y,7,7,0);r:outline(x,y,7,7,8)
  r:fill(x+3,y+1,1,1,7);r:fill(x+2,y+3,3,2,7)
  r:fill(x+2,y+5,1,1,7);r:fill(x+4,y+5,1,1,7)
 elseif kind=='move'then
  local shape={'0011100','0100010','1000001','1001001','1000001','0100010','0011100'}
  for row,bits in ipairs(shape)do for col=1,7 do if bits:sub(col,col)=='1'then
   r:fill(x+col-2,y+row-2,3,3,0)
  end end end
  for row,bits in ipairs(shape)do for col=1,7 do if bits:sub(col,col)=='1'then
   r:fill(x+col-1,y+row-1,1,1,row==4 and 13 or 7)
  end end end
 else
  for i=0,4 do
   r:fill(x+i-1,y+i-1,3,3,7);r:fill(x+3-i,y+i-1,3,3,7)
  end
  for i=0,4 do r:fill(x+i,y+i,1,1,31);r:fill(x+4-i,y+i,1,1,31)end
 end
end
return I
