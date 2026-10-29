-- Campaign-scoped economies. Missing version means the original saved economy.
local Rules = {
	baseline = "baseline",
	current = "p1",
	redesign = "balance1",
	development = "balance2",
	landwork = "balance3",
	opening = "balance4",
	specialization = "balance5",
	default = "balance5",
}
function Rules.isP1(context)
	return context and context.contentRules == Rules.current
end
function Rules.isRedesign(context)
	return context
		and (
			context.contentRules == Rules.redesign
			or context.contentRules == Rules.development
			or context.contentRules == Rules.landwork
			or context.contentRules == Rules.opening
			or context.contentRules == Rules.specialization
		)
end
function Rules.hasDevelopment(context)
	return context
		and (
			context.contentRules == Rules.development
			or context.contentRules == Rules.landwork
			or context.contentRules == Rules.opening
			or context.contentRules == Rules.specialization
		)
end
function Rules.hasBuilders(context)
	return context
		and (
			context.contentRules == Rules.landwork
			or context.contentRules == Rules.opening
			or context.contentRules == Rules.specialization
		)
end
function Rules.startsWithSettler(context)
	return context
		and (context.contentRules == Rules.opening or context.contentRules == Rules.specialization)
end
function Rules.hasSpecialties(context)
	return context and context.contentRules == Rules.specialization
end
function Rules.available(record, context)
	if record.tileDevelopment and not Rules.hasBuilders(context) then
		return false
	end
	if record.retiredByBuilders and Rules.hasBuilders(context) then
		return false
	end
	return not record.development or Rules.hasDevelopment(context)
end
function Rules.usesP1Economy(context)
	return Rules.isP1(context) or Rules.isRedesign(context)
end
function Rules.label(context)
	return Rules.hasSpecialties(context) and "SPECIALIZATION V5"
		or Rules.startsWithSettler(context) and "FOUNDERS V4"
		or Rules.hasBuilders(context) and "LANDWORK V3"
		or Rules.hasDevelopment(context) and "DEVELOPMENT V2"
		or Rules.isRedesign(context) and "REDESIGN V1"
		or Rules.isP1(context) and "P1"
		or "ORIGINAL"
end
function Rules.ability(record, context)
	if Rules.isRedesign(context) and record.healer then
		return "Adjacent owned resting allies recover +10 HP; no self-support or stacking. Acting allies do not recover."
	end
	return record.ability
end
function Rules.validate(id)
	assert(
		id == nil
			or id == Rules.baseline
			or id == Rules.current
			or id == Rules.redesign
			or id == Rules.development
			or id == Rules.landwork
			or id == Rules.opening
			or id == Rules.specialization,
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
			base, step =
				Rules.hasDevelopment(player) and 28 or 40, Rules.hasDevelopment(player) and 8 or 12
		end
	end
	return base, step
end
return Rules
