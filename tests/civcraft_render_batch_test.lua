local native=dofile
colors={black=32768,white=1,gray=128,lightGray=256,orange=2,lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local Renderer=native('games/civcraft/render.lua')
local calls,pixels=0,nil
local m={getSize=function(mode)if mode==2 then return 120,90 end;return 20,10 end,
 setGraphicsMode=function()end,getPaletteColor=function()return 0,0,0 end,setPaletteColor=function()end}
function m.drawPixels(x,y,rows,w,h)
 calls=calls+1;assert(x==0 and y==0 and w==120 and h==90 and type(rows)=='table')
 assert(#rows==90);for _,row in ipairs(rows)do assert(#row==120)end;pixels=rows
end
local r=Renderer.new(m)
r:begin();r:fill(0,0,r.w,r.h,2)
r:withClip({x=4,y=3,w=5,h=4},function()r:fill(0,0,30,30,8)end)
r:fill(20,10,3,3,13);r:finish()
assert(calls==1,'A complete graphics frame must use one batched peripheral update')
local function pixel(x,y)return pixels[math.floor(r.oy+y*r.sy)+1]:byte(math.floor(r.ox+x*r.sx)+1)end
assert(pixel(0,0)==2 and pixel(4,3)==8 and pixel(8,6)==8 and pixel(9,6)==2,'Viewport clipping survives batching')
assert(pixel(20,10)==13 and pixels[1]:byte(1)==0,'Palette values and letterboxing survive batching')
r:begin();r:fill(0,0,r.w,r.h,2)
local transparent=string.char(255)
r:withClip({x=5,y=4,w=2,h=2},function()r:blit({string.char(8,8,8),transparent..string.char(13,13)},4,4)end)
r:finish()
assert(pixel(4,4)==2 and pixel(5,4)==8 and pixel(6,4)==8 and pixel(5,5)==13,'Cached sprites respect transparency and viewport clipping')
local writes=0
local t={getSize=function()return 20,10 end,setCursorPos=function(x,y)assert(x==1 and y>=1 and y<=10)end,
 blit=function(text,fg,bg)assert(#text==20 and #fg==20 and #bg==20);writes=writes+1 end}
local text=Renderer.new(t)
local function frame()
 text:begin();text:fill(0,0,40,30,2);text:text(2,3,'HELLO',8);text:finish()
end
frame();assert(writes==10,'Text mode flushes one blit per row')
frame();assert(writes==10,'Unchanged text rows never reach the peripheral')
print('CIVCRAFT: one-call graphics frames, cached sprite clipping, text row batching and unchanged-row reuse passed.')
