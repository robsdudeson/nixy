---
title: refactor: Migrate rd-td-mbp Darwin host to nixy/nixy-priv
type: refactor
status: active
date: 2026-10-07
origin: docs/brainstorms/determinate-nix-macos-host-requirements.md
---

# refactor: Migrate rd-td-mbp Darwin host to nixy/nixy-priv

## Overview

Migrate the legacy Darwin workstation configuration from the nested `nix-it-up` flake into the public/private `nixy` + `nixy-priv` split. The target is for the real Mac host in `nixy-priv` to render the important workstation behavior formerly owned by `nix-it-up`'s `rd-td-mbp` flake, while keeping public-safe reusable modules in `nixy` and private identity/app choices in `nixy-priv`.

The current `nixy-priv` Darwin host already has the newer Determinate Nix boundary, Pi environment, and managed `llama-server`. This migration should preserve those additions and layer the missing workstation behavior deliberately: Homebrew ownership, app inventory, fish shell, Git/1Password SSH signing, VS Code, fonts/packages, and macOS defaults.

---

## Problem Frame

The old `nix-it-up` root flake now only renders `home-nas`, but a nested legacy Darwin flake remains under `nix-it-up` at `hosts/rd-td-mbp/`. That nested flake still contains the old real Mac workstation intent: casks, system packages, fish shell, Touch ID sudo, macOS defaults, VS Code, 1Password SSH signing, and user Git settings.

The new repos already establish the desired architecture:

- `nixy` is the public-safe base with reusable modules, profiles, docs, checks, and fake-safe examples.
- `nixy-priv` owns real hostnames, real users, private app inventory, identity material, and host-specific values.

The migration should move reusable capability into `nixy` only when it is broadly useful and public-safe. Real host identity, real app lists, signing keys, and adoption notes belong in `nixy-priv`.

---

## Requirements Trace

From the origin requirements in `docs/brainstorms/determinate-nix-macos-host-requirements.md`:

- R1. Keep the public base safe to publish: no private hostnames, tokens, secret values, or private identity material.
- R2. Support shared profiles plus host-specific private overrides.
- R3. Preserve the public/private boundary: public modules in `nixy`, real host composition in `nixy-priv`.
- R5/R6. Keep Determinate Nix as Nix owner and nix-darwin as macOS/system owner; do not reintroduce nix-darwin Nix daemon management.
- R7. Use Home Manager for user shell, Git, SSH, VS Code, and user-level tooling.
- R9/R10. Restore workstation scope: CLI tools, shells, Git, editor/dev tooling, fonts, macOS defaults, and Homebrew casks where stable.
- R11. Keep secrets and plaintext credentials out of Nix evaluation, builds, generated store paths, docs, logs, and commits.
- R12/R14. Preserve documented build-before-switch validation and non-destructive existing-Mac adoption.

Current user-specific requirement:

- Migrate the old `rd-td-mbp` host behavior into the `nixy`/`nixy-priv` model after UTM hosts have been decommissioned.

---

## Scope Boundaries

### In scope

- Preserve current `nixy-priv` Darwin host additions: Pi profile and managed `llama-server`.
- Add or wire public-safe reusable Darwin/Home Manager modules in `nixy` where needed.
- Add private host composition in `nixy-priv` for `rd-mbp-MRX43R2HDH`.
- Port old `rd-td-mbp` workstation behaviors that are still desired:
  - Homebrew + casks.
  - Fish as system/user shell.
  - CLI/system package baseline and fonts.
  - Git identity and SSH signing with 1Password.
  - 1Password app/CLI and SSH agent wiring.
  - VS Code settings/extensions, if still wanted declaratively.
  - macOS defaults and selected activation-time preferences.
- Validate with dry builds/checks before any switch.
- After new host parity is proven, decommission the nested legacy Darwin flake from `nix-it-up` in a separate final unit.

### Out of scope

- Do not migrate or change `home-nas`.
- Do not change any `system.stateVersion` or `home.stateVersion` anchors except if preserving an existing anchor in a newly migrated host/user file is explicitly necessary.
- Do not resolve or embed secrets through Nix.
- Do not adopt destructive Homebrew cleanup.
- Do not add Intel Darwin support.
- Do not require every GUI app's internal state to be declarative.
- Do not remove the old nested `nix-it-up` flake until the new `nixy-priv` host builds and the old/new inventory differences are reviewed.

