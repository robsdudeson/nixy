---
date: 2026-09-18
topic: determinate-nix-macos-host
---

# Determinate Nix macOS Host Setup

## Problem Frame

Create a reusable macOS host-configuration repo that can bootstrap and maintain multiple Macs with Determinate Nix, nix-darwin, Home Manager, and a private overlay. The setup should be public-safe by default while still supporting a full workstation bootstrap for the owner's actual machines.

---

## Actors

- A1. Host owner: Uses the repo to set up and maintain macOS workstations.
- A2. Future maintainer/agent: Reads the repo and runs documented rebuild/bootstrap commands safely.
- A3. Private overlay: The private `nixy-priv` repository supplies machine- or identity-specific configuration that should not live in the public-safe base.

---

## Requirements

**Repository shape**
- R1. The base repo must be safe to publish: no secrets, no private hostnames that matter, no tokens, no unencrypted identity material.
- R2. The repo must support multiple hosts with shared profiles and host-specific overrides.
- R3. The repo must clearly separate public-safe base modules from a private overlay loaded only when present.
- R4. The initial structure must be small enough to understand and extend without becoming a framework.

**Host management**
- R5. Determinate Nix owns the Nix installation and daemon.
- R6. nix-darwin manages macOS system settings and host-level packages/settings, with `nix.enable = false` when Determinate owns Nix.
- R7. Home Manager manages user-level dotfiles, shell config, CLI tools, and app configuration where practical.
- R8. The setup should support Apple Silicon first and avoid assuming Intel support unless verified.

**Full workstation bootstrap**
- R9. Day-one scope includes CLI tools, shells, Git, editor/dev tooling, fonts, macOS defaults, Homebrew taps/brews/casks, and Mac App Store apps if needed.
- R10. GUI apps should be installed declaratively where stable, but the repo should allow manual escape hatches for apps that resist declarative management.
- R11. Secrets must be external or encrypted; plain secrets must not enter flake files because they may be copied to the Nix store.

**Operations and safety**
- R12. The repo must document first-run bootstrap, normal rebuild, update, rollback, and host addition flows.
- R13. The first milestone must prove a minimal rebuild on one host before layering the full workstation catalog.
- R14. The setup must include validation commands that can run before applying risky system changes.

---

## Key Flows

- F1. Bootstrap a new Mac
  - **Trigger:** A fresh or existing Mac should become managed by the repo.
  - **Actors:** A1, A2, A3
  - **Steps:** Install Determinate Nix; clone the base repo; make/private-link the overlay if available; select a host; run the nix-darwin bootstrap; verify shell and core tools; apply full host profile.
  - **Outcome:** The Mac can be rebuilt from the flake and has the expected workstation baseline.
  - **Covered by:** R1, R3, R5, R6, R9, R12, R13

- F2. Add a second host
  - **Trigger:** Another Mac should share the base setup with host-specific differences.
  - **Actors:** A1, A2
  - **Steps:** Add a host file; pick shared profiles; add host-specific overrides; run a dry validation; apply on that machine.
  - **Outcome:** Shared behavior stays centralized while host differences remain explicit.
  - **Covered by:** R2, R4, R12, R14

---

## Success Criteria

- A new Mac can be brought from Determinate Nix install to a usable workstation with one documented path and no secret leakage.
- The first host can run `darwin-rebuild switch --flake ...` successfully and repeatably.
- Adding a second host requires adding a host module and selecting profiles, not copying the whole configuration.
- A future agent can understand public/private boundaries before editing the repo.

---

## Scope Boundaries

- Do not manage secrets in plain Nix files.
- Do not require all GUI app state to be declarative on day one.
- Do not build a highly abstract module framework before the first host rebuild works.
- Do not assume the private overlay exists; the base repo should evaluate or fail with a clear message when private inputs are requested.
- Do not optimize for Linux/NixOS hosts in the initial version.

---

## Key Decisions

- Use a public-safe base plus private overlay: preserves portability and lets the base repo be shared or reused without exposing personal/work details.
- Target full workstation bootstrap: include Homebrew/casks and macOS defaults, but keep manual escape hatches.
- Treat Determinate Nix as the owner of Nix itself: nix-darwin should not attempt to manage the Nix installation.
- Prove one minimal host before adding large app/default catalogs: reduces risk and makes failures easier to diagnose.

---

## Dependencies / Assumptions

- Determinate Nix is installed with Determinate's official installer before nix-darwin bootstrap.
- The initial primary Mac is likely Apple Silicon; verify architecture during planning.
- The private overlay repository exists at `https://github.com/robsdudeson/nixy-priv` and is checked out as sibling `nixy-priv`.
- Homebrew remains useful for casks and Mac App Store support that Nix does not cover well.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R8][Needs research] Confirm current Determinate Nix installer behavior and support constraints for Intel Macs, if any Intel hosts matter.
- [Affects R9][User inventory] Identify day-one packages, casks, fonts, MAS apps, and macOS defaults.
- [Affects R11][Technical] Choose a secrets strategy: 1Password CLI references, sops-nix/age, agenix, or private manual files.
- [Affects R3][Resolved] Use the private repository at `https://github.com/robsdudeson/nixy-priv`, checked out as sibling `nixy-priv`, as the private overlay target.

---

## Next Steps

-> Use the implementation plan in `.agents/plans/2026-09-18-001-determinate-nix-macos-setup.md`, then run a planning/deepening pass once the package/app inventory is known.
