-- Original note sequences; no downloaded audio assets or blocking playback loops.
local A = {}
A.__index = A
local melody = { 12, 16, 19, 16, 14, 17, 21, 17, 12, 19, 24, 19, 11, 14, 19, 14 }
local effects = {
	click = { 12 },
	move = { 14, 19 },
	build = { 12, 16 },
	research = { 16, 21 },
	turn = { 12, 19 },
	error = { 6 },
}
function A.new()
	local self = setmetatable({ enabled = true, music = true, volume = 1, step = 1 }, A)
	for _, name in ipairs(peripheral.getNames()) do
		if peripheral.getType(name) == "speaker" then
			self.speaker = peripheral.wrap(name)
			break
		end
	end
	local path = "/games/civcraft/data/audio.dat"
	if fs and fs.exists(path) then
		local file = fs.open(path, "r")
		if file then
			local saved = textutils.unserialize(file.readAll())
			file.close()
			if type(saved) == "table" then
				self.enabled = saved.enabled ~= false
				self.music = saved.music ~= false
				if type(saved.volume) == "number" and saved.volume > 0 and saved.volume <= 1 then
					self.volume = saved.volume
				end
			end
		end
	end
	return self
end
function A:note(instrument, note, volume)
	if self.enabled and self.speaker and self.speaker.playNote then
		pcall(self.speaker.playNote, instrument, math.min(3, (volume or 0.3) * self.volume), note)
	end
end
function A:effect(name)
	for _, note in ipairs(effects[name] or effects.click) do
		self:note(name == "error" and "bass" or "harp", note, 0.45)
	end
end
function A:update(screen)
	if screen == "title" and self.enabled and self.music and self.speaker and os.startTimer then
		self:note("harp", melody[self.step], 0.22)
		if self.step % 4 == 1 then
			self:note("bass", math.max(0, melody[self.step] - 12), 0.18)
		end
		self.step = self.step % #melody + 1
		self.timer = os.startTimer(0.38)
	else
		self.timer = nil
	end
end
function A:save()
	local path = "/games/civcraft/data"
	if not fs.exists(path) then
		fs.makeDir(path)
	end
	local file = fs.open(path .. "/audio.dat", "w")
	if file then
		file.write(
			textutils.serialize({ enabled = self.enabled, music = self.music, volume = self.volume })
		)
		file.close()
	end
end
function A:toggle(screen)
	self.enabled = not self.enabled
	self:save()
	self:update(screen)
	return self.enabled
end
function A:toggleMusic(screen)
	self.music = not self.music
	self:save()
	self:update(screen)
end
function A:cycleVolume(screen)
	self.volume = self.volume <= 0.5 and 0.7 or self.volume <= 0.85 and 1 or 0.35
	self:save()
	self:update(screen)
end
return A