---

## Context & Research

### Legacy source files in `nix-it-up`

- `hosts/rd-td-mbp/flake.nix`
  - Defines `darwinConfigurations.rd-td-mbp`.
  - Uses `nixpkgs/nixpkgs-25.05-darwin`, `nix-darwin-25.05`, `home-manager/release-25.05`, `nix-homebrew`, `homebrew-core`, `homebrew-cask`, `mac-app-util`, `nix-vscode-extensions`, and `my-modules` from `../../modules`.
  - Wires `my.machine.standard-config.enable = true` and a VS Code extensions overlay.
- `hosts/rd-td-mbp/configuration.nix`
  - Sets `nixpkgs.hostPlatform = "aarch64-darwin"`.
  - Sets `system.stateVersion = 6`.
  - Sets hostname through legacy `my.machine.hostname` module.
  - Installs system packages: `fastfetch`, `gh`, `git`, `meslo-lgs-nf`, `neovim`, `nerd-fonts.fira-code`, `nh`, `nixfmt`, `vscode`, `wget`.
  - Sets `EDITOR = "nvim"`.
  - Enables zsh and fish.
  - Enables Touch ID for sudo.
  - Sets user shell to fish.
  - Enables Homebrew casks: `1password`, `1password-cli`, `brave-browser`, `ghostty`, `notion`, `rectangle`, `slack`, `steam`.
  - Sets macOS defaults for extensions, scrollbars, 24-hour time, save panels, tap-to-click, dark mode, dock, trackpad.
  - Uses an activation script for screenshots path, clock format, battery percent, natural scrolling, purple accent/highlight, dock apps, and restarting Dock/SystemUIServer/Finder.
- The legacy user module under `hosts/rd-td-mbp` (Home Manager config for the `rd` user)
  - Sets `home.stateVersion = "25.05"`.
  - Enables fish, Git identity/signing, VS Code, and SSH.
  - Uses 1Password SSH signing program at `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`.

### Current target files in `nixy`

- `flake.nix`
  - Uses `nixpkgs-unstable`, `nix-darwin/master`, `home-manager/master`, `nix-homebrew`, `pi`, and scoped NixOS/WSL inputs.
  - Exposes `darwinConfigurations.example-aarch64-darwin` and Darwin checks for opt-in profiles.
- `modules/darwin/determinate.nix`
  - Sets `nix.enable = false` for Determinate Nix ownership.
- `modules/darwin/home-manager.nix`
  - Imports Home Manager's nix-darwin module and initializes the primary user profile.
- `modules/darwin/homebrew.nix`
  - Imports `nix-homebrew` and sets non-destructive Homebrew activation behavior.
- `profiles/onepassword.nix`
  - Composes 1Password app/CLI installation and SSH agent wiring.
- `modules/home/onepassword-ssh.nix`
  - Sets SSH `IdentityAgent` and `SSH_AUTH_SOCK` to the 1Password SSH agent socket.
- `modules/home/git.nix`
  - Provides `gitIdentity` options for real name, email, signing key, SSH signing program, and workstation defaults.
- `modules/home/fish.nix`, `modules/home/gh.nix`, `modules/home/shell.nix`, `modules/home/vscode.nix`
  - Already cover much of the old Home Manager shape.
  - `modules/home/vscode.nix` expects `pkgs.vscode-marketplace`, but the current public flake does not yet wire `nix-vscode-extensions`.
- `tests/home/vscode-test.nix`
  - Provides a fake `vscode-marketplace` attrset for module shape tests.

### Current target files in `nixy-priv`

- `flake.nix`
  - Defines `darwinConfigurations.rd-mbp-MRX43R2HDH` through `lib/mk-darwin-host.nix`.
- `lib/mk-darwin-host.nix`
  - Central helper for real Darwin hosts.
