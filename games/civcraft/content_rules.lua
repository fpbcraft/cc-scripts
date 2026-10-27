-- Campaign-scoped economies. Missing version means the original saved economy.
local Rules = { baseline = "baseline", current = "p1" }
function Rules.isP1(context)
	return context and context.contentRules == Rules.current
end
function Rules.validate(id)
	assert(id == nil or id == Rules.baseline or id == Rules.current, "Unsupported content economy")
end
function Rules.unitCost(id, record, player)
	local base, step =
		record.production or math.ceil((record.wood or 8) * 2.5), record.productionStep or 0
	if Rules.isP1(player) then
		if id == "scout" then
			base = 15
		end
		if id == "warrior" then
			base = 20
		end
		if id == "settler" then
			base, step = 40, 12
		end
	end
	return base, step
end
return Rules
