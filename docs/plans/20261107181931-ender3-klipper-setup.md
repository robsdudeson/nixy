---
title: "plan: Improve Ender 3 Pro workflow with Klipper"
type: plan
status: draft
date: 2026-11-07T18:19:31Z
---

# Ender 3 Pro with SKR Mini E3 V3 and Orange Pi Zero 3W

## Recommendation

Use the Orange Pi as the Linux host for **Klipper, Moonraker, and Mainsail**. Keep the SKR Mini E3 V3.0 as the printer MCU and connect it to the Orange Pi over USB.

This gives the best upgrade path for the available hardware:

- Mainsail provides remote control, file upload, history, macros, and live status.
- Klipper moves motion planning to the Orange Pi while the SKR handles real-time I/O.
- The SKR Mini E3 V3.0 has a maintained Klipper configuration and is flashed from `firmware.bin` on an SD card.
- Ubuntu is a reasonable host base if the Orange Pi image has stable USB, networking, and systemd support.

Treat the TFT35 as optional. The cleanest interface is Mainsail from a phone, tablet, or computer. The TFT can remain disconnected, run Marlin mode only, or be added later through a community Klipper bridge. Do not make the bridge part of the first working build.

## Hardware roles

- **Orange Pi Zero 3W 4GB:** Linux host; Klipper host process, Moonraker, Mainsail, backups, and optional webcam service.
- **SKR Mini E3 V3.0:** Klipper MCU; heaters, thermistors, endstops, fans, steppers, and the LCD connector.
- **GD TFT35 E3 V3.0:** optional local UI. It is not required for Klipper and has less certain support than Mainsail.
- **Ender 3 Pro:** retain the stock motion system, hotend, thermistors, and mechanical endstops initially.

## Staged plan

### 1. Capture the known-good state

Before changing firmware, photograph or record:

- Current Marlin version and configuration, if available.
- Motor direction, steps/mm, thermistor types, bed size, and Z offset.
- Current wiring and connector positions.
- Whether the TFT is connected by EXP1/EXP2, serial, or both.

Save the current firmware and configuration files somewhere safe. This preserves a fallback if the first Klipper configuration is wrong.

### 2. Stabilize the Orange Pi host

- Use a supported 64-bit Ubuntu image for the exact Zero 3W board revision.
- Use a quality power supply and a reliable microSD card or other supported storage.
- Give the board a stable hostname or DHCP reservation.
- Enable SSH keys and keep SSH limited to the LAN.
- Connect the SKR by USB and confirm that `/dev/serial/by-id/` exposes a stable device.
- Do not expose Moonraker or SSH directly to the Internet.

If Ubuntu proves unstable under sustained USB or Wi-Fi use, keep the hardware plan but move the host to a better-supported Debian image rather than debugging Klipper and the OS at the same time.

### 3. Install the Klipper stack

Install one maintained stack, preferably **KIAUH**, or install the components manually:

- Klipper
- Moonraker
- Mainsail
- Optional: KlipperScreen only if a local HDMI/DSI display will be used

Use systemd services and persistent storage. Back up `printer.cfg`, macros, Moonraker configuration, and calibration data before upgrades.

### 4. Flash the SKR MCU

Build Klipper for the SKR Mini E3 V3.0 using the board's documented settings:

- STM32G0B1
- 8 KiB bootloader
- USB communication

Copy the generated `out/klipper.bin` to an SD card as `firmware.bin`, boot the SKR with that card, then connect it to the Orange Pi by USB. Confirm the MCU serial path before writing the printer configuration.

### 5. Start with a minimal printer configuration

Use Klipper's `generic-bigtreetech-skr-mini-e3-v3.0.cfg` as the pin-mapping base, then apply Ender 3 Pro dimensions and hardware values. Start with:

- X/Y/Z steppers and endstops
- Extruder and hotend thermistor
- Heated bed and bed thermistor
- Hotend, part-cooling, and controller fans
- Safe temperature limits
- Correct rotation distances and homing directions

Do not add input shaping, pressure advance, probe support, filament sensors, or custom macros until basic motion and heating are proven.

### 6. Commission safely

Test in this order:

1. MCU connects without errors.
2. Temperature readings are plausible at room temperature.
3. Heaters remain off until explicitly commanded.
4. Fans respond to commands.
5. Each axis moves a small distance in the expected direction.
6. Endstops report the correct state.
7. Home one axis at a time with a hand near the power switch.
8. Heat the hotend and bed separately and verify thermal shutdown behavior.
9. Run a small first-layer test.
10. Run a small calibration cube before longer prints.

Never reuse an old `printer.cfg` without checking every pin, thermistor, direction, and limit.

### 7. Tune for a better experience

After basic printing works:

- Set rotation distance and extrusion calibration.
- Tune bed mesh only if the bed and gantry are mechanically sound.
- Tune pressure advance.
- Add input shaping with an ADXL345 or compatible accelerometer if higher speed is a goal.
- Add a probe only if you want automated mesh creation; choose the probe and mount after deciding whether the existing Z endstop will remain.
- Add useful macros for `START_PRINT`, `END_PRINT`, pause, resume, cancel, load filament, and unload filament.
- Add a webcam only after the core printer is reliable.

## TFT decision

### Default: do not depend on the TFT

Use Mainsail as the primary UI. This is the lowest-risk route and gives the strongest user experience for remote operation.

### Later: attempt TFT integration

The GD TFT35 can be investigated after Klipper is stable:

- **Marlin mode:** may be usable as a simple local control surface, but it does not provide a native Klipper UI.
- **Community bridge:** can provide touch-mode support through an extra Klipper module and serial wiring, but it adds a third-party dependency and another failure mode.
- **Replacement display:** a supported KlipperScreen display is a cleaner local UI if a physical touchscreen is important.

Keep the TFT disconnected during initial bring-up unless local controls are a hard requirement.

## Rollback plan

Keep the original Marlin firmware and configuration. To roll back:

1. Stop Klipper and disconnect the Orange Pi.
2. Flash the known-good Marlin firmware to the SKR.
3. Reconnect the TFT using its original wiring.
4. Confirm endstops and temperature readings before heating or moving.

## Acceptance criteria

- The printer can be controlled from Mainsail over the LAN.
- A user can upload, start, pause, resume, and cancel a print remotely.
- The SKR reconnects after Orange Pi reboot without manual reconfiguration.
- Temperature, endstop, heater, fan, and motion tests pass.
- A first-layer test and calibration cube complete successfully.
- Configuration and calibration files are backed up.
- The TFT is either intentionally retired or documented as a separate follow-up.

## References

- [Klipper installation](https://www.klipper3d.org/Installation.html)
- [Klipper configuration reference](https://www.klipper3d.org/Config_Reference.html)
- [Klipper SKR Mini E3 V3.0 configuration](https://github.com/Klipper3d/klipper/blob/master/config/generic-bigtreetech-skr-mini-e3-v3.0.cfg)
- [BTT SKR Mini E3 V3.0 Klipper notes](https://github.com/bigtreetech/BIGTREETECH-SKR-mini-E3/tree/master/firmware/V3.0/Klipper)
- [Community BTT TFT bridge](https://github.com/oterek/klipper-btt-tft-bridge)
