---
title: "Backup and recovery strategy for the Orange Pi Klipper host"
type: plan
status: draft
date: 2026-11-14T01:12:20Z
---

# Goal

Make the Ender 3 host recoverable after a bad configuration change, SD-card failure, or complete host loss.

The plan uses three layers:

1. Fast rollback for printer configuration.
2. Encrypted backups for host data and rebuild metadata.
3. A documented host rebuild and restore path that does not depend on the failed SD card.

# Current system

- Board: Orange Pi Zero 3W 4GB, Allwinner A733 (`sun60iw2`).
- OS: Ubuntu 26.04.1 LTS.
- Kernel: `6.6.98-sun60iw2`.
- Root filesystem: `/dev/mmcblk1p1`, ext4, about 118 GiB.
- Host user: `rd`.
- Klipper: `/home/rd/klipper`, system service `klipper.service`.
- Moonraker: `/home/rd/moonraker`, system service `moonraker.service`.
- Mainsail: `/home/rd/mainsail`, served by nginx.
- Mainsail macros: `/home/rd/mainsail-config/client.cfg`; `/home/rd/printer_data/config/mainsail.cfg` is a symlink to that file.
- Persistent printer state: `/home/rd/printer_data`.
- MCU reconnect workaround: `/home/rd/.config/systemd/user/klipper-reconnect.*` and `/home/rd/.local/bin/klipper-reconnect-check.sh`.
- Boot configuration: `/boot/orangepiEnv.txt` and the vendor A733 device tree.
- MCU device: `/dev/serial/by-id/usb-Klipper_stm32g0b1xx_3200060002504E5238363120-if00`.

The host currently has no reliable external backup system. The repository contains planning material but is not a complete host image or restore artifact. The current root filesystem is a single ext4 partition on `/dev/mmcblk1p1`; the boot configuration points to its UUID. The host also has an active user-level reconnect timer and a system-level Klipper/Moonraker/nginx stack.

# Integration with nixy and nixy-priv

Integrate the recovery system, but do not pretend the current Ubuntu host is already a NixOS host.

## Public `nixy`

Keep reusable, secret-free components here:

- Export and manifest scripts.
- Restore and validation scripts that accept host-specific paths as arguments.
- A documented backup file list and retention policy.
- An example Orange Pi host manifest with fake names and no LAN details.
- Generic restic or archive helpers that do not contain repository passwords.
- This plan and a public-safe recovery checklist.

These components can be packaged with Nix or exposed through a `nix develop` shell, even while the printer host remains on vendor Ubuntu.

## Private `nixy-priv`

Keep real deployment data here:

- The Orange Pi hostname, user, LAN address, and DHCP reservation.
- Backup repository location and restic environment wiring.
- 1Password or age secret references.
- The real package and service inventory.
- The private bootstrap and restore entry points.
- The real host manifest and recovery notes.
- Optional Mac launchd scheduling for pull-based backups.

The backup destination should be managed from the Mac, NAS, or another trusted machine. The printer host should not contain long-lived credentials that allow deletion of all backups.

## Long-term NixOS option

Do not add a real `nixosConfiguration` for this Orange Pi yet. The current host relies on the vendor A733 kernel, device tree, Wi-Fi modules, firmware, and boot layout. Once those are reproducible and tested, the private host can move toward a NixOS configuration. Until then, use Nix to package the recovery tooling and keep the Ubuntu host rebuild process explicit.

# Backup tiers

## Tier 1: configuration rollback

Keep a small, rotating set of recent snapshots on the host for quick recovery. Do not create unbounded files beside the active configuration.

Capture these files together:

- `/home/rd/printer_data/config/printer.cfg`
- `/home/rd/printer_data/config/moonraker.conf`
- `/home/rd/mainsail-config/client.cfg` and its symlink `/home/rd/printer_data/config/mainsail.cfg`.
- `/home/rd/printer_data/systemd/klipper.env`
- `/home/rd/printer_data/systemd/moonraker.env`
- `/etc/systemd/system/klipper.service`
- `/etc/systemd/system/moonraker.service`
- `/home/rd/.config/systemd/user/klipper-reconnect.service`
- `/home/rd/.config/systemd/user/klipper-reconnect.timer`
- `/home/rd/.local/bin/klipper-reconnect-check.sh`

Store snapshots under a dedicated directory such as `/home/rd/backup/config/`, retain the last 10–20 snapshots, and include a manifest with timestamps, git revisions, and printer state. Before a configuration change, write a snapshot. After a successful change, record the change and validation result.

## Tier 2: encrypted off-host backup

Use a pull-based backup from the Mac or another trusted machine so the printer host does not need write credentials for the backup destination.

Use `restic` or an equivalent encrypted backup tool. Back up:

- `printer_data/config/`.
- `printer_data/database/` if print history matters.
- Selected or all G-code files, based on storage needs.
- Printer logs when investigating a failure; do not retain them forever.
- The reconnect service and script.
- Systemd unit files and environment files.
- `/boot/orangepiEnv.txt`, `/etc/fstab`, and a non-secret system inventory.
- Package manifests from `dpkg-query` and installed Python package manifests.
- Klipper and Moonraker git revision metadata.
- The Klipper MCU build configuration and firmware artifact when available.
- A copy of this recovery plan and a generated host manifest.

Do not back up private SSH keys, Wi-Fi passwords, or tokens into the project repository. Store those in 1Password or in the encrypted backup repository. Treat NetworkManager connection files and any Moonraker secret files as sensitive.

