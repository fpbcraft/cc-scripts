if type(require) == "function" then
  return require("lib.fpb.packages")
end
return dofile("/apps/fpbstore/_lib/fpb/packages.lua")
