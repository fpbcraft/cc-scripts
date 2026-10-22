# FPBCRAFT Remote Factory Node

A CC:Tweaked satellite program for remote factory telemetry and **paired** redstone output control.

## Install on each remote computer

The remote computer needs a Wireless or Ender Modem. Add wired modems and cables for other peripherals or relay blocks. Run:

```
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/peripheral-onboarding/node/install.lua feat/peripheral-onboarding "Andesite Farm"
reboot
```

Update the main Factory Manager to the same feature branch. Both computers must stay chunk-loaded to operate.

## Easy pairing via floppy disk

This option avoids typing a long pairing secret:

1. Attach a **Disk Drive** to the remote computer, insert a writable ComputerCraft floppy disk.
2. Temporarily stop the running node with **Ctrl+T**, then run `/fpb-node/export_pairing.lua`. It writes only the node ID, display name, and pairing key to `fpb_pairing.db` on the disk.
3. Type `reboot` on the node. Move the disk into a Disk Drive attached to the **main Factory Manager computer**.
4. On the main monitor, open **Devices → the remote computer → PAIR FROM DISK**. The manager imports the secret, deletes the floppy's pairing file, and initiates a signed handshake.
5. When the remote device says **PAIRED**, select **REGISTER AS MACHINE** to control the remote computer's redstone sides, or select a remote Redstone Relay and register it as a machine.

As an alternative, use **PAIR NODE** and enter the 48-character key displayed on the remote computer. A physical keyboard on the main computer is recommended for this mode.

## Remote control and recovery

- The node accepts commands only from its paired Factory Manager and verifies HMAC-SHA256 signatures, acknowledgements, and sequence numbers.
- It supports only `setOutput(side,boolean)` for its own computer or a connected redstone relay. It cannot run arbitrary remote Lua code.
- After 15 seconds without authenticated contact with the main computer, the node attempts to turn its managed outputs **OFF**. On reboot it also initializes managed outputs to OFF.
- This is not a physical safety guarantee. The watchdog requires a loaded computer, and relays may have inverted signal wiring. Use a real manual emergency-stop circuit.
- The current built-in random key generator is **not cryptographically secure**. Do not rely on pairing alone against a sophisticated hostile player with network access.
- Remote telemetry remains unauthenticated; never treat it as a trusted machine safety sensor.

To pair with a different main computer, stop the node with Ctrl+T, run `/fpb-node/unpair.lua`, then reboot. Old control outputs are switched OFF during unpairing.

## Updates and storage

Both the node installer and the Factory Manager installer update **without creating full backups**. They preserve the node configuration, pairing secret, and Factory Manager data while clearing older installer backup directories. The installer refuses to replace unrelated startup programs.

The node automatically starts via `/startup.lua` and reconnects after reboot. Normal remote sensor discovery uses `fpb.factory.node.v1`; authenticated control uses a separate `fpb.factory.control.v1` protocol.
