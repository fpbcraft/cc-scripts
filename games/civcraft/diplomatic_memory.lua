-- Pairwise memories explain trust; immediate military pressure is assessed separately.
local Events = dofile("/games/civcraft/events.lua")
local Memory = {}
function Memory.key(observer, subject)
	return tostring(observer) .. ":" .. tostring(subject)
end

function Memory.relation(state, observer, subject)
	local relations = state.diplomacy.relations
	local key = Memory.key(observer, subject)
	relations[key] = relations[key] or { trust = 0, grievances = 0, memories = {} }
	local relation = relations[key]
	relation.memories = relation.memories or {}
	return relation
end

function Memory.add(state, observer, subject, kind, trust, grievances, duration, explanation)
	local relation = Memory.relation(state, observer, subject)
	for _, memory in ipairs(relation.memories) do
		if memory.kind == kind and memory.round == state.round then
			return false
		end
	end
	local oldTrust, oldGrievances = relation.trust, relation.grievances
	relation.trust = math.max(-200, math.min(200, oldTrust + trust))
	relation.grievances = math.max(0, oldGrievances + grievances)
	trust, grievances = relation.trust - oldTrust, relation.grievances - oldGrievances
	relation.memories[#relation.memories + 1] = {
		kind = kind,
		trust = trust,
		grievances = grievances,
		round = state.round,
		expiresRound = duration and state.round + duration,
		explanation = explanation,
	}
	Events.notice(state, "order", nil, explanation, observer)
	-- Retain severe, lasting effects in the aggregate even if their old explanation ages out.
	while #relation.memories > 32 do
		local old = table.remove(relation.memories, 1)
		if old.expiresRound then
			relation.pendingExpiry = relation.pendingExpiry or {}
			local pending = relation.pendingExpiry[old.expiresRound]
				or { trust = 0, grievances = 0 }
			pending.trust, pending.grievances =
				pending.trust + old.trust, pending.grievances + old.grievances
			relation.pendingExpiry[old.expiresRound] = pending
		end
	end
	return true
end

function Memory.advance(state)
	for _, relation in pairs(state.diplomacy.relations) do
		for deadline, effect in pairs(relation.pendingExpiry or {}) do
			if deadline <= state.round then
				relation.trust = math.max(-200, math.min(200, relation.trust - effect.trust))
				relation.grievances = math.max(0, relation.grievances - effect.grievances)
				relation.pendingExpiry[deadline] = nil
			end
		end
		for index = #(relation.memories or {}), 1, -1 do
			local memory = relation.memories[index]
			if memory.expiresRound and memory.expiresRound <= state.round then
				relation.trust = math.max(-200, math.min(200, relation.trust - memory.trust))
				relation.grievances = math.max(0, relation.grievances - memory.grievances)
				table.remove(relation.memories, index)
			end
		end
	end
end

return Memory
