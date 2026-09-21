# nixy

Public-safe macOS workstation configuration with Determinate Nix, nix-darwin, and Home Manager.

This repo is the reusable base. Real machine names, real user names, work-only apps, private taps, and secret references belong in the sibling private repo, `nixy-priv`.

## Current status

The public flake exposes one build-safe Apple Silicon example host:

```sh
nix flake show
nix build .#darwinConfigurations.example-aarch64-darwin.system --dry-run
```

Do not run `darwin-rebuild switch` against the public example unless the Mac has an existing user named `example`. For a real Mac, define the real host and existing macOS user in `nixy-priv` or in a local ignored override.

## Bootstrap script

For guided setup, use `scripts/bootstrap.sh`. It validates the repo layout,
confirms the `nixy-priv` sibling is present, discovers real hosts, dry-builds
the selected host, and prompts before switching:

```sh
./scripts/bootstrap.sh
```

Or use `just bootstrap` if `just` is installed. Pass `--build-only` to
validate without switching. Use `--help` for all options.

The script never stores private hostnames in this repo — it discovers them
from your `nixy-priv` checkout at runtime. See
[`docs/operations.md`](docs/operations.md) for the full validate-build-switch
flow the script wraps.

## Fresh Mac outline

1. Install Determinate Nix from the official installer.
2. Clone this repo and `nixy-priv` as sibling directories.
3. Run `./scripts/bootstrap.sh` (or follow the manual steps below).
4. The script validates the layout, discovers real hosts, and guides you
   through a dry-build before any switch.

Manual steps (without the script):

1. Validate the public base:

   ```sh
   nix flake show
   nix build .#darwinConfigurations.example-aarch64-darwin.system --dry-run
   ```

2. Build the real private host from `nixy-priv` before switching.
3. Switch only after the build succeeds and the host config names an existing macOS user.

See [`docs/operations.md`](docs/operations.md) for rebuild, rollback, update, and existing-Mac adoption notes.

## Public/private boundary

This repo may contain:

- Shared modules and profiles.
- Fake-safe example users and hosts.
- Public-safe package choices.
- Documentation for safe operations.

This repo must not contain:

- Tokens, passwords, SSH private keys, signing keys, or secret file contents.
- Real private hostnames or work inventory.
- Private flake inputs or private lock entries.
- Plaintext data that should not enter the world-readable Nix store.

See [`docs/private-overlay.md`](docs/private-overlay.md) for the `nixy-priv` contract.

## Secrets: 1Password

This repo's secrets strategy is 1Password. Nix installs and wires the
1Password app, CLI v2, and SSH agent; 1Password itself holds SSH keys and
secret values. Sign-in, unlock, and feature toggles are manual first-run
steps. See [`docs/onepassword.md`](docs/onepassword.md), including its
[first-run checklist](docs/onepassword.md#first-run-checklist) and
[troubleshooting table](docs/onepassword.md#troubleshooting).

## pi coding agent

This repo provides an opt-in profile (`profiles/pi.nix`) for the
[pi coding agent](https://github.com/earendil-works/pi-coding-agent).
Nix installs Bun, Node/npm for LazyPi, and pi's non-secret environment (PATH,
config directory, package directory, telemetry). The `pi` binary itself is
installed with `bun install -g @earendil-works/pi-coding-agent` as a one-time
manual step. LazyPi is optional and runs after pi is installed to bootstrap
community Pi packages. Provider API keys are never committed — supply them at
runtime via `op run --env-file .env.op -- pi` (see
[`docs/onepassword.md`](docs/onepassword.md#runtime-secrets-op-run)).

See [`docs/pi.md`](docs/pi.md) for the full install, LazyPi, upgrade, secrets,
and uninstall guide.

## Useful commands

If `just` is installed:

```sh
just bootstrap            # guided setup (validate, discover hosts, build, switch)
just show
just build-example
just check-public-safety
```

Without `just`, run the commands in [`justfile`](justfile) directly.
