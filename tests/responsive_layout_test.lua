package.path="./factory/?.lua;"..package.path
local Layout=require("layout")
local count=18
local small=Layout.graphGrid(42,27,count,1)
local medium=Layout.graphGrid(82,45,count,1)
local large=Layout.graphGrid(144,76,count,1)
assert(small.perPage<medium.perPage and medium.perPage<large.perPage,
  "A larger monitor should display more charts per page")
for _,case in ipairs({{42,27,small},{82,45,medium},{144,76,large}}) do
  local w,h,grid=case[1],case[2],case[3]
  for _,tile in ipairs(grid.tiles) do
    assert(tile.x>=2 and tile.y>=5)
    assert(tile.x+tile.width-1<=w-2)
    assert(tile.y+tile.height-1<=h-5)
  end
end
assert(large.columns>=4 and #large.tiles>=12)
local compact=Layout.overviewCharts(55,38,20)
local big=Layout.overviewCharts(144,76,20)
assert(#compact==4 and #big>#compact)
for _,tile in ipairs(big) do
  assert(tile.y>=15 and tile.y+tile.height-1<=73)
end
local pixelSmall=Layout.pixelGrid(340,348,12,1,false)
local pixelLarge=Layout.pixelGrid(960,740,12,1,false)
assert(pixelLarge.perPage>pixelSmall.perPage)
assert(pixelLarge.perPage==12)
assert(#pixelLarge.tiles==12)
assert(Layout.pixelGrid(340,348,12,2,false).tiles[1].index==
  pixelSmall.perPage+1)
for _,tile in ipairs(pixelLarge.tiles) do
  assert(tile.x>=0 and tile.y>=0 and
    tile.x+tile.width<=960 and tile.y+tile.height<=740-45)
end
print("Responsive Basalt and pixel layout tests passed")
