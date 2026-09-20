# 1Password

This repo installs and wires the 1Password desktop app, 1Password CLI v2, and
the 1Password SSH agent declaratively. It never stores plaintext secrets,
real account/vault/item metadata, or private SSH host mappings. Account
sign-in, unlock, and feature toggles stay manual — see
[First-run setup](#first-run-setup).

## What's declarative vs. manual

Declarative (this repo, once a host opts in via `profiles/onepassword.nix`):

- Installing the 1Password desktop app (Homebrew cask).
- Installing the 1Password CLI v2, `op` (Homebrew `1password-cli` formula).

Manual (you, once per machine, after a switch):

- Signing in to the 1Password desktop app.
- Unlocking 1Password.
- Enabling CLI integration (1Password → Settings → Developer → "Integrate
  with 1Password CLI").
- Importing or creating SSH keys and enabling the SSH agent.

Nix does not and cannot own 1Password account state, imported keys, app
approvals, or the SSH agent toggle. Treat those as first-run and existing-Mac
setup steps, not build output.

## Enabling this on a host

Public `nixy` does not enable 1Password on the public example host by
default. A real host opts in from `nixy-priv` (or a local ignored override)
by importing `profiles/onepassword.nix`:

```nix
imports = [
  # ... other nixy modules/profiles
  inputs.nixy + "/profiles/onepassword.nix"
];
```

`profiles/onepassword.nix` composes `modules/darwin/onepassword.nix` (app +
CLI install) and `modules/home/onepassword-ssh.nix` (SSH agent wiring, opt-in
per user). See [`docs/private-overlay.md`](private-overlay.md) for where real
`op://` references and SSH host mappings belong.

## Installed tooling

- 1Password desktop app: Homebrew cask `1password`.
- 1Password CLI v2: Homebrew formula `1password-cli`.

Both come from Homebrew, not nixpkgs, to match 1Password's supported macOS
install path and to avoid path ambiguity from installing `op` twice. If
1Password was previously installed by hand, `nix-homebrew` does not migrate
or remove that install for you — see
[Existing-Mac adoption](operations.md#existing-mac-adoption).

## First-run setup

After a successful `darwin-rebuild switch` on a host with this profile
enabled:

1. Open 1Password.app and sign in.
2. Unlock 1Password.
3. Enable CLI integration (Settings → Developer → "Integrate with 1Password
   CLI").
4. Verify the CLI can see your account:

   ```sh
   op vault list
   ```

If `op vault list` fails, 1Password is either not signed in, locked, or CLI
integration is disabled — fix that before assuming a Nix problem.
