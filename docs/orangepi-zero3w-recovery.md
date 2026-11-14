# Orange Pi Zero 3W recovery model

This document describes how the Orange Pi printer host fits into `nixy` and
`nixy-priv`.

## Current boundary

The Orange Pi Zero 3W is **not currently a NixOS host**. It runs the vendor
Ubuntu image and depends on vendor-specific A733 support:

- Kernel: `6.6.98-sun60iw2`.
- Device tree: `sun60i-a733-orangepi-zero3w.dtb`.
- Wi-Fi driver and firmware: AIC8800 vendor modules and firmware.
- Boot layout: vendor A733 SD-card layout.

Do not create a real `nixosConfiguration` for this board until those pieces can
be reproduced and tested. The public Raspberry Pi modules are not a suitable
fallback.

## What belongs in `nixy`

Keep reusable and public-safe material here:

- Export, manifest, restore, and validation scripts.
- Generic backup-tool packaging.
- Fake-safe examples.
- Recovery documentation and checklists.
- Board-support research that contains no credentials or private network data.

The scripts must accept host-specific paths and values as arguments or read
them from the private repository. They must not embed the real printer host's
identity.

## What belongs in `nixy-priv`

Keep the real host record and deployment details there:

- Hostname, user, LAN address, and DHCP reservation.
- Real backup destination and retention policy.
- Secret-manager references.
- The package and service manifest captured from the host.
- Private bootstrap and restore wrappers.
- Recovery test results and host-specific exceptions.

Do not commit backup contents, SSH private keys, Wi-Fi passwords, restic
passwords, or tokens.

## Recovery layers

### Configuration rollback

Restore the printer-specific state first:

- `/home/rd/printer_data/config/printer.cfg`.
- `/home/rd/printer_data/config/moonraker.conf`.
- `/home/rd/mainsail-config/client.cfg`.
- The Klipper MCU build configuration and matching firmware record.
- The USB reconnect timer and script.

Restart Klipper only after checking the configuration, then confirm that
Moonraker reports `ready`.

### Host rebuild

Write the recorded vendor Ubuntu image to a replacement card, restore the
package and service manifests, clone the pinned Klipper/Moonraker/Mainsail
revisions, and restore `printer_data`. Provision SSH and Wi-Fi secrets from the
password manager rather than from Git.

### Full-card image

A compressed, offline SD-card image may provide a fast emergency recovery path,
but it is not the source of truth. Keep file-level backups and rebuild metadata
as the durable backup. Create images only while the host is shut down or from a
consistent recovery environment.

## Limitations

- The current plan does not yet install an automated backup job.
- The Orange Pi's OS and boot chain are not declaratively rebuilt by Nix.
- A host rebuild still depends on the vendor image and A733 kernel support.
- The printer's G-code library and logs are large; retention must be chosen
  separately from configuration backups.
- SSH host keys and Wi-Fi credentials require manual secret provisioning.
- A backup is not considered valid until a restore test succeeds.

See [the recovery strategy plan](plans/20261114011220-backup-and-recovery-strategy.md)
for the implementation phases and restore acceptance criteria.
