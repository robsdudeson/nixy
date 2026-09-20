# Operations

This guide keeps risky system changes behind build checks.

## Ownership model

Determinate Nix owns:

- The installed Nix version.
- The Nix daemon and launchd service.
- `/etc/nix/nix.conf`.

nix-darwin owns:

- macOS system configuration.
- System packages and profiles.
- Home Manager activation through the nix-darwin module.

The public Determinate boundary lives in `modules/darwin/determinate.nix` and sets `nix.enable = false`. Do not add ordinary nix-darwin `nix.*` daemon settings while Determinate owns Nix.

`nix-homebrew` owns Homebrew bootstrap through `modules/darwin/homebrew.nix`; nix-darwin's `homebrew.*` options then declare brews/casks on top of that prefix. `nix-homebrew` refuses to adopt a Homebrew installation it does not already own rather than migrating it destructively — if activation stops with an ownership conflict, resolve it by hand (per `nix-homebrew`'s own docs) before retrying. Activation defaults (`autoUpdate`, `upgrade`, `cleanup = "none"`) stay non-destructive so adopting an existing Mac does not silently update, upgrade, or remove apps. Nix rollback does not remove or restore Homebrew cask/app state that exists outside a generation.

## Bootstrap script

`scripts/bootstrap.sh` is a guided wrapper around the validate-build-switch
flow below. It handles:

- Confirming the public checkout path (default `~/code/nixy`; override with
  `--repo <path>` or `NIXY_REPO`).
- Confirming the `nixy-priv` sibling checkout exists (override with
  `--private-repo <path>` or `NIXY_PRIV_REPO`).
- Discovering real `darwinConfigurations` from `nixy-priv` at runtime.
- Dry-building the selected host before offering a switch.
- Prompting for explicit confirmation (`y/N`) before any `darwin-rebuild switch`.
- Printing the [1Password first-run checklist](onepassword.md#first-run-checklist)
  pointer after a successful switch on 1Password-enabled hosts.

```sh
./scripts/bootstrap.sh            # interactive: prompt for host, then confirm switch
./scripts/bootstrap.sh --build-only   # validate and build; skip switch
./scripts/bootstrap.sh --host <host>  # non-interactive host selection
./scripts/bootstrap.sh --help         # all options
```

Use `just bootstrap` as a shortcut if `just` is installed.

The manual steps in the sections below are what the script wraps. Use them
directly when you need more control or are troubleshooting.

## Validate before switching

Use this order:

1. Show flake outputs.
2. Build the target system.
3. Switch only after the build passes.

Public example validation:

```sh
nix flake show
nix build .#darwinConfigurations.example-aarch64-darwin.system --dry-run
```

A real switch must use a host that names an existing macOS user. Put that host in `nixy-priv` or in a local ignored override.

## First switch

When `darwin-rebuild` is not installed yet, run it through nix-darwin:

```sh
sudo nix run nix-darwin#darwin-rebuild -- switch --flake /path/to/nixy-priv#<host>
```

After the first switch, use the installed command:

```sh
sudo darwin-rebuild switch --flake /path/to/nixy-priv#<host>
```

Do not switch the public `example-aarch64-darwin` host unless the Mac has an existing `example` user.

## Normal rebuild

From the real host repo:

```sh
nix flake show
nix build .#darwinConfigurations.<host>.system --dry-run
sudo darwin-rebuild switch --flake .#<host>
```

If the build fails, fix the expression before switching. If activation fails, read the activation log before retrying.

## Updates

Update inputs in the repo that owns the host:

```sh
nix flake update
nix build .#darwinConfigurations.<host>.system --dry-run
sudo darwin-rebuild switch --flake .#<host>
```

Review `flake.lock` before committing. Public lock files must not contain private Git URLs or private path inputs.

## Rollback

Nix and nix-darwin generations can roll back. Homebrew casks, MAS apps, and macOS defaults are not fully rollback-safe and may need manual cleanup.

Useful commands:

```sh
darwin-rebuild --list-generations
sudo darwin-rebuild rollback
```

If a GUI app, MAS app, or macOS default caused the issue, check the related module and be ready to undo the change by hand.

Rolling back a generation reverts which 1Password-related *modules* are
wired (whether `profiles/onepassword.nix` is imported, whether the SSH
agent module is enabled) but does not touch 1Password's own app state:
account sign-in, unlock state, imported/created SSH keys, the CLI
integration and SSH agent toggles, per-client SSH approvals, or a manual
`agent.toml`. That state lives inside the 1Password app and macOS Keychain,
outside any Nix generation. A rollback that disables the SSH agent module
still leaves 1Password's own "Use the SSH agent" setting on; turn it off by
hand in 1Password if you want SSH to stop offering those keys.

## Existing Mac adoption

Before adopting an existing Mac:

1. Back up the machine.
2. Inventory current CLI tools, GUI apps, fonts, shell setup, Git config, and Homebrew state.
3. Classify each item as public base, private config, or manual.
4. Build before switching.
5. Keep Homebrew cleanup non-destructive.

Do not use destructive Homebrew cleanup during early adoption.

## Adding a host

For a real host, add it in `nixy-priv`:

1. Import this public repo.
2. Define `darwinConfigurations.<host>` in the private flake.
3. Set the real existing macOS user there.
4. Import public modules and profiles from this repo.
5. Keep real hostnames, private app lists, private taps, and secret references out of this repo.

For a public example host, use a sanitized host alias and fake-safe user data.

## Secrets

Secret values never enter Nix evaluation, builds, or generated files. Use
`op run --env-file <reference-file> -- <command>` to resolve 1Password
references only into the environment of the command that needs them. See
[`docs/onepassword.md`](onepassword.md#runtime-secrets-op-run) for the full
pattern, including where reference files belong and what to avoid.

## pi coding agent

Nix installs the Bun runtime and environment. Install pi itself once after
the first switch on a host that imports `profiles/pi.nix`:

```sh
bun install -g @earendil-works/pi-coding-agent
```

Upgrade with `pi update --self`. Supply provider API keys at runtime via
`op run --env-file .env.op -- pi` — never hardcode them. See
[`docs/pi.md`](pi.md) for the full guide.

## Direnv

Direnv is enabled through Home Manager, but `.envrc` files are not auto-approved. Read each `.envrc` before running:

```sh
direnv allow
```
