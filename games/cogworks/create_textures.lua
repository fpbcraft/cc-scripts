-- Orthographic Create-inspired top faces for Cogworks' high-resolution renderer.
-- The references are Minecraft's wood/andesite/redstone mechanisms, but all
-- artwork remains native, self-contained CC:Graphics (16 palette colors).
return function(R)
  local priorPiece, priorSpan, priorIcon = R.piece, R.drawSpan, R.toolIcon
  local pi, sin, cos, floor = math.pi, math.sin, math.cos, math.floor
  local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
  end
  local function phase(self, spin)
    if not spin or not spin.sign or spin.sign == 0 then
      return 0
    end
    return (self.motionOverride or self.motionNow or 0) * pi * 1.8 * clamp(spin.rate or 1, 0, 8) * spin.sign
  end
  -- The top of a Create gearbox/gearshift/clutch is WOOD, with inset dark
  -- joinery, redstone routes and an outer andesite rim. In particular, the
  -- shaft is on the side face: there is no giant shaft painted on the lid.
  -- Here u/v are coordinates in a 16x16 pixel texture, rotated with the part.
  local function pixel(kind, u, v, powered, tick)
    local frame = u == 0 or v == 0 or u == 15 or v == 15
    if frame then
      return (u + v) % 3 == 0 and 13 or 4
    end
    if (u == 1 or u == 14) and (v == 1 or v == 14) then
      return 15 -- steel corner rivets
    end
    if u == 1 or v == 1 or u == 14 or v == 14 then
      return 13
    end
    local grain = (u * 3 + floor(v / 2) * 5) % 11
    local wood = grain < 2 and 6 or (grain < 4 and 10 or 7)
    if kind == "Q" then
      -- Gearbox: full wooden lid with a dark lengthwise joinery strip.
      if (u == 5 or u == 10) and v >= 3 and v <= 12 then
        return 10
      end
      if u >= 6 and u <= 9 then
        return (u + v) % 4 == 0 and 10 or 7
      end
      if v == 5 or v == 10 then
        return (u % 4 < 2) and 6 or 7
      end
    elseif kind == "Z" then
      -- Gearshift: redstone crosses the lid beneath two raised wood slats.
      if (u == 4 or u == 5 or v == 4 or v == 5)
        or (u == 11 or v == 11) and (u < 5 or v < 5)
      then
        return powered and 14 or 8
      end
      if (u >= 6 and u <= 9 and v >= 3 and v <= 12)
        or (v == 8 or v == 9) and u >= 3 and u <= 12
      then
        return (u + v) % 4 == 0 and 6 or 7
      end
    elseif kind == "C" then
      -- Clutch: parallel redstone bus strips flank a timber coupling.
      if u == 3 or u == 4 or u == 11 or u == 12 then
        return powered and 14 or 8
      end
      if u >= 5 and u <= 10 then
        if v == 4 or v == 11 then
          return 10
        end
        return ((v + floor(u / 3)) % 5 == 0) and 6 or 7
      end
    elseif kind == "D" then
      -- Encased chain drive: compact dark interlocked chain run and
      -- bright, bolted andesite edges in a wood casing.
      if u == 2 or u == 13 then
        return 4
      end
      if u >= 5 and u <= 10 then
        if (v + tick) % 4 < 2 then
          return (u + v + tick) % 3 == 0 and 13 or 10
        end
        return (u + v) % 3 == 0 and 4 or 1
      end
      if u == 4 or u == 11 then
        return 10
      end
    end
    return wood
  end
  local function topFace(self, x, y, size, tile, powered, spin)
    local quarter = (tile.r or 0) % 4
    local turn = floor(phase(self, spin) * 2 / pi)
    -- Rasterize continuous runs, not hundreds of one-pixel peripheral calls.
    for v = 0, 15 do
      local sy = floor(v * size / 16)
      local height = floor((v + 1) * size / 16) - sy
      if height > 0 then
        local previous, start = nil, 0
        for u = 0, 16 do
          local ink
          if u < 16 then
            local tx, ty = u, v
            if quarter == 1 then
              tx, ty = 15 - v, u
            elseif quarter == 2 then
              tx, ty = 15 - u, 15 - v
            elseif quarter == 3 then
              tx, ty = v, 15 - u
            end
            ink = pixel(tile.kind, tx, ty, powered, turn)
          end
          if ink ~= previous then
            if previous then
              local x1 = floor(start * size / 16)
              local x2 = floor(u * size / 16)
              if x2 > x1 then
                self:rect(x + x1, y + sy, x2 - x1, height, previous)
              end
            end
            start, previous = u, ink
          end
        end
      end
    end
  end
  -- A small Create cog's shaft is horizontal/vertical in the board plane.
  -- Its wheel is perpendicular to that shaft, so it is seen EDGE-ON from
  -- above. It must not look like the circular, face-on large wheel.
  local function sideCog(self, x, y, size, tile, spin)
    local horizontal = (tile.r or 0) % 2 == 1
    local function part(u, v, w, h, ink)
      if horizontal then
        self:rect(x + u, y + v, w, h, ink)
      else
        self:rect(x + v, y + u, h, w, ink)
      end
    end
    local mid = floor(size / 2)
    local shaftWidth = math.max(2, floor(size / 5))
    local thickness = math.max(4, floor(size * 0.32))
    local rimStart = floor((size - thickness) / 2)
    local tick = floor(phase(self, spin) * 4 / pi)
    -- The steel axle runs through the wooden cog wheel.
    part(0, mid - floor(shaftWidth / 2), size, shaftWidth, 4)
    part(1, mid - floor(shaftWidth / 2), size - 2, math.max(1, shaftWidth - 1), 13)
    part(0, mid - floor(shaftWidth / 2), 2, shaftWidth, 4)
    part(size - 2, mid - floor(shaftWidth / 2), 2, shaftWidth, 4)
    -- Dark wood walls and raised rim, spanning almost the entire tile.
    part(rimStart, 2, thickness, size - 4, 10)
    part(rimStart + 1, 1, math.max(2, thickness - 2), size - 2, 7)
    part(rimStart + 1, 2, math.max(1, thickness - 3), size - 4, 6)
    part(rimStart + thickness - 2, 2, 1, size - 4, 10)
    local pitch = math.max(3, floor(size / 6))
    for v = 2, size - 3, pitch do
      local color = (floor(v / pitch) + tick) % 3 == 0 and 6 or 7
      part(rimStart - 2, v, 3, math.max(2, floor(pitch / 2)), color)
      part(rimStart + thickness - 1, v, 3, math.max(2, floor(pitch / 2)), color)
      part(rimStart + 1, v, thickness - 2, 1, (floor(v / pitch) + tick) % 2 == 0 and 10 or 6)
    end
    -- Small bright metal hub at the intersection, not a circular gear face.
    part(rimStart + 1, mid - 2, thickness - 2, 4, 4)
    part(rimStart + 2, mid - 1, math.max(1, thickness - 4), 2, 13)
    if spin then
      part(rimStart + 1, 2 + (tick % math.max(1, size - 7)), 1, 2, spin.sign > 0 and 11 or 14)
    end
  end
  local function beltPulley(self, x, y, size, tile, spin)
    local mid, horizontal = floor(size / 2), (tile.r or 0) % 2 == 1
    self:rect(x, y, size, size, 4)
    self:rect(x + 1, y + 1, size - 2, size - 2, 13)
    self:rect(x + 2, y + 2, size - 4, size - 4, 10)
    if horizontal then
      self:rect(x + 2, y + 4, size - 4, size - 8, 1)
      self:rect(x + 2, y + 5, size - 4, 1, 4)
      self:rect(x + 2, y + size - 6, size - 4, 1, 7)
    else
      self:rect(x + 4, y + 2, size - 8, size - 4, 1)
      self:rect(x + 5, y + 2, 1, size - 4, 4)
      self:rect(x + size - 6, y + 2, 1, size - 4, 7)
    end
    local turn = floor(phase(self, spin) * 3 / pi)
    for i = 3, size - 4, 4 do
      local color = (i + turn) % 3 == 0 and 13 or 7
      if horizontal then
        self:rect(x + i, y + floor(size / 2) - 2, 1, 4, color)
      else
        self:rect(x + floor(size / 2) - 2, y + i, 4, 1, color)
      end
    end
    self:rect(x + mid - 2, y + mid - 2, 5, 5, 4)
    self:rect(x + mid - 1, y + mid - 1, 3, 3, 13)
  end
  function R:piece(x, y, size, tile, light)
    if size < 12 or not ({ G = true, Q = true, D = true, C = true, Z = true, V = true })[tile.kind] then
      return priorPiece(self, x, y, size, tile, light)
    end
    local spin
    if light and light.powered then
      spin = light.ports and (light.ports[tile.r] or light.ports[next(light.ports)])
        or (light.rate and light)
    end
    -- Create_art's tile clipping still applies: this override lives inside it.
    if tile.kind == "G" then
      sideCog(self, x, y, size, tile, spin)
    elseif tile.kind == "V" then
      beltPulley(self, x, y, size, tile, spin)
    else
      topFace(self, x, y, size, tile, light and light.redstone, spin)
    end
  end
  function R:drawSpan(x1, y1, x2, y2, kind, powered, motion)
    if kind ~= "V" or self.cell < 12 then
      return priorSpan(self, x1, y1, x2, y2, kind, powered, motion)
    end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 2 then
      return
    end
    local ux, uy = dx / length, dy / length
    local nx, ny = -uy, ux
    local function stroke(offset, ink)
      self:line(
        floor(x1 + nx * offset + 0.5), floor(y1 + ny * offset + 0.5),
        floor(x2 + nx * offset + 0.5), floor(y2 + ny * offset + 0.5), ink
      )
    end
    -- Belt body is continuous dark rubber framed by gray mechanical edging.
    -- Visible moving diagonal ridges imitate the in-game conveyor texture.
    for offset = -4, 4 do
      stroke(offset, math.abs(offset) == 4 and 13 or (math.abs(offset) == 3 and 4 or 10))
    end
    local shift = powered and motion and phase(self, motion) * 3 or 0
    for distance = 2, floor(length) - 2, 4 do
      local pos = (distance + shift) % math.max(4, length - 3)
      if pos >= 1 and pos <= length - 2 then
        local px, py = x1 + ux * pos, y1 + uy * pos
        self:line(
          floor(px - nx * 2 + 0.5), floor(py - ny * 2 + 0.5),
          floor(px + nx * 2 + ux + 0.5), floor(py + ny * 2 + uy + 0.5),
          (distance % 8 == 0) and 7 or 4
        )
      end
    end
    stroke(-5, 4)
    stroke(5, 4)
  end
  function R:toolIcon(x, y, kind)
    if kind == "G" and self.wide then
      self:rect(x, y + 3, 7, 2, 13) -- axle
      self:rect(x + 2, y, 3, 7, 7) -- wheel edge, perpendicular to axle
      self:rect(x + 3, y + 1, 1, 5, 6)
      self:rect(x + 1, y + 1, 1, 2, 7)
      self:rect(x + 5, y + 4, 1, 2, 7)
    elseif (kind == "Q" or kind == "C" or kind == "Z" or kind == "D") and self.wide then
      topFace(self, x, y, 7, { kind = kind, r = 0 }, false, nil)
    else
      priorIcon(self, x, y, kind)
    end
  end
end