Suggested retention:

- Daily backups for 30 days.
- Monthly backups for 12 months.
- A manual backup before firmware, OS, or major Klipper changes.

## Tier 3: rebuild image

Maintain a rebuild artifact for the host rather than relying only on a live disk image.

Capture:

- The exact vendor Ubuntu image or download URL and checksum.
- The board-specific boot files and device tree.
- `/boot/orangepiEnv.txt`.
- The package manifest.
- The service unit files.
- The Klipper, Moonraker, and Mainsail repository revisions.
- A bootstrap script that installs packages, creates the `rd` user and groups, clones the repositories, creates virtual environments, installs dependencies, installs services, and restores printer data.
- A restore script that copies the backed-up state into place, fixes ownership, reloads systemd, and validates the services.

Keep a full SD-card image only as an additional emergency shortcut. Create it while the host is shut down or from a known-consistent recovery environment; do not treat a live `dd` image as the primary backup. Store compressed images outside the printer host.

# Data classification

## Rebuild from source

These should be recreated from pinned source and package metadata:

- Ubuntu packages.
- Klipper and Moonraker virtual environments.
- Git working trees for Klipper, Moonraker, Mainsail, and Mainsail config.
- nginx package and standard service files.

Record exact commits and local modifications. The Klipper tree currently has an untracked `.config.before-skr-mini-e3-v3.0`; preserve it as part of the MCU build record or explicitly replace it with a named, documented build configuration.

## Restore verbatim

These contain printer-specific state and should be restored exactly:

- `printer.cfg`.
- `moonraker.conf`.
- Mainsail macros/configuration.
- Moonraker database if history matters.
- Reconnect service and script.
- Klipper MCU build configuration and the matching firmware binary.
- Any custom nginx or systemd overrides.

## Recreate manually

Document but do not blindly restore:

- SSH host keys.
- User SSH keys.
- Wi-Fi credentials and NetworkManager secrets.
- Router DHCP reservation.
- 1Password agent configuration.

Provision these from the password manager during recovery.

# Host rebuild procedure

1. Obtain a known-good 5 V / 3 A supply, a replacement microSD card, and the exact Orange Pi Zero 3W vendor image.
2. Verify the image checksum and write it to the replacement card.
3. Boot the board and confirm the A733 device tree, kernel, storage, Wi-Fi, hostname, and SSH access.
4. Apply security updates and create the `rd` account with `sudo` and `dialout` access.
5. Install the pinned package set.
6. Clone Klipper, Moonraker, Mainsail, and Mainsail config at the recorded revisions.
7. Recreate the Python environments and install dependencies.
8. Install and enable the system services.
9. Restore `/home/rd/printer_data` and the reconnect workaround.
10. Restore `/boot/orangepiEnv.txt` only after confirming the replacement image uses the same boot layout.
11. Connect the SKR by USB and confirm the `/dev/serial/by-id/` path.
12. Start Klipper and Moonraker. Confirm the printer is ready before heating or moving.
13. Validate temperatures, endstops, homing, mesh loading, macros, Mainsail access, USB reconnect recovery, and a small test print.

# Restore validation

Run these checks after every restore:

- `systemctl is-enabled` and `systemctl is-active` for Klipper, Moonraker, nginx, and the reconnect timer.
- Moonraker reports Klippy connected and printer state `ready`.
- Mainsail loads over the LAN.
- The SKR serial by-id path exists.
- The saved BLTouch offset and default mesh are present.
- `START_PRINT`, `PAUSE`, `RESUME`, and `CANCEL_PRINT` load without config errors.
- X/Y travel limits and the `X10/Y15` slicer origin remain documented and correct.
- Heaters report plausible room temperatures and remain off until commanded.
- USB unplug/replug recovery returns Klipper to ready without manual intervention.
- A small first-layer or calibration print completes.

# Backup automation phases

## Phase 1: export and manifest

Create a read-only export script that gathers the selected files, package lists, git revisions, boot metadata, enabled services, and checksums into a dated staging directory. Redact secrets before writing the manifest.

## Phase 2: encrypted backup

Run the export from the Mac on a schedule, then push the staging directory into an encrypted `restic` repository. Add a pre-change command for manual snapshots.

## Phase 3: restore tooling

Add a bootstrap script and restore script. Make both idempotent and safe to run more than once. Keep them in a private repository if they contain real host names, network details, or secret references.

## Phase 4: recovery drill

Test a config-only restore first. Then perform a host rebuild on a spare card or virtual staging directory. Record the time to reach a ready printer and fix every undocumented step.

# Decisions to make before implementation

1. Backup destination: Mac, NAS, external disk, or encrypted cloud repository.
2. Whether to retain all G-code or only selected files.
3. Whether print history is worth retaining.
4. Whether the private host rebuild scripts belong in `nixy-priv` or a dedicated private repository.
5. Whether to keep a periodic full SD-card image in addition to file-level backups.
6. Whether the host should use a DHCP reservation or a documented static lease during recovery.

# Acceptance criteria

- A dated backup can restore the printer configuration without touching the OS.
- A replacement microSD card can be rebuilt from documented inputs and the encrypted backup.
- The restored host reaches Klipper `ready` without hand-editing unknown files.
- Secrets stay outside the public repository.
- A quarterly restore test proves that the backup is usable, not merely present.