- `hosts/rd-mbp-MRX43R2HDH/default.nix`
  - Imports Determinate boundary, Home Manager, `profiles/minimal.nix`, `profiles/pi.nix`, and `profiles/llama-server.nix`.
  - Sets hostname, platform, primary user, state version.
  - Configures managed `llama-server` for Qwen3.8 on localhost port 8080.
- `users/rd.nix`
  - Sets username/home directory and basic Git user name/email.

### Research decision

Local repo patterns and docs are sufficient for this plan. External research is not necessary before planning because the repos already contain the relevant Determinate Nix, nix-homebrew, 1Password, Pi, and private-overlay operating guidance. Implementation should use those local docs first and only consult upstream docs if a specific option name or nix-darwin/Home Manager API has changed.

---

## Key Technical Decisions

1. **Keep public modules generic; keep real inventory private.**
   - Add public modules/profiles in `nixy` only for reusable behavior such as Homebrew ownership, macOS defaults options, VS Code module support, and shell/tool defaults.
   - Put the real cask list, signing key, host-specific dock apps, and hostname/user choices in `nixy-priv`.

2. **Preserve the new host's existing improvements.**
   - `profiles/pi.nix` and `profiles/llama-server.nix` remain imported by `hosts/rd-mbp-MRX43R2HDH/default.nix` unless explicitly removed later.
   - The migration layers old workstation behavior on top rather than replacing the host file wholesale.

3. **Use existing `gitIdentity` instead of porting legacy `my.programs.git`.**
   - `users/rd.nix` should use the current `gitIdentity` option from `modules/home/git.nix` for signing and workstation defaults.
   - Do not copy the old legacy module namespace into `nixy`.

4. **Treat Homebrew adoption as non-destructive.**
   - Import `modules/darwin/homebrew.nix` and set casks/brews from `nixy-priv`.
   - Keep `onActivation.cleanup = "none"`, no forced upgrades, and no destructive adoption assumptions.

5. **Make VS Code support explicit before enabling it on the real host.**
   - Either add `nix-vscode-extensions` to public `nixy` and apply its overlay for Darwin hosts, or split the VS Code module so settings can be managed without marketplace extension resolution.
   - Do not enable `modules/home/vscode.nix` on the real host until the overlay path evaluates in `nixy-priv`.

6. **Separate build parity from switch/adoption.**
   - First build and compare the new render.
   - Only then switch on the Mac.
   - Only after a successful switch and manual first-run checks should the old nested `nix-it-up` flake be removed or marked decommissioned.

---

## Open Questions

### Resolved before implementation (2026-10-07, via user decisions)

- Homebrew casks: keep the full old list exactly as-is (`brave-browser`, `ghostty`, `notion`, `rectangle`, `slack`, `steam`, plus `1password`/`1password-cli` from the 1Password profile).
- VS Code: full Nix management — add `nix-vscode-extensions` to `nixy` inputs, install `pkgs.vscode` via a new public Darwin module, and manage extensions/settings via the existing home module (U5 path 1).
- Dock persistent apps: carry forward exactly as in the old activation script, including `Cursor.app` and `Obsidian.app` even though they are not Nix/Homebrew-managed casks. The dock rewrite is explicit and documented as a full reset of the persistent-apps array.
- Host name stays `rd-mbp-MRX43R2HDH`; no rename or alias to `rd-td-mbp`.
- Branch strategy: continue on `main` in both repos (no feature branch).
- Git identity name: keep `Robby Thompson` (the spelling already used by the current live host and majority of commit history) rather than the legacy lowercase variant.

### Deferred to implementation/adoption

- Whether `nix-vscode-extensions` is currently compatible with the public `nixpkgs-unstable`/Darwin line.
- Whether Homebrew ownership conflicts exist on the current Mac.
- Whether an unmanaged `~/.ssh/config` exists and must be moved or converted before enabling Home Manager SSH.
- Whether applying dock and UI defaults on the existing Mac should happen all at once or behind an option with an explicit private-host enable flag.

---

## Target End State

- `nixy-priv#rd-mbp-MRX43R2HDH` builds cleanly and renders the desired workstation baseline.
- The target host preserves:
  - Determinate Nix boundary.
  - Pi runtime setup.
  - Managed `llama-server`.
  - Fish shell and old shell ergonomics.
  - Git identity, SSH signing, and 1Password SSH agent wiring.
  - Homebrew casks and non-destructive Homebrew activation.
  - VS Code settings/extensions if selected.
  - macOS defaults that are still desired.
