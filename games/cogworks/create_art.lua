-- Create-inspired, resolution-aware kinetic artwork.
-- All drawing is native indexed CC:Graphics; no external image assets or
-- texture pack is required. The compact renderer remains unchanged.
local E = require("games.cogworks.engine")
return function(R)
  local original = {
    piece = R.piece,
    redstonePiece = R.redstonePiece,
    drawSpan = R.drawSpan,
    toolIcon = R.toolIcon,
  }
  local pi, sin, cos = math.pi, math.sin, math.cos
  local function nearest(value)
    return math.floor(value + 0.5)
  end
  local function limit(value, low, high)
    return math.max(low, math.min(high, value))
  end
  local function motion(tile, light)
    if not light or not light.powered then
      return nil
    end
    return light.ports and (light.ports[tile.r] or light.ports[next(light.ports)])
      or (light.rate and { sign = light.sign, rate = light.rate })
  end
  local function phase(self, spin)
    if not spin then
      return 0
    end
    -- A one-speed shaft makes 0.9 visual revolutions per second. This is
    -- intentionally more lively than the old ~5fps index-tooth animation;
    -- 2X runs twice as quickly, 0.5X runs at half speed, and negative signs
    -- reverse everything, including the opposing strands of a belt.
    local now = self.motionOverride or self.motionNow or 0
    return now * (pi * 1.8) * limit(spin.rate or 1, 0, 8) * (spin.sign or 1)
  end
  local function ring(self, cx, cy, radius, color, angle, points, step)
    points = points or 32
    step = step or 1
    local lastX, lastY
    for i = 0, points do
      local theta = i / points * pi * 2 + (angle or 0)
      local x, y = nearest(cx + cos(theta) * radius), nearest(cy + sin(theta) * radius)
      if lastX and (x ~= lastX or y ~= lastY) then
        self:line(lastX, lastY, x, y, color)
      end
      lastX, lastY = x, y
    end
  end
  local function bolt(self, x, y)
    self:rect(x, y, 2, 2, 7)
    self:rect(x, y, 1, 1, 15)
  end
  local function casing(self, x, y, size, brass)
    local frame = brass and 7 or 4
    local trim = brass and 6 or 13
    self:rect(x + 1, y + 1, size - 2, size - 2, frame)
    self:rect(x + 2, y + 2, size - 4, size - 4, trim)
    self:rect(x + 3, y + 3, size - 6, size - 6, 2)
    self:rect(x + 4, y + 4, size - 8, size - 8, 1)
    bolt(self, x + 2, y + 2)
    bolt(self, x + size - 4, y + 2)
    bolt(self, x + 2, y + size - 4)
    bolt(self, x + size - 4, y + size - 4)
  end
  local function hub(self, cx, cy, size)
    local d = limit(math.floor(size / 6), 3, 6)
    local left = cx - math.floor(d / 2)
    local top = cy - math.floor(d / 2)
    self:rect(left - 1, top - 1, d + 2, d + 2, 7)
    self:rect(left, top, d, d, 13)
    self:rect(cx, cy, 1, 1, 1)
    self:rect(left + 1, top, 1, 1, 15)
  end
  local function cog(self, cx, cy, radius, large, spin)
    local angle = phase(self, spin)
    -- Create's wood-toothed wheels have two distinct silhouettes: the small
    -- solid pinion and the large open-spoked wheel. Gold represents wood
    -- highlights, with darker wood shadows and an andesite shaft hub.
    local count = large and 12 or 8
    local tooth = radius >= 8 and 3 or 2
    local interior = large and math.max(3, radius - 4) or math.max(2, radius - 3)
    ring(self, cx + 1, cy + 1, radius - 1, 7, angle, radius * 8)
    ring(self, cx, cy, radius - 1, 6, angle, radius * 8)
    ring(self, cx, cy, radius - 2, 7, angle, radius * 8)
    if large then
      -- Negative-space spokes let the background show through the gear,
      -- which makes big wheels unmistakable even from a distance.
      ring(self, cx, cy, interior, 7, angle, radius * 6)
      for spoke = 0, 5 do
        local theta = angle + spoke * pi / 3
        local dx, dy = cos(theta), sin(theta)
        self:line(cx, cy, nearest(cx + dx * (radius - 3)), nearest(cy + dy * (radius - 3)), 7)
        self:line(
          nearest(cx + dx * 2),
          nearest(cy + dy * 2),
          nearest(cx + dx * (radius - 4)),
          nearest(cy + dy * (radius - 4)),
          6
        )
      end
    else
      for spoke = 0, 3 do
        local theta = angle + spoke * pi / 2
        self:line(cx, cy, nearest(cx + cos(theta) * (radius - 2)), nearest(cy + sin(theta) * (radius - 2)), 7)
      end
      ring(self, cx, cy, interior, 6, angle, radius * 6)
    end
    for index = 0, count - 1 do
      local theta = angle + index * pi * 2 / count
      local tx = nearest(cx + cos(theta) * radius) - math.floor(tooth / 2)
      local ty = nearest(cy + sin(theta) * radius) - math.floor(tooth / 2)
      local ink = index == 0 and spin and 15 or (index % 3 == 0 and 7 or 6)
      self:rect(tx, ty, tooth, tooth, ink)
    end
    hub(self, cx, cy, radius * 2)
    if spin then
      local theta = angle + pi / 4
      self:rect(
        nearest(cx + cos(theta) * (radius - 3)),
        nearest(cy + sin(theta) * (radius - 3)),
        2,
        2,
        spin.sign > 0 and 11 or 14
      )
    end
  end
  local function shaft(self, x, y, size, tile, spin)
    local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
    local horizontal = tile.r % 2 == 1
    local length = math.max(4, size - 4)
    local width = limit(math.floor(size / 5), 3, 6)
    local majorX = horizontal and x + 2 or cx - math.floor(width / 2)
    local majorY = horizontal and cy - math.floor(width / 2) or y + 2
    self:rect(majorX, majorY, horizontal and length or width, horizontal and width or length, 7)
    self:rect(
      majorX + (horizontal and 0 or 1),
      majorY + (horizontal and 1 or 0),
      horizontal and length or width - 2,
      horizontal and width - 2 or length,
      13
    )
    local shine = spin and (nearest((sin(phase(self, spin)) + 1) * (width - 1) / 2)) or 1
    if horizontal then
      self:rect(majorX, majorY + shine, length, 1, spin and 15 or 4)
      self:rect(majorX, majorY, 2, width, 4)
      self:rect(majorX + length - 2, majorY, 2, width, 4)
      self:rect(majorX + 1, majorY + width - 1, 1, 1, 6)
    else
      self:rect(majorX + shine, majorY, 1, length, spin and 15 or 4)
      self:rect(majorX, majorY, width, 2, 4)
      self:rect(majorX, majorY + length - 2, width, 2, 4)
      self:rect(majorX + width - 1, majorY + 1, 1, 1, 6)
    end
    hub(self, cx, cy, size)
  end
  local function pulley(self, cx, cy, radius, spin, chain)
    local angle = phase(self, spin)
    local n = chain and 8 or 12
    ring(self, cx, cy, radius, chain and 13 or 7, angle, radius * 8)
    ring(self, cx, cy, radius - 1, chain and 4 or 6, angle, radius * 8)
    ring(self, cx, cy, math.max(2, radius - 3), 7, angle, radius * 6)
    for i = 0, n - 1 do
      local theta = angle + pi * 2 * i / n
      local r = radius - 2
      self:rect(nearest(cx + cos(theta) * r), nearest(cy + sin(theta) * r), 1, 1, i == 0 and spin and 15 or 13)
    end
    hub(self, cx, cy, radius * 2)
  end
  local function redstone(self, g, tile, result, x, y, size)
    local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
    local lit = result.redstone and result.redstone[tile.id]
    if tile.kind == "B" then
      casing(self, x, y, size, false)
      self:rect(x + 4, y + 4, size - 8, size - 8, 8)
      self:rect(x + 6, y + 6, size - 12, size - 12, lit and 14 or 7)
      self:rect(cx - 2, cy - 2, 5, 5, 8)
      hub(self, cx, cy, size)
      return
    end
    -- Dust branches follow the actual wiring solver, not a decorative cross.
    local connects = E.wireConnections(g, tile)
    local shade = lit and 8 or 7
    local glow = lit and 14 or 4
    for i, offset in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
      if connects[i] then
        local x2 = cx + offset[1] * math.floor(size / 2)
        local y2 = cy + offset[2] * math.floor(size / 2)
        self:line(cx + 1, cy + 1, x2 + 1, y2 + 1, shade)
        self:line(cx, cy, x2, y2, glow)
      end
    end
    self:rect(cx - 2, cy - 2, 5, 5, shade)
    self:rect(cx - 1, cy - 1, 3, 3, glow)
    self:rect(cx, cy, 1, 1, lit and 15 or 8)
  end
  function R:redstonePiece(g, tile, result, x, y, size)
    if not self.wide or size < 16 then
      return original.redstonePiece(self, g, tile, result, x, y, size)
    end
    return redstone(self, g, tile, result, x, y, size)
  end
  function R:piece(x, y, size, tile, light)
    if not self.wide or size < 16 then
      return original.piece(self, x, y, size, tile, light)
    end
    local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
    local spin = motion(tile, light)
    local kind = tile.kind
    if kind == "X" then
      casing(self, x, y, size, false)
      self:rect(x + 5, y + 5, size - 10, size - 10, 4)
      for i = 6, size - 6, 5 do
        self:rect(x + i, y + 5 + i % 3, 3, 1, 13)
      end
    elseif kind == "I" then
      shaft(self, x, y, size, tile, spin)
    elseif kind == "G" or kind == "O" then
      local radius = math.floor(size / 2) - 3
      if kind == "G" then
        radius = math.max(5, math.floor(size * 0.32))
      end
      cog(self, cx, cy, radius, kind == "O", spin)
    elseif kind == "S" then
      casing(self, x, y, size, true)
      self:rect(x + 5, y + 5, size - 10, size - 10, 10)
      self:rect(cx - 4, cy - 4, 9, 9, 7)
      hub(self, cx, cy, size)
      self:fontFit(x + 4, y + size - 10, "MTR", 15, size - 8)
    elseif kind == "M" then
      casing(self, x, y, size, false)
      local correct = light and light.correct
      self:rect(x + 4, y + 4, size - 8, size - 8, correct and 10 or 2)
      local stroke = math.max(2, math.floor(size / 5))
      local travel = correct and nearest((sin((self.motionNow or 0) * 6) + 1) * 2) or 0
      self:rect(cx - stroke, cy - 3 + travel, stroke * 2 + 1, 5, 13)
      self:rect(cx - 2, cy + 3 + travel, 5, 2, 6)
      self:fontFit(x + 4, y + size - 8, (tile.sign == 1 and ">" or "<") .. tostring(tile.speed) .. "X", 15, size - 7)
    elseif kind == "Q" then
      casing(self, x, y, size, false)
      cog(self, cx, cy, math.max(5, math.floor(size / 4)), false, spin)
      self:rect(cx - 1, y + 3, 3, 2, 6)
      self:rect(x + size - 5, cy - 1, 2, 3, 6)
    elseif kind == "D" then
      casing(self, x, y, size, false)
      local rail = math.floor(size / 2) - 4
      local horizontal = tile.r % 2 == 1
      for i = -rail, rail, 4 do
        if horizontal then
          self:rect(cx + i, cy - 2, 2, 5, 13)
        else
          self:rect(cx - 2, cy + i, 5, 2, 13)
        end
      end
      pulley(self, cx, cy, math.floor(size / 3), spin, true)
    elseif kind == "V" then
      self:rect(x + 2, y + 2, size - 4, size - 4, 7)
      self:rect(x + 4, y + 4, size - 8, size - 8, 1)
      pulley(self, cx, cy, math.floor(size / 2) - 5, spin, false)
    elseif kind == "C" or kind == "Z" then
      casing(self, x, y, size, false)
      local redstone = light and light.redstone
      local engaged = kind == "C" and not redstone or redstone
      local highlight = redstone and 8 or 6
      shaft(self, x + 2, y + 2, size - 4, tile, spin)
      local gap = engaged and 0 or 2
      self:rect(cx - 4 - gap, cy - 4, 3, 9, 13)
      self:rect(cx + 2 + gap, cy - 4, 3, 9, 13)
      self:rect(cx - 1, cy - 5, 3, 11, highlight)
      if kind == "Z" then
        self:fontFit(x + 3, y + 4, redstone and "<" or ">", highlight, size - 6)
      end
    else
      return original.piece(self, x, y, size, tile, light)
    end
    if spin then
      self:rect(x + 1, y + size - 4, 3, 3, spin.sign > 0 and 11 or 14)
    end
  end
  function R:drawSpan(x1, y1, x2, y2, kind, powered, light)
    if not self.wide or self.cell < 16 then
      return original.drawSpan(self, x1, y1, x2, y2, kind, powered, light)
    end
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 1 then
      return
    end
    local ux, uy = dx / distance, dy / distance
    local nx, ny = -uy, ux
    local span = kind == "V" and 3 or 4
    local edge = kind == "V" and 7 or 4
    for side = -1, 1, 2 do
      self:line(
        nearest(x1 + nx * side * span),
        nearest(y1 + ny * side * span),
        nearest(x2 + nx * side * span),
        nearest(y2 + ny * side * span),
        edge
      )
    end
    local cycle = kind == "V" and 7 or 5
    local shift = powered and light and phase(self, light) * cycle / pi or 0
    for pos = 0, math.floor(distance), 2 do
      local middleX, middleY = x1 + ux * pos, y1 + uy * pos
      local tick = math.floor((pos + shift) / cycle)
      if kind == "D" then
        if tick % 2 == 0 then
          self:line(
            nearest(middleX + nx * 3),
            nearest(middleY + ny * 3),
            nearest(middleX - nx * 3),
            nearest(middleY - ny * 3),
            13
          )
        end
      elseif (pos + shift) % cycle < 2 then
        for side = -1, 1, 2 do
          local accent = side < 0 and 15 or 6
          self:rect(nearest(middleX + nx * side * span), nearest(middleY + ny * side * span), 1, 1, accent)
        end
      end
    end
  end
  function R:toolIcon(x, y, kind)
    if not self.wide then
      return original.toolIcon(self, x, y, kind)
    end
    if kind == "G" or kind == "O" then
      self:rect(x + 1, y + 1, 5, 5, 7)
      self:rect(x + 2, y + 2, 3, 3, kind == "O" and 2 or 6)
      for _, t in ipairs({ { 3, 0 }, { 6, 3 }, { 3, 6 }, { 0, 3 } }) do
        self:rect(x + t[1], y + t[2], 1, 1, 6)
      end
      self:rect(x + 3, y + 3, 1, 1, 13)
    elseif kind == "I" then
      self:rect(x + 2, y, 3, 7, 4)
      self:rect(x + 3, y, 1, 7, 15)
      self:rect(x + 1, y + 2, 5, 1, 7)
      self:rect(x + 1, y + 5, 5, 1, 7)
    elseif kind == "Q" or kind == "C" or kind == "Z" or kind == "D" then
      self:rect(x, y, 7, 7, 4)
      self:rect(x + 1, y + 1, 5, 5, 13)
      self:rect(x + 2, y + 2, 3, 3, 2)
      self:rect(x + 3, y + 3, 1, 1, kind == "C" and 8 or 6)
    elseif kind == "V" then
      self:rect(x + 1, y + 1, 5, 5, 7)
      self:rect(x + 2, y + 2, 3, 3, 2)
      self:rect(x + 2, y + 1, 1, 1, 6)
      self:rect(x + 4, y + 5, 1, 1, 6)
    elseif kind == "R" then
      self:rect(x + 3, y, 1, 7, 8)
      self:rect(x, y + 3, 7, 1, 14)
      self:rect(x + 2, y + 2, 3, 3, 8)
    elseif kind == "B" then
      self:rect(x, y, 7, 7, 7)
      self:rect(x + 1, y + 1, 5, 5, 8)
      self:rect(x + 2, y + 2, 3, 3, 14)
    end
  end
end
