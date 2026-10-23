package.path="./factory/?.lua;"..package.path
local Text=require("ui_text")

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

print("Unicode text helpers passed")
