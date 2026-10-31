-- Pure material reservations over one post-extraction snapshot. Descriptors are
-- derived by authoritative machinery rules, never accepted as client recipes.
local Stock = dofile("/games/civcraft/resource_stock.lua")
local R = {}
local function integer(value)
	return type(value) == "number"
		and value == value
		and value % 1 == 0
		and math.abs(value) < math.huge
end
local function copy(values)
	local result = {}
	for key, value in pairs(values) do
		result[key] = value
	end
	return result
end
local function before(a, b)
	if a.priority ~= b.priority then
		return a.priority < b.priority
	end
	if a.cityID ~= b.cityID then
		return a.cityID < b.cityID
	end
	return a.buildingID < b.buildingID
end
local function descriptor(owner, op)
	if
		type(op) ~= "table"
		or op.owner ~= owner
		or not integer(op.cityID)
		or op.cityID < 1
		or type(op.buildingID) ~= "string"
		or op.buildingID == ""
		or not integer(op.priority)
		or op.priority < 1
	then
		return nil, "Invalid owned operation identity/priority"
	end
	for _, field in ipairs({ "inputs", "outputs" }) do
		local ok, why = Stock.validate(op[field])
		if not ok then
			return nil, why
		end
	end
	return {
		owner = owner,
		cityID = op.cityID,
		buildingID = op.buildingID,
		priority = op.priority,
		inputs = copy(op.inputs),
		outputs = copy(op.outputs),
	}
end
function R.begin(stock, owner)
	if not integer(owner) then
		return nil, "Invalid owner"
	end
	local snapshot, why = Stock.migrate(stock)
	if not snapshot then
		return nil, why
	end
	local room, inputs, outputs = {}, {}, {}
	for _, id in ipairs(Stock.order) do
		room[id], inputs[id], outputs[id] = math.max(0, Stock.caps[id] - snapshot[id]), 0, 0
	end
	return {
		owner = owner,
		snapshot = snapshot,
		available = copy(snapshot),
		room = room,
		inputs = inputs,
		outputs = outputs,
		operations = {},
		seen = {},
	}
end
function R.reserve(session, operation)
	local op, why = descriptor(session.owner, operation)
	if not op then
		return nil, why
	end
	local identity = op.cityID .. ":" .. op.buildingID
	if session.seen[identity] then
		return nil, "Duplicate city/building operation"
	end
	if session.last and before(op, session.last) then
		return nil, "Operations must be reserved in stable order"
	end
	local reason, resource
	-- Check full output room before reserving any input. Outputs never replenish
	-- available snapshot inputs, and a paused operation reserves nothing.
	for _, id in ipairs(Stock.order) do
		if (op.outputs[id] or 0) > session.room[id] then
			reason, resource = "output_cap", id
			break
		end
	end
	if not reason then
		for _, id in ipairs(Stock.order) do
			if (op.inputs[id] or 0) > session.available[id] then
				reason, resource = "missing_input", id
				break
			end
		end
	end
	op.active, op.reason, op.resource = reason == nil, reason, resource
	if op.active then
		for _, id in ipairs(Stock.order) do
			local debit, credit = op.inputs[id] or 0, op.outputs[id] or 0
			session.available[id] = session.available[id] - debit
			session.inputs[id], session.outputs[id] =
				session.inputs[id] + debit, session.outputs[id] + credit
			session.room[id] = session.room[id] - credit
		end
	end
	session.seen[identity], session.last = true, op
	session.operations[#session.operations + 1] = op
	return { active = op.active, reason = reason, resource = resource }
end
function R.result(session)
	local stock, operations = {}, {}
	for _, id in ipairs(Stock.order) do
		stock[id] = session.snapshot[id] - session.inputs[id] + session.outputs[id]
	end
	for index, op in ipairs(session.operations) do
		operations[index] = copy(op)
		operations[index].inputs, operations[index].outputs = copy(op.inputs), copy(op.outputs)
	end
	return {
		owner = session.owner,
		stock = stock,
		snapshot = copy(session.snapshot),
		inputs = copy(session.inputs),
		outputs = copy(session.outputs),
		caps = copy(Stock.caps),
		operations = operations,
	}
end
function R.plan(stock, owner, operations)
	if type(operations) ~= "table" then
		return nil, "Operations must be an array"
	end
	local sorted = {}
	for index, op in pairs(operations) do
		if not integer(index) or index < 1 or index > #operations then
			return nil, "Invalid operation array"
		end
		local item, why = descriptor(owner, op)
		if not item then
			return nil, why
		end
		sorted[index] = item
	end
	for index = 1, #operations do
		if sorted[index] == nil then
			return nil, "Sparse operation array"
		end
	end
	table.sort(sorted, before)
	local session, why = R.begin(stock, owner)
	if not session then
		return nil, why
	end
	for _, op in ipairs(sorted) do
		local result
		result, why = R.reserve(session, op)
		if not result then
			return nil, why
		end
	end
	return R.result(session)
end
return R
