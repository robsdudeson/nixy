# Orange Pi Zero 3W NixOS bring-up

This guide records the work needed to build a NixOS SD-card image for the Orange Pi Zero 3W 4GB.

## Current status

The board boots the vendor image and accepts SSH over Wi-Fi. Native NixOS support is not complete yet.

Known working board details:

- SoC: Allwinner A733 / `sun60iw2`.
- CPU: 2 Cortex-A76 cores and 6 Cortex-A55 cores.
- Architecture: `aarch64`.
- Device-tree model: `sun60iw2`.
- Compatible strings: `xunlong,orangepi-4-pro`, `arm,sun60iw2p1`.
- Vendor kernel: `6.6.98-sun60iw2`.
- Vendor OS: Orange Pi Resolute 26.04.
- Board device tree: `sun60i-a733-orangepi-zero3w.dtb`.
- Wi-Fi bus: SDIO.
- Wi-Fi driver: `aicwf_sdio`.
- Wi-Fi modules: `aic8800_fdrv` and `aic8800_btlpm`.
- Wi-Fi firmware directory: `/lib/firmware/aic8800d80/`.

The vendor system proves that the board, device tree, kernel, bootloader, Wi-Fi driver, and firmware work together.

## Source of truth

The official Orange Pi Zero 3W support page provides manuals, schematics, official images, tools, and source links:

<http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3W.html>

The relevant vendor repositories are:

- <https://github.com/orangepi-xunlong/orangepi-build>
- <https://github.com/orangepi-xunlong/linux-orangepi>
- <https://github.com/orangepi-xunlong/u-boot-orangepi>

`orangepi-build` already contains a board definition at:

```text
external/config/boards/orangepizero3w.conf
```

It selects:

```text
BOARDFAMILY=sun60iw2
BOOTCONFIG=sun60iw2p1_t736_defconfig
BOOT_FDT_FILE=allwinner/sun60i-a733-orangepi-zero3w.dtb
MODULES=aic8800_fdrv aic8800_btlpm
```

The matching family configuration selects the current vendor kernel:

```text
KERNELSOURCE=https://gitee.com/orangepi-xunlong/orange-pi-6.6-sun60iw2.git
KERNELBRANCH=branch:orange-pi-6.6-sun60iw2
LINUXCONFIG=linux-sun60iw2-current-a733
```

The GitHub mirror contains the matching branch:

```text
orange-pi-6.6-sun60iw2
```

The branch currently used for validation is pinned at:

```text
2ac08e8c7cdc28abbdc5c9a9dd812f887ae9c79f
```

Pin a reviewed commit in Nix expressions rather than following a moving branch.

## Build environment

An ARM64 Arch Linux VM on an Apple Silicon Mac is sufficient for kernel and image builds.

Recommended VM resources:

- 4 vCPUs.
- 8 GB RAM.
- 64 GB disk minimum; 100 GB is more comfortable.
- ARM64 guest architecture.
- USB card-reader passthrough when writing SD cards.

Install the host tools:

```sh
sudo pacman -Syu
sudo pacman -S --needed \
  git base-devel bc bison flex openssl libelf pahole cpio perl python \
  rsync dtc uboot-tools lz4 zstd xz unzip wget
```

Install Nix with the multi-user installer and enable flakes:

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
mkdir -p ~/.config/nix
printf 'experimental-features = nix-command flakes\n' \
  >> ~/.config/nix/nix.conf
```

For noninteractive SSH commands, make Nix available in `~/.zshenv`:

```sh
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
```

Verify the environment:

```sh
uname -s
uname -m
nix doctor
nix build 'nixpkgs#hello'
```

The expected architecture is `Linux` and `aarch64`.

## Fetch the vendor sources

```sh
mkdir -p ~/src
cd ~/src

git clone --filter=blob:none \
  https://github.com/orangepi-xunlong/orangepi-build.git

git clone --filter=blob:none \
  https://github.com/orangepi-xunlong/linux-orangepi.git

git clone --filter=blob:none \
  https://github.com/orangepi-xunlong/u-boot-orangepi.git
```

Check out the matching kernel branch:

```sh
cd ~/src/linux-orangepi
git fetch --depth=1 origin orange-pi-6.6-sun60iw2
git switch -C orange-pi-6.6-sun60iw2 FETCH_HEAD
```

Confirm the board files exist:

```sh
git ls-files | grep -E \
  'sun60i-a733-orangepi-zero3w|zero3w.*dts|aic8800'
