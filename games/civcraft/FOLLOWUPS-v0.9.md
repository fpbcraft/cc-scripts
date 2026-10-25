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
- Increase map preset dimensions further, preserving existing saved worlds.
- Add Civilization-style conversations with AI factions.
- Wake units automatically for accepted orders. Verify every applicable action.
- [x] Remove green player/faction colors and preserve visibility on terrain.
- [x] Add a top-right faction/player details button.
- Show the predicted result when attacking a unit; keep the prediction shared
  with authoritative resolution.
- [x] Add a persistent Settings menu accessible from the title and pause screens,
  covering sound/music, volume, animation/accessibility and display preferences.

Surprise War first strike: the attacker uses **all remaining legal actions**
before the defender responds. Previously spent movement and attacks stay spent.

Existing implementation already covers accepted-order wake and deterministic
combat previews; these still need the final integrated interaction checks.