- `nixy` gains only public-safe reusable modules/checks.
- `nixy-priv` owns private host inventory and identity.
- `nix-it-up` no longer carries a live or misleading nested Darwin host after successful migration.

---

## Implementation Units

- [x] U1. **Inventory old vs new Darwin render and decide migration set**

**Goal:** Produce a concrete migration matrix so implementation does not blindly copy stale old Mac settings.

**Requirements:** R9, R10, R12, R14

**Dependencies:** None

**Files:**
- Read/reference in `nix-it-up`: `hosts/rd-td-mbp/flake.nix`
- Read/reference in `nix-it-up`: `hosts/rd-td-mbp/configuration.nix`
- Read/reference in `nix-it-up`: the legacy user module under `hosts/rd-td-mbp`
- Read/reference in `nixy-priv`: `hosts/rd-mbp-MRX43R2HDH/default.nix`
- Read/reference in `nixy-priv`: `users/rd.nix`
- Modify: `docs/plans/2026-10-07-001-refactor-migrate-rd-td-mbp-to-nixy-plan.md` if decisions materially change the plan
- Optional create/modify in `nixy-priv`: `README.md` for durable host inventory notes

**Approach:**
- Build a table of old behaviors and classify each as:
  - public reusable module/profile in `nixy`,
  - private host/user config in `nixy-priv`,
  - manual/adoption-only,
  - obsolete/defer.
- Decide cask list, VS Code install strategy, dock app list, and host naming before changing Nix files.
- Keep state-version anchors unchanged in active target files.

**Test scenarios:**
- Happy path: every old `rd-td-mbp` behavior has an explicit keep/drop/defer classification.
- Edge case: an app appears only in the dock activation script and not in the cask list; the matrix flags it for explicit decision.
- Safety path: signing keys and real app inventory are classified as private, not public.

**Verification:**
- The implementer can identify all planned file changes before editing.
- No secret values are read or resolved.

---

- [x] U2. **Wire Homebrew and 1Password into the real Darwin host**

**Goal:** Restore Homebrew ownership and 1Password app/CLI/SSH-agent support in the new host using existing public modules.

**Requirements:** R3, R9, R10, R11, R12

**Dependencies:** U1 cask decision

**Files:**
- Modify in `nixy-priv`: `hosts/rd-mbp-MRX43R2HDH/default.nix`
- Possibly modify in `nixy`: `profiles/onepassword.nix` only if composition gaps are found
- Possibly modify in `nixy`: `modules/darwin/homebrew.nix` only if host-specific cask composition requires a cleaner option surface
- Possibly modify in `nixy-priv`: `README.md`

**Approach:**
- Import `inputs.nixy`'s `modules/darwin/homebrew.nix` in the real host before enabling Homebrew casks.
- Import `inputs.nixy`'s `profiles/onepassword.nix` for 1Password app/CLI and SSH-agent wiring.
- Declare the selected cask list in `nixy-priv`, not `nixy`.
- Preserve non-destructive Homebrew activation defaults.
- Do not put account, vault, item, token, or resolved credential values in Nix.

**Test scenarios:**
- Happy path: Darwin host eval includes `nix-homebrew.enable = true`, `homebrew.enable = true`, selected casks, and non-destructive activation settings.
- Existing-Mac path: if Homebrew is already installed outside nix-homebrew, activation may stop with an ownership conflict; docs point to manual resolution rather than forcing migration.
- Security path: 1Password account/sign-in state remains manual and no secrets enter generated files.

**Verification:**
- `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run` from `nixy-priv`.
- `nix eval` checks for Homebrew casks and activation settings if useful.

---

- [x] U3. **Restore shell, package, font, and editor baseline**

**Goal:** Bring the old CLI/system baseline into the new host without fighting current `nixy` module boundaries.

**Requirements:** R7, R9, R14

**Dependencies:** U1

