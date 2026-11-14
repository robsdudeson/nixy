---
title: "feat: Bootstrap an Orange Pi Zero 3 Klipper host"
type: feat
status: draft
date: 2026-11-03T18:23:56Z
---

# Bootstrap an Orange Pi Zero 3W Klipper host

## Goal

Build a reproducible SD-card image for an Orange Pi Zero 3W 4GB that boots, joins the local Wi-Fi network, enables SSH password login, and leaves a clean path to SSH keys and Klipper services later.

The Orange Pi Zero 3W is different from the Orange Pi Zero 3. Its official specification lists the Allwinner A733, two Cortex-A76 plus six Cortex-A55 cores, LPDDR5, Wi-Fi 6/Bluetooth 5.4, and TF/microSD storage. Confirm the PCB revision before implementation.

## Recommendation

Do not start by building a NixOS image. The Zero 3W uses the newer Allwinner A733, so H618/Zero 3 boot instructions do not apply. First boot the vendor Debian/Ubuntu image and prove Wi-Fi and SSH. Because Ethernet is unavailable, obtain a USB-TTL serial adapter if possible; it is the best recovery path for a headless board.

Use a small ARM64 Linux VM on the Mac for reproducible image-building tools and private-repository work. The VM will not emulate the board. If native NixOS support is missing, keep the vendor image and install Klipper there first. Revisit a native NixOS SD image after the board kernel, device tree, bootloader, and Wi-Fi firmware have been identified.

Keep two viable deployment paths:

1. **Preferred long-term:** a native NixOS SD image once A733 support is verified.
2. **Pragmatic first host:** vendor Debian/Ubuntu with Nix-managed configuration and Klipper services.

Do not begin with Klipper. First prove the board boot, Wi-Fi, SSH, and recovery path.

## Scope boundaries

### First milestone

- Generate an uncompressed `.img` or `.img.zst` from the flake.
- Write it to a microSD card.
- Boot the Orange Pi from the card.
- Obtain a DHCP lease on the configured Wi-Fi network.
- Find the host by DHCP lease or a temporary hostname/IP discovery method.
- SSH to the host using a named non-root user and a password.
- Verify reboot persistence and basic diagnostics.

### Not in the first milestone

- Klipper, Moonraker, Fluidd/Mainsail, webcam, GPIO, or printer MCU wiring.
- SSH key authentication as the only login method.
- Public exposure, port forwarding, or automatic router changes.
- Secrets committed to this public repository.
- Board overclocking, thermal tuning, or performance claims.

## Design decisions

### 1. Separate generic headless behavior from board support

Extract or reuse a generic headless NixOS module for:

- OpenSSH.
- DHCP or NetworkManager/systemd-networkd policy.
- Firewall policy with TCP/22 enabled only on the local network path.
- A named normal user in `wheel`.
- Small diagnostic tools.

Create an Orange Pi module for only the hardware-specific concerns:

- `aarch64-linux` platform.
- A733 kernel and device tree.
- Board-specific U-Boot and SD-card layout.
- Board-specific wireless firmware and driver.
- Console UART and Wi-Fi defaults.

Do not reuse `modules/nixos/raspberry-pi.nix` for this board. Its extlinux and filesystem defaults may be useful patterns, but the boot chain must be verified independently.

### 2. Keep real identity and credentials private

Put the real Orange Pi host in `nixy-priv`, not this public example repository. The public repository may contain a fake-safe example host and tests, but not the real hostname, Wi-Fi SSID, password, password hash, SSH keys, or LAN inventory.

For the first image, pass a password hash through a private/local ignored input. Never put a plaintext password in Nix source or a committed environment file. Prefer a private overlay module with `users.users.<name>.hashedPasswordFile`, or a local image-generation wrapper that prompts for the password and creates a temporary hash file.

Treat a password hash as sensitive because it enters the built system's closure. Plan to enable key authentication and disable password authentication after first access.

### 3. Choose network configuration deliberately

Use NetworkManager or systemd-networkd consistently; do not mix ad-hoc `wpa_supplicant` configuration with the selected manager. The first implementation should support:

- Wi-Fi SSID and passphrase supplied from private configuration.
- DHCP on Wi-Fi.
- Serial-console recovery, since Ethernet is unavailable.
- A stable hostname.
- A documented way to discover the DHCP address.

Avoid embedding Wi-Fi credentials in a public SD image. If the image must be generated on a trusted machine, use a private module or secret provisioning step and document that the credentials are present in the resulting image/closure.

## Implementation phases

### Phase 0 — Confirm hardware and toolchain

- Confirm the exact Zero 3W PCB revision and 4 GB variant.
- Confirm microSD size and power supply.
- Obtain or identify a 3-pin USB-TTL serial adapter; Ethernet is not available.
- Confirm whether an ARM64 Linux VM on the Mac is acceptable for the build environment.
- Put the real host configuration in `nixy-priv` immediately.

