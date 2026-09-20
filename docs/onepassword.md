# 1Password

This repo installs and wires the 1Password desktop app, 1Password CLI v2, and
the 1Password SSH agent declaratively. It never stores plaintext secrets,
real account/vault/item metadata, or private SSH host mappings. Account
sign-in, unlock, and feature toggles stay manual — see
[First-run checklist](#first-run-checklist).

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

## First-run checklist

After a successful `darwin-rebuild switch` on a host with this profile
enabled:

1. Open 1Password.app and sign in.
2. Unlock 1Password.
3. Enable CLI integration (Settings → Developer → "Integrate with 1Password
   CLI").
4. Enable the SSH agent (Settings → Developer → "Use the SSH agent") — only
   needed if the host also wires `modules/home/onepassword-ssh.nix`.
5. Import or create SSH keys in 1Password.
6. Verify the CLI can see your account:

   ```sh
   op vault list
   ```

7. Attempt an SSH connection that uses a 1Password-held key (for example
   `ssh -T git@github.com`) and approve the first-connection prompt from
   1Password.
8. Verify the agent offers the expected keys:

   ```sh
   ssh-add -l
   ```

If `op vault list` fails, 1Password is either not signed in, locked, or CLI
integration is disabled — fix that before assuming a Nix problem. If step 7
fails, see [SSH agent](#ssh-agent) for the same failure mapped to a fix.

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

## Existing-Mac adoption

Adopting a Mac that already has 1Password-related state in place:

- **1Password already installed manually:** `nix-homebrew` does not migrate
  or remove an existing 1Password install it does not already own — see
  [Existing-Mac adoption](operations.md#existing-mac-adoption). If ownership
  conflicts, resolve it by hand before retrying `darwin-rebuild switch`.
- **A different SSH agent already running** (e.g. a manually started
  `ssh-agent`, GPG's agent in SSH mode, or another password manager's
  agent): enabling `modules/home/onepassword-ssh.nix` sets `IdentityAgent`
  to the 1Password socket for SSH's own config, but it does not stop or
  unconfigure another agent running outside SSH config (for example one
  exported globally via `SSH_AUTH_SOCK` in shell startup). Check for and
  remove conflicting `SSH_AUTH_SOCK` exports in `~/.zshrc`/`~/.zprofile`
  before relying on the 1Password agent.
- **An existing unmanaged `~/.ssh/config`:** see
  [SSH agent](#ssh-agent) above — move it aside or restructure it as an
  `Include` before enabling the SSH module.
- **Manually exported secrets** (real values sitting in `~/.zshrc`,
  `~/.zprofile`, a global `.env`, or launchd `EnvironmentVariables`):
  migrate these to `op run --env-file` (see
  [Runtime secrets](#runtime-secrets-op-run)) and remove the plaintext
  export. Do this deliberately, one secret at a time — do not assume a Nix
  switch removes secrets that live outside files this repo manages.

## Runtime secrets: `op run`

The default pattern for command-scoped and project-scoped secrets is:

```sh
op run --env-file <reference-file> -- <command>
```

`<reference-file>` is a `KEY=op://<vault>/<item>/<field>` env file. `op run`
resolves each `op://` reference at the moment the command starts, injects
the resolved values only into that command's process environment, and never
writes them to disk, Nix, or the Nix store. If 1Password is locked, missing
the item, or lacks vault access, the command fails immediately — unlock,
sign in, or fix vault access, then rerun the command. No Nix build is
involved in this failure mode.

Prefer a project-local wrapper (a `direnv`-managed reference file, or a
one-off `op run --env-file .env.op -- npm start`) over a single global
secrets file. A repo with no reference file must still open shells and run
unrelated commands without prompting, hanging, or erroring — `op run` only
runs when a command explicitly invokes it.

### Where reference files live

| Location | Contents | Notes |
|---|---|---|
| Public `nixy` | Placeholders only, e.g. `EXAMPLE_VALUE=op://<vault>/<item>/<field>` | Never a real vault, item, or field name. |
| `nixy-priv` | Non-public reference metadata (real vault/item/field names) | Only if you accept that this can appear in Git history and, if templated through Nix, possibly Nix store paths. |
| Local ignored files (not committed anywhere) | Highly sensitive account, vault, item, host, or service names; full env-reference files | Use for anything you don't want in Git at all, public or private. |

### What never to do

- Never call `op read` or resolve `op://` references during Nix evaluation
  or a Nix build (`builtins.readFile` on a secret, `builtins.exec`-style
  tricks, or any derivation that shells out to `op` at build time). Values
  resolved that way land in the world-readable Nix store.
- Never let Home Manager generate a plaintext file containing a resolved
  secret (`home.file` with a resolved value baked in).
- Never put a resolved secret in a launchd `EnvironmentVariables` plist.
- Never export a resolved secret as a global, always-on shell variable
  (e.g. in `.zshrc`/`.zprofile`). Resolve at the point of use instead.
- Never call `op` during shell startup. Shell startup should be fast and
  should not depend on 1Password being unlocked; only the commands that
  actually need secrets should invoke `op run`.

### After `op run` resolves values

Resolved secrets are ordinary process environment variables for the
lifetime of the child command (and anything it spawns). `op run` prevents
Nix-store leakage, but it does not prevent every other kind of leak:

- Avoid wrapping long-running services or daemons in `op run` unless you've
  accepted that every child process inherits the secret environment for the
  life of the service.
- Avoid shell tracing (`set -x`), verbose/debug logs, crash reporters, and
  telemetry tools for anything invoked under `op run` — these can capture
  and persist the environment.
- Avoid commands that print or dump their environment (`env`, `printenv`,
  some verbose `--debug` flags) while running under `op run`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `darwin-rebuild switch` fails during Homebrew activation | Homebrew already installed outside `nix-homebrew`'s ownership | See [Existing-Mac adoption](operations.md#existing-mac-adoption); resolve the ownership conflict by hand, then retry. |
| `op vault list` fails or hangs | 1Password is locked, not signed in, or CLI integration is off | Unlock/sign in to 1Password, enable Settings → Developer → "Integrate with 1Password CLI", retry. |
| `ssh-add -l` shows no keys / SSH prompts for a password instead of using 1Password | SSH agent setting is off, or no keys are imported | Enable Settings → Developer → "Use the SSH agent" and import/create keys in 1Password. |
| SSH connects but 1Password never prompts and the wrong key is offered | A different identity file or agent is taking precedence, or 1Password is offering a broader key set than intended | Check for stale `IdentityFile`/`IdentityAgent` entries elsewhere in SSH config and for private per-host key filtering — see [Local trust boundary](#ssh-agent) and keep real filtering rules in `nixy-priv` or a local ignored file. |
| `op run --env-file ... -- <command>` fails immediately | 1Password is locked, the referenced item doesn't exist, or the account lacks vault access | Unlock/sign in, confirm the item/vault name and access, then rerun the command — no Nix build is involved. |
| A command run under `op run` seems to have no secrets in its environment | The reference file path is wrong, or the file lives outside version control by design (see [Where reference files live](#where-reference-files-live)) | Confirm the `--env-file` path and that it isn't an accidentally-empty placeholder file. |
