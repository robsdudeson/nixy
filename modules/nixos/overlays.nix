# Public bun + pi-coding-agent overlay for NixOS WSL hosts.
#
# The live WSL host needs bun 1.4.x (the locked nixos-26.05 rev still
# carries 1.3.13) and the packaged pi-coding-agent binary instead of a
# manual `bun install -g`. Exposed as a function of the flake inputs so
# the public example host and nixy-priv's mk-nixos-host consume the same
# definition.

inputs:
[
  (final: prev: {
    bun = inputs.nixpkgs-bun.legacyPackages.${final.system}.bun;
    pi-coding-agent = inputs.pi.packages.${final.system}.pi;
  })
]
