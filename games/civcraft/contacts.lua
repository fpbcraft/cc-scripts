local Events = dofile("/games/civcraft/events.lua")
local Contacts = {}
local function player(state, id)
	for _, participant in ipairs(state.players or {}) do
		if participant.id == id then
			return participant
		end
	end
end

function Contacts.knows(state, observer, subject)
	if observer == subject then
		return player(state, observer) ~= nil
	end
	local viewer = player(state, observer)
	return viewer ~= nil and (viewer.contacts or {})[subject] == true
end

function Contacts.meet(state, a, b, notices)
	if a == nil or b == nil then
		return false
	end
	local first, second = player(state, a), player(state, b)
	if not first or not second or a == b then
		return false
	end
	local changed = false
	for _, pair in ipairs({ { first, second }, { second, first } }) do
		local observer, subject = pair[1], pair[2]
		observer.contacts = observer.contacts or {}
		if not observer.contacts[subject.id] then
			observer.contacts[subject.id] = true
			changed = true
			local event = {
				type = "contact",
				recipient = observer.id,
				content = "Met " .. (subject.name or "FACTION " .. tostring(subject.id)),
			}
			if notices then
				notices[#notices + 1] = event
			else
				Events.emit(state, event)
			end
		end
	end
	return changed
end

function Contacts.observe(state, observer, notices)
	for _, entities in ipairs({ state.cities or {}, state.units or {} }) do
		for _, entity in ipairs(entities) do
			if
				entity.owner ~= observer.id
				and (observer.visible or {})[entity.x .. ":" .. entity.y]
			then
				Contacts.meet(state, observer.id, entity.owner, notices)
			end
		end
	end
end

return Contacts
