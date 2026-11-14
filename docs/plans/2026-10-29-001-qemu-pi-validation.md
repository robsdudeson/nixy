---
title: "feat: Add an ARM64 QEMU validation path for Raspberry Pi configuration"
type: feat
status: active
date: 2026-10-29
---

# feat: Add an ARM64 QEMU validation path for Raspberry Pi configuration

## Overview

Add a fake-safe, ARM64 NixOS VM target that runs on the Apple Silicon macOS development host. It will validate the shared NixOS, Home Manager, headless-service, and application configuration before that configuration reaches a real Raspberry Pi.

The VM is a fast configuration-test environment, not a replacement for hardware testing. It will use QEMU's generic ARM `virt` machine rather than emulate a Pi board. A real Pi remains required for Raspberry Pi firmware, U-Boot/extlinux boot, device trees, Wi-Fi/Bluetooth, GPIO/HATs, storage, and performance checks.

---

## Problem Frame

The repository has an `aarch64-linux` Pi 4 example, but it only proves evaluation and a toplevel build. Its configuration combines reusable headless concerns with Pi-specific boot and storage defaults, and it has no runnable VM output. Developers therefore cannot boot the reusable configuration locally before writing an SD card or changing a private hardware host.

The new VM target must preserve the public/private boundary: it must use fake-safe identity and no network inventory, SSH keys, secrets, or private host data. It must make the intended validation boundary explicit in both code and docs: validate shared configuration in QEMU first, then test physical-Pi concerns on the target hardware.

---

## Requirements Trace

### VM Platform and Output

- R1. Expose a fake-safe `aarch64-linux` NixOS VM configuration and a runnable VM artifact from the flake.
- R2. Make the VM runner work from the repository's Apple Silicon (`aarch64-darwin`) development environment by supplying Darwin-host QEMU packages while retaining an ARM64 Linux guest.

### Shared Runtime and Pi Isolation

- R3. Share headless runtime behavior—OpenSSH policy, firewall opening, DHCP defaults, and troubleshooting packages—between the Pi and VM paths without copying those settings.
- R4. Keep Pi firmware, bootloader, SD-card filesystem labels, and `nixos-hardware` board configuration out of the VM.
- R5. Retain existing Raspberry Pi behavior and tests for the physical-host configuration.

### Validation and Operations

- R6. Add automated evaluation/build coverage for the VM output and its shared module seam.
- R7. Document what the VM validates, what only a real Pi validates, and the supported build/run workflow.
- R8. Preserve the public-safe example-host and `nixy-priv` ownership boundaries.

---

## Scope Boundaries

- Do not use QEMU's `raspi4b` machine as the primary validation target. Its device coverage is incomplete, including PCIe, GENET Ethernet, and PWM.
- Do not claim that a successful VM boot proves Pi firmware, device-tree overlays, GPIO/HATs, wireless, Bluetooth, or hardware performance.
- Do not add real hostnames, users, LAN policy, credentials, or SSH material to this public repository.
- Do not change the private-repository host contract or deploy the VM configuration to a physical host.
- Do not add a graphical desktop or model peripheral devices in this first VM target; the target is a serial, headless configuration validation environment.

### Deferred to Follow-Up Work

- A Pi-board-specific `raspi4b` smoke test, if a future configuration needs the subset of emulated peripherals that QEMU supports.
- Automated end-to-end boot assertions with the NixOS test driver, after the runnable VM path is stable and concrete service behavior warrants it.
- Pi-specific image generation and hardware acceptance automation for `nixy-priv` hosts.

---

## Context & Research

### Relevant Code and Patterns

