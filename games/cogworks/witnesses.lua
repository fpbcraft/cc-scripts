-- Designer/test entrypoint. Every solution is replayed through player actions
-- against the same initial board and inventory; this never changes level data.
local E = require("games.cogworks.engine")
local W = {}
function W.play(number, name)
  local stage = assert(E.levels[number], "Invalid campaign level")
  name = name or "normal"
  for _, bonus in ipairs(stage.bonuses) do
    if bonus.id == name then
      name = bonus.witness
      break
    end
  end
  local solution = name == "normal" and { parts = stage.build, remove = stage.removeRedstone }
    or assert(stage.solutions[name], "Unknown solution witness")
  local g = E.new(number)
  for _, cell in ipairs(solution.remove or {}) do
    assert(E.remove(g, cell[1], cell[2]), "Witness cannot remove starting part")
  end
  for _, piece in ipairs(solution.parts) do
    assert(E.place(g, piece.x, piece.y, piece.kind, 0), "Witness exceeds stock or overlaps machinery")
    for _ = 1, piece.r or 0 do
      assert(E.rotate(g, piece.x, piece.y), "Witness cannot rotate part")
    end
  end
  for _, cell in ipairs(solution.toggle or {}) do
    assert(E.toggle(g, cell[1], cell[2]), "Witness cannot operate control")
  end
  return g, E.evaluate(g)
end
return W
