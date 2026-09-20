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

Declarative, opt-in per user (once a host also wires
`modules/home/onepassword-ssh.nix`, e.g. via `profiles/onepassword.nix`):

- SSH `IdentityAgent` pointed at the 1Password SSH agent socket.
- `SSH_AUTH_SOCK` exported to the same socket for tools that read the
  environment instead of SSH config.

Manual (you, once per machine, after a switch):

- Signing in to the 1Password desktop app.
- Unlocking 1Password.
- Enabling CLI integration (1Password → Settings → Developer → "Integrate
  with 1Password CLI").
- Enabling the SSH agent (1Password → Settings → Developer → "Use the SSH
  agent").
- Importing or creating SSH keys in 1Password.
- Approving the first SSH connection attempt from a new client (1Password
  prompts for this).

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

## SSH agent

`modules/home/onepassword-ssh.nix` sets SSH's `IdentityAgent` to the
1Password SSH agent socket:

```
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

SSH private keys stay in 1Password; none are written to `~/.ssh`. This
module is opt-in and only applies to hosts/users that import it (real hosts
do this through `profiles/onepassword.nix` in `nixy-priv`).

**Existing `~/.ssh/config`:** Home Manager will not silently overwrite an
existing, unmanaged `~/.ssh/config`. If one already exists, either move it
aside (e.g. `mv ~/.ssh/config ~/.ssh/config.bak`) before the first switch
that enables this module, or restructure it as a private `Include` file and
let Home Manager manage the top-level file. Do not enable this module and
expect an existing hand-written config to merge automatically.

**Verify after enabling and completing first-run setup:**

```sh
ssh-add -l                    # lists keys offered by the agent
ssh -T git@github.com          # exercises Git-over-SSH through the agent
```

If 1Password is locked or the SSH agent setting is off, SSH fails outright
rather than silently falling back to another agent — unlock/start 1Password
and enable the SSH agent setting, then retry.

**Local trust boundary:** any process running as your user can attempt to
use the 1Password SSH agent socket to request a signature. 1Password prompts
for approval on new clients/keys by default — do not disable that prompt
globally. Real per-host or per-key filtering (which keys are offered where)
is a privacy/least-privilege control, not just a troubleshooting tool; keep
real host/key mappings in `nixy-priv` or a local ignored file (see
[`docs/private-overlay.md`](private-overlay.md)).
