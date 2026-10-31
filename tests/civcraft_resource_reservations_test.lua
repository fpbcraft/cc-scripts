local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local R = dofile("/games/civcraft/resource_reservations.lua")
local function op(city, priority, inputs, outputs, building)
	return {
		owner = 1,
		cityID = city,
		buildingID = building or "mixer",
		priority = priority,
		inputs = inputs or { copper = 1, zinc = 1 },
		outputs = outputs or { brass = 2 },
	}
end
local stock = { copper = 1, zinc = 1, brass = 0 }
local first, second = op(3, 3), op(2, 3)
local plan = assert(R.plan(stock, 1, { first, second }))
assert(plan.operations[1].cityID == 2 and plan.operations[1].active)
assert(not plan.operations[2].active and plan.operations[2].reason == "missing_input")
assert(plan.stock.copper == 0 and plan.stock.zinc == 0 and plan.stock.brass == 2)
assert(stock.copper == 1 and stock.zinc == 1 and stock.brass == 0)
assert(first.cityID == 3, "Sorting must not mutate caller descriptors")
local reversed = assert(R.plan(stock, 1, { second, first }))
assert(reversed.operations[1].cityID == 2 and reversed.stock.brass == plan.stock.brass)
local cap = assert(R.plan({ copper = 2, zinc = 2, brass = 9 }, 1, { first, second }))
assert(cap.stock.copper == 2 and cap.stock.zinc == 2 and cap.stock.brass == 9)
assert(cap.operations[1].reason == "output_cap" and cap.operations[2].reason == "output_cap")
cap = assert(R.plan({ copper = 2, zinc = 2, brass = 8 }, 1, { first, second }))
assert(cap.stock.brass == 10 and cap.stock.copper == 1 and cap.operations[2].reason == "output_cap")
cap = assert(R.plan({ copper = 2, zinc = 2, brass = 12 }, 1, { first }))
assert(cap.stock.brass == 12 and cap.stock.copper == 2)
-- Generic descriptors prove material staging; these are not new gameplay recipes.
local producer = op(1, 1, { copper = 1 }, { brass = 2 }, "producer")
local consumer = op(2, 2, { brass = 2 }, { iron = 1 }, "consumer")
local staged = assert(R.plan({ copper = 1 }, 1, { consumer, producer }))
assert(staged.operations[1].active and staged.operations[2].reason == "missing_input")
assert(staged.stock.brass == 2 and staged.stock.iron == 0, "Outputs cannot fund later operations")
local tie = assert(
	R.plan(
		{ copper = 1, zinc = 1 },
		1,
		{ op(2, 2, nil, nil, "z"), op(3, 1), op(2, 2, nil, nil, "a") }
	)
)
assert(tie.operations[1].cityID == 3 and tie.operations[1].active)
assert(tie.operations[2].buildingID == "a" and tie.operations[3].buildingID == "z")
local session = assert(R.begin(stock, 1))
assert(R.reserve(session, second).active)
local result = R.result(session)
result.stock.brass, result.operations[1].inputs.copper = 999, 999
assert(R.result(session).stock.brass == 2 and R.result(session).operations[1].inputs.copper == 1)
assert(not R.reserve(session, second), "Duplicate identity is invalid even after a pause")
assert(not R.reserve(session, op(1, 1)), "Incremental callers must preserve canonical ordering")
local last = assert(R.reserve(session, first))
assert(not last.active and last.reason == "missing_input")
for _, mutate in ipairs({
	function(x)
		x.owner = 2
	end,
	function(x)
		x.priority = 0
	end,
	function(x)
		x.priority = 0.5
	end,
	function(x)
		x.cityID = -1
	end,
	function(x)
		x.buildingID = ""
	end,
	function(x)
		x.inputs = { secret = 1 }
	end,
	function(x)
		x.outputs = { brass = -1 }
	end,
	function(x)
		x.outputs = { brass = math.huge }
	end,
}) do
	local invalid = op(1, 1)
	mutate(invalid)
	assert(not R.plan(stock, 1, { invalid }))
	assert(stock.copper == 1 and stock.zinc == 1)
end
assert(not R.plan(stock, 1, { first, first }))
assert(not R.plan(stock, 1, { [0] = first }))
assert(not R.begin({ copper = -1 }, 1))
print(
	"CIVCRAFT: ordered atomic reservations, complete output room, staging and detached forecasts passed"
)
