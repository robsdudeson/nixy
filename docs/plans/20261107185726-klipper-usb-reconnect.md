---
title: Automatic Klipper USB reconnect
type: implementation
status: proposed
date: 2026-11-07
---

# Goal

Restart Klipper automatically when the SKR Mini E3 USB MCU appears after the Orange Pi or printer starts.

# Findings

- Klipper starts before the SKR USB device when the printer powers on late.
- The configured `/dev/serial/by-id/` path is absent at that point.
- Klippy stays running in an error state instead of exiting, so systemd's restart policy does not help.
- A manual `FIRMWARE_RESTART` reconnects the MCU once the USB device exists.

# Design

1. Add a root-owned systemd oneshot service that restarts `klipper.service`.
2. Add a udev rule that triggers that service when the SKR's Klipper USB device (`1d50:614e`) appears.
3. Reload udev and systemd, then verify the current printer remains ready.
4. Test the rule by restarting Klipper and checking that Moonraker reports `ready` without manually issuing `FIRMWARE_RESTART`.

# Safety and rollback

- Do not change `printer.cfg`, firmware, or TFT wiring.
- The reconnect action only restarts Klipper after the matching USB device appears. A USB disconnect already puts Klipper into a shutdown state.
- Roll back by removing the udev rule and reconnect service, then reloading systemd/udev.

# Validation

- Confirm the rule matches only USB vendor `1d50`, product `614e`.
- Confirm `/dev/serial/by-id/` is present.
- Confirm Moonraker reports `state: ready`.
- Confirm Klipper has no new serial-open or MCU-connect errors.