**Files:**
- Modify in `nixy-priv`: `hosts/rd-mbp-MRX43R2HDH/default.nix`
- Modify in `nixy-priv`: `users/rd.nix`
- Possibly modify in `nixy`: `profiles/minimal.nix` if a public baseline genuinely belongs there
- Possibly create in `nixy`: `profiles/workstation.nix` if repeated public-safe workstation packages should be centralized
- Possibly modify/add tests in `nixy`: `tests/home/fish-test.nix`, `tests/home/git-test.nix`, or a new profile test

**Approach:**
- Enable fish at system level and set the real user's shell to `pkgs.fish` in `nixy-priv`.
- Import Home Manager modules for fish, shell, gh, and Git through the user's profile.
- Add package/font baseline intentionally, avoiding duplicates when Home Manager already installs a tool.
- Keep host-specific package inventory in `nixy-priv` unless it is fake-safe and broadly reusable.

**Test scenarios:**
- Happy path: the rendered host enables fish, points the user shell at fish, and includes the selected CLI/font packages.
- Compatibility path: zsh remains enabled for macOS defaults and nix-darwin environment setup.
- Duplication path: packages are not split arbitrarily between system and Home Manager in a way that makes ownership unclear.

**Verification:**
- `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run` from `nixy-priv`.
- Existing `nixy` checks for touched Home Manager modules.

---

- [x] U4. **Restore Git identity, SSH signing, and 1Password SSH behavior**

**Goal:** Replace the legacy `my.programs.git`/`my.programs.ssh` setup with current `nixy` Home Manager modules.

**Requirements:** R3, R7, R11

**Dependencies:** U2, U3

**Files:**
- Modify in `nixy-priv`: `users/rd.nix`
- Reference in `nixy`: `modules/home/git.nix`
- Reference in `nixy`: `modules/home/onepassword-ssh.nix`
- Possibly modify in `nixy-priv`: `README.md` for adoption notes

**Approach:**
- Use `gitIdentity.enable = true` in `users/rd.nix`.
- Set the real name/email/signing key in `nixy-priv`.
- Set `sshSigningProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"` if this remains the correct macOS path.
- Let `profiles/onepassword.nix` provide SSH agent socket wiring.
- Preserve the warning that unmanaged existing `~/.ssh/config` can block Home Manager activation.

**Test scenarios:**
- Happy path: rendered Git config includes user identity, SSH signing, and optional 1Password signing program.
- Existing config path: if `~/.ssh/config` is unmanaged, activation refuses to overwrite and documentation tells the user to move/convert it.
- Security path: only public SSH signing keys and socket paths are committed; no private key material or resolved credentials are stored.

**Verification:**
- `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run` from `nixy-priv`.
- Existing or updated `git-test` validates module shape where possible.
- Post-switch manual checks: `op vault list`, `ssh-add -l`, `ssh -T git@github.com`.

---

- [x] U5. **Decide and implement VS Code management path**

**Goal:** Restore old VS Code settings/extensions only after the extension source and package ownership are explicit.

**Requirements:** R7, R9, R10, R14

**Dependencies:** U1, U3

**Files:**
- Modify in `nixy`: `flake.nix` if adding `nix-vscode-extensions` input/overlay
- Modify in `nixy`: `modules/home/vscode.nix` if splitting settings from marketplace extensions is preferred
- Modify in `nixy`: `tests/home/vscode-test.nix` if module behavior changes
- Modify in `nixy-priv`: `users/rd.nix` to import/enable VS Code module
- Possibly modify in `nixy-priv`: `hosts/rd-mbp-MRX43R2HDH/default.nix` if VS Code package or overlay is host-level

**Approach:**
- Choose one path:
  1. Add `nix-vscode-extensions` to public `nixy`, apply the overlay for Darwin hosts, and keep current extension-managed module; or
  2. Split VS Code settings from extensions so settings can be managed even if extension packaging is deferred; or
  3. Install VS Code as a Homebrew cask/manual app and defer declarative extensions.
- Prefer the smallest path that builds reliably on the current Darwin input line.
- Keep user settings public-safe; real private extension choices, if any, belong in `nixy-priv`.

