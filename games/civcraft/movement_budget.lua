-- Movement allowances are granted only by the normal round reset, never by loading.
local Movement = { embarked = 6 }
function Movement.base(unit, stats, owner)
	return (stats.move or 1)
		+ (owner and owner.civ == "nomad" and unit.kind == "scout" and 1 or 0)
		+ (owner and owner.civ == "mariner" and stats.naval and 1 or 0)
end
function Movement.nextRound(state, unit, stats, owner, hex)
	local base = Movement.base(unit, stats, owner)
	local sea = not stats.naval
		and not stats.air
		and hex.terrain(unit.x, unit.y, state) == "water"
		and (unit.publicEmbarked or owner and (owner.techs or {}).navigation)
	return sea and math.max(base, Movement.embarked) or base, sea == true
end
function Movement.reset(state, unit, stats, owner, hex)
	local allowance, sea = Movement.nextRound(state, unit, stats, owner, hex)
	unit.waterMovementRound = sea and state.round or nil
	unit.turnMovementAllowance, unit.movementAllowanceRound = allowance, state.round
	unit.movesLeft = (stats.hostile or unit.villageGuard) and 0 or allowance
	unit.moved = stats.hostile == true or unit.villageGuard ~= nil
end
function Movement.response(state, unit, stats, owner, hex)
	if unit.responseMovementRound == state.round then
		return
	end
	unit.responseMovementRound = state.round
	local _, sea = Movement.nextRound(state, unit, stats, owner, hex)
	if sea then
		unit.waterMovementRound = state.round
	end
	-- Response windows preserve both spent and remaining movement; only the sea rate changes.
end
function Movement.attackRange(state, unit, stats, hex)
	if not stats.naval and not stats.air and hex.terrain(unit.x, unit.y, state) == "water" then
		return (stats.strength or 0) > 0 and 1 or 0
	end
	return stats.range or 1
end
return Movement
