# FPB Monitor Input — NeoForge 1.21.1

**Source preview: requires a successful NeoForge build and in-game test before distribution.**

CC:Tweaked's Advanced Monitor sends `monitor_touch` for right-clicks only. This companion adds `monitor_left_click` and keeps `monitor_touch` intact, including the CC: Graphics coordinate changes.

## Input contract

- Right-click: standard CC:Tweaked `monitor_touch(side, x, y)` (CC: Graphics emits pixel coordinates).
- Left-click: `monitor_left_click(side, normalizedX, normalizedY)` with `0 <= normalizedX,Y < 1`. Multiply by `monitor.getSize()` character dimensions and `floor + 1` to resolve the cell. Coordinates are independent of rendering mode, text scale, and multi-block monitor size.
- Only the **display-facing side** of an Advanced Monitor is a touchscreen. You can still break it normally by attacking its sides/back. The mod prevents mining the screen front while attached.
- Requires this mod on **both client and server**. Compatibility target NeoForge 1.21.1 + CC:Tweaked, optionally CC: Graphics.

## Build

Requires Java 21 and Gradle 8.10 or later:

```bash
gradle build
```

JAR: `build/libs/fpb-monitor-input-0.1.0.jar`. Install on server and each player client.

## Caveats

Until runtime-verified, use the left-click event for read-only secondary functions (inspect/help) rather than destructive actions. No right-click behaviour is overridden. The hook accesses internal CC:Tweaked monitor state via a small mixin, so future CC:Tweaked updates could require maintenance.