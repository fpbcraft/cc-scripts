-- Deterministic modifications of authored reference boards. Still never prebuilt.
return function(campaign)
  local swaps = {
    [9] = { { "T", "Q", 1 } },
    [13] = { { "T", "Q", 1 } },
    [16] = { { "G", "O", 1 } },
    [17] = { { "T", "Q", 1 } },
    [19] = { { "G", "O", 1 } },
    [20] = { { "T", "Q", 1 } },
    [22] = { { "G", "O", 1 } },
    [24] = { { "T", "Q", 1 } },
    [25] = { { "I", "V", 2 } },
    [26] = { { "G", "O", 1 } },
    [27] = { { "T", "Q", 1 }, { "I", "D", 2 } },
    [28] = { { "G", "O", 1 } },
    [29] = { { "T", "Q", 1 } },
    [30] = { { "T", "Q", 1 }, { "G", "O", 1 }, { "I", "V", 2 } },
  }
  for number, spec in pairs(swaps) do
    local stage = campaign[number]
    for _, rule in ipairs(spec) do
      local amount = rule[3]
      for _, tile in ipairs(stage.build) do
        if amount > 0 and tile.kind == rule[1] then
          tile.kind = rule[2]
          amount = amount - 1
        end
      end
      assert(amount == 0, "Upgrade failed on level " .. number)
    end
  end
  local function bridge(number, kind, a, b, m)
    local stage = campaign[number]
    local found = {}
    for i, t in ipairs(stage.build) do
      found[t.x .. "," .. t.y] = { i = i, t = t }
    end
    local x = assert(found[a[1] .. "," .. a[2]]).t
    local y = assert(found[b[1] .. "," .. b[2]]).t
    local mid = assert(found[m[1] .. "," .. m[2]])
    assert(x.kind == "I" and y.kind == "I" and mid.t.kind == "I")
    x.kind = kind
    y.kind = kind
    table.remove(stage.build, mid.i)
    stage.blocks[#stage.blocks + 1] = { m[1], m[2] }
  end
  bridge(6, "V", { 3, 3 }, { 5, 3 }, { 4, 3 })
  bridge(23, "D", { 6, 2 }, { 6, 4 }, { 6, 3 })
  local dir = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
  local shapes = { S = { 0 }, M = { 0 }, I = { 0, 2 }, L = { 0, 1 }, T = { 0, 1, 3 }, G = { 0, 2 }, B = { 0, 2 }, Q = {
    0,
    1,
    2,
    3,
  }, O = {
    0,
    2,
  }, V = {
    0,
    2,
  }, D = {
    0,
    2,
  } }
  local function port(t, d)
    for _, p in ipairs(shapes[t.kind] or {}) do
      if (p + t.r) % 4 == d then
        return true
      end
    end
    return false
  end
  local function prepare(stage)
    local map = {}
    local tiles = { stage.source }
    for _, v in ipairs(stage.build) do
      tiles[#tiles + 1] = v
    end
    for _, v in ipairs(stage.goals) do
      tiles[#tiles + 1] = v
    end
    for _, v in ipairs(tiles) do
      map[v.x .. "," .. v.y] = v
    end
    local function connect(t, d)
      if not port(t, d) then
        return nil
      end
      local dx, dy = dir[d + 1][1], dir[d + 1][2]
      local found = map[(t.x + dx) .. "," .. (t.y + dy)]
      if found and port(found, (d + 2) % 4) then
        return found
      end
      if t.kind ~= "V" and t.kind ~= "D" then
        return nil
      end
      local max = t.kind == "V" and 3 or 4
      for distance = 2, max do
        local x, y = t.x + dx * distance, t.y + dy * distance
        if x < 1 or y < 1 or x > 7 or y > 6 then
          return nil
        end
        found = map[x .. "," .. y]
        if found then
          if found.kind == t.kind and port(found, (d + 2) % 4) then
            return found
          end
          return nil
        end
      end
    end
    -- Find input side of every large cog before propagation.
    local seen = { [stage.source] = true }
    local queue = { stage.source }
    local first = 1
    while first <= #queue do
      local t = queue[first]
      first = first + 1
      for d = 0, 3 do
        local next = connect(t, d)
        if next and not seen[next] then
          seen[next] = true
          if next.kind == "O" then
            next.r = (d + 2) % 4
          end
          queue[#queue + 1] = next
        end
      end
    end
    local slots = {}
    local pending = { { t = stage.source, d = stage.source.r, rate = 1, sign = 1 } }
    first = 1
    while first <= #pending do
      local entry = pending[first]
      first = first + 1
      local t = entry.t
      if not slots[t] then
        slots[t] = {}
      end
      if not slots[t][entry.d] then
        slots[t][entry.d] = { rate = entry.rate, sign = entry.sign }
        for d = 0, 3 do
          if d ~= entry.d and port(t, d) then
            local rate, sign = entry.rate, entry.sign
            if t.kind == "G" then
              sign = -sign
            end
            if t.kind == "O" then
              sign = -sign
              rate = rate * ((entry.d - t.r) % 4 == 0 and 2 or 0.5)
            elseif t.kind == "B" then
              rate = rate * ((entry.d - t.r) % 4 == 0 and 2 or 0.5)
            end
            pending[#pending + 1] = { t = t, d = d, rate = rate, sign = sign }
          end
        end
        local target = connect(t, entry.d)
        if target then
          pending[#pending + 1] = { t = target, d = (entry.d + 2) % 4, rate = entry.rate, sign = entry.sign }
        end
      end
    end
    for _, goal in ipairs(stage.goals) do
      local state = slots[goal] and slots[goal][goal.r]
      assert(state, "Unpowered authored goal on " .. stage.name)
      goal.speed = state.rate
      goal.sign = state.sign
    end
  end
  for i, stage in ipairs(campaign) do
    if i >= 4 then
      prepare(stage)
    end
    stage.stock = {}
    for _, tile in ipairs(stage.build) do
      stage.stock[tile.kind] = (stage.stock[tile.kind] or 0) + 1
    end
  end
  return campaign
end
