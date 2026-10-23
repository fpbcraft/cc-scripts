package.path="./factory/?.lua;"..package.path
local Text=require("ui_text")
local Graphics=require("graphics_capabilities")

assert(Text.columns("Électricité")==11)
assert(Text.clip("Électricité",6)=="Élect~",
  "Accent must never be split across UTF-8 bytes")
assert(Text.clip("André",12)=="André")
assert(Text.limit("André",4)=="Andr")
assert(Text.limit("André",5)=="André")
assert(Text.limit("électricité",1)=="é")
assert(Text.clip("日本語",5)=="日本~",
  "Full-width glyphs need two terminal columns")
assert(Text.columns("ÁB")==2,
  "Combining accent should not take another cell")
assert(Text.clip("ÁBC",2)=="Á~")
assert(Text.clip("",6)=="")
assert(Text.clip("a",1)=="a")
assert(Text.clip("abc",1)=="~")
assert(type(Text.clip("\255\254",1))=="string",
  "Invalid UTF-8 must not throw or hang")

local plain={getSize=function()return 30,20 end}
assert(Graphics.inspect(plain).available==false)
assert(Graphics.inspect(nil).available==false)
local touched=false
local capable={
  getGraphicsMode=function()return false end,
  setGraphicsMode=function()touched=true end,
  drawPixels=function()end,
  getSize=function(mode)
    assert(mode==2,"Pixel dimensions require mode-specific getSize")
    return 330,240
  end
}
local detected=Graphics.inspect(capable)
assert(detected.available and detected.mode==0)
assert(detected.width==330 and detected.height==240)
assert(not touched,"Capability inspection must not switch graphics modes")
print("Unicode text helpers and graphics capability tests passed")
