-- UTF-8-aware display text helpers.
-- No dependency on Lua 5.3's utf8 library: CraftOS uses Lua 5.2.
-- Degrades gracefully if the Unicode Support mod is not installed.
local Text={}
local function charAt(s,i)
  local a=s:byte(i)
  if not a then return nil end
  local n=a<0x80 and 1 or
    a>=0xC2 and a<=0xDF and 2 or
    a>=0xE0 and a<=0xEF and 3 or
    a>=0xF0 and a<=0xF4 and 4 or 1
  if n==1 then return i+1,a end
  local cp=a%(2^(7-n))
  for j=1,n-1 do
    local v=s:byte(i+j)
    if not v or v<0x80 or v>0xBF then return i+1,a end
    cp=cp*64+v-0x80
  end
  if (n==2 and cp<0x80) or (n==3 and cp<0x800) or
     (n==4 and cp<0x10000) or cp>0x10FFFF or
     (cp>=0xD800 and cp<=0xDFFF) then
    return i+1,a
  end
  return i+n,cp
end
local function width(cp)
  -- Combining marks and variation selectors have no independent cell.
  if (cp>=0x300 and cp<=0x36F) or
     (cp>=0x1AB0 and cp<=0x1AFF) or
     (cp>=0x1DC0 and cp<=0x1DFF) or
     (cp>=0xFE00 and cp<=0xFE0F) then return 0 end
  -- East Asian full-width glyphs / most emoji typically occupy two cells.
  if (cp>=0x1100 and cp<=0x115F) or
     (cp>=0x2E80 and cp<=0xA4CF) or
     (cp>=0xAC00 and cp<=0xD7A3) or
     (cp>=0xF900 and cp<=0xFAFF) or
     (cp>=0xFE10 and cp<=0xFE6F) or
     (cp>=0xFF01 and cp<=0xFF60) or
     (cp>=0x1F300 and cp<=0x1FAFF) then
    return 2
  end
  return 1
end
function Text.columns(value)
  local s=tostring(value or "")
  local n,i=0,1
  while i<=#s do
    local nextPos,cp=charAt(s,i)
    n=n+width(cp)
    i=nextPos
  end
  return n
end
local function prefix(s,limit)
  if limit<=0 then return "" end
  local i,used=1,0
  while i<=#s do
    local nextPos,cp=charAt(s,i)
    local cells=width(cp)
    if used+cells>limit then break end
    used=used+cells
    i=nextPos
  end
  return s:sub(1,i-1)
end
function Text.clip(value,columns)
  local s=tostring(value or "")
  columns=math.max(1,math.floor(tonumber(columns) or 16))
  if Text.columns(s)<=columns then return s end
  return prefix(s,columns-1).."~"
end
-- Limit length in UTF-8 display characters instead of splitting a byte
-- sequence. Used by touch keyboard/paste synchronization.
function Text.limit(value,maxChars)
  local s=tostring(value or "")
  maxChars=math.max(0,math.floor(tonumber(maxChars) or 160))
  local i,n=1,0
  while i<=#s and n<maxChars do
    local pos=charAt(s,i)
    i=pos
    n=n+1
  end
  return s:sub(1,i-1)
end
return Text
