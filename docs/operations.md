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

## Direnv

Direnv is enabled through Home Manager, but `.envrc` files are not auto-approved. Read each `.envrc` before running:

```sh
direnv allow
```
