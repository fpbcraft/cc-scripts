-- Paged rows keep every control visible and clickable at small terminal sizes.
local Icons=dofile('/games/civcraft/icons.lua')
local P={}
function P.rows(r,rect,rows,model,key)
 key=key or 'offset'
 local rowHeight=12
 local capacity=math.max(1,math.floor((rect.h-12)/rowHeight))
 model[key]=math.max(0,math.min(model[key]or 0,math.max(0,#rows-capacity)))
 local area=rect
 if #rows>capacity then rect={x=rect.x,y=rect.y,w=rect.w-7,h=rect.h}end
 for i=1,capacity do
  local row=rows[model[key]+i]
  if row then
   local y=rect.y+(i-1)*rowHeight
   if row.adjust then
    if row.adjust.icon then
     Icons.yield(r,row.adjust.icon,rect.x+2,y+3,5)
     r:text(rect.x+10,y+3,row.adjust.label,7,1,rect.w-42)
    else r:text(rect.x+2,y+3,row.adjust.label,7,1,rect.w-34)end
    r:button(rect.x+rect.w-30,y,14,11,'-',row.adjust.minus)
    r:button(rect.x+rect.w-14,y,14,11,'+',row.adjust.plus)
   elseif row.yields then
    local width=math.floor((rect.w-4)/3)
    for n,kind in ipairs({'food','wood','science'})do
     Icons.yieldValue(r,kind,row.yields[kind=='wood' and 'industry' or kind],rect.x+2+(n-1)*width,y+3,width)
    end
   elseif row.buttons then
    local gap=2;local width=math.floor((rect.w-gap*(#row.buttons-1))/#row.buttons)
    for n,button in ipairs(row.buttons)do
     r:button(rect.x+(n-1)*(width+gap),y,width,11,button.label,button.run,button.style)
    end
   else r:text(rect.x+2,y+3,row.text,row.color or 6,1,rect.w-4)end
  end
 end
 local width=math.floor((rect.w-4)/2)
 local bottom=rect.y+rect.h-12
 if #rows>capacity then
  r:button(rect.x,bottom,width,11,'PREV',function()model[key]=math.max(0,model[key]-capacity)end)
  r:button(rect.x+width+4,bottom,width,11,'NEXT',function()model[key]=math.min(#rows-capacity,model[key]+capacity)end)
 end
 if #rows>capacity then
  local max=#rows-capacity
  local track={x=area.x+area.w-5,y=area.y,w=5,h=area.h-14}
  local thumb=math.max(4,math.floor(track.h*capacity/#rows))
  local pos=math.floor((track.h-thumb)*model[key]/max)
  r:fill(track.x,track.y,track.w,track.h,3)
  r:fill(track.x,track.y+pos,track.w,thumb,8)
  local bar={x=track.x,y=track.y,w=track.w,h=track.h,area=area,model=model,key=key,max=max,thumb=thumb}
  local function scrollTo(_,py)
   model[key]=math.floor(math.max(0,math.min(1,(py-track.y-thumb/2)/math.max(1,track.h-thumb)))*max+.5)
  end
  bar.move=scrollTo
  r.scrollbars=r.scrollbars or {};r.scrollbars[#r.scrollbars+1]=bar
  r.buttons[#r.buttons+1]={x=track.x,y=track.y,w=track.w,h=track.h,label='SCROLLBAR',fn=scrollTo}
 end
 model.pageCapacity=capacity;model.pageMax=math.max(0,#rows-capacity)
end
function P.wrap(r,value,width)
 local lines={};local line=''
 for word in tostring(value):gmatch('%S+')do
  local nextLine=line=='' and word or line..' '..word
  if r:textWidth(nextLine)>width and line~=''then lines[#lines+1]=line;line=word else line=nextLine end
  while r:textWidth(line)>width do
   local size=math.max(1,math.floor(#line*width/r:textWidth(line)))
   lines[#lines+1]=line:sub(1,size);line=line:sub(size+1)
  end
 end
 if line~=''then lines[#lines+1]=line end
 return lines
end
return P
