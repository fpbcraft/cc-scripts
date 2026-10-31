local Stock = dofile("games/civcraft/resource_stock.lua")

local function equal(actual, expected, message)
	assert(actual == expected, (message or "values differ") .. ": " .. tostring(actual))
end

local migrated = assert(Stock.migrate({ iron = 3, diamond = 9 }))
equal(migrated.iron, 3)
equal(migrated.copper, 0)
equal(migrated.diamond, 9, "legacy over-cap stock is preserved")
local copy = assert(Stock.copy(migrated))
copy.iron = 0
equal(migrated.iron, 3, "query output is copied")

local plan = assert(Stock.planInflow({ iron = 9 }, "iron", 3))
equal(plan.accepted, 1)
equal(plan.overflow, 2)
local after = assert(Stock.applyInflow({ iron = 9 }, plan))
equal(after.iron, 10)
equal(Stock.planInflow({ iron = 12 }, "iron", 1).accepted, 0)
equal(Stock.planInflow({ iron = 12 }, "iron", 1).overflow, 1)

local output, reason, blocked = Stock.planOutput({ brass = 9 }, "brass", 2)
equal(output, nil)
equal(reason, "output_cap")
equal(blocked.room, 1)
assert(Stock.planOutput({ brass = 8 }, "brass", 2))

local paid = assert(Stock.debit({ copper = 2, zinc = 1 }, { copper = 1, zinc = 1 }))
equal(paid.copper, 1)
equal(paid.zinc, 0)
local rejected = Stock.debit({ copper = 0 }, { copper = 1 })
equal(rejected, nil, "insufficient debit rejected")

for _, invalid in ipairs({ { iron = -1 }, { iron = 1.5 }, { unknown = 2 } }) do
	local bad = Stock.migrate(invalid)
	equal(bad, nil, "malformed migration rejected")
end
local unchanged = { iron = 2 }
local invalidPlan = Stock.planInflow(unchanged, "iron", -1)
equal(invalidPlan, nil)
equal(unchanged.iron, 2, "rejected operations do not mutate source")

print("civcraft_resource_stock_test: ok")
