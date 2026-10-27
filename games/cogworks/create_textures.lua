-- The approved HTML art review translated to indexed CC:Graphics.
-- Actual top faces are sampled from the user-provided Create renders;
-- the small/large cogs and belt are rasterizations of the approved mockup.
local packed = require("games.cogworks.approved_atlas")
return function(R)
	local priorPiece, priorSpan, priorIcon = R.piece, R.drawSpan, R.toolIcon
	local floor, pi, sqrt = math.floor, math.pi, math.sqrt
	local atlas = {}
	-- Each pair encodes a repeat count (A=1..backtick=32) and a palette ink.
	-- '/' separates rows; '.' is transparent so the board shows through.
	for kind, frames in pairs(packed) do
		atlas[kind] = {}
		for frame, encoded in ipairs(frames) do
			local bitmap = {}
			for row in encoded:gmatch("[^/]+") do
				local pixels = {}
				local x = 1
				for i = 1, #row, 2 do
					local count = row:byte(i) - 64
					local symbol = row:sub(i + 1, i + 1)
					local ink = symbol ~= "." and tonumber(symbol, 16) or false
					for _ = 1, count do
						pixels[x] = ink
						x = x + 1
					end
				end
				assert(x == 33, "Invalid approved art row for " .. kind)
				bitmap[#bitmap + 1] = pixels
			end
			assert(#bitmap == 32, "Invalid approved art frame for " .. kind)
			atlas[kind][frame] = bitmap
		end
	end
	local scales, scaleCount = {}, 0
	local function getSpans(kind, frame, size, rotation, redstone)
		local key = table.concat({ kind, frame, size, rotation, redstone and 1 or 0 }, ":")
		if scales[key] then
			return scales[key]
		end
		local image = atlas[kind][frame]
		if not image then
			return nil
		end
		local spans = {}
		for dy = 0, size - 1 do
			local sy = floor(dy * 32 / size)
			local old, start = false, 0
			for dx = 0, size do
				local ink = false
				if dx < size then
					local sx = floor(dx * 32 / size)
					local u, v = sx, sy
					if rotation == 1 then
						u, v = sy, 31 - sx
					elseif rotation == 2 then
						u, v = 31 - sx, 31 - sy
					elseif rotation == 3 then
						u, v = 31 - sy, sx
					end
					ink = image[v + 1][u + 1]
					-- When activated, only the existing redstone channels brighten.
					if redstone and ink == 8 then
						ink = 14
					end
				end
				if ink ~= old then
					if old then
						spans[#spans + 1] = { start, dy, dx - start, old }
					end
					start, old = dx, ink
				end
			end
		end
		if scaleCount > 100 then
			scales, scaleCount = {}, 0
		end
		scales[key], scaleCount = spans, scaleCount + 1
		return spans
	end
	local function paint(self, kind, frame, x, y, size, rotation, powered)
		local spans = getSpans(kind, frame, size, rotation, powered)
		if not spans then
			return
		end
		local previousClip = self.spriteClip
		self.spriteClip = { x = floor(x), y = floor(y), size = size }
		for _, run in ipairs(spans) do
			self:rect(x + run[1], y + run[2], run[3], 1, run[4])
		end
		self.spriteClip = previousClip
	end
	local function motion(tile, light)
		if not light or not light.powered then
			return nil
		end
		return light.ports and (light.ports[tile.r] or light.ports[next(light.ports)])
			or (light.rate and light)
	end
	local function phase(self, spin)
		if not spin then
			return 0
		end
		local now = self.motionOverride or self.motionNow or 0
		return now * pi * 1.8 * math.min(8, math.max(0, spin.rate or 1)) * (spin.sign or 1)
	end
	local function spriteFrame(self, kind, spin)
		if not spin then
			return 1, 0
		end
		if kind == "G" then
			-- The small cog's wood teeth advance behind a stationary steel axle.
			local step = floor((self.motionOverride or self.motionNow or 0) * 8 * (spin.rate or 1))
				* (spin.sign or 1)
			return (step % 3) + 1, 0
		end
		if kind == "O" then
			-- Four approved frames span one quadrant; rotate the bitmap to
			-- compose 16 discrete angles without storing redundant pixel data.
			local step = floor(phase(self, spin) * 8 / pi + 0.5) % 16
			return (step % 4) + 1, floor(step / 4)
		end
		return 1, 0
	end
	local function animateBelt(self, x, y, size, tile, spin)
		if not spin then
			return
		end
		local shift = floor(phase(self, spin) * 3)
		local horizontal = (tile.r or 0) % 2 == 0
		-- The rubber surface stays fixed in the artwork, with subtle moving
		-- stitching like the sampled belt from the HTML prototype.
		for p = 4, size - 5, math.max(4, floor(size / 7)) do
			local position = 4 + ((p + shift - 4) % math.max(1, size - 8))
			if horizontal then
				self:rect(x + position, y + floor(size * 0.26), 2, 1, 13)
				self:rect(x + position, y + floor(size * 0.78), 2, 1, 4)
			else
				self:rect(x + floor(size * 0.26), y + position, 1, 2, 13)
				self:rect(x + floor(size * 0.78), y + position, 1, 2, 4)
			end
		end
	end
	function R:piece(x, y, size, tile, light)
		local kind = tile.kind
		if size < 10 or not atlas[kind] then
			return priorPiece(self, x, y, size, tile, light)
		end
		local spin = motion(tile, light)
		local frame, offset = spriteFrame(self, kind, spin)
		-- The approved small cog is horizontal in its base image, which matches
		-- shaft orientation r=1. All other base images have r=0.
		local rotation = ((tile.r or 0) + (kind == "G" and 3 or 0) + offset) % 4
		paint(
			self,
			kind,
			frame,
			x,
			y,
			size,
			rotation,
			(kind == "C" or kind == "Z") and light and light.redstone
		)
		if kind == "V" then
			animateBelt(self, x, y, size, tile, spin)
		end
	end
	function R:drawSpan(x1, y1, x2, y2, kind, powered, light)
		if kind ~= "V" or self.cell < 10 then
			return priorSpan(self, x1, y1, x2, y2, kind, powered, light)
		end
		local dx, dy = x2 - x1, y2 - y1
		local length = sqrt(dx * dx + dy * dy)
		if length < 2 then
			return
		end
		local ux, uy, nx, ny = dx / length, dy / length, -dy / length, dx / length
		-- Full-width dark rubber with continuous steel borders. The old
		-- thin neon lines were unlike the ingame mechanical belt.
		for offset = -5, 5 do
			local ink = math.abs(offset) == 5 and 4 or (math.abs(offset) == 4 and 13 or 10)
			self:line(
				floor(x1 + nx * offset + 0.5),
				floor(y1 + ny * offset + 0.5),
				floor(x2 + nx * offset + 0.5),
				floor(y2 + ny * offset + 0.5),
				ink
			)
		end
		local shift = powered and light and floor(phase(self, light) * 3) or 0
		for pos = 3, floor(length) - 3, 7 do
			local p = (pos + shift) % math.max(4, floor(length) - 4)
			if p >= 2 and p <= length - 2 then
				local cx, cy = x1 + ux * p, y1 + uy * p
				self:line(
					floor(cx - nx * 4 + 0.5),
					floor(cy - ny * 4 + 0.5),
					floor(cx + nx * 4 + 0.5),
					floor(cy + ny * 4 + 0.5),
					4
				)
				self:rect(floor(cx + nx * 5), floor(cy + ny * 5), 2, 2, 13)
			end
		end
	end
	function R:toolIcon(x, y, kind)
		if self.wide and atlas[kind] then
			-- Palette glyphs are taken from the same art as the board pieces.
			local rotation = kind == "G" and 0 or 0
			paint(self, kind, 1, x, y, 7, rotation, false)
		else
			priorIcon(self, x, y, kind)
		end
	end
end
