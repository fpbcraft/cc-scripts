# Skyways — Route planning and power controls

## Route screen

The selected route's stops use two-line summaries: route order/name/type on the tappable line, then **rounded X/Z, target Y, and dwell time**. On monitors at least 56 characters wide, the summary also includes the recorded normal and fine lift strengths. `>` identifies the saved next stop; blue highlights the selected stop. Use **DETAIL** to edit lift, stop duration, station precision and heading; **RECORD** captures the current position and aggregate main/fine network signals while stopped. The old route editor, library and floppy transfers remain available.

## Power screen

The **PWR** tab provides buttons to increase/decrease **normal lift**, **fine lift**, and the **engine-request** signal in integer steps from 0 to 15. `TX` is the value last requested by this program; `Link` is the aggregate level observed on the matching Create Redstone Link frequency, which can be raised by other transmitters. These numbers **are not physical engine RPM or burner output**. The signal mappings are configured on the Setup → Control Frequencies screen.

Manual lift changes **disable altitude assist**, so the automatic controller will not immediately overwrite the operator's selected levels. If a route is actively flying, the next waypoint may still apply its own recorded levels. Engine +/- controls switch engine automation off and set an explicit strength; **ENG AUTO** restores the normal active-flight engine request (15 when active, 0 when idle). Remember that the engine link was previously wired through an **inverted LAC receiver**: transmitter level 15 requests an engine-on condition. A physical override must remain available.

## Height mismatches at stations

There are three ways to resolve a station that cannot match the saved height:

1. **Edit the station Y tolerance** (default ±1.5 blocks, configurable ±0.5–10). A slightly larger tolerance can accommodate lift steps and normal motion without discarding the saved station's target Y. The horizontal radius and heading checks still apply.
2. **Try opt-in Y ASSIST** in PWR. When a route waypoint has recorded target Y **and both** main and fine baseline strengths, Skyways uses the actual Y from the Avionics Navigation Table and observed vertical rate to apply a small proportional+damping correction around the recorded lift levels. Each channel is limited to ±3 levels from its recorded baseline and changes by at most one level per update (~0.35 s). It does not attempt height correction when no target Y is stored. The algorithm has **not been calibrated on your ship**; the default is OFF. First verify while manually supervised whether *increasing* Redstone Link signal makes the ship rise or fall, and configure **RISE +SIGN / -SIGN** accordingly. Do not enable assist if the engine/balloon circuitry is unsafe for automatic adjustments. The maximum correction may be insufficient to reach a target: you can change recorded baseline strengths or operate the lift manually.
3. **SKIP Y CHECK** (PWR) is an explicit, confirmed, *temporary* operator override for the current route station. It is only permitted when the ship is already within the station's horizontal radius and nearly stopped (speed ≤0.5 blocks/s). It does **not** bypass X/Z, heading, or the stable-position dwell requirement, and it automatically clears on the next waypoint or on Stop. The saved waypoint is not changed.

Importantly: the station cannot silently advance when its Y is wrong. If automatic height adjustment is unavailable or saturated, use manual power or a controlled, explicit override. Do not use unattended station docking before verifying the actual response of the ship.

## Update

The branch's installer preserves route-library and configuration files (including waypoint Y tolerances and altitude-assist settings). To preview the open PR branch:

```sh
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/airship-recorded-routes-stations/install-airship.lua feat/airship-recorded-routes-stations
```