- `flake.nix` defines the isolated `nixpkgs-rpi` / `home-manager-rpi` input line and the existing fake-safe `nixosConfigurations.example-aarch64-rpi` output. The VM should remain on that ARM64 NixOS input line while using host packages only for the macOS QEMU runner.
- `hosts/example-aarch64-rpi/default.nix` composes the reusable common and Pi modules, Home Manager, an `example` user, and state version `26.05`. It is the source pattern for the VM's fake-safe identity and shared user composition.
- `modules/nixos/raspberry-pi.nix` currently owns both generic headless behavior and Pi-only boot/storage defaults. The shared behavior needs an explicit generic module boundary before the VM can reuse it safely.
- `modules/nixos/common.nix` provides generic NixOS defaults and shared Home Manager settings. Both physical and virtual ARM64 hosts should continue to use it.
- `tests/nixos/raspberry-pi-test.nix` uses focused `lib.evalModules` assertions; add equivalent coverage at the extracted runtime seam rather than relying only on a full system build.
- `README.md` and `docs/operations.md` define the fake-safe host and build-before-switch contract. They are the appropriate public entry points for explaining VM-first validation.

### Institutional Learnings

- There is no `docs/solutions/` directory or prior QEMU-specific learning. The repository's existing fake-safe public outputs provide the applicable institutional pattern: public examples prove reusable composition, while real hosts and private inventory live in `nixy-priv`.

### External References

