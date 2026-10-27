-- Optional Opus Overview integration. Never modify Opus's own system apps.db.
local O = {}
local REGISTRY = "/usr/.registry"
local SHORTCUTS = "/apps/fpbstore/shortcuts"

function O.available()
	return fs.exists("/sys/apps/Overview.lua") and not fs.isDir("/sys/apps/Overview.lua")
end

local function write(path, value)
	fs.makeDir(fs.getDir(path))
	local h = assert(fs.open(path, "w"))
	h.write(value)
	h.close()
end

local function shortcut(id)
	assert(id:match("^[%w_-]+$"), "Invalid shortcut ID")
	return SHORTCUTS .. "/" .. id .. ".lua"
end

function O.sync(apps, installed, prefs)
	if not O.available() then
		return false
	end
	fs.makeDir(REGISTRY)
	if prefs.opusStore == false then
		if fs.exists(REGISTRY .. "/fpbstore-store") then
			fs.delete(REGISTRY .. "/fpbstore-store")
		end
	else
		write(
			REGISTRY .. "/fpbstore-store",
			textutils.serialize({
				key = "fpbstore-store",
				title = "FPB Store",
				category = "Apps",
				run = "/apps/fpbstore/main.lua",
			})
		)
	end
	for _, app in ipairs(apps) do
		local id = app.id
		local reg = REGISTRY .. "/fpbstore-" .. id
		local entry = shortcut(id)
		if
			prefs.opusApps ~= false
			and (not prefs.opusShortcuts or prefs.opusShortcuts[id] ~= false)
			and installed(app)
		then
			write(
				entry,
				'return dofile("/apps/fpbstore/launch.lua")(' .. string.format("%q", id) .. ")\n"
			)
			write(
				reg,
				textutils.serialize({
					key = "fpbstore-" .. id,
					title = app.name,
					category = app.category or "Games",
					run = entry,
				})
			)
		else
			if fs.exists(reg) then
				fs.delete(reg)
			end
			if fs.exists(entry) then
				fs.delete(entry)
			end
		end
	end
	if os.queueEvent then
		os.queueEvent("overview_refresh")
	end
	return true
end

return O