**Test scenarios:**
- Happy path: enabling VS Code on the real host evaluates and includes expected settings/extensions.
- Compatibility path: if marketplace extension overlay breaks, settings-only management can still proceed or VS Code is deferred explicitly.
- Ownership path: VS Code is not installed by both Nix and Homebrew unless that is intentional and documented.

**Verification:**
- `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run` from `nixy-priv`.
- `nix build .#checks.aarch64-darwin.<vscode-related-check>` if a new check is added.
- Existing `tests/home/vscode-test.nix` still passes through public checks.

---

- [x] U6. **Restore selected macOS defaults and activation-time preferences**

**Goal:** Carry forward old macOS UI/defaults behavior in a safer, reviewable module shape.

**Requirements:** R6, R9, R10, R12, R14

**Dependencies:** U1 cask/dock decisions

**Files:**
- Create/modify in `nixy`: `modules/darwin/macos-defaults.nix`
- Modify in `nixy`: `flake.nix` to add a public check if useful
- Modify in `nixy-priv`: `hosts/rd-mbp-MRX43R2HDH/default.nix`
- Possibly modify in `nixy-priv`: `README.md` for manual/adoption notes

**Approach:**
- Put reusable defaults in a public module with either conservative defaults or explicit options.
- Keep real dock persistent app paths in `nixy-priv` because they reveal private app inventory and may reference apps not installed declaratively.
- Prefer native nix-darwin `system.defaults` options where available.
- Use activation scripts only for preferences not covered by nix-darwin options, and make scripts idempotent.
- Consider an explicit private-host enable flag for disruptive existing-Mac defaults such as dock rewrites.

**Test scenarios:**
- Happy path: rendered config includes selected `system.defaults` values.
- Idempotency path: activation script creates screenshots directory and writes defaults repeatedly without accumulating duplicate state.
- Adoption path: dock rewrite is either explicitly enabled or deferred so an existing Mac is not surprised by a full dock reset.

**Verification:**
- `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run` from `nixy-priv`.
- `nix eval` targeted values for important `system.defaults` fields.
- Post-switch manual check of Dock/Finder/SystemUIServer behavior.

---

- [ ] U7. **Build, compare, and switch only after dry validation**

**Goal:** Prove the new host render before applying it to the Mac.

**Requirements:** R12, R14

**Dependencies:** U2-U6 selected implementation complete

**Files:**
- Modify in `nixy-priv`: `README.md` if validation/adoption commands need updating
- Possibly modify in `nixy`: `docs/operations.md` if reusable adoption guidance changes

**Approach:**
- Run formatting on touched Nix files.
- Run public `nixy` checks affected by changed modules.
- Run private host dry build from `nixy-priv`.
- Compare high-level rendered values to the migration matrix from U1.
- Switch only on the target Mac after dry build passes and Homebrew/SSH/1Password adoption concerns are reviewed.

**Test scenarios:**
- Happy path: public checks and private Darwin build pass.
- Failure path: if Homebrew ownership or unmanaged SSH config blocks activation, stop and document the manual fix rather than forcing the switch.
- Rollback path: if a GUI/default change is bad after switch, Nix rollback is available but Homebrew/macOS defaults may need manual cleanup.

**Verification:**
- In `nixy`: `nix flake check --no-build` or narrower checks matching touched modules.
- In `nixy-priv`: `nix flake show`.
- In `nixy-priv`: `nix build .#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run`.
- On target Mac only: `sudo darwin-rebuild switch --flake .#rd-mbp-MRX43R2HDH`.

---

- [x] U8. **Retire the legacy nested Darwin flake from `nix-it-up` after adoption**

**Goal:** Remove the old `rd-td-mbp` management surface once `nixy-priv` is the source of truth.

**Requirements:** R12, migration cleanup

**Dependencies:** U7 successful dry build and, ideally, successful switch/adoption

**Files:**
- Delete in `nix-it-up`: `hosts/rd-td-mbp/flake.nix`
- Delete in `nix-it-up`: `hosts/rd-td-mbp/flake.lock`
- Delete in `nix-it-up`: `hosts/rd-td-mbp/configuration.nix`
- Delete in `nix-it-up`: the legacy user module under `hosts/rd-td-mbp`
- Modify in `nix-it-up`: `README.md`
- Modify in `nix-it-up`: `docs/HOSTS.md`
- Modify in `nix-it-up`: `CONTEXT.md` and/or `AGENTS.md` only if they still mention the nested Darwin flake as active

