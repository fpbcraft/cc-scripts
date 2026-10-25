-- Content-derived entries stay in sync with the simulation's costs and unlocks.
local Systems = dofile("/games/civcraft/systems.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local E = {}
local mechanics = {
  {
    id = "turns",
    name = "TURNS AND VICTORY",
    text = "Issue orders, then end your turn. Production, research and movement reset after every player is ready. New campaigns: conquer all rival capitals, sustain three industrial cities connected by rail for ten rounds, or complete the three End expedition projects. Score decides after round 180. Simultaneous qualifiers share victory. Legacy campaigns keep eight cities / round 90 rules.",
  },
  {
    id = "population",
    name = "POPULATION AND JOBS",
    text = "Jobs and worked hexes share one population pool. Minus unworks a tile of that type. Plus assigns an idle citizen to an available owned tile of that type. Food, industry and science jobs follow the tile's strongest yield. No free matching tile means no new assignment. Population grows from surplus food.",
  },
  {
    id = "tiles",
    name = "WORKED HEXES",
    text = "A city works its center automatically. Each additional citizen can work one owned hex within three steps. Gold-framed worker badges mark staffed hexes. Open TILES and tap a worked hex to unassign it, or an available hex to work it. The JOBS controls automatically choose tiles; TILES lets you pick them manually. Both change the same assignments.",
  },
  {
    id = "territory",
    name = "CITY TERRITORY",
    text = "Cities receive a short name from a civilization-themed pool, displayed above the city and retained in saves. New cities claim their center and six neighboring hexes. Borders then acquire one adjacent unclaimed hex at a time, up to three hexes away. Border growth takes 6 plus one turn per four claimed tiles. Population no longer claims entire rings. The nearest city claims each hex, with stable ties. Borders trace the actual sides of hexes. A new city must be at least three hexes from another city. Strategic deposits must connect to your territory.",
  },
  {
    id = "yields",
    name = "FOOD INDUSTRY SCIENCE",
    text = "Worked terrain and deposits provide yields. City-center tiles show two base food, one industry and one science, plus building and civilization bonuses. Add the worked tiles to get the inspector total. Each citizen eats two food per round. Surplus fills local storage. Growth requires 20 plus 8 times population in stored food and at least four rounds since the last population change. Zero surplus stagnates. An empty food store and three hungry rounds lose one citizen, down to a minimum population of one. New citizens automatically work an available owned tile. If none is free, they stay idle.",
  },
  {
    id = "production",
    name = "CITY PRODUCTION",
    text = "Open an owned city, choose PROD, then UNITS or BUILDS. Select an unlocked project. Industry is added each round; stored industry is not spent to buy it instantly. Switching retains project progress. NO PRODUCTION pauses work and reminders until you select a new project. Scouts cost five industry. Settlers start at twelve industry and cost five more for each settler the empire has finished training. Queueing or switching does not increase that count; settling or losing a settler does not reduce it. A finished unit waits if no valid spawn hex is free.",
  },
  {
    id = "research",
    name = "RESEARCH",
    text = "Select a technology in TECH TREE, then start research. Required technologies must be completed first. Drag the research canvas to pan; compact research details scroll by dragging. Your cities add science every round until the cost is met. Named research milestones advance your empire through Survival, Iron, Redstone & Diamond, Rotation, Brass, and Steam & Rail. Branch technologies remain available. Selecting a different target retains earlier progress.",
  },
  {
    id = "movement",
    name = "MOVEMENT",
    text = "Select an owned unit, then press MOVE / ATTACK in the inspector to show legal destinations. Cyan dotted borders and numbered badges show reachable movement costs; outlined red crosses mark attacks. Choose a destination to preview its route, then click it again or press the confirm icon. Gold pips identify awake units that can still move. Clicking the unit again deselects it. Cancel leaves your orders unchanged. Plains cost one movement point; forests and hills cost two. Settlers have three movement points and pay one on ordinary land, but need movement remaining to found a city. Valid orders wake sleeping units. Scouts and rangers cross forests for one. Mountains block land units.",
  },
  {
    id = "combat",
    name = "COMBAT AND RANGE",
    text = "Only highlighted enemy hexes can be attacked. Strength, defense, city defenses, terrain and unit abilities affect deterministic combat. Ranged attacks do not move the attacker into the target hex and consume its remaining movement. Units have 100 HP. Melee exchanges damage; ranged strikes do not take immediate retaliation and cannot capture cities. Damage depends on effective strength, terrain, health and levels. A unit at zero HP is removed.",
  },
  {
    id = "naval",
    name = "NAVAL UNITS",
    text = "Ships travel on water rather than land. Build them in a coastal city with a shipyard beside a free water hex. Navigation lets land units embark for two movement points per water hex; embarked land units cannot attack or found cities. Some ships require an owned strategic deposit and research. Mariner ships receive one extra movement point each round.",
  },
  {
    id = "fog",
    name = "EXPLORATION AND FOG",
    text = "Visible hexes show current units. Explored hexes retain terrain but hide unseen enemies. Unexplored terrain and deposits stay concealed. Vision comes from cities and units. Hotseat handoffs conceal the previous player, and network views filter private information.",
  },
  {
    id = "maps",
    name = "MAP TYPES",
    text = "Choose Compact, Standard or Large in the lobby. Continents, Archipelago, Pangaea and Highlands create different terrain distributions. A fixed seed reproduces the same world. Scouts reveal land; settlers expand into new territory.",
  },
  {
    id = "saving",
    name = "SAVES AND MULTIPLAYER",
    text = "Local hotseat uses three campaign slots and a private handoff screen. Network hosting and joining use modem connections and a separate match save. Save from the pause menu. Updating code preserves campaigns. Main Menu returns to the title; Exit closes the game.",
  },
  {
    id = "controls",
    name = "MAP AND INSPECTOR",
    text = "Click the narrow map edges, or drag or scroll inside the map, to pan. Use + and - in the left sidebar to zoom. Its bottom fullscreen icon opens the fog-aware world overview; click a region to jump there. Resources, yields and territory are independent overlay toggles, off by default. TERRAIN clears overlays. YIELDS zooms in for readable drumstick, cog and flask symbols. Yields up to five repeat the symbol; higher yields show a number, and zero yields are omitted. The right inspector stays visible. Use its scrollbar or PREV and NEXT to reach long lists. Modal screens block map input until closed.",
  },
}
mechanics[#mechanics + 1] = {
  id = "standby",
  name = "SLEEP AND TURN CHECKS",
  text = "SLEEP UNIT keeps a unit on standby across rounds. Wake it with WAKE UNIT before issuing orders. Ending a turn asks for confirmation when awake units have movement left, cities lack production, or research is unassigned. END ANYWAY deliberately skips these orders.",
}
mechanics[#mechanics + 1] = {
  id = "reports",
  name = "TURN REPORTS",
  text = "Each turn begins with a private report of your economy, completed research and buildings, city growth, recruited or lost units, and damaged units. REPORT opens it again. Hotseat camera and selection reset when passing the screen to another player.",
}
mechanics[#mechanics + 1] = {
  id = "empire",
  name = "EMPIRE AND IDLE UNITS",
  text = "The city icon at the top right opens EMPIRE. End-turn reminders offer GO TO buttons for cities without production. Its unit and city lists center the map on your selection. The shield/arrow icon jumps to the next awake unit with movement left. These controls only select; MOVE / ATTACK still activates orders. CITY and UNIT in the inspector switch between a city and its garrison.",
}
mechanics[#mechanics + 1] = {
  id = "icons",
  name = "ACTION BAR ICONS",
  text = "Bottom left: connected nodes open TECH TREE and shield/arrow selects NEXT IDLE UNIT. The labeled END TURN button is at the bottom right. Left sidebar: plus/minus zoom and fullscreen opens WORLD OVERVIEW. Top right: city opens EMPIRE, book opens CODEX, clipboard opens REPORT, and pause opens the pause menu.",
}
mechanics[#mechanics + 1] = {
  id = "gold",
  name = "GOLD AND UPKEEP",
  text = "Each city earns two gold plus its population each round. Markets add three, bazaars three and banks five. Every unit pays its listed upkeep. A treasury can temporarily cover negative income, but unpaid units disband if gold runs out. DISBAND in the unit inspector lets you reduce upkeep voluntarily after confirmation. The top bar shows stocks and projected changes; click it for the full ledger. Owned iron, horses and saltpeter deposits add one stock per round; specialized units consume two stock on completion.",
}
mechanics[#mechanics + 1] = {
  id = "health",
  name = "HEALTH LEVELS AND HEALING",
  text = "Units have 100 HP. Combat grants XP: attacks give three, defending gives two, defeating a unit adds five, and city attacks give four. Each ten total XP per level increases level and adds two strength. Injuries reduce effective strength. FORTIFY / HEAL skips orders and restores 20 HP per round only in owned territory. Units that did not act also recover only on owned land. Adjacent support crews can heal outside owned territory. A valid movement or attack order wakes a sleeping unit.",
}
mechanics[#mechanics + 1] = {
  id = "citycombat",
  name = "CITY COMBAT AND SIEGE",
  text = "Cities have 200 HP. Walls provide 100 outer defense HP and fortresses 200. Ordinary melee deals 35 percent and ordinary ranged 25 percent damage against walls; siege units deal full damage. Only a surviving melee unit can capture a city reduced to zero HP. Cities recover 15 HP per round unless all adjacent land escape routes are controlled by enemy melee units. Walls recover after three quiet rounds. Functioning walls permit one visible ranged strike within two hexes each round.",
}
mechanics[#mechanics + 1] = {
  id = "explore",
  name = "AUTO EXPLORE",
  text = "Scouts and explorers can automatically search for unexplored territory using legal, non-attacking routes. AUTO EXPLORE moves immediately if points remain and continues each new round. STOP EXPLORING or a manual order cancels it. It stops when no safe route or unexplored territory remains.",
}
mechanics[#mechanics + 1] = {
  id = "audio",
  name = "AUDIO",
  text = "A connected speaker plays short interaction, movement, research, production and turn effects. The title screen plays an original note-based melody. Toggle AUDIO in the pause menu to mute or restore sound; the setting persists. No speaker means silent play.",
}
mechanics[#mechanics + 1] = {
  id = "create",
  name = "CREATE PRODUCTION",
  text = "City machinery forms local prerequisite chains. Water Wheel -> Mechanical Press -> Belt Logistics and Crushing Wheels. Nether Portal -> Blaze Burner; combine with a press to build a Heated Mixer. After Brassworking, each mixer converts one copper and one zinc to two brass each round. Deployers and assembly workshops lead to mechanical crafting and steam plants. Routine fuel and intermediate parts are included in industry costs.",
}
mechanics[#mechanics + 1] = {
  id = "materials",
  name = "MATERIALS AND TRADE",
  text = "Iron, copper, zinc, redstone and diamond deposits produce one stock per round once claimed and researched. Brass comes from heated mixing. Specialized units consume two stock on completion. A trading hall, or a discovered independent village with 20 influence, enables material purchases in the resource ledger: 20 gold per stock. Research the material technology first.",
}
mechanics[#mechanics + 1] = {
  id = "rails",
  name = "RAILWAYS",
  text = "After Railways, select an engineer and BUILD RAIL. Choose its current or an adjacent eligible owned land hex, then confirm. A segment costs two iron and all remaining movement. Both ends of a rail move must be railed and friendly: each edge costs one-quarter movement point. Stations must have rail on their city center. Connecting two or more stations grants each city two industry and two gold once, independent of loops. Three connected industrial complexes sustained for ten rounds win.",
}
mechanics[#mechanics + 1] = {
  id = "mobs",
  name = "HOSTILE SPAWNERS",
  text = "Choose Off, Standard or Dangerous in the lobby. Spawners start at least five hexes from starting capitals. After round five, Standard spawns every five rounds, Dangerous every three. Each camp supports at most three living mobs; the global cap is one per twenty map hexes. Zombies, skeletons and spiders appear first; creepers and pillagers arrive later. Mobs attack nearby targets, including villages, but only raid cities. Occupy a camp with surviving melee infantry to clear it permanently for 25 gold.",
}
mechanics[#mechanics + 1] = {
  id = "villages",
  name = "VILLAGER CITY-STATES",
  text = "Independent farmer, librarian and toolsmith villages have guards and face hostile raids. They use no player slots. Defeat a mob within three hexes to earn ten influence. Send an envoy for 25 gold to gain ten influence, once per five rounds. At 20 influence trade becomes available. The highest influence at or above 40 earns the alliance, with player ID breaking ties. Farmers grant two food, librarians two science, toolsmiths two industry to the ally's oldest city. Villages can be conquered; conquered villages become normal cities and stop giving alliance benefits.",
}
mechanics[#mechanics + 1] = {
  id = "wonders",
  name = "SPECIAL TILES AND WONDERS",
  text = "Natural landmarks are seeded map tiles that reward citizens working them. City production has a WONDER category: select a unique constructed wonder and choose a highlighted empty city-owned land hex. Finish it through ordinary industry. A competing completion ends your queue while preserving invested progress. Its benefits belong to the city controlling that tile. Wonders cannot overlap cities, other landmarks or rails.",
}
local function title(id)
  return id:gsub("_", " "):upper()
end
function E.entries(category)
  if category == "mechanics" then
    return mechanics
  end
  local source = category == "wonders" and Systems.wonders
    or category == "sites" and Systems.naturalWonders
    or category == "units" and Systems.units
    or category == "buildings" and Systems.buildings
    or Systems.techs
  local result = {}
  for id, record in pairs(source) do
    result[#result + 1] = { id = id, name = record.name or title(id), record = record }
  end
  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end
function E.describe(category, entry, player)
  if entry.text then
    return { entry.text }
  end
  local record = entry.record
  local lines = {}
  if category == "sites" then
    return { record.description, "Natural landmark: work the tile with a citizen to collect its bonus." }
  end
  if category == "wonders" then
    return {
      "Industry cost: " .. record.production,
      record.description,
      "Research: " .. Systems.techs[record.tech].name,
      "Unique across the world. Choose an empty owned land hex. Benefits follow tile ownership. Capturing a wonder transfers its benefits.",
    }
  end
  if category == "units" then
    if record.hostile then
      return {
        record.ability,
        "Movement "
          .. record.move
          .. " / attack "
          .. record.strength
          .. " / defense "
          .. record.defense
          .. " / range "
          .. record.range,
        "Spawns in the wilderness. Cannot own cities or be recruited.",
      }
    end
    lines = {
      "Industry cost: " .. Systems.projectCost("unit", entry.id, player),
      "Attack " .. (10 + record.strength * 5) .. " / defense " .. (10 + record.defense * 5),
      "HP 100 / upkeep " .. (record.upkeep or 1) .. " gold per round",
      "Movement " .. record.move .. " / vision " .. record.vision .. " / range " .. record.range,
      record.naval and "Domain: water" or "Domain: land",
      record.ability or "",
    }
  elseif category == "buildings" then
    lines = {
      "Industry cost: " .. Systems.projectCost("building", entry.id),
      record.description or "",
      "One of this building per city.",
    }
  else
    lines = { "Science cost: " .. record.cost, "Unlock: " .. title(record.unlock or "none") }
    local needs = {}
    for _, id in ipairs(record.requires or {}) do
      needs[#needs + 1] = (Systems.techs[id] or {}).name or title(id)
    end
    lines[#lines + 1] = "Prerequisites: " .. (#needs > 0 and table.concat(needs, ", ") or "none")
  end
  if category == "units" and entry.id == "settler" then
    lines[#lines + 1] =
      "Starts at 12 industry; +5 for each settler trained by your empire. Counts completed settlers, including those later lost or settled."
  end
  if record.age then
    lines[#lines + 1] = "Age: " .. Systems.ages[record.age].name
  end
  for _, need in ipairs(category == "buildings" and record.requires or {}) do
    lines[#lines + 1] = "Required building: " .. Systems.label("building", need)
  end
  if record.tech then
    lines[#lines + 1] = "Research: " .. Systems.techs[record.tech].name
  end
  if record.resource then
    lines[#lines + 1] = "Needs two " .. title(record.resource) .. " stock on completion"
  end
  if record.building then
    lines[#lines + 1] = "Required city building: " .. title(record.building)
  end
  if record.coastal then
    lines[#lines + 1] = "Coastal cities only"
  end
  if record.unique then
    lines[#lines + 1] = "Civilization: " .. Systems.civ(record.unique).name
  end
  return lines
end
function E.draw(ui, rect)
  local player
  for _, p in ipairs(ui.state.players or {}) do
    if p.id == ui.playerID then
      player = p
      break
    end
  end
  local r = ui.r
  local model = ui.codex or { category = "units" }
  ui.codex = model
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  r:fill(x, y, w, h, 1)
  r:outline(x, y, w, h, 8)
  r:text(x + 4, y + 3, "ENCYCLOPEDIA", 8, 1, w - 46)
  r:button(x + w - 37, y + 1, 35, 11, "CLOSE", function()
    ui.panel = "context"
  end)
  local categories = { "units", "buildings", "techs", "wonders", "sites", "mechanics" }
  local labels = { "UNITS", "BUILDS", "TECH", "WONDER", "SITES", "HELP" }
  local width = math.floor((w - 14) / 6)
  for i, category in ipairs(categories) do
    r:button(x + 2 + (i - 1) * (width + 2), y + 13, width, 11, labels[i], function()
      model.category = category
      model.entry = nil
      model.offset = 0
    end, { selected = model.category == category })
  end
  local body = { x = x + 3, y = y + 24, w = w - 6, h = h - 26 }
  local rows = {}
  if model.entry then
    rows[#rows + 1] = {
      buttons = {
        {
          label = "BACK TO LIST",
          run = function()
            model.entry = nil
            model.offset = 0
          end,
        },
      },
    }
    for _, line in ipairs(Panels.wrap(r, model.entry.name, body.w - 4)) do
      rows[#rows + 1] = { text = line, color = 8 }
    end
    for _, paragraph in ipairs(E.describe(model.category, model.entry, player)) do
      for _, line in ipairs(Panels.wrap(r, paragraph, body.w - 4)) do
        rows[#rows + 1] = { text = line }
      end
    end
  else
    for _, entry in ipairs(E.entries(model.category)) do
      rows[#rows + 1] = {
        buttons = {
          {
            label = entry.name,
            run = function()
              model.entry = entry
              model.offset = 0
            end,
          },
        },
      }
    end
  end
  Panels.rows(r, body, rows, model)
end
return E