- [NixOS VM tutorial](https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html): a NixOS configuration can produce `system.build.vm` and a `run-nixos-vm` runner.
- [NixOS QEMU wiki](https://wiki.nixos.org/wiki/Qemu): cross-platform VM runners use host-platform QEMU packages; this informs the Darwin-host/Linux-guest split.
- [NixOS Raspberry Pi guide](https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi): Pi boards boot through Pi firmware and U-Boot and use board profiles that select downstream kernels and device-tree support.
- [QEMU Raspberry Pi board support](https://www.qemu.org/docs/master/system/arm/raspi.html): `raspi4b` exists but omits PCIe, GENET Ethernet, and PWM, so it is not the main configuration-validation target.

---

## Key Technical Decisions

- **Use a generic ARM64 QEMU VM, not board emulation.** QEMU's `virt` machine offers a stable virtual platform for service and configuration testing. The physical Pi target retains board-specific firmware, storage, and kernel setup.
- **Separate headless runtime defaults from Pi boot defaults.** A new generic module will own SSH, firewall, DHCP, and diagnostic-package policy. The Pi module will enable or compose that module while keeping its firmware, extlinux, and SD-card concerns isolated.
- **Keep the guest `aarch64-linux` but use `aarch64-darwin` host packages for the runner.** The VM configuration will use NixOS's host-package seam so its generated runner invokes macOS-compatible QEMU. This supports local Apple Silicon testing rather than producing a Linux-only launcher.
- **Expose both a configuration and a runnable artifact.** The configuration makes the VM inspectable and easy for private overlays to reuse; the artifact provides the normal local boot path. Flake checks will cover evaluation/buildability but will not launch an emulator in every check.
- **Use a serial, headless VM.** This matches the existing Pi module's administration model, lowers runner complexity, and validates SSH/service behavior without adding desktop or virtual GPU concerns.
- **Document a two-stage validation contract.** The docs will state exactly what QEMU validates and list the hardware-only acceptance checks that still gate deployment.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
shared runtime module
  ├── common NixOS defaults
  ├── headless runtime defaults (SSH, firewall, DHCP, diagnostics)
  └── fake-safe Home Manager/user composition
             │
             ├── Pi host: Pi firmware + extlinux + SD mounts + Pi 4 hardware profile
             └── QEMU host: qemu-vm runner + generic virt disks/network + Darwin host QEMU

QEMU boot proves: shared runtime and services start
Real Pi boot proves: board firmware, kernel/device tree, hardware, and performance
```

---

## Implementation Units

- [ ] U1. **Extract reusable headless runtime defaults**

**Goal:** Create a generic NixOS module for the headless settings that both the Pi and QEMU hosts need, leaving the Raspberry Pi module responsible only for Pi-specific behavior.

**Requirements:** R3, R4, R5, R8

**Dependencies:** None

**Files:**
- Create: `modules/nixos/headless.nix`
- Modify: `modules/nixos/raspberry-pi.nix`
- Modify: `tests/nixos/raspberry-pi-test.nix`
- Create: `tests/nixos/headless-test.nix`
- Modify: `flake.nix`

**Approach:**
- Move the configuration that is not tied to Pi firmware or storage—OpenSSH defaults, port-22 firewall rule, DHCP/firewall defaults, diagnostic packages, and extension points—behind a named generic module and opt-in option.
- Keep `machine.raspberry-pi.enable` as the physical-host entry point. Make it compose the generic behavior so existing Pi hosts retain their observable defaults without changing their host definitions.
- Retain only Pi-specific firmware, extlinux bootloader, and SD-card mount defaults in `modules/nixos/raspberry-pi.nix`.
- Preserve opt-in behavior and override semantics so private Pi configurations can still disable SSH, package installation, or the firewall port as they can today.

**Patterns to follow:**
- `modules/nixos/common.nix` for an opt-in NixOS module with options and `mkIf`/`mkMerge` configuration.
- `modules/nixos/raspberry-pi.nix` and `tests/nixos/raspberry-pi-test.nix` for options, defaults, and focused module evaluation.

**Test scenarios:**
- Happy path: enabling the new generic module enables the current headless SSH, firewall, DHCP, and diagnostic-package defaults.
- Edge case: disabling SSH or the SSH firewall option changes only the corresponding service/port behavior.
- Edge case: adding extra packages appends them without removing the standard diagnostic packages.
- Integration: enabling the Pi module preserves its existing headless defaults while also retaining Pi firmware, extlinux, and SD-card mount settings.
- Error path: with neither module enabled, no headless or Pi boot defaults leak into a consuming host.

**Verification:** Focused module tests pass, the existing Pi test still covers its physical defaults, and the public Pi configuration evaluates unchanged except for the intentional internal module boundary.

---

- [ ] U2. **Add the fake-safe ARM64 QEMU host and VM artifact**

**Goal:** Define a generic ARM64 NixOS VM that shares the extracted runtime configuration and can generate a macOS-runnable QEMU launcher.

**Requirements:** R1, R2, R3, R4, R6, R8

**Dependencies:** U1

**Files:**
- Create: `hosts/example-aarch64-qemu/default.nix`
- Modify: `flake.nix`
- Modify: `tests/nixos/headless-test.nix` if the VM needs an option-level assertion beyond U1

**Approach:**
- Add `nixosConfigurations.example-aarch64-qemu` on the existing `aarch64-linux` Raspberry Pi input line, with the same fake-safe `example` identity and Home Manager composition as the Pi example.
- Import the NixOS QEMU VM module and configure a headless, generic virtual ARM machine with virtual storage and user-mode networking.
- Define one local access contract: bind a fixed loopback-only host port (for example, `127.0.0.1:2222`) to guest TCP/22 through `virtualisation.forwardPorts`; document the exact `ssh` command, the occupied-port failure, and how to choose an alternate port without opening the VM to the LAN.
- Add an explicit `machine.headless.authorizedKeys`-style option for the example VM. In `flake.nix`, read `builtins.getEnv "NIXY_VM_SSH_PUBLIC_KEY"` only for the VM output, pass it as `specialArgs.vmSshPublicKey`, and make `hosts/example-aarch64-qemu/default.nix` validate it before the VM derivation builds. Use a small build-time validation derivation that writes the supplied one-line value to a temporary file and runs `ssh-keygen -lf` from `pkgs.openssh`; make the VM output depend on that derivation. This checks the complete OpenSSH wire format and that the embedded algorithm matches the textual type—not merely a base64-looking value. Reject an empty, multiline, malformed, or private-key value with a message that names `NIXY_VM_SSH_PUBLIC_KEY`. Inject the public key into `users.users.example.openssh.authorizedKeys.keys`; retain disabled password authentication. Document this exact command: `export NIXY_VM_SSH_PUBLIC_KEY="$(< "$HOME/.ssh/nixy-vm_ed25519.pub")"; nix build --impure .#nixosConfigurations.example-aarch64-qemu.config.system.build.vm`. State that the public key enters the VM closure, then document disk reset and key-rotation cleanup.
- Set the NixOS VM host package collection to the `aarch64-darwin` package set derived from the same pinned Nixpkgs input. The generated runner must use Darwin-compatible QEMU rather than a Linux QEMU binary.
- Define a remote `aarch64-linux` builder as the supported guest-closure contract. The documented matrix has two explicit rows: an `aarch64-darwin` coordinator evaluates the impure VM output, realizes the native QEMU runner, and runs it; an `aarch64-linux` remote builder builds the guest closure. Document a local-only setup using an SSH-config alias: `export NIXY_REMOTE_BUILDER=<ssh-alias>; export NIX_CONFIG="builders = ssh-ng://$NIXY_REMOTE_BUILDER aarch64-linux - 4 1"`; verify it with `nix store ping --store "ssh-ng://$NIXY_REMOTE_BUILDER"`. State that the builder must be a trusted `aarch64-linux` Nix daemon and that its SSH authorization remains outside this public repository. From a clean Apple Silicon coordinator, run the exact `NIXY_VM_SSH_PUBLIC_KEY` build command, then `./result/bin/run-nixos-vm`; confirm the generated script selects `aarch64-darwin` QEMU and includes only the loopback forwarding rule before testing SSH. Keep static Darwin-runner evaluation and ARM64 Linux guest-closure checks separate from this end-to-end coordinator gate.
- Enable `machine.common` and the extracted generic headless module. Do not import `nixos-hardware`'s Raspberry Pi profile or `machine.raspberry-pi`.
- Export the VM build output through the configuration's `system.build.vm` and add an ARM64 Linux flake check that proves the configuration and VM derivation remain evaluable/buildable. Keep normal checks non-interactive and do not boot QEMU inside `nix flake check`.
- Choose a stable output name and document it; preserve the existing `example-aarch64-rpi` output and check.

**Patterns to follow:**
- `flake.nix` public example configuration and per-system check conventions.
- `hosts/example-aarch64-rpi/default.nix` fake-safe user/Home Manager composition.
- NixOS's QEMU VM module and `virtualisation.host.pkgs` host-runner boundary.

**Test scenarios:**
- Happy path: the QEMU configuration evaluates locally and exposes a non-null VM build artifact through the configured remote `aarch64-linux` builder.
- Integration: a Darwin evaluation assertion proves `virtualisation.host.pkgs` resolves to `aarch64-darwin` QEMU, while the remote builder receives only the `aarch64-linux` guest closure; the generated runner references the former and boots the latter.
- Integration: the runner forwards only the selected loopback host port to guest TCP/22; an SSH connection using the supplied disposable key succeeds, while password authentication and non-loopback access remain disabled.
- Error path: an absent, multiline, private, or syntactically base64-but-invalid `NIXY_VM_SSH_PUBLIC_KEY`, an occupied forwarded port, or an unavailable compatible remote builder produces the documented failure and recovery path before the VM is started.
- Integration: the VM host imports the generic headless module and does not import the Raspberry Pi hardware profile or Pi boot module.
- Edge case: building or evaluating the Pi configuration still uses the Pi hardware profile; building or evaluating the VM does not introduce `NIXOS_SD` or `FIRMWARE` mount assumptions.
- Error path: a configuration that accidentally composes Pi boot defaults into the VM fails its focused configuration assertion or check.

**Verification:** The VM artifact builds from the intended development environment or documented Linux-builder path, its runner reaches a serial NixOS boot prompt, and the existing Pi output continues to evaluate independently.

---

- [ ] U3. **Document the VM-first and hardware-final validation workflow**

**Goal:** Make the intended test boundary discoverable so future Pi changes use the VM before hardware without treating it as hardware certification.

**Requirements:** R7, R8

**Dependencies:** U2

**Files:**
- Modify: `README.md`
- Modify: `docs/operations.md`
- Create: `docs/qemu-pi-validation.md`

**Approach:**
- Add a concise README pointer to the new public QEMU example alongside the existing Pi configuration.
- Document the build/run entry point with the exact public-key export, `NIXY_REMOTE_BUILDER`/`NIX_CONFIG` builder setup, `nix store ping`, `nix build --impure` target, generated-runner command, and loopback SSH command. Explain the two-platform matrix, serial-console workflow, expected networking behavior, VM disk lifecycle, reset steps, and the fact that only the public key enters the VM closure.
- State the two-stage test contract in plain language: QEMU verifies shared ARM64 NixOS configuration and services; the real Pi verifies its boot chain, device tree, kernel support, peripherals, networking hardware, and performance.
- Include a physical-Pi acceptance checklist after VM success so the VM is a prerequisite, not a substitute.
- Apply the repository's `plain-english` guidance before finalizing documentation.

**Patterns to follow:**
- `README.md` current-status and public-example wording.
- `docs/operations.md` build-before-switch and Raspberry Pi host sections.
- `docs/onepassword.md` and `docs/pi.md` for focused operational guidance with constraints and troubleshooting.

**Test scenarios:**
- Happy path: a reader can identify the QEMU output, build it, boot it, and locate the serial console without consulting private-host files.
- Edge case: the documentation explains the Linux-builder fallback when a macOS machine cannot build the ARM64 Linux guest locally.
- Error path: the documentation lists hardware-only concerns clearly enough that a user does not treat a VM boot as proof that Wi-Fi, GPIO, Pi firmware, or storage will work.
- Integration: README and operations links resolve and use only fake-safe/public names and paths.

**Verification:** Documentation review confirms a new user can follow the VM-first path and understands when to move to real-hardware validation; all links resolve and no private-host information appears.

---

- [ ] U4. **Run the validation gates and record the supported workflow**

**Goal:** Confirm that extraction, VM output, existing Pi composition, and public-safety boundaries all hold together.

**Requirements:** R5, R6, R8

**Dependencies:** U1, U2, U3

**Files:**
- Modify: `flake.nix` only if U2 reveals an additional named check is needed
- Modify: `justfile` only if the existing aggregate check does not run the new relevant flake checks
- Modify: `scripts/check-public-safety.sh` or `scripts/check-public-safety.test.sh` only if the new docs/config surface reveals a real unguarded private-data pattern

**Approach:**
- Use the existing flake-check and public-safety conventions rather than adding a second validation framework.
- Validate focused generic-headless and existing Pi module tests, the Pi toplevel configuration, the QEMU configuration/VM artifact, formatter output, and the repository's safety gate.
- From a clean Apple Silicon coordinator, set `NIXY_REMOTE_BUILDER` to a configured SSH alias and `NIX_CONFIG` to the documented `aarch64-linux` builder declaration; verify it with `nix store ping`. Set `NIXY_VM_SSH_PUBLIC_KEY` from a disposable, one-line local public-key file and run the documented `nix build --impure` command. Confirm `./result/bin/run-nixos-vm` selects Darwin QEMU and loopback forwarding, then boot it. Verify the serial console, `ssh -i "$HOME/.ssh/nixy-vm_ed25519" -p 2222 example@127.0.0.1`, forwarded-port behavior, and shared service state. Treat that end-to-end boot as the runtime proof that static evaluation cannot provide.
- Keep test credentials and keys fake-safe, local, and ephemeral. Never encode a real user password, key, host, or network inventory in the repository. Reset the VM disk and remove the disposable key after the check.

**Patterns to follow:**
- `flake.nix` `runModuleTest` helper and per-platform `checks` outputs.
- `justfile` aggregate validation targets.
- `scripts/check-public-safety.sh` for the public/private boundary.

**Test scenarios:**
- Happy path: all existing module tests and the new headless test pass.
- Happy path: the ARM64 QEMU VM build artifact evaluates/builds and the runner boots to a serial console.
- Integration: SSH and firewall behavior in the booted VM matches the generic headless module's declared policy through the documented loopback port-forward and disposable-key command.
- Regression: the Raspberry Pi example still retains its extlinux and SD-card configuration while the VM has no Pi filesystem mounts.
- Safety: public-safety checks pass with the new configuration and documentation.

**Verification:** The documented aggregate validation path is green, a local VM boot validates the shared runtime behavior, and a real Pi remains the final required acceptance environment.

---

## System-Wide Impact

- **Interaction graph:** `flake.nix` will compose a new generic runtime module into two consumers: the physical Pi host and the QEMU VM host. Both use the existing common module and fake-safe Home Manager user composition; only the Pi path imports the Pi 4 hardware profile.
- **Error propagation:** A host-package platform mismatch would fail when building or running the VM artifact; focused output assertions and a manual serial boot catch it before docs recommend the command. Missing cross-platform builders must produce an actionable documented fallback, not an implicit assumption that macOS can build all Linux guest inputs.
- **State lifecycle risks:** QEMU runtime disks are mutable local test state. The documentation must say where that state lives and how to reset it without affecting a real Pi or Nix store output.
- **API surface parity:** `machine.raspberry-pi` remains the physical-board API. The new generic headless module is the shared API; its defaults and override semantics become a compatibility surface for private hosts.
- **Integration coverage:** Static module checks prove the configuration boundary; an explicit manual VM boot proves the generated runner, serial access, networking, and service startup.
- **Unchanged invariants:** Public examples remain fake-safe, physical Pi hosts remain private, and the real Pi remains the authority for board-specific validation.

---

## Risks & Dependencies

| Risk | Mitigation |
|---|---|
| A Linux-target VM runner cannot execute on macOS | Set the VM host package set to `aarch64-darwin`; verify the generated runner uses Darwin QEMU before documenting it. |
| macOS cannot build a required Linux guest derivation locally | Require and document a configured remote `aarch64-linux` builder, including its verification command, trust boundary, build command, and recovery when it is unavailable. |
| Refactoring headless defaults changes current Pi behavior | Preserve current option names/defaults where practical and cover Pi + generic module behavior with focused tests. |
| VM settings accidentally inherit Pi SD-card mounts or firmware boot | Keep VM and Pi hosts separate; assert the VM has no Pi hardware module or Pi mount labels. |
| Users treat QEMU success as full board validation | Put the validation boundary and physical-Pi checklist in README and the dedicated operations guide. |
| QEMU runtime disk state obscures a configuration change | Document reset/cleanup behavior and use disposable fake-safe VM state. |
| VM SSH is inaccessible or exposed beyond the host | Forward only a loopback host port; pass a disposable public key through `NIXY_VM_SSH_PUBLIC_KEY` and `nix build --impure`; then test success plus missing-key, malformed-key, and occupied-port failures. |

---

## Documentation / Operational Notes

- `docs/qemu-pi-validation.md` is the authoritative explanation of the intent and test boundary.
- `README.md` should present the VM as a public example configuration, not a deployment target.
- `docs/operations.md` should place VM validation before the existing first-boot/switch guidance for private Raspberry Pi hosts and name remote-builder setup as a prerequisite for a bootable guest closure.
- Apply `plain-english` to the documentation changes; keep technical terms such as QEMU, U-Boot, device tree, and ARM64 where they are necessary for precision.

---

## Sources & References

- Related code: `flake.nix`, `hosts/example-aarch64-rpi/default.nix`, `modules/nixos/raspberry-pi.nix`, `modules/nixos/common.nix`, `tests/nixos/raspberry-pi-test.nix`
- [NixOS virtual machines](https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html)
- [NixOS QEMU wiki](https://wiki.nixos.org/wiki/Qemu)
- [NixOS on ARM/Raspberry Pi](https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi)
- [QEMU Raspberry Pi board support](https://www.qemu.org/docs/master/system/arm/raspi.html)
