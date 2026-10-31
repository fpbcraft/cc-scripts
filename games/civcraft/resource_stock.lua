-- Canonical resource stock limits and pure, conservative stock operations.
local Stock = {}

Stock.caps = {
	iron = 10,
	copper = 10,
	zinc = 10,
	redstone = 10,
	diamond = 6,
	brass = 10,
	horses = 10,
	saltpeter = 10,
	coal = 10,
}
Stock.order =
	{ "iron", "copper", "zinc", "redstone", "diamond", "brass", "horses", "saltpeter", "coal" }

local function integer(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

local function validateAmount(value, label)
	if not integer(value) or value < 0 then
		return false, "invalid " .. label
	end
	return true
end

function Stock.validate(stock)
	if type(stock) ~= "table" then
		return false, "stockpile must be a table"
	end
	for resource, amount in pairs(stock) do
		if Stock.caps[resource] == nil then
			return false, "unknown resource " .. tostring(resource)
		end
		local valid, reason = validateAmount(amount, "stock for " .. resource)
		if not valid then
			return false, reason
		end
	end
	return true
end

function Stock.migrate(stock)
	local valid, reason = Stock.validate(stock)
	if not valid then
		return nil, reason
	end
	local migrated = {}
	for _, resource in ipairs(Stock.order) do
		migrated[resource] = stock[resource] or 0
	end
	return migrated
end

function Stock.copy(stock)
	local valid, reason = Stock.validate(stock)
	if not valid then
		return nil, reason
	end
	local result = {}
	for resource, amount in pairs(stock) do
		result[resource] = amount
	end
	return result
end

function Stock.planInflow(stock, resource, amount)
	local valid, reason = Stock.validate(stock)
	if not valid then
		return nil, reason
	end
	if Stock.caps[resource] == nil then
		return nil, "unknown resource " .. tostring(resource)
	end
	valid, reason = validateAmount(amount, "inflow")
	if not valid then
		return nil, reason
	end
	local current = stock[resource] or 0
	local accepted = math.min(amount, math.max(0, Stock.caps[resource] - current))
	return {
		resource = resource,
		before = current,
		accepted = accepted,
		overflow = amount - accepted,
	}
end

function Stock.applyInflow(stock, plan)
	local valid, reason = Stock.validate(stock)
	if not valid then
		return nil, reason
	end
	if type(plan) ~= "table" then
		return nil, "inflow plan must be a table"
	end
	for _, field in ipairs({ "accepted", "overflow" }) do
		valid, reason = validateAmount(plan[field], "plan " .. field)
		if not valid then
			return nil, reason
		end
	end
	local expected, planReason =
		Stock.planInflow(stock, plan.resource, plan.accepted + plan.overflow)
	if not expected then
		return nil, planReason
	end
	if
		plan.before ~= expected.before
		or plan.accepted ~= expected.accepted
		or plan.overflow ~= expected.overflow
	then
		return nil, "stale or invalid inflow plan"
	end
	local result = Stock.copy(stock)
	result[plan.resource] = expected.before + expected.accepted
	return result
end

function Stock.planOutput(stock, resource, amount)
	local plan, reason = Stock.planInflow(stock, resource, amount)
	if not plan then
		return nil, reason
	end
	if plan.overflow > 0 then
		return nil, "output_cap", { resource = resource, room = plan.accepted, required = amount }
	end
	return plan
end

function Stock.debit(stock, costs)
	local valid, reason = Stock.validate(stock)
	if not valid then
		return nil, reason
	end
	if type(costs) ~= "table" then
		return nil, "costs must be a table"
	end
	for resource, amount in pairs(costs) do
		if Stock.caps[resource] == nil then
			return nil, "unknown resource " .. tostring(resource)
		end
		valid, reason = validateAmount(amount, "cost for " .. resource)
		if not valid then
			return nil, reason
		end
		if (stock[resource] or 0) < amount then
			return nil, "missing " .. resource
		end
	end
	local result = Stock.copy(stock)
	for resource, amount in pairs(costs) do
		result[resource] = (result[resource] or 0) - amount
	end
	return result
end

-- Plan both outgoing reservations before checking either recipient's room.
function Stock.trade(first, second, giveResource, giveAmount, askResource, askAmount)
	for _, amount in ipairs({ giveAmount, askAmount }) do
		local valid, reason = validateAmount(amount, "trade amount")
		if not valid then
			return nil, reason
		end
	end
	if giveAmount == nil or askAmount == nil then
		return nil, "missing trade amount"
	end
	local firstCosts, secondCosts = {}, {}
	if giveAmount > 0 then
		if Stock.caps[giveResource] == nil then
			return nil, "unknown offered resource"
		end
		firstCosts[giveResource] = giveAmount
	end
	if askAmount > 0 then
		if Stock.caps[askResource] == nil then
			return nil, "unknown requested resource"
		end
		secondCosts[askResource] = askAmount
	end
	local a, why = Stock.debit(first, firstCosts)
	if not a then
		return nil, why
	end
	local b
	b, why = Stock.debit(second, secondCosts)
	if not b then
		return nil, why
	end
	for _, transfer in ipairs({
		{ stock = b, resource = giveResource, amount = giveAmount },
		{ stock = a, resource = askResource, amount = askAmount },
	}) do
		if transfer.amount > 0 then
			local plan
			plan, why = Stock.planOutput(transfer.stock, transfer.resource, transfer.amount)
			if not plan then
				return nil, "Recipient stock cap would be exceeded"
			end
			transfer.stock[transfer.resource] = plan.before + plan.accepted
		end
	end
	return { first = a, second = b }
end

return Stock