```

## Collect information from a working vendor image

Run these commands on a board that boots the vendor image. Do not include Wi-Fi passwords, SSH private keys, or other secrets in shared output.

```sh
uname -a
cat /etc/os-release
cat /proc/device-tree/model
tr '\0' '\n' < /proc/device-tree/compatible
cat /boot/orangepiEnv.txt
ethtool -i wlan0
modinfo aic8800_fdrv
find /lib/firmware/aic8800d80 -maxdepth 1 -type f -printf '%f\n' | sort
```

Important files from the tested board were copied to a local working directory named `/tmp/orangepi-zero3w-info/`:

```text
boot.cmd
orangepiEnv.txt
config-6.6.98-sun60iw2
sun60i-a733-orangepi-zero3w.dtb
platform_install.sh
sun60iw2p1_t736_defconfig
orangepizero3w-u-boot.dts
boot_package.fex
```

These files are local investigation artifacts. Do not commit real credentials, board-specific private configuration, or opaque vendor binaries without checking their license and provenance.

## Boot layout

The vendor `boot.cmd` loads:

```text
uInitrd
uImage
dtb/allwinner/sun60i-a733-orangepi-zero3w.dtb
```

It then runs `bootm` with the kernel, initrd, and device tree.

The vendor U-Boot installer writes the SD-card boot package as follows:

```sh
dd if=boot0_sdcard.fex of=$device bs=8k seek=1 conv=fsync
dd if=boot_package.fex of=$device bs=8k seek=2050 conv=fsync
```

That is:

- `boot0_sdcard.fex` at 8 KiB.
- `boot_package.fex` at 16,400 KiB.

The first NixOS image should preserve this layout. Do not assume the Raspberry Pi extlinux layout applies.

## Kernel requirements

The vendor configuration is:

```text
~/src/orangepi-build/external/config/kernel/linux-sun60iw2-current-a733.config
```

Important settings include:

```text
CONFIG_ARCH_SUN60IW2=y
CONFIG_ARCH_SUN60IW2P1=y
CONFIG_AIC_WLAN_SUPPORT=y
CONFIG_AIC_INTF_SDIO=y
CONFIG_AIC8800_WLAN_SUPPORT=m
CONFIG_AIC8800_BTLPM_SUPPORT=m
CONFIG_BLK_DEV_INITRD=y
CONFIG_DEVTMPFS=y
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_EXT4_FS=y
```

The kernel source includes the AIC8800 driver. The driver expects firmware names that the vendor image packages under `/lib/firmware/aic8800d80/`. Keep the module and firmware versions matched to the kernel commit.

## Kernel build validation

Build the kernel out of tree. Run Kconfig separately before compiling:

```sh
cd ~/src/linux-orangepi
rm -rf build-zero3w
mkdir build-zero3w
cp ~/src/orangepi-build/external/config/kernel/linux-sun60iw2-current-a733.config \
  build-zero3w/.config

