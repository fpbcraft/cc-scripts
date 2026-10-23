-- Pure layout geometry, independently testable without Basalt.
local M={}
local function cols(width,minTile,maxColumns)
  for c=maxColumns,1,-1 do
    if math.floor((width-4-(c-1)*2)/c)>=minTile then
      return c
    end
  end
  return 1
end
function M.graphGrid(w,h,count,page)
  count=math.max(0,tonumber(count) or 0)
  page=math.max(1,math.floor(tonumber(page) or 1))
  local columns=cols(w,22,math.min(6,math.max(1,math.floor(w/24))))
  local tileWidth=math.floor((w-4-(columns-1)*2)/columns)
  local tileHeight=h>=65 and 15 or h>=46 and 12 or h>=29 and 10 or 8
  local rows=math.max(1,math.floor((h-10)/(tileHeight+1)))
  -- Put an explicit footer between the last chart and the nav bar.
  while rows>1 and 5+(rows-1)*(tileHeight+1)+tileHeight>h-5 do
    rows=rows-1
  end
  local perPage=math.max(1,columns*rows)
  local pages=math.max(1,math.ceil(count/perPage))
  page=math.min(page,pages)
  local tiles={}
  for slot=1,perPage do
    local index=(page-1)*perPage+slot
    if index>count then break end
    local column=(slot-1)%columns
    local row=math.floor((slot-1)/columns)
    tiles[#tiles+1]={
      index=index,x=2+column*(tileWidth+2),
      y=5+row*(tileHeight+1),width=tileWidth,height=tileHeight
    }
  end
  return {
    columns=columns,rows=rows,perPage=perPage,pages=pages,
    page=page,tiles=tiles
  }
end
function M.overviewCharts(w,h,count)
  local result={}
  if w<32 or h<27 or (count or 0)<=0 then return result end
  local columns=cols(w,22,6)
  local tileHeight=h>=70 and 12 or h>=50 and 10 or 8
  local tileWidth=math.floor((w-4-(columns-1)*2)/columns)
  if tileWidth<21 then return result end
  -- Space above y=15 remains reserved for overview status and controls.
  local available=h-4-15
  local maxRows=math.max(0,math.floor(available/(tileHeight+1)))
  -- One row is possible at smaller heights by occupying the final margin.
  if maxRows==0 and 15+tileHeight<=h-3 then maxRows=1 end
  local rows=math.min(maxRows,math.max(1,math.ceil(count/columns)))
  if rows<1 then return result end
  local start=h-3-rows*(tileHeight+1)
  if start<15 then start=15 end
  for i=1,math.min(count,columns*rows) do
    local column=(i-1)%columns
    local row=math.floor((i-1)/columns)
    local x=2+column*(tileWidth+2)
    local y=start+row*(tileHeight+1)
    if x+tileWidth-1<=w-2 and y+tileHeight-1<=h-3 then
      result[#result+1]={
        x=x,y=y,width=tileWidth,height=tileHeight,index=i
      }
    end
  end
  return result
end
-- Responsive pixel chart grid, reserving footer for range controls.
function M.pixelGrid(w,h,count,page,detail)
  local columns=detail and 1 or
    (w>=900 and 4 or w>=600 and 3 or w>=290 and 2 or 1)
  local rows=detail and 1 or
    (h>=650 and 3 or h>=255 and 2 or 1)
  local perPage=columns*rows
  local total=math.max(0,tonumber(count) or 0)
  local pages=math.max(1,math.ceil(total/perPage))
  page=math.max(1,math.min(pages,math.floor(tonumber(page) or 1)))
  local margin,top,bottom=12,32,45
  local tileWidth=math.floor((w-margin*(columns+1))/columns)
  local tileHeight=math.floor((h-top-bottom-margin*(rows+1))/rows)
  local tiles={}
  for slot=1,perPage do
    local index=(page-1)*perPage+slot
    if index>total then break end
    local c=(slot-1)%columns
    local r=math.floor((slot-1)/columns)
    tiles[#tiles+1]={
      index=index,x=margin+c*(tileWidth+margin),
      y=top+margin+r*(tileHeight+margin),
      width=tileWidth,height=tileHeight
    }
  end
  return {columns=columns,rows=rows,perPage=perPage,pages=pages,
    page=page,tiles=tiles}
end
return M
