# FPBCRAFT Wireless Factory Node

A small CC:Tweaked program for factories located away from the main controller. The node sends read-only sensor measurements from its local **wired** peripheral network over wireless Rednet.

## Physical setup

At the remote factory:
- 1 basic or Advanced Computer
- 1 Wireless Modem (shorter range) or Ender Modem (long-distance/cross-dimensional)
- 1 Wired Modem + Networking Cable for local peripherals; each remote sensor also needs its own wired modem if not adjacent to the computer
- Sensors (Create Stressometer/Speedometer, Power Grid gauge, etc.)

At the main Factory Manager:
- Attach **one Wireless Modem or Ender Modem** to its computer, *in addition to* the wired factory network's modem.
- Factory Manager automatically opens compatible wireless/Ender modems and listens for nodes. No address or computer ID configuration is required.

The remote node periodically advertises its connected, recognized scalar sensors with its name and ComputerCraft computer ID. The main controller automatically shows them in **Devices**, with names such as `remote:37:Create_Stressometer_0`. Open the device and configure it in **Readings**, just like a locally wired peripheral.

## One-command setup

Run on the **remote computer**, choosing a meaningful node name:

```
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/main/node/install.lua main "Andesite Farm"
```

For testing the current feature branch before merge:

```
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/peripheral-onboarding/node/install.lua feat/peripheral-onboarding "Andesite Farm"
```

The installer:
- Downloads `node/main.lua` into `/fpb-node`.
- Preserves `config.db` (name/interval), unless a new name is supplied.
- Backs up the previous `/fpb-node` version to `/fpb-node.backup`.
- Replaces `/startup.lua` so the node automatically runs after reboot (backing up older startup programs).
- Uses the same one-line command for future updates. To change the display name, simply rerun with a different name.

Run `reboot` after installation or start `/fpb-node/main.lua` manually.

Install/update Factory Manager itself on the main computer with its normal `install.lua` command. Both sides must be on matching versions of the v1 remote protocol.

## Features and limits

- Auto-discovery, reconnection after reboot, and offline detection when snapshots stop arriving (~22 seconds).
- Nodes do not need a manual IP address or configured hub ID.
- Node broadcasts every 5 seconds by default, with its available read-only scalar metrics.
- Supported methods use a conservative whitelist (e.g. `getStress`, `getSpeed`, `voltage`, `current`, `power`, `rpm`, `getValue`). A brand-new mod method may require review before enabling automatic polling.
- Remote sensors may be renamed, have their values graphed, and have read-only alert thresholds.
- **Remote machine switching and package requests are not sent over Rednet** in this version. CC:Tweaked explicitly warns Rednet provides no authenticity or security against spoofed senders. Add explicit pairing and message authentication before introducing dangerous control actions.
- Ordinary Wireless Modems obey distance limits; Ender Modems have unlimited range by default.
- Both the remote computer and the central Factory Manager must be in loaded chunks to keep reporting. Force-load only the infrastructure that needs continuous operation.
- Changes to the remote computer's ID or peripheral network name require manual relinking to avoid connecting a stored sensor to the wrong device.

For reliable end-to-end updates: attach the modem, install and reboot the node, then open the main controller's **Devices → Rescan**, pick its named remote sensor, and **Add Reading**.

## Protocol

The node broadcasts messages on `fpb.factory.node.v1` with `kind = "snapshot"`, version `1`, its label, and up to 40 peripheral snapshots. The main controller caches these and expires idle nodes; it does **not** forward remote Lua method calls or actuator commands.