make O=build-zero3w ARCH=arm64 olddefconfig
make O=build-zero3w ARCH=arm64 -j"$(nproc)" Image
make O=build-zero3w ARCH=arm64 -j"$(nproc)" dtbs
make O=build-zero3w ARCH=arm64 -j"$(nproc)" modules
```

Do not request `Image modules dtbs` as parallel top-level goals with this vendor tree. Its Makefiles can race while regenerating `include/config/auto.conf`, producing a repeated:

```text
GEN Makefile
SYNC include/config/auto.conf
```

Build the goals sequentially instead.

Expected outputs include:

```text
build-zero3w/arch/arm64/boot/Image
build-zero3w/arch/arm64/boot/dts/allwinner/sun60i-a733-orangepi-zero3w.dtb
```

### GNU Make 4.4 compatibility

The vendor branch still uses the pre-GNU-Make-4.3 multi-target Kconfig rule:

```make
%/config/auto.conf %/config/auto.conf.cmd %/generated/autoconf.h %/generated/rustc_cfg: $(KCONFIG_CONFIG)
```

GNU Make 4.4 can repeatedly regenerate these files and loop on `GEN Makefile` / `SYNC include/config/auto.conf`. The rule should use a grouped target instead:

```make
%/config/auto.conf %/config/auto.conf.cmd %/generated/autoconf.h %/generated/rustc_cfg &: $(KCONFIG_CONFIG)
```

However, this patch alone did not make the vendor branch build successfully. The branch also contains an older backport of Kbuild's GNU Make 4.4.1 directory-recursion logic. On the ARM64 VM, both normal out-of-tree builds and explicit `--no-print-directory` builds continued to repeat `GEN Makefile` and `SYNC include/config/auto.conf` without compiling an object.

Record this as an unresolved vendor-build compatibility issue. The next options are:

- Build with the exact toolchain used by the vendor image, including its supported GNU Make version.
- Compare and backport the complete upstream Kbuild recursion fix rather than only the grouped-target change.
- Use `orangepi-build` as the reference build until the kernel can be packaged reproducibly.

Do not silently change the pinned upstream source; carry any eventual change as an explicit Nix patch when packaging the kernel.

## NixOS integration plan

Start with a minimal image, not Klipper.

1. Package the vendor kernel source and pinned configuration.
2. Package the AIC8800 modules and firmware.
3. Package the exact device tree.
4. Reuse or package the vendor U-Boot boot package.
5. Add a custom SD-image post-build step for the two boot offsets.
6. Generate `uImage`, `uInitrd`, and the board device tree in the layout expected by the vendor boot script, or replace the script with a tested NixOS-compatible U-Boot script.
7. Configure Wi-Fi DHCP, OpenSSH, a non-root user, and temporary password authentication.
8. Boot from a spare microSD card and test Wi-Fi SSH, reboot, and recovery.
9. Add SSH keys and disable password login.
10. Add Klipper, Moonraker, and a frontend only after the base host is stable.

The real host belongs in `nixy-priv`. Keep this public repository limited to reusable hardware modules, sanitized examples, tests, and this bring-up guide.

## Recovery and safety

- Keep the current working vendor SD card untouched.
- Use a second microSD card for NixOS experiments.
- Confirm the target block device before writing an image.
- A 3-pin USB-TTL serial adapter is strongly recommended because Ethernet is unavailable.
- Keep the vendor image available for recovery.
- Do not publish Wi-Fi credentials, password hashes, SSH private keys, or private host names.
- Do not publish vendor binaries until their redistribution terms are clear.

## Alternative operating systems

As of the current bring-up, there is no known ready-made immutable image for this exact board that also supports its vendor A733 boot chain and AIC8800 Wi-Fi.

| Option | Board image | Immutable updates | Assessment |
| --- | --- | --- | --- |
| **DietPi** | Yes. DietPi 10.6 added Zero 3W images using the vendor Linux 6.6 kernel and U-Boot. | No | Best turnkey path if a mutable Debian-family system is acceptable. |
| **Fedora IoT** | No known Zero 3W image. Official AArch64 validation lists Raspberry Pi 3, DragonBoard, and Pine64. | Yes, OSTree/rpm-ostree | Good model, but still requires board image and kernel integration. |
| **openSUSE MicroOS** | No known Zero 3W image. Generic ARM64 images expect a standard UEFI boot environment. | Yes, transactional Btrfs | Poor fit for the vendor U-Boot/SD-card layout without custom boot work. |
| **Ubuntu Core** | No known Zero 3W device model, kernel snap, or gadget snap. | Yes, snap-based image updates | Requires a custom device enablement project. |
| **balenaOS** | The supported-device list does not include Zero 3W. | Yes, image-based | Requires custom board support; not a ready-made option. |
| **Mender/RAUC** | Can update a vendor Debian image. | Update mechanism, not a distro | Useful later, but still requires custom board integration and image layout. |

Sources:

- [DietPi 10.6 release notes](https://dietpi.com/docs/releases/v10_6/)
- [Fedora IoT release criteria](https://fedoraproject.org/wiki/InternetOfThings/IoT_Release_Criteria)
- [openSUSE supported ARM boards](https://en.opensuse.org/openSUSE:Supported_ARM_boards)
- [openSUSE MicroOS](https://get.opensuse.org/microos/)
- [balena supported hardware](https://docs.balena.io/reference/hardware/devices)
- [Mender device support](https://docs.mender.io/overview/device-support)

### Arch-family options

Arch-specific support is also limited:

- **Orange Pi OS (Arch):** Orange Pi's Zero 3W support page links an Arch image folder, but the folder is currently empty. It is therefore not a usable installation source today: <https://drive.google.com/drive/folders/1OVsCZX2OPQEs6EcF9G-8-I0rJRszMWzp?usp=sharing>.
- **Arch Linux ARM:** A generic AArch64 root filesystem is not a board image. It does not provide the Zero 3W's vendor U-Boot artifacts, A733 device tree, kernel modules, or AIC8800 firmware. It can be used as a userspace on top of a working vendor/Armbian boot, but that is still a custom integration.
- **Manjaro ARM:** The existing `opi-zero3` project targets the older Allwinner H618 Orange Pi Zero 3. It must not be treated as support for the A733 Zero 3W. Manjaro's current supported-device information does not list the Zero 3W.
- **Armbian:** The community Zero 3W support is real and tested, but the standard images are Debian-family images, not Arch images. An Arch root filesystem could be layered onto its boot and kernel support, but that would be a custom port.

There is no ready-made Arch image for the Zero 3W at present. The most credible Arch solution is a hybrid: use the proven Armbian/vendor bootloader, kernel, DTB, modules, and AIC8800 firmware, then replace the Debian root filesystem with the official Arch Linux ARM AArch64 root filesystem. This keeps the board-specific risk in the known-good boot stack while providing a normal rolling Arch userspace. It is custom, but substantially less work than porting boot support into Arch from scratch.

### Recommendation

For this board, choose one of these paths:

1. **Lowest engineering cost:** use the official vendor image or DietPi, then run Klipper and Moonraker as systemd services. Add systemd-sysupdate, Mender, or RAUC only if atomic updates become important.
2. **Immutable requirement:** keep pursuing a custom Fedora IoT, MicroOS, or Ubuntu Core port. This does not eliminate board work; it moves the work from NixOS to the distro's image, kernel, bootloader, and Wi-Fi integration.
3. **Lowest long-term maintenance:** change to a board with a first-class immutable image and upstream kernel support. The Zero 3W's current dependency on vendor Linux 6.6, vendor U-Boot, and AIC8800 firmware is the main maintenance risk.

For the current hardware, DietPi is the best fallback, but it is not immutable. A true immutable deployment still requires us to own a small amount of board-specific integration.

## Related plan

See [`plans/20261103182356-orangepi-zero3w-klipper-host.md`](plans/20261103182356-orangepi-zero3w-klipper-host.md) for the implementation plan and acceptance gates.