**Gate:** no image work starts until the board identity and recovery path are known.

### Phase 1 — Establish board support

- Inspect current Linux/U-Boot support for the A733 and this exact Zero 3W revision; do not reuse H618/Zero 3 support.
- First boot the vendor Debian/Ubuntu image and validate Wi-Fi, SSH, reboot, and serial logging.
- Use the vendor image to identify the Wi-Fi chipset, firmware files, device-tree name, boot media layout, and kernel version.
- Evaluate whether a maintained mainline or vendor kernel can be packaged for NixOS. If not, keep the vendor image as the base and run Nix-managed services on it.
- Add focused Nix evaluation tests only after a concrete kernel/U-Boot/device-tree source is selected.

**Gate:** the board reaches a login or SSH service over Wi-Fi, and serial output or a documented SD-card recovery procedure exists.

### Phase 2 — Add Wi-Fi and password SSH

- Add private Wi-Fi configuration using the chosen network manager.
- Add the Wi-Fi firmware and driver identified from the vendor image.
- Enable OpenSSH and local firewall access.
- Define a non-root administrative user with a private password hash.
- Keep root SSH login disabled.
- Keep password authentication enabled only for the bootstrap period.
- Add a first-boot verification checklist: interface state, route, DNS, DHCP lease, SSH listener, reboot, and reconnect.

**Gate:** a freshly written card boots without a monitor, joins Wi-Fi, and accepts one password SSH login from the LAN.

### Phase 3 — Add key authentication and lock down access

- Add the user's SSH public key from private configuration or a secret manager.
- Test key login while password login remains available.
- Disable SSH password authentication after key login succeeds.
- Rotate or remove the bootstrap password.
- Restrict SSH to the LAN if the router/firewall model supports it.
- Record recovery steps using the SD card or UART before locking down access.

**Gate:** key login works after reboot and password login is rejected; recovery remains documented.

### Phase 4 — Add the Klipper host

- Add a separate Klipper profile rather than coupling it to board boot code.
- Package or enable Klipper, Moonraker, and one frontend only after the base host is stable.
- Decide how printer MCU USB access is declared and tested.
- Add service users, persistent state, backups, and update/rollback procedures.
- Validate temperature, storage, and power behavior during a long print before enabling unattended updates.

## Proposed repository shape

Public repository:

- `modules/nixos/headless.nix` — reusable SSH/firewall/DHCP defaults.
- `modules/nixos/orange-pi-zero3w.nix` — board-specific options and boot assumptions, only if they are safe to publish.
- `hosts/example-aarch64-orangepi-zero3w/default.nix` — fake-safe evaluation target.
- `tests/nixos/orange-pi-zero3w-test.nix` — option and boot-layout assertions.
- `docs/orangepi-zero3w.md` — supported hardware, image workflow, recovery, and known limitations.

Private repository:

- Real hostname and user.
- Wi-Fi credentials.
- Password hash or provisioning secret.
- SSH public keys and any private deployment metadata.
- Real image build/deploy commands.

Possible flake outputs:

- `nixosConfigurations.example-aarch64-orangepi-zero3w` — public-safe evaluation target.
- `nixosConfigurations.<real-orangepi-host>.config.system.build.sdImage` — private target.
- A separate `packages.aarch64-linux.<board>-sd-image` only if the image needs custom post-build steps.

## Verification plan

### Static and evaluation checks

- `nix flake check` succeeds.
- The example configuration evaluates without private inputs.
- The SD image derivation has the expected platform, kernel, U-Boot, device tree, filesystem labels, and firmware.
- Tests assert that Raspberry Pi modules are not imported by the Orange Pi host.
- Tests assert that password authentication is enabled only in the bootstrap profile and root SSH remains disabled.

### Hardware checks

- Write the image with a tool that verifies the target device before destructive writing.
- Capture serial output during the first boot when possible.
- Confirm boot, Wi-Fi association, DHCP, DNS, SSH, reboot, and reconnect.
- Confirm serial-console or SD-card recovery before making Wi-Fi the only path.
- Record kernel logs for Wi-Fi firmware failures and throttling/undervoltage warnings.

### Security checks

- No plaintext Wi-Fi password or SSH password in Git.
- No real credentials in a derivation that is pushed to a public cache.
- SSH root login disabled.
- SSH exposed only on the intended LAN.
- Key authentication tested before password authentication is disabled.

## Risks and fallback criteria

