# Private overlay contract

The public repo must evaluate without private files. The private repo, `nixy-priv`, imports this repo and defines real hosts.

## Checkout layout

Use sibling directories:

```text
code/rd/
├── nixy/
└── nixy-priv/
```

The public repo should not import `nixy-priv`. That keeps public evaluation stable and keeps private inputs out of the public lock file.

## What belongs in `nixy-priv`

Put these in the private repo:

- Real hostnames.
- Real macOS user names.
- Work-only apps and private app inventory.
- Private Homebrew taps.
- Identity config.
- Secret references.
- Encrypted secret files.
- Real 1Password account, vault, and item metadata.
- Real SSH host aliases and host-to-key mappings.
- A real `agent.toml` for 1Password SSH agent key filtering, if used.

## What never belongs in Nix plaintext

Do not put these in public or private Nix expressions if they can enter the Nix store:

- Tokens.
- Passwords.
- SSH private keys.
- Signing keys.
- Secret file contents.
- Unencrypted credential files.

The Nix store is readable by local users. Store secret material in a secret manager or encrypted file workflow added in a later pass.

## Import pattern

`nixy-priv` should import this repo as an input and compose real hosts from public modules and profiles. Keep the public repo as a base, not as a caller of private code.

A private host can use this shape:

```nix
{
  inputs.nixy.url = "github:robsdudeson/nixy";
  inputs.nix-darwin.follows = "nixy/nix-darwin";
  inputs.nixpkgs.follows = "nixy/nixpkgs";
}
```

Use a local path override while developing if needed:

```sh
nix build .#darwinConfigurations.<host>.system --override-input nixy path:../nixy
```

Do not commit a public lock file that points at a private path, private Git URL, or machine-local checkout.

## Public exports

The public flake should expose only stable, useful surfaces. Add module or profile exports only when `nixy-priv` needs them. Avoid a broad custom framework before real hosts prove the shape.

## Public-safety check

Run the safety check before committing or pushing:

```sh
./scripts/check-public-safety.sh
```

The check scans tracked and intent-to-add files for common private-input and secret patterns. It allows intentional documentation references to `nixy-priv`, but it should block private flake inputs, private lock entries, real local user paths, and token/key material.
