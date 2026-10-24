-- Geometry for compact Overview charts, kept independent of Basalt.
local M={}
function M.overviewCharts(w,h,count)
  local result={}
  if w<32 or h<27 or (count or 0)<=0 then return result end
  local columns=w>=50 and 2 or 1
  local height=8
  local rows=h>=36 and 2 or 1
  local width=math.floor((w-4-(columns-1)*2)/columns)
  if width<21 then return result end
  local start=h-3-rows*(height+1)
  if start<15 then return result end
  for i=1,math.min(count,columns*rows) do
    local column=(i-1)%columns
    local row=math.floor((i-1)/columns)
    local x=2+column*(width+2)
    local y=start+row*(height+1)
    if x+width-1<=w-2 and y+height-1<=h-3 then
      result[#result+1]={x=x,y=y,width=width,height=height,index=i}
    end
  end
  return result
end
return M
