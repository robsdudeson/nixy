---
title: "feat: Install and configure pi-coding-agent for nix-managed hosts"
type: feat
status: active
date: 2026-09-20
---

# feat: Install and configure pi-coding-agent for nix-managed hosts

## Overview

Add first-class support for the `pi` coding agent (`@earendil-works/pi-coding-agent`) to this nix-darwin + Home Manager repo. Because pi is not in nixpkgs, the chosen strategy is **runtime declarative, pi imperative (lightest)**: Nix/Home Manager owns the JavaScript runtime and all non-secret configuration, while the `pi` executable itself is installed and upgraded imperatively through pi's own tooling, pinned and documented as a manual step.

This mirrors the repo's existing posture toward tools it cannot fully own declaratively (see how 1Password is wired: Nix installs and points at the app while sign-in and secrets stay manual — `profiles/onepassword.nix`, `docs/onepassword.md`). Provider API keys are secrets and flow through the existing 1Password strategy; they never enter committed Nix files or the world-readable Nix store.

---

## Problem Frame

Developers on nix-managed Macs want `pi` available with consistent, reproducible configuration, without hand-crafting each machine. Two forces constrain the solution:

1. **pi is not packaged in nixpkgs.** It ships as an npm/bun package whose entrypoint is a bundled `dist/bundle/cli.js`. Fully declarative packaging (`buildNpmPackage`) was explicitly rejected for this iteration in favor of the lightest path.
2. **pi actively mutates its config directory.** `~/.pi -> ~/.config/pi/agent/` holds `settings.json`, `trust.json`, `ide-selection.json`, session history, package installs (`~/.pi/agent/npm|git`), and caches. Home Manager's default file management creates read-only symlinks into the Nix store, which would break pi's ability to write these. So config management must be surgical, not wholesale.

pi is also explicitly Nix-aware: its docs call out `PI_PACKAGE_DIR` as "useful for Nix/Guix where store paths tokenize poorly," and `PI_OFFLINE` / `PI_TELEMETRY` for controlling startup network behavior — signals the plan uses directly.

---

## Requirements Trace

- R1. `pi` is runnable on a nix-managed host after a rebuild plus one documented imperative install step.
- R2. The JavaScript runtime pi needs is installed declaratively via Home Manager.
- R3. pi's global install location is user-writable and on `PATH` without relying on a read-only Nix-store prefix.
- R4. Non-secret pi configuration and environment (telemetry, offline, package dir) is declared in this repo.
- R5. Provider API keys and other secrets are supplied through 1Password at runtime and never committed or placed in the Nix store (repo invariant; see README "Public/private boundary").
- R6. pi's mutable config/session/cache state is not clobbered by read-only Home Manager symlinks.
- R7. Install, upgrade, offline/telemetry, secrets, and uninstall flows are documented.
- R8. The public example host still evaluates and `check-public-safety` still passes with the new module present.
- R9. The pi module is opt-in composition consistent with existing module/profile conventions; the public example remains build/eval-safe.

---

## Scope Boundaries

- Do not package pi as a Nix derivation (`buildNpmPackage`) or add a version-wrapping flake input in this iteration — explicitly deferred (the "fully declarative" and "flake wrapper" options were considered and not chosen).
- Do not commit provider API keys, auth files, or any secret values into Nix files or generated dotfiles.
- Do not symlink pi's whole config directory or its mutable files read-only from the Nix store.
- Do not manage pi package installs (`pi install ...` extensions/skills) declaratively in this iteration; they remain imperative.
- Do not enable pi automatically on the public example host in a way that would require a real user or secrets to evaluate.
- Do not manage Linux/NixOS hosts here; this repo is Apple Silicon macOS (`aarch64-darwin`) only, consistent with the existing foundation plan.

### Deferred to Follow-Up Work

