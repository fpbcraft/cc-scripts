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

for _, resource in ipairs(Stock.order) do
	local cap = resource == "diamond" and 6 or 10
	equal(Stock.caps[resource], cap)
	local full = { [resource] = cap }
	equal(Stock.planInflow(full, resource, 1).accepted, 0)
	equal(
		assert(Stock.applyInflow(full, assert(Stock.planInflow(full, resource, 1))))[resource],
		cap
	)
end
for _, malformed in ipairs({
	{},
	{ resource = "iron", before = 2, accepted = "1", overflow = 0 },
	{ resource = "iron", before = 2, accepted = 1, overflow = -1 },
	{ resource = "iron", before = 2, accepted = 0 / 0, overflow = 0 },
	{ resource = "unknown", before = 0, accepted = 1, overflow = 0 },
}) do
	local ok, value = pcall(Stock.applyInflow, unchanged, malformed)
	assert(ok and value == nil, "Malformed plans must reject without throwing")
	equal(unchanged.iron, 2)
end
local stale = assert(Stock.planInflow({ iron = 2 }, "iron", 1))
equal(Stock.applyInflow({ iron = 3 }, stale), nil, "Stale plan rejected")
local source = { copper = 2, zinc = 0 }
equal(Stock.debit(source, { copper = 1, zinc = 1 }), nil)
equal(source.copper, 2, "Multi-input debit rejects atomically")
for _, amount in ipairs({ math.huge, -math.huge, 0 / 0 }) do
	equal(Stock.migrate({ iron = amount }), nil)
end
print("civcraft_resource_stock_test: ok")