- **Board support risk:** A733 support may require an external kernel, device tree, bootloader, or firmware overlay. If the native NixOS image cannot boot over Wi-Fi within the first implementation pass, use the vendor Debian/Ubuntu image and keep native support as a separate work item.
- **Wi-Fi risk:** Wi-Fi may depend on vendor firmware or a kernel patch. Treat serial console or SD-card replacement as the recovery path.
- **Power/storage risk:** use a known-good USB-C supply and high-quality microSD card; do not debug software from an unstable power source.
- **Cross-build risk:** building the kernel on macOS may be slow or unsupported. Prefer a pinned `aarch64-linux` builder for image builds and keep the coordinator's flake evaluation separate from the builder's compilation.
- **Secret leakage risk:** Wi-Fi credentials and password hashes can enter the Nix store. Keep the real build private and document this explicitly.

## Initial hardware findings

Collected from the running board over SSH on 2026-11-03:

- Device-tree model: `sun60iw2`.
- Compatible strings: `xunlong,orangepi-4-pro`, `arm,sun60iw2p1`.
- Kernel: `6.6.98-sun60iw2`, aarch64, vendor build `1.0.2`.
- Device tree: `allwinner/sun60i-a733-orangepi-zero3w.dtb`.
- OS: `Orange Pi 1.0.2 Resolute`, version `26.04`.
- CPU: 8 cores: 2 Cortex-A76 and 6 Cortex-A55.
- Wi-Fi: SDIO device using the `aicwf_sdio` driver and `aic8800_*` modules.
- Wi-Fi firmware: `/lib/firmware/aic8800d80/`, including `fmacfw_8800d80_*` and Bluetooth firmware.
- Wi-Fi is working at 5 GHz with roughly `-53 dBm` signal and 200 Mbit/s link rate.
- Vendor packages include `linux-image-current-sun60iw2`, `linux-dtb-current-sun60iw2`, `linux-u-boot-orangepizero3w-current`, `orangepi-bsp`, and `orangepi-firmware`.
- Boot configuration sets `overlay_prefix=sun60i-a733` and the Zero 3W device tree.

These findings confirm that the board is an A733/Sun60iw2 target with vendor-specific kernel, U-Boot, device tree, Wi-Fi driver, and firmware. The next research target is packaging or reusing these exact components, not H618 support.

Additional files fetched to `/tmp/orangepi-zero3w-info/`:

- `boot.cmd` — U-Boot loads `uInitrd`, `uImage`, and `dtb/${fdtfile}`, then runs `bootm`.
- `orangepiEnv.txt` — sets the A733 device tree and an ext4 root UUID.
- `config-6.6.98-sun60iw2` — vendor kernel configuration.
- `sun60i-a733-orangepi-zero3w.dtb` — working board device tree.
- `platform_install.sh` — documents the SD-card boot layout.
- `sun60iw2p1_t736_defconfig` and `orangepizero3w-u-boot.dts` — vendor U-Boot metadata.
- `boot_package.fex` — vendor A733 boot package.

The SD-card installer writes `boot0_sdcard.fex` at 8 KiB and `boot_package.fex` at 16,400 KiB. The kernel configuration confirms the non-upstream AIC wireless path: `CONFIG_AIC_WLAN_SUPPORT=y`, SDIO transport, and modular `CONFIG_AIC8800_WLAN_SUPPORT`/`CONFIG_AIC8800_BTLPM_SUPPORT`. This gives us a concrete first implementation path: preserve the vendor boot layout, package the vendor kernel and modules, include the exact DTB and firmware, and let NixOS provide the root filesystem and userspace.

## External research used

- Orange Pi's official Zero 3W specification: Allwinner A733, two Cortex-A76 plus six Cortex-A55 cores, LPDDR5, Wi-Fi 6/Bluetooth 5.4, and TF/microSD storage.
- Orange Pi's official Zero 3W support page provides user-manual, schematic, mechanical, tool, Ubuntu, Debian, Android, Android source, and Linux source links. It does not provide a NixOS image or NixOS board module.
- The linked Orange Pi repositories expose the relevant source path: `orangepi-build` contains A733/sun60iw2 kernel configs, while the Orange Pi Linux and U-Boot repositories are the likely source for the vendor kernel and bootloader.
- Existing repository patterns: `modules/nixos/raspberry-pi.nix`, `hosts/example-aarch64-rpi/default.nix`, and the QEMU validation plan. These are structural references only; the Zero 3W is not an H618 or Raspberry Pi target.
- Earlier H618/Orange Pi Zero 3 Nix projects are not directly applicable and must not be reused without verifying the SoC and device tree.

## Open questions before implementation

1. What exact PCB revision and Wi-Fi chipset does the board report or show in its manual?
2. Can you obtain a 3-pin USB-TTL serial adapter for first boot and recovery?
3. Is the vendor Debian/Ubuntu image acceptable as a fallback if native NixOS support is not ready?
4. Should the first Linux build environment be a local ARM64 Linux VM, or should we configure a remote `aarch64-linux` builder?
5. What Wi-Fi network manager and secret-provisioning approach should the private host use?
