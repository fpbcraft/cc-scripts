# Map topology contract

Generated maps store `world.wrapX` as an explicit boolean. Missing values in
older saves migrate to `false` without changing their tiles, seeds, or
generation versions. New generation remains finite by default; tests or an
explicit caller may opt in with `context.wrapX = true` (or `mapWrapX = true`).
The lobby and player-safe world projections expose only this public setting.

`Hex.canonical(x, y, state)` is the coordinate boundary: it wraps integer X
coordinates when `state.world.wrapX` is true, and always rejects Y outside the
map. Geometry helpers with no state keep their bounded-map behavior. With a
state, `Hex.neighbours` removes duplicate/self neighbors on narrow cylinders,
`Hex.withinRadius` returns unique canonical positions, `Hex.distance` returns
the shortest odd-row hex distance over horizontal map images, and
`Hex.edgeNeighbours` carries seam coordinates while keeping top and bottom
edges open. External game requests should validate supplied coordinates with
`Hex.inBounds`; geometry helpers canonicalize aliases for calculations.

The generation core uses that same geometry for land components, start spacing,
local openings, coasts, and landmark spacing. Wrapped generation samples its
terrain fields periodically across X; Y and polar climate remain bounded. No
other authoritative gameplay distance call or map rendering path is switched
to wrapped behavior by this stage. The later gameplay and UI integrations must
pass the world state to the canonical helpers before wrapped maps can become a
player-facing default.
