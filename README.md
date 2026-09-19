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

## Fresh Mac outline

1. Install Determinate Nix from the official installer.
2. Clone this repo and, for real hosts, clone `nixy-priv` as a sibling directory.
3. Validate the public base:

   ```sh
   nix flake show
   nix build .#darwinConfigurations.example-aarch64-darwin.system --dry-run
   ```

4. Build the real private host from `nixy-priv` before switching.
5. Switch only after the build succeeds and the host config names an existing macOS user.

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

## Useful commands

If `just` is installed:

```sh
just show
just build-example
just check-public-safety
```

Without `just`, run the commands in [`justfile`](justfile) directly.
