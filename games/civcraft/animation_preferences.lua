-- Device preferences stay separate from campaign saves and audio settings.
local Preferences = {}
local path = "/games/civcraft/data/animations.dat"

function Preferences.load()
	local result = { speed = "normal", reducedMotion = false, display = "auto" }
	if not (fs and textutils and fs.exists(path)) then
		return result
	end
	local file = fs.open(path, "r")
	if not file then
		return result
	end
	local ok, saved = pcall(function()
		return textutils.unserialize(file.readAll())
	end)
	file.close()
	if ok and type(saved) == "table" then
		if saved.speed == "normal" or saved.speed == "fast" or saved.speed == "off" then
			result.speed = saved.speed
		end
		result.reducedMotion = saved.reducedMotion == true
		result.display = saved.display == "text" and "text" or "auto"
	end
	return result
end

function Preferences.save(preferences)
	if not (fs and textutils) then
		return
	end
	fs.makeDir("/games/civcraft/data")
	local file = fs.open(path, "w")
	if file then
		file.write(textutils.serialize(preferences))
		file.close()
	end
end

return Preferences
