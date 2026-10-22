package.path="./factory/?.lua;"..package.path
local layout=require("layout")
for _,size in ipairs({{55,38},{55,31},{45,38},{38,28},{64,30}}) do
  local w,h=size[1],size[2]
  local tiles=layout.overviewCharts(w,h,4)
  assert(#tiles>=1,"Charts missing at "..w.."x"..h)
  for _,tile in ipairs(tiles) do
    assert(tile.x>=2 and tile.width>=21)
    assert(tile.y>=15,"Chart overlaps Overview control/alert section")
    assert(tile.y+tile.height-1<=h-3,"Chart overlaps status/footer")
    assert(tile.x+tile.width-1<=w-2,"Chart exceeds screen")
  end
end
assert(#layout.overviewCharts(55,38,4)==4,
  "Expected 2x2 chart grid on 55x38 monitor")
assert(#layout.overviewCharts(55,31,4)==2,
  "Expected 1x2 compact row on 55x31 monitor")
assert(#layout.overviewCharts(38,28,4)==1,
  "Expected one compact chart on narrow monitor")
assert(#layout.overviewCharts(30,24,4)==0)
print("Overview chart layout tests passed")
