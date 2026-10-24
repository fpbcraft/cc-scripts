-- Small recognizable unit/settlement symbols (not font characters).
local I={}
local function rect(r,x,y,w,h,c)r:fill(x,y,math.max(1,w),math.max(1,h),c)end
function I.draw(r,kind,x,y,size,color)
 local a=math.max(1,math.floor(size/9))
 local cx=x+math.floor(size/2)
 if kind=="warrior"then
  -- Shield + sword crossing its edge.
  rect(r,cx-2*a,y+2*a,4*a,4*a,color)
  rect(r,cx-1*a,y+3*a,2*a,3*a,7)
  rect(r,cx+2*a,y, a,6*a,6)
  rect(r,cx+a,y+2*a,3*a,a,8)
  rect(r,cx+2*a,y+6*a,a,2*a,8)
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
return I
