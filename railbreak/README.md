# RAILBREAK: Kinetic Frontier

**Turn-based cooperative factory and railway roguelite for 1–4 players on a 5×5 CC:Tweaked Advanced Monitor.** Inspired by the visible mechanical automation of Minecraft's Create mod. The game runs entirely inside ComputerCraft: it **does not modify or control** real Create machines, Minecraft tracks, or inventories.

## Install

On a ComputerCraft computer connected to a **5×5 Advanced Monitor**:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/install-railbreak.lua
/railbreak/main.lua
```

The installer downloads and validates every Lua module into a staging directory before activating, preserves `/railbreak/data/`, and rolls back on activation failure. Use `--startup` to enable autostart on a *dedicated computer without an existing startup script*. It never silently replaces an existing `/startup.lua`. Supply a branch/tag as the installer argument to test another revision.

The game selects the largest color monitor automatically. Specify a monitor peripheral name for multiple attached displays:

```sh
/railbreak/main.lua monitor_0
```

The game sets monitor text scale to **0.5** and restores the original scale when the program exits. It tries to enable CC: Graphics pixel mode 2 if available, otherwise uses the native colored terminal. It operates on **character-cell touch coordinates** in either mode. A 5×5 Advanced Monitor is the design target; smaller displays show an explicit size warning.

## Play

- **1–4 engineers, one shared monitor.** Enter names with the on-monitor keyboard. Players collaborate on the same workshop and resource pool. Tap **CREW** to attribute actions to a different engineer. There are no turn timers or simultaneous-touch requirements.
- **Plan freely.** Select a workshop tile, tap **BUILD MACHINES**, choose the desired machine, and tap an empty tile to place it. Tap any existing machine to read its description, input/output recipe, rotation, stress, and buffer contents. Use **ROTATE** and **DISMANTLE** to adjust layouts. Dismantling returns 75% of build materials (rounded down) and all buffered items.
- **Execute production shifts.** **1 SHIFT** advances one deterministic simulation tick. **5 SHIFTS** advances five. **AUTO** runs until four additional iron sheets enter the warehouse, a significant warning occurs, or twenty shifts pass. Animations are cosmetic; thinking and building do not consume time.
- **Manufacture supplies.** A starter water wheel drives a shaft and mechanical press. An input depot sends iron along a belt to the press; completed sheets travel on an output belt to the collection chest and warehouse. Build saws, crushers, mixers and deployer assemblies to manufacture planks, gravel, railway track kits and bridge sections.
- **Expand the railway.** The **RAILWAY** screen shows two destinations per chapter, their construction material requirements, and obtainable supplies. Craft what you need, then choose a route. Complete delivery contracts for bonus supplies and reputation. Four connected railway legs finish the expedition.
- **No soft-locks.** If an experiment strands your supplies, **WAREHOUSE → EMERGENCY SCAVENGE** recovers raw materials for one shift and a score penalty. This is available in solo and co-op.

### Core machinery

| Machine | Role |
|---|---|
| Water Wheel | 32 stress-unit capacity, no fuel consumption |
| Steam Engine | 80 stress-unit capacity, burns coal on powered shifts |
| Shaft | Joins connected kinetic machine networks |
| Speed Gear | Makes a network run at 32 RPM instead of 16 RPM, doubling stress demand |
| Mechanical Press | One iron → one iron sheet |
| Mechanical Saw | One log → two planks |
| Crushing Wheels | One cobblestone → two gravel |
| Mechanical Mixer | One gravel + one iron sheet → two track kits |
| Deployer Assembly | Two planks + one iron sheet → one bridge section |
| Input Depot | Extracts a chosen material from shared warehouse onto its facing belt |
| Conveyor Belt | Moves a packet one tile per shift in its facing direction |
| Storage Interface | Returns incoming belt products to the warehouse |

**Physical layout matters:** items must reach machines by belt, machines must connect to rotational power, and processed items need a belt or storage interface at the machine's output face. An overstressed network stops its connected processing machines rather than destroying them. The kinetic calculation is intentionally a simplified Create-inspired network model, **not** a one-to-one reimplementation of Create's real gearbox/axle transmission.

### Workstation orientation

Facing directions cycle **East → South → West → North** when rotated. Belt and depot direction is important. The default input depot already feeds an east-facing belt into an east-facing press, and the press outputs to an east-facing belt and chest. Many parallel machines can share power if the stress budget allows.

**Tip: build a saw line:** next to the starter press, add a saw at `(4, 5)`, a belt at `(3, 5)` fed by an input depot at `(2, 5)` filtered to `logs`, and an output belt/chest at `(5, 5)` and `(6, 5)`. Its power connects to the press above. Run shifts until you have planks. Additional recipes unlock after extending the railway.

### Contracts, scores, and difficulty

There are four expedition chapters. Each destination has its own route cost and resource reward; the choice order and small supply bonuses are generated deterministically from the expedition seed. Factory processing and railway decisions use that same seeded state. Contracts have shift-based deadlines, not real-world timers. Late contracts reduce reputation, but they don't end the expedition or prevent travel.

The completed-run score accounts for earned reputation, fulfilled contracts, total crafted batches, shifts spent, emergency scavenging, and completed chapters. More engineers do **not** multiply available resources, shift count or factory throughput; multiplayer benefits from shared planning, not extra actions per person. Contributions are tracked by optional manual crew selection.

## Code organization

```text
railbreak/
  main.lua                  Peripheral setup and event loop
  core/util.lua             Pure helpers, seeded RNG, inventory operations
  content/catalog.lua       Machine data, recipes, routes, contracts
  game/state.lua            Versioned game state, starting workshop, route choices
  game/kinetics.lua         Connected network graph, RPM, capacity, stress
  game/processing.lua       Ordered belt transfers, machine work, shift resolution
  game/commands.lua         Validated build, dismantle, rotate, deliver, travel orders
  render/canvas.lua         CC: Graphics pixel renderer + text-mode fallback
  ui/app.lua                Screens, touch hitboxes, dialogs, setup keyboard
  platform/storage.lua      Validated saves and backup recovery
  tests/run.lua             Offline integration and simulation tests
```

The renderer consumes logical state and is not permitted to advance the simulation. Production and logistics only advance from explicit player commands. This allows fast headless tests with a mock terminal. The game does not depend on Basalt, Pine3D, network APIs, or third-party Lua libraries.

## Validation and limitations

Run unit/integration tests with Lua 5.3 (`texlua` is sufficient in the development environment):

```sh
texlua railbreak/tests/run.lua
```

Tests cover the working starter conveyor line, warehouse conservation, machine construction, rotation and refunds, kinetic overstress, coal exhaustion, mixed-ingredient processing, route progression, multiplayer setup, and graphical/text display hitboxes at multiple monitor sizes.

**Not yet verified inside Minecraft:** This build has been validated offline against fake CC peripherals, not the actual graphics mod and multiplayer touchscreen. Rendering load, monitor scaling and the optional graphics API must be evaluated in-game. The initial release is a complete, playable **first campaign** rather than the full planned feature set: mechanical arms, complex signal automation, freeform rail track routing and animated encounter puzzles remain future enhancements.
