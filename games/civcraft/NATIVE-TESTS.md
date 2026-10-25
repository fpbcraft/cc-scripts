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