**Approach:**
- Treat this as a separate cleanup commit in `nix-it-up`, similar to the UTM decommissioning pattern.
- Do not touch `home-nas`.
- Preserve history; do not rewrite old commits.
- Update docs to say Darwin host management moved to `nixy-priv`.

**Test scenarios:**
- Happy path: `nix-it-up` root still shows only `home-nas` and no docs imply `rd-td-mbp` is active there.
- Safety path: `home-nas` config and hardware configuration are untouched.
- Provenance path: old nested Darwin files remain recoverable from git history.

**Verification:**
- In `nix-it-up`: `nix flake show`.
- In `nix-it-up`: `scripts/check-docs`.
- In `nix-it-up`: `git diff -- hosts/home-nas` is empty.

---

## Progress Log

### 2026-10-07 — U2-U6 implementation complete (dry-build green)

**Public `nixy` commits (main):**
- `deec4ee` feat(darwin): add vscode and macos-defaults modules (U5/U6 public side, plus `nix-vscode-extensions` input).
- `f150f87` fix(darwin): pass `inputs` to the Home Manager user evaluation via
  `home-manager.extraSpecialArgs`. Root cause of the "infinite recursion"
  seen while wiring `users/rd.nix`: user modules that import nixy modules via
  `"${inputs.nixy}/..."` strings need the flake inputs inside the HM evaluation
  context. Without them the module system falls back to `_module.args`, which
  forces `config` and recurses. The private NixOS host already worked around
  this in its host file; the fix moves it into the public Darwin module so all
  Darwin hosts get it. Same commit: `nixpkgs.config.allowUnfree = true` in the
  vscode module (it declares `pkgs.vscode`) and a null-check fix for the
  macos-defaults `primaryUser` assertion.
- `8bdad01` + `f6dda6d` users/example.nix: `home.stateVersion` is now
  `lib.mkDefault "25.11"` so a private host can pin the legacy anchor.

**Private `nixy-priv` (uncommitted at log time):**
- `hosts/rd-mbp-MRX43R2HDH/default.nix`: full composition — determinate,
  home-manager, homebrew (non-destructive), macos-defaults, vscode, minimal,
  onepassword, pi, llama-server profiles; fish user shell + system zsh/fish;
  legacy CLI/font package baseline; Touch ID sudo; carried-over cask list
  (brave, ghostty, notion, rectangle, slack, steam; 1Password via profile);
  declarative `system.defaults`; `darwin.macosDefaults` activation block with
  the legacy dock app list; llama-server service preserved.
- `users/rd.nix`: fish/gh/vscode home modules; `home.stateVersion = "25.05"`
  (legacy anchor, avoids running newer HM migrations on adoption);
  `gitIdentity` with real name/email/signing key, `op-ssh-sign`,
  `workstationDefaults = false`, legacy extra ignores; full legacy git alias
  set via `programs.git.settings.alias` (the old `programs.git.aliases`
  option is deprecated). 1Password SSH agent socket comes from
  `profiles/onepassword.nix`.
- `lib/mk-darwin-host.nix`: user module now imported at top level
  (`imports = [ (import userModule) ]`), mirroring `mk-nixos-host.nix`.
- `flake.lock`: `nixy` updated to `f6dda6d`; `nix-vscode-extensions` and
  `nix-homebrew` follows added in `flake.nix`.

**Validation (Linux dev box, cross-eval/dry-build only):**
- `nixy`: `checks.aarch64-darwin.example-aarch64-darwin`,
  `example-aarch64-darwin-vscode`, `x86_64-linux.git-test`,
  `x86_64-linux.vscode-test` all pass (dry-run); public-safety script passes.
- `nixy-priv`: `.#darwinConfigurations.rd-mbp-MRX43R2HDH.system --dry-run`
  passes; rendered HM user config verified (identity, aliases, ignores,
  stateVersion 25.05, vscode/gh/fish enabled); WSL check still passes.

