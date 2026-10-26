# Additional implementation requirements

User clarifications, 25 October 2026. These override earlier provisional choices
in the design draft. Keep this list alongside the main roadmap until verified.

- [x] Replay actions automatically, one at a time, centering the camera on each.
  Do not ask whether to replay. Exclude the observer's own auto-explore actions.
- [x] Add game length and enabled-victory controls to campaign creation.
- [x] Show full civilization bonuses during selection.
- [x] Show food, industry and science as rates rather than accumulated totals in
  the top bar. Gate other materials by their technologies. Omit zero-rate suffixes;
  retain positive and negative rates where applicable.
- [x] All healing, including support healing, requires the receiving unit to be in
  its own civilization's territory.
- [x] Move Research into the top-right controls and Next Idle Unit next to End Turn.
  Limit the bottom bar to the inspector width and give the map the freed height.
- [x] Expand technology descriptions and add Codex links for unlocked buildings and
  units. Keep the connected research tree on small screens.
- [x] Increase map preset dimensions further, preserving existing saved worlds.
  Compact 24x16, Standard 40x26, Large 56x36, Huge 72x46 and Vast 96x60.
- [x] Add Civilization-style conversations with AI factions.
- [x] Require discovery of another civilization before conversations or proactive
  diplomacy, enforced by the host as well as the faction UI. Persist first contact
  from visible foreign cities/units without revealing the other side's map.
- [x] Redesign conversations into focused tabs/submenus and detail dialogs instead
  of one scrolling stream. Use suitable Basalt 2.5 components (tabs, lists,
  inputs and dialogs); keep overview, deal editing, agreements and messages
  separate. Validate compact and large text/graphics screens visually.
- Wake units automatically for accepted orders. Verify every applicable action.
- [x] Remove green player/faction colors and preserve visibility on terrain.
- [x] Add a top-right faction/player details button.
- Show the predicted result when attacking a unit; keep the prediction shared
  with authoritative resolution.
- [x] Add a persistent Settings menu accessible from the title and pause screens,
  covering sound/music, volume, animation/accessibility and display preferences.
- [x] Capture an unprotected settler immediately when reached by a melee attack.
  Ranged attacks damage settlers normally (user clarification). Allow one settler
  and one protecting unit to share a hex; the protecting unit takes combat first.
  A winning melee attack captures the remaining settler. Captures transfer
  ownership without fresh movement or the previous owner's private AI plans.
- [x] Attach/detach a settler and protecting unit as an escort group that moves
  together. Linked movement must be legal and affordable for both units.
- [x] Allow distant destinations and multiple future movement orders. Persist each
  unit's route/queue and execute only its affordable legal movement at the start
  of its next eligible turn. Respect terrain, occupancy, fog, combat limits and
  war-group scheduling; do not regenerate movement. Provide cancel/replace and
  interruption feedback, including for attached settler escorts. Routes use
  explored terrain, never automatically attack, and pause for explicit replanning
  when obstructed. Up to 16 waypoints may be queued.
- [x] Fix city-name and other label blur immediately after zooming. Bitmap text
  snaps fractional camera origins to the pixel grid before drawing strokes. The
  first uploaded frame stays sharp with either warm or cold scaling caches;
  panning is not required.
- [x] Keep explored tiles outside vision visible, greyed out and frozen at their
  last observed state. Do not show unseen units, new cities or other changes.
  Re-entering vision updates the remembered state. Check local, hotseat, remote
  snapshots and event playback against the same observation rules.
- [x] Add a top-right Event Log button. List the observer's known events in reverse
  chronological order, newest first, with no hidden actions or action-count
  leakage. Keep compact observer-filtered history separately from the bounded
  replay window so older known events remain reachable by scrolling/pagination.
- [x] Add a short pause before each replayed event at the start of a turn so the
  player can parse successive actions. Pause/reduced-motion/speed preferences
  must remain coherent; simulation must not wait on presentation.

Surprise War first strike: the attacker uses **all remaining legal actions**
before the defender responds. Previously spent movement and attacks stay spent.

Existing implementation already covers accepted-order wake and deterministic
combat previews; these still need the final integrated interaction checks.

## Further interaction and combat requirements

- [x] Replace separate Next Idle Unit and End Turn controls with one primary button.
  Its label must describe the next action: select an idle unit, choose city
  production, choose research, or end the turn only when no required task remains.
  Explicit No Production satisfies a city's production reminder.
- [x] Add a unit Skip Turn order. It ignores that unit for this turn's idle reminders
  and clears at its next eligible turn; it is distinct from persistent Sleep.
- [x] Implement Civ6-style [zone of control](https://civilization.fandom.com/wiki/Zone_of_control_%28Civ6%29):
  hostile military/city control restricts movement after entering controlled
  terrain, with appropriate domain and unit exceptions. Use shared legality for
  pathfinding, human/AI orders, queued movement and visible previews. Preserve
  legal attacks and avoid exposing hidden enemies through previews.
- [x] Give embarked land units a larger water movement allowance when they begin
  their eligible turn in water. They may initiate melee attacks onto land.
  Land-based melee units cannot initiate attacks against embarked units, but may
  retaliate when attacked; ranged units may attack them. Keep forecasts, AI,
  reachability and actual combat consistent.
- [x] Reserve faction colors separately from every terrain color. Borders, units and
  city markers must remain legible on each biome, including text fallback;
  validate strong outlines/contrast as well as distinct palette entries.
- [x] Compact inspectors must separate city Overview, Jobs, Tiles and Production
  into focused views, and unit actions from secondary details. Keep relevant
  actions accessible without paging through unrelated information. Move status
  feedback (for example Order Accepted) into the empty strip below the map.
