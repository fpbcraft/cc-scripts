# FPBCRAFT Remote Factory Node

A CC:Tweaked satellite program for remote factory telemetry and **paired** redstone output control.

## Install on each remote computer

The remote computer needs a Wireless or Ender Modem. Add wired modems and cables for other peripherals or relay blocks. Run:

```
wget run https://raw.githubusercontent.com/fpbcraft/cc-scripts/feat/peripheral-onboarding/node/install.lua feat/peripheral-onboarding "Andesite Farm"
reboot
```

Update the main Factory Manager to the same feature branch. Both computers must stay chunk-loaded to operate.

## Built-in GUI and pairing via floppy disk

The remote computer now automatically opens its own compact **CraftOS dashboard**, showing its name, ID, modem connection, discovered sensor count, hub pairing status, managed outputs, and removable-disk status. This needs no Basalt dependency and **runs concurrently with telemetry, command reception, and the safety watchdog**.

To pair, without stopping the node or running another script:

1. Attach a **Disk Drive** to the remote computer. Insert a writable ComputerCraft floppy disk.
2. Click **EXPORT KEY TO DISK** on the remote computer GUI (or press **E** on its keyboard). The GUI automatically locates the disk and writes `fpb_pairing.db` containing only this node's ID, name, and pairing secret.
3. Click **EJECT DISK** if desired, then move the floppy to a Disk Drive attached to the main Factory Manager.
4. On the main monitor, select **Devices → remote computer → PAIR FROM DISK**. The Factory Manager imports the secret, removes the pairing file from the floppy, and initiates a signed handshake.
5. After the device displays **PAIRED**, select **REGISTER AS MACHINE**, if you want to control redstone outputs.

The GUI updates its disk status automatically. If the floppy already contains a *different* pairing key, press **EXPORT KEY TO DISK** twice to explicitly confirm replacement. Other files on the floppy are untouched. If it already holds the same key, no rewrite is needed. Select **SHOW PAIRING KEY** (or press **K**) only if you need manual entry instead.

The previous `/fpb-node/export_pairing.lua` script remains available as a command-line fallback, but is no longer necessary during routine use. Normal GUI exports do **not** restart or interrupt the remote-node controller.

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