- Fully declarative pi packaging (`buildNpmPackage` using pi's shipped `npm-shrinkwrap.json`): future iteration if reproducibility of the binary itself becomes required.
- Declarative management of specific pi packages (extensions/skills/themes): future iteration once the stable set is known.

---

## Context & Research

### Relevant Code and Patterns

- `modules/home/shell.nix`, `modules/home/direnv.nix` — shape of a Home Manager module (`home.packages`, `programs.*`); the new pi module follows this form.
- `users/example.nix` — where home modules are imported and wired per user.
- `profiles/onepassword.nix`, `modules/darwin/onepassword.nix`, `modules/home/onepassword-ssh.nix`, `docs/onepassword.md` — the established "Nix wires the tool, 1Password holds the secrets, first-run is manual" pattern this plan reuses for provider keys.
- `flake.nix` `checks.${system}` — the eval-only `example-aarch64-darwin-onepassword` check demonstrates how to prove an opt-in profile composes without making it a switch target; the pi module gets the same treatment.
- `scripts/check-public-safety.sh` (+ `.test.sh`) — deny-pattern secret scanner already covers `api[_-]?key`, `token`, `secret`, private-key blocks; U-work must keep passing it and may extend it.
- `justfile` `check` target — the aggregate gate (`nix flake show`, dry-build, onepassword eval check, bootstrap test, public-safety) the new work plugs into.

### External References

- pi README / docs (bundled at `@earendil-works/pi-coding-agent/docs/`): install via `npm install -g --ignore-scripts @earendil-works/pi-coding-agent` or `curl -fsSL https://pi.dev/install.sh | sh`; `pi update --self` for upgrades; `PI_PACKAGE_DIR`, `PI_OFFLINE`, `PI_TELEMETRY` env vars; `enableInstallTelemetry` in `settings.json`; config dir `.pi`; packages land in `~/.pi/agent/npm|git`.
- Current machine state (informational): pi v0.85.1 installed via bun at `~/.cache/.bun/bin/pi`; `~/.pi -> ~/.config/pi`.

---

## Key Technical Decisions

- **Runtime = Bun, declared via `home.packages`.** Bun is in nixpkgs, matches the currently-working install (`~/.cache/.bun/bin/pi`), and its global-install prefix (`~/.bun/bin` / `$BUN_INSTALL/bin`) is user-writable by default — sidestepping the read-only Nix-store npm-prefix problem (R3). Node + a user-writable `npm_config_prefix` is a documented alternative but adds PATH/prefix friction the "lightest" choice avoids. Rationale recorded so a future switch to Node is a conscious change.
- **pi installed imperatively, pinned.** Install/upgrade via `bun install -g @earendil-works/pi-coding-agent[@version]` (or the official installer), documented in `docs/pi.md`. Not declarative by decision (see Scope). `pi update --self` is the upgrade path.
- **Config split: declare the static, leave the mutable alone.** Env vars and PATH go in `home.sessionVariables` / Home Manager. A *baseline* `settings.json` is seeded into `~/.config/pi/agent/` only if absent, via a Home Manager activation copy (writable file), never a read-only store symlink — protecting pi's ability to rewrite it and its sibling mutable files (R4, R6).
- **`PI_PACKAGE_DIR` set explicitly** to a stable, user-writable path so package installs are predictable regardless of how pi was launched (addresses pi's documented Nix store-path caveat).
- **Secrets via 1Password `op run`.** Provider keys are read at launch (e.g. a `pi` shell wrapper/alias running `op run -- pi …`, or `op read` into the session), reusing the repo's 1Password strategy. No keys in Nix, matching R5 and the public/private boundary.
- **Opt-in, eval-safe.** The pi home module is importable but the public example stays build-safe; composition is proven with an eval-only flake check, mirroring the onepassword pattern (R8, R9).

---

## Open Questions

### Resolved During Planning

- How declarative should the pi binary be? → Runtime declarative, pi imperative (user-selected).
- Node or Bun runtime? → Bun (matches current working install; user-writable global prefix). Revisit only if a Node-based toolchain becomes standard.
- Manage `settings.json` as a read-only symlink? → No; seed-if-absent writable copy, because pi mutates it.

### Deferred to Implementation

- Exact baseline `settings.json` contents (theme, `enableInstallTelemetry`, editor) — finalize while implementing U2; keep public-safe and secret-free.
- Whether the 1Password launch integration is a shell wrapper, alias, or documented `op run` snippet — decide in U3 against the actual key set the user stores. Depends on real 1Password item names, which live in `nixy-priv`, not here.
- Which env defaults ship on-by-default (e.g. `PI_TELEMETRY=0`) vs. left to the user — decide in U1 while writing the module.

---

## Implementation Units

- [x] U1. **Home Manager pi module: runtime + environment**

**Goal:** Install the Bun runtime declaratively and set pi's non-secret environment and PATH so an imperatively-installed `pi` is runnable and predictable.

**Requirements:** R2, R3, R4

**Dependencies:** None

**Files:**
- Create: `modules/home/pi.nix`
- Modify: `users/example.nix` (add to `imports`)
- Test: extend `scripts/` test coverage or flake check per U5 (no standalone unit test framework for Nix modules; evaluation is the test)

**Approach:**
- `home.packages = [ pkgs.bun ];` (runtime only; pi itself is imperative).
- `home.sessionVariables`: set `PI_PACKAGE_DIR` to a stable user-writable path (e.g. `${config.home.homeDirectory}/.local/share/pi/packages`), and any chosen defaults (`PI_TELEMETRY`/`PI_OFFLINE`) — final on/off decided here.
- Ensure Bun's global bin is on `PATH` (`home.sessionPath` or `BUN_INSTALL`), so `bun install -g pi` produces a `pi` on `PATH`.
- Keep the module import-only and side-effect-free at eval so it composes into the public example without needing secrets.

**Patterns to follow:** `modules/home/shell.nix` (packages + `programs.*` shape), `users/example.nix` (import wiring).

**Test scenarios:**
- Happy path: `nix build .#darwinConfigurations.example-aarch64-darwin.system --dry-run` evaluates successfully with the module imported.
- Edge case: module evaluates without any secret/provider values present (proves eval-safety with no 1Password data).
- Integration: after eval, `home.sessionVariables` contains `PI_PACKAGE_DIR` and Bun's global bin path is present in the session PATH.

**Verification:** Dry-build succeeds; `pi` resolves on `PATH` after the documented imperative install; `env | grep PI_` shows the declared variables in a fresh login shell.

---

- [x] U2. **Baseline non-secret pi config (seed-if-absent)**

**Goal:** Provide a public-safe baseline `settings.json` for pi without clobbering pi's mutable config directory.

**Requirements:** R4, R6

**Dependencies:** U1

**Files:**
- Modify: `modules/home/pi.nix` (add activation-based seed)
- Test: covered by U5 eval check + a public-safety assertion

**Approach:**
- Use a Home Manager activation script (`home.activation`) that writes a baseline `settings.json` into `~/.config/pi/agent/` **only if the file does not already exist**, leaving user edits and pi's own writes untouched.
- Explicitly do **not** use `home.file`/`xdg.configFile` for this path (those create read-only store symlinks and would break pi's writes and its sibling mutable files: `trust.json`, `ide-selection.json`, sessions, caches).
- Baseline contents: theme/editor/`enableInstallTelemetry` — no secrets, no API keys, no private paths.

**Patterns to follow:** existing conservative, non-destructive activation posture (e.g. `modules/darwin/homebrew.nix` deliberately avoids destructive activation).

**Test scenarios:**
- Happy path: on a host with no existing `settings.json`, activation creates it with the baseline contents.
- Edge case: on a host where `settings.json` already exists, activation leaves it unchanged (idempotent, non-destructive).
- Edge case: activation does not touch `trust.json`, `ide-selection.json`, `sessions/`, or package dirs.
- Error path: baseline JSON is valid JSON (a malformed seed would break pi startup) — assert parseability.

**Verification:** Fresh account gets a baseline `settings.json`; a modified `settings.json` survives a subsequent `darwin-rebuild switch`; `jq . settings.json` succeeds.

---

- [x] U3. **Provider secrets via 1Password**

**Goal:** Supply pi provider API keys at runtime from 1Password without committing secrets, reusing the repo's established strategy.

**Requirements:** R5

**Dependencies:** U1; the existing 1Password profile (`profiles/onepassword.nix`) as the composition anchor for real hosts.

**Files:**
- Modify: `modules/home/pi.nix` (optional launch wrapper/alias) or `docs/pi.md` (documented `op run` snippet)
- Modify: `docs/onepassword.md` (cross-link pi's key usage) if a new item convention is introduced

**Approach:**
- Prefer `op run -- pi …` (or `op read` into the launching shell) so keys never touch disk in plaintext or the Nix store.
- If a wrapper/alias is added, keep item names/paths out of public nixy — real 1Password references belong in `nixy-priv` or a local ignored override (mirrors how real hostnames stay out of this repo).
- Document opt-out/manual path for users not on 1Password.

**Execution note:** Verify no secret literal ever lands in a committed file — this unit is the highest-risk for leakage.

**Patterns to follow:** `docs/onepassword.md` first-run checklist; README "Public/private boundary".

**Test scenarios:**
- Happy path: launching pi through the documented 1Password path makes the provider key available to pi's process environment.
- Error path: with 1Password locked/unavailable, the launch fails loudly (no silent fallback to an unauthenticated or hardcoded key).
- Integration / safety: `scripts/check-public-safety.sh` finds no key/token literal introduced by this unit (ties to U5).

**Verification:** `check-public-safety` passes; grep of the repo shows no provider key patterns; pi authenticates when launched via the 1Password path and fails cleanly when it is not unlocked.

---

- [x] U4. **Documentation**

**Goal:** Document install, upgrade, config, secrets, offline/telemetry, and uninstall for pi on nix-managed hosts.

**Requirements:** R7

**Dependencies:** U1, U2, U3

**Files:**
- Create: `docs/pi.md`
- Modify: `README.md` (add pi to tools/secrets sections, link `docs/pi.md`)
- Modify: `docs/operations.md` (add pi install/upgrade to the operating flows)

**Approach:**
- `docs/pi.md`: imperative install (`bun install -g @earendil-works/pi-coding-agent`), pin/upgrade (`pi update --self`), what Nix owns vs. what stays manual, `PI_PACKAGE_DIR`/`PI_OFFLINE`/`PI_TELEMETRY` rationale, secrets via 1Password, seed-if-absent `settings.json` behavior, and uninstall/escape-hatch.
- Apply the `plain-english` skill before finalizing (per repo docs-writing rule).

**Execution note:** Documentation-writing rule requires the `plain-english` pass on new/materially-edited docs.

**Patterns to follow:** `docs/onepassword.md` structure (first-run checklist + troubleshooting), `docs/operations.md` flow style.

**Test scenarios:**
- `Test expectation: none -- documentation only.` Correctness is verified by review and by following the steps on a real host; links resolve.

**Verification:** A reader can install, configure, upgrade, and uninstall pi from `docs/pi.md` alone; README and operations cross-links resolve; `plain-english` pass applied.

---

- [x] U5. **Validation: eval check + public-safety guard**

**Goal:** Prove the pi module composes and guarantee the change introduces no committed secrets, wired into the repo's existing gate.

**Requirements:** R8, R9

**Dependencies:** U1, U2, U3

**Files:**
- Modify: `flake.nix` (`checks.${system}` — add an eval-only pi composition check, mirroring `example-aarch64-darwin-onepassword`)
- Modify: `justfile` (`check` target — include the new check)
- Modify: `scripts/check-public-safety.sh` / `scripts/check-public-safety.test.sh` only if a pi-specific pattern is warranted beyond existing `api[_-]?key`/`token` coverage

**Approach:**
- Add an eval-only `darwinSystem` in `checks` that imports the pi module (and, where relevant, the onepassword profile) to prove composition without being a switch target.
- Extend the `just check` aggregate so the new check runs alongside the existing ones.
- Confirm existing deny-patterns already catch pi provider keys; extend only if a gap is found.

**Patterns to follow:** `flake.nix` `example-aarch64-darwin-onepassword` eval-only check; `justfile` `check` target; `scripts/check-public-safety.test.sh` test style.

**Test scenarios:**
- Happy path: `nix build .#checks.aarch64-darwin.<pi-check> --dry-run` evaluates.
- Edge case: the check is eval-only and cannot be switched to (no real user/secret required).
- Error path: `check-public-safety` fails if a fake provider-key literal is planted in a pi file (regression-guards the scanner covers pi's surface).
- Integration: `just check` runs the pi eval check plus public-safety in one pass and succeeds.

**Verification:** `just check` passes green with the pi module present; planting a dummy provider-key assignment in a pi file makes `check-public-safety` fail; removing it restores green.

---

## System-Wide Impact

- **Interaction graph:** New home module imported by `users/example.nix`; new eval-only flake check; `just check` aggregate gains a step. No change to the darwin/system ownership boundary (Determinate owns Nix; nix-darwin owns system; Home Manager owns user).
- **Error propagation:** 1Password-locked launch must fail loudly (no silent unauthenticated fallback). Malformed baseline `settings.json` would break pi startup — guarded by JSON validity in U2.
- **State lifecycle risks:** pi's mutable config dir must never become a read-only store symlink (U2's core constraint). Seed-if-absent is idempotent and non-destructive across rebuilds.
- **API surface parity:** `PATH`/global-bin behavior differs between Bun (chosen) and Node; documented so a future runtime change is deliberate.
- **Integration coverage:** Eval-only flake check proves composition; public-safety scanner proves no secret leakage — the two cross-layer guarantees unit-level evaluation alone would miss.
- **Unchanged invariants:** Public example host stays build/eval-safe and secret-free; the public/private boundary and 1Password-as-secrets-source are preserved, not changed.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Home Manager symlinks pi's config read-only, breaking pi writes | Seed-if-absent activation copy only; never `home.file` for the config dir (U2). |
| Provider key committed to public repo | 1Password `op run` at launch; keys/item names live in `nixy-priv`; `check-public-safety` gate (U3, U5). |
| Bun global-install prefix not on PATH → `pi` not found | Set `BUN_INSTALL`/`home.sessionPath` in the module; verify in U1. |
| pi upgrades drift silently (imperative binary) | Document pin + `pi update --self`; note current version (0.85.1) in `docs/pi.md`. |
| `PI_PACKAGE_DIR` unset → packages land in tokenized/unpredictable store-adjacent paths | Set it explicitly to a user-writable path (U1). |
| Baseline `settings.json` invalid JSON breaks startup | Validate JSON in U2 test scenarios. |

---

## Documentation / Operational Notes

- New `docs/pi.md`; README and `docs/operations.md` updated. Apply `plain-english` before finalizing docs.
- Real hosts compose the pi module (and 1Password) from `nixy-priv`; the public example stays eval-safe.
- Before any push to the public GitHub remote, run the `public-push-guard` skill (repo rule) in addition to `check-public-safety`.

---

## Sources & References

- Related code: `flake.nix` (`checks`), `profiles/onepassword.nix`, `modules/home/shell.nix`, `users/example.nix`, `scripts/check-public-safety.sh`, `justfile`.
- Prior art in repo: `docs/plans/2026-09-18-001-feat-determinate-nix-macos-plan.md` (foundation + eval-safe/opt-in conventions), `docs/onepassword.md` (Nix-wires-tool / secrets-manual pattern).
- pi docs (bundled): install/update, `PI_PACKAGE_DIR`, `PI_OFFLINE`, `PI_TELEMETRY`, `settings.json`, package dirs.
