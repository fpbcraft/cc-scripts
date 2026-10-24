-- Small recognizable unit/settlement symbols (not font characters).
local I={}
local function rect(r,x,y,w,h,c)r:fill(x,y,math.max(1,w),math.max(1,h),c)end
local sprites={
 diamond={'0001000','0011100','0111110','1111111','0111110','0011100','0001000'},
 redstone={'0001000','0101010','0011100','1111111','0011100','0101010','0001000'},
 copper={'0000000','0011110','0111111','1111110','1111100','0111000','0000000'},
 zinc={'0000000','0011110','0111111','1111110','1111100','0111000','0000000'},
 brass={'0000000','0011110','0111111','1111110','1111100','0111000','0000000'},
 zombie={'0111110','0101010','0111110','0011100','1111111','0011100','0100010'},
 skeleton={'0111110','0101010','0110110','0001000','0111110','0001000','0100010'},
 spider={'1000001','0101010','1111111','0111110','1111111','0101010','1000001'},
 creeper={'0111110','0101010','0110110','0101010','0011100','0011100','0100010'},
 pillager={'0111110','0101010','0110110','0011100','1111111','1011101','0100010'},
 engineer={'0011100','0111110','0011100','1111110','1011101','0011100','0100010'},
 golem={'0111110','0101010','0111110','1111111','1111111','1011101','0010100'},
 wonder={'0001000','0011100','0111110','0011100','0111110','1111111','1111111'},
 spawner={'1111111','1010101','1101011','1011101','1101011','1010101','1111111'},
 village={'0001000','0011100','0111110','1111111','0101010','0111010','0111110'},
 gear={'0010100','1111111','0111110','1110111','0111110','1111111','0010100'}}
local spriteColors={diamond=13,redstone=31,copper=9,zinc=5,brass=8,zombie=11,skeleton=7,spider=16,creeper=11,pillager=5,engineer=9,golem=7,wonder=8,spawner=31,village=9,gear=8}
local function sprite(r,kind,x,y,size,color)
 local shape=sprites[kind];if not shape then return false end
 if size<7 then
  for row,bits in ipairs(shape)do for col=1,7 do if bits:sub(col,col)=='1'then r:fill(x+math.floor((col-1)*size/7),y+math.floor((row-1)*size/7),1,1,color or spriteColors[kind])end end end
  return true
 end
 local scale=math.max(1,math.floor(size/7));local shift=math.floor((size-scale*7)/2)
 for row,bits in ipairs(shape)do for col=1,7 do if bits:sub(col,col)=='1'then r:fill(x+shift+(col-1)*scale,y+shift+(row-1)*scale,scale,scale,color or spriteColors[kind])end end end
 return true
end
function I.draw(r,kind,x,y,size,color)
 local aliases={brassengineer='engineer',railengineer='engineer',alchemist='engineer',supplycrew='engineer',expedition='engineer',heavysiege='gear',dispenserbarge='frigate'}
 if kind=='diamondguard' or kind=='netherguard'then
  I.draw(r,'swordsman',x,y,size,kind=='diamondguard'and 13 or 4);return
 end
 kind=aliases[kind]or kind
 if sprite(r,kind,x,y,size)then return end
 if kind=='food' or kind=='grain'then I.yield(r,'food',x,y,size);return end
 local a=math.max(1,math.floor(size/9))
 local cx=x+math.floor(size/2)
 if kind=='catapult'then
  rect(r,cx-4*a,y+6*a,8*a,2*a,16);rect(r,cx-3*a,y+7*a,2*a,2*a,7);rect(r,cx+2*a,y+7*a,2*a,2*a,7)
  rect(r,cx-a,y+2*a,2*a,5*a,9);rect(r,cx,y+a,4*a,a,7);rect(r,cx+3*a,y,2*a,2*a,4)
 elseif kind=="warrior"then
  -- Shield + sword crossing its edge.
  rect(r,cx-2*a,y+2*a,4*a,4*a,color)
  rect(r,cx-1*a,y+3*a,2*a,3*a,7)
  rect(r,cx+2*a,y, a,6*a,6)
  rect(r,cx+a,y+2*a,3*a,a,8)
  rect(r,cx+2*a,y+6*a,a,2*a,8)
 elseif kind=="scout" or kind=="explorer"then
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
 gold={'01110','11011','10101','11011','01110'},
 food={'01110','11110','11100','00110','00011'},
 wood={'10101','01110','11011','01110','10101'},
 science={'01110','00100','01010','10001','11111'},
}
local yieldColors={food=18,wood=7,science=13,gold=8}
function I.yield(r,kind,x,y,size)
 x,y=math.floor(x),math.floor(y)
 if kind=='industry'then kind='wood'end
 local glyph=yieldGlyphs[kind];if not glyph then return end
 local scale=math.max(1,math.floor((size or 5)/5))
 local offset=math.floor(((size or 5)-5*scale)/2)
 for row,bits in ipairs(glyph)do for col=1,5 do if bits:sub(col,col)=='1'then
  r:fill(x+offset+(col-1)*scale,y+offset+(row-1)*scale,scale,scale,kind=='food' and (row>=4 and 7 or (row==2 and col==2)and 9 or 16)or yieldColors[kind])
 end end end
end
function I.yieldWidth(r,value)
 value=tonumber(value)or 0
 if value<=0 then return 0 end
 return value<=5 and value*6-1 or 7+r:textWidth(tostring(value))
end
function I.yieldValue(r,kind,value,x,y,width,background)
 x,y=math.floor(x),math.floor(y)
 local numeric=tonumber(value)
 if numeric and numeric<=0 then return 0 end
 local repeated=numeric and numeric>=1 and numeric<=5 and numeric==math.floor(numeric)
 local total=repeated and numeric*6-1 or 7+r:textWidth(tostring(value or 0))
 local columns=repeated and math.max(1,math.min(numeric,math.floor(((width or total)+1)/6)))or 1
 local rows=repeated and math.ceil(numeric/columns)or 1
 local drawn=repeated and columns*6-1 or total
 if background then r:fill(x-1,y-1,drawn+2,rows*6+1,0)end
 if repeated then
  for i=0,numeric-1 do I.yield(r,kind,x+(i%columns)*6,y+math.floor(i/columns)*6,5)end
 else
  I.yield(r,kind,x,y,5);r:text(x+7,y,tostring(value or 0),7,1,math.max(0,(width or total)-7))
 end
 return drawn
end
function I.resource(r,kind,x,y)
 if sprites[kind]then sprite(r,kind,x,y,5);return end
 local glyph=({iron={'01110','11111','11011','11111','01110'},horses={'00110','01111','11110','01100','01010'},saltpeter={'10100','01010','10101','01110','00100'}})[kind]
 if not glyph then return end
 for row,bits in ipairs(glyph)do for col=1,5 do if bits:sub(col,col)=='1'then r:fill(x+col-1,y+row-1,1,1,kind=='horses'and 9 or 7)end end end
end
function I.moveCost(r,cost,x,y)
 local value=tostring(cost);local width=math.max(7,r:textWidth(value)+2)
 r:fill(x-width/2,y-3,width,7,0);r:outline(x-width/2,y-3,width,7,13)
 r:text(x-r:textWidth(value)/2,y-2,value,7)
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