**Remaining:** U7 switch on the target Mac (`sudo darwin-rebuild switch
--flake .#rd-mbp-MRX43R2HDH`), post-switch 1Password/SSH manual checks, then
U8 decommission of the legacy nested flake in `nix-it-up`.

### 2026-10-08 — Crash recovery: fidelity fixes committed and pushed

The machine crashed after the render-comparison fixes were validated but
before they were committed. Resumed from session history:

- nixy `589bb77`: VS Code `/Applications` bundle symlink activation fix
  (public darwin module).
- nixy-priv `39df728` + `b45c0b9`: lock bump to the new nixy rev, and the
  user-config fixes (`xdg.enable`, removal of the `workstationDefaults`
  override that dropped the legacy git workflow).
- Re-ran dry validation after the lock bump: private host dry build and the
darwin example checks all green. Both repos pushed.
- Signing note: commit signing works through the configured
  `gpg.ssh.program` helper; the lost Linux `op` CLI session was a red
  herring for git signing.

**Remaining:** U7 switch on the target Mac + post-switch 1Password/SSH
checks, then U8 decommission of the legacy nested flake in `nix-it-up`.

### 2026-10-08 — U8: legacy nested Darwin flake decommissioned from nix-it-up

Per user direction, the legacy `hosts/rd-td-mbp/` nested flake was retired
from `nix-it-up` ahead of a confirmed switch (U7 dry build is green; the
files remain recoverable from `nix-it-up` git history if the switch fails):

- nix-it-up `4d04c2e`: delete `hosts/rd-td-mbp/` (flake, lock, configuration,
  user module). Root flake still shows only `home-nas`; `scripts/check-docs`
  passes; `hosts/home-nas` untouched.
- nix-it-up `22f5d27`: README repo map and HOSTS.md inventory updated to
  record the removal alongside the other decommissioned hosts.

**Remaining:** U7 switch on the target Mac + post-switch 1Password/SSH
checks (the final adoption gate).

---

## Suggested Sequencing

1. U1: classify old behavior and make app/default decisions.
2. U2-U4: restore Homebrew, 1Password, shell/packages, Git/SSH. These are foundational and relatively direct.
3. U5: handle VS Code only once extension/package ownership is clear.
4. U6: apply macOS defaults after deciding how disruptive dock/default rewrites should be on an existing Mac.
5. U7: validate and switch.
6. U8: decommission the old nested `nix-it-up` Darwin flake only after `nixy-priv` is proven.

---

## Risks & Mitigations

- **Homebrew ownership conflict:** Use non-destructive nix-homebrew settings and stop for manual adoption if activation reports a conflict.
- **Unmanaged SSH config conflict:** Follow `docs/onepassword.md`; move or convert existing `~/.ssh/config` before enabling Home Manager SSH.
- **VS Code extension overlay incompatibility:** Keep VS Code as a distinct unit with a settings-only or deferred fallback.
- **Dock/default surprise on existing Mac:** Gate disruptive defaults or document them explicitly before switching.
- **Secret leakage:** Keep real identity/config in `nixy-priv`, never resolve `op://` during Nix eval/build, and run public-safety checks for public repo changes.
- **State-version churn:** Preserve `system.stateVersion = 6`; do not casually change Home Manager state anchors.
- **Losing new host additions:** Treat Pi and `llama-server` as existing target behavior to preserve unless the user explicitly removes them.

---

## Validation Checklist

Before implementation is considered complete:

- [x] `nixy` Nix files are formatted with `nixfmt-rfc-style` (run via `nix fmt`; nixy-priv uses the same formatter through its flake).
- [x] `nixy` relevant checks pass.
- [x] `nixy-priv#rd-mbp-MRX43R2HDH` dry-builds.
- [ ] Selected old `rd-td-mbp` behaviors are either rendered in the new host or explicitly deferred/dropped.
- [ ] No public `nixy` file contains real hostnames, private app inventory, signing keys, secret refs, or user identity.
- [ ] No Nix file resolves or embeds secret values.
- [ ] Post-switch manual 1Password and SSH checks are documented or completed.
- [ ] `nix-it-up` legacy nested Darwin flake is removed or clearly marked decommissioned only after new host adoption succeeds.
