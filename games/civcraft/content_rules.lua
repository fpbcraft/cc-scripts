-- Campaign-scoped economies. Missing version means the original saved economy.
local Rules = { baseline = "baseline", current = "p1", redesign = "balance1" }
function Rules.isP1(context)
	return context and context.contentRules == Rules.current
end
function Rules.isRedesign(context)
	return context and context.contentRules == Rules.redesign
end
function Rules.usesP1Economy(context)
	return Rules.isP1(context) or Rules.isRedesign(context)
end
function Rules.label(context)
	return Rules.isRedesign(context) and "REDESIGN V1" or Rules.isP1(context) and "P1" or "ORIGINAL"
end
function Rules.ability(record, context)
	if Rules.isRedesign(context) and record.healer then
		return "Adjacent owned resting allies recover +10 HP; no self-support or stacking. Acting allies do not recover."
	end
	return record.ability
end
function Rules.validate(id)
	assert(
		id == nil or id == Rules.baseline or id == Rules.current or id == Rules.redesign,
		"Unsupported content economy"
	)
end
function Rules.unitCost(id, record, player)
	local base, step =
		record.production or math.ceil((record.wood or 8) * 2.5), record.productionStep or 0
	if Rules.usesP1Economy(player) then
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
