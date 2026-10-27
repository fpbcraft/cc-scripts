-- Convert an observer event into drawing primitives without simulation access.
local Frame = {}
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

local function duration(event)
	if event.type ~= "move" then
		return (event.type == "combat" or event.type == "cityStrike") and 0.65 or 0.45
	end
	local time = 0
	for _, path in ipairs(event.paths or {}) do
		time = time + math.max(1, #path - 1) * 0.12 + 0.06
	end
	return math.max(0.12, time - 0.06)
end

-- Convert odd-row hex centers before interpolation: fractional row parity is invalid.
local function center(point)
	return { x = point.x - 0.5 + ((point.y - 1) % 2) * 0.5, y = (point.y - 1) * 0.75 + 0.5 }
end

local function between(a, b, progress)
	local start, finish = center(a), center(b)
	return {
		x = start.x + (finish.x - start.x) * progress,
		y = start.y + (finish.y - start.y) * progress,
	}
end

local function identity(actor)
	if actor and actor.id then
		return (actor.kind == "city" and "city:" or "unit:") .. actor.id
	end
end
Frame.identity = identity

local function hide(frame, actor)
	local key = identity(actor)
	if key then
		frame.hidden[key] = true
	end
end

local function sprite(frame, actor, position, hp, opacity)
	if actor then
		frame.sprites[#frame.sprites + 1] = {
			actor = copy(actor),
			position = position,
			hp = hp or actor.hp,
			opacity = opacity or 1,
		}
	end
end

local function movement(frame, event, progress)
	local time = progress * duration(event)
	for _, path in ipairs(event.paths or {}) do
		local seconds = math.max(1, #path - 1) * 0.12
		if time <= seconds then
			if #path == 1 then
				sprite(frame, event.actor, center(path[1]))
			elseif #path > 1 then
				local segment = math.min(#path - 1, math.floor(time / 0.12) + 1)
				local amount = math.min(1, (time - (segment - 1) * 0.12) / 0.12)
				sprite(frame, event.actor, between(path[segment], path[segment + 1], amount))
			end
			return
		end
		time = time - seconds
		if time < 0.06 then
			return -- Concealed route gap: never draw a connecting segment.
		end
		time = time - 0.06
	end
end

local function combat(frame, event, progress)
	local result = event.result or {}
	local impacted = progress >= 0.5
	local start, target = event.start, event.target
	if start and target then
		local ranged = result.ranged or event.type == "cityStrike"
		local advance = not ranged
			and not result.attackerDied
			and (result.defenderDied or result.captured)
		local offset = progress < 0.5 and progress * 0.8 or (1 - progress) * 0.8
		if advance and impacted then
			offset = 0.4 + (progress - 0.5) * 1.2
		end
		local position = ranged and center(start) or between(start, target, offset)
		sprite(
			frame,
			event.actor,
			position,
			impacted and result.attackerHP or nil,
			impacted and result.attackerDied and (1 - progress) * 2 or 1
		)
		if ranged and not impacted then
			frame.projectile =
				{ start = center(start), position = between(start, target, progress * 2) }
		end
	elseif start then
		sprite(
			frame,
			event.actor,
			center(start),
			impacted and result.attackerHP or nil,
			impacted and result.attackerDied and (1 - progress) * 2 or 1
		)
	end
	if target then
		sprite(
			frame,
			event.defender,
			center(target),
			impacted and (result.defenderHP or result.cityHP) or nil,
			impacted and result.defenderDied and (1 - progress) * 2 or 1
		)
		if impacted and result.captured and frame.sprites[#frame.sprites] then
			frame.sprites[#frame.sprites].actor.owner = event.actor.owner
		end
		if impacted then
			frame.effects[#frame.effects + 1] = {
				kind = result.captured and "capture" or "impact",
				position = center(target),
				progress = (progress - 0.5) * 2,
			}
		end
	end
end

local function paint(frame, event, progress)
	hide(frame, event.actor)
	if event.type == "move" then
		movement(frame, event, progress)
	elseif event.result then
		hide(frame, event.defender)
		combat(frame, event, progress)
	elseif event.target then
		if event.type == "disband" then
			sprite(frame, event.actor, center(event.target), nil, 1 - progress)
		elseif event.type == "spawn" then
			sprite(frame, event.actor, center(event.target), nil, progress)
		elseif event.type == "found" then
			sprite(frame, event.actor, center(event.target), nil, progress)
		end
		frame.effects[#frame.effects + 1] = {
			kind = event.type,
			position = center(event.target),
			progress = progress,
		}
	end
end

Frame.duration = duration
Frame.paint = paint
return Frame
