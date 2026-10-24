local U={}
function U.copy(v)
 if type(v)~="table" then return v end
 local t={};for k,a in pairs(v) do t[k]=U.copy(a) end;return t
end
function U.clamp(v,lo,hi)return math.max(lo,math.min(hi,v))end
function U.key(x,y)return x..":"..y end
function U.name(v)return tostring(v or ""):upper():gsub("[^A-Z0-9 _%-]",""):sub(1,12)end
function U.random(seed)
 local state=(tonumber(seed) or 42)%2147483647
 if state<=0 then state=42 end
 return function(max)
  state=(state*48271)%2147483647
  return max and 1+state%max or state/2147483647
 end
end
function U.cost(stock,needs)
 for k,n in pairs(needs or {}) do if (stock[k] or 0)<n then return false,k,n end end
 return true
end
function U.pay(stock,needs)
 for k,n in pairs(needs or {}) do stock[k]=stock[k]-n end
end
function U.add(stock,items)
 for k,n in pairs(items or {}) do stock[k]=(stock[k] or 0)+n end
end
function U.format(items)
 local t={};for k,n in pairs(items or {}) do t[#t+1]=k:upper().." "..n end
 table.sort(t);return #t>0 and table.concat(t,", ") or "FREE"
end
return U
