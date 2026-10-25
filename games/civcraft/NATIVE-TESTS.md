# Native CraftOS checks

The developer machine has CraftOS-PC at `/Applications/CraftOS-PC.app`. Use a
dedicated emulator directory: these test programs write campaign slots 1 and 3
and diagnostic files. The repository is mounted read-only; the game is copied
into the isolated computer's writable filesystem. Existing user computers and
campaigns are not used.

From the repository root, create a fresh profile and run:

```sh
civcraft_test_root=$(mktemp -d /tmp/civcraft-native.XXXXXX)
/Applications/CraftOS-PC.app/Contents/MacOS/craftos \
  --headless --directory "$civcraft_test_root" \
  --mount-ro "/repo=$PWD" \
  --exec 'fs.copy("/repo/games/civcraft","/games/civcraft");fs.copy("/repo/tests","/tests");local results={};for _,name in ipairs({"civcraft_events_test.lua","civcraft_animations_test.lua","civcraft_craftos_smoke.lua","civcraft_craftos_session.lua"})do results[name]=shell.run("/tests/"..name)end;local out=assert(fs.open("/native-results.txt","w"));out.write(textutils.serialize({host=_HOST,results=results}));out.close();os.shutdown()'
```

Results are under `$civcraft_test_root/computer/0/`:

- `native-results.txt`: each program's pass/fail result and emulator version.
- `civcraft-native-smoke.txt`: renderer mode, actual button commands, journal
  sequence, interpolated positions, elapsed playback time, successful Skip and
  filesystem campaign/AI-plan save/reload.
- `civcraft-native-session.txt`: full game-loop stages, round two, renderer mode
  and successful save/reload.
- `session-input.log`: injected mouse coordinates and the actual buttons under
  those coordinates, for diagnosing the native session driver.

The full-session driver uses real `os.queueEvent` mouse down/up events. Its UI
instrumentation chooses button coordinates and acknowledges when the game's
renderer has consumed the input marker. It follows paged controls, introductory
reports, two human turns, private handoffs, pause, save and exit. It does not
replace the terminal, renderer, filesystem, peripheral APIs, input loop, rules
or save implementation.

Recorded local validation used **CraftOS-PC 2.8.3 / ComputerCraft 1.112.0**.
Headless checks use the real **text** backend at the default **51×19** terminal.
The separate regression suite covers graphics primitives and text/graphics
layout with fake displays. GUI pixel animation, physical advanced-monitor input,
network modem traffic and multi-client reconnects still need their own tests;
headless success does not establish those behaviors.

For the economic AI scenarios, run `/tests/civcraft_economic_ai_test.lua` inside
the isolated computer. Run `/tests/civcraft_craftos_session.lua --ai` to configure
a third AI through the session commands and execute its real turn alongside the
two human turns. Its session result also verifies AI-plan reload. This variant
still overwrites only the isolated profile's save slot 1.

Add `--settings` to that full-session command to open Settings with real mouse
input, change animation speed, cycle the display preference twice and continue
through the campaign. `settingsReload` in the session result confirms the saved
preferences. `tests/civcraft_settings_test.lua` separately checks all settings,
including independent sound/music and volume gain, with instrumented displays
and a speaker.

Add `--research` to traverse the compact technology graph, open a technology's
description, follow its building Codex link, return to research and choose it
using real mouse input. `researchFlow` records that the selected research order
survives the round boundary and save reload. The driver preserves and navigates
the detail scroll position when reopening research.

Add `--campaign` to open Campaign Options in the lobby, select Quick and disable
Score, then start the campaign. `campaignOptions` confirms that the selected
pace, deadline and victory toggles survive the full session and save reload.

Add `--war` to the two-human session to have the second human declare Surprise
War after the first human has ended. The driver hands the screen back for the
first human's response, saves during that response and finishes it before the
round boundary. `warResponse` and `responseSaved` confirm the path and persisted
Ready/reaction state. The next round rotates the war group's starting player.

Use `--host-ai` instead of `--ai` for a separate host-mode scenario: add an AI
through the network lobby, complete the host/AI round, save and exit.
`hostModeAI` confirms this path. It can combine with `--settings`, `--research`
and `--campaign`, but not `--war` (which requires the two-human scenario).
This tests the actual host code without a modem; it does not establish live
rednet transport or multi-client reconnect behavior.

Add `--conversation` to either AI session to open the AI faction's conversation,
greet it, offer commerce and send gold through real mouse input. The host must
execute the AI replies and actual agreement/exchange effects; `conversationFlow`
confirms that the accepted exchange and active commerce survive save reload.
This combines with the hotseat `--war` response/save scenario. Run
`/tests/civcraft_diplomacy_test.lua` separately for offer ownership, atomic
funding, defense choices, armistices, counters, obligations, observation privacy,
promise movement and expiry scenarios.

The conversation driver now navigates Basalt tabs, agreement menus and trade
review dialogs. With `--conversation` or `--war`, its isolated map fixture places
capitals within normal sight so first contact is established through revelation.
It never assigns contact flags or bypasses host diplomacy validation. Run
`civcraft_contacts_test.lua` and `civcraft_conversation_ui_test.lua` in the isolated
computer for contact privacy, actual widget input and counteroffer checks.

The main session now follows the unified turn button, chooses Skip Turn for its
human units, chooses No Production for idle cities and assigns research before
ending. `turnTasks` verifies those accepted orders in the saved campaign. The
response scenario uses the same task workflow during the defender's unspent-action
window. The driver allows 45 seconds for the longer sequence of real mouse events.

Run `civcraft_zone_control_test.lua` in its own isolated computer for movement
locks, civilian costs, domain/peace exceptions, hidden-guard discovery and aborted
attack approaches. It asserts actual frozen replay endpoints and preserves an
unused attack on interruption. Full-session success also verifies startup and
existing turn/diplomacy flows with control enabled.

Run `civcraft_embarkation_test.lua` in an isolated profile for sea allowances,
landing and response budgets, amphibious forecast/resolution parity, coastal
capture, shore attack restrictions and observed-enemy danger estimates. The
normal full session also exercises the response activation hook without granting
an ended defender a second movement budget.
