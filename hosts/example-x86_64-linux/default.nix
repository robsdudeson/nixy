# Fake-safe example NixOS WSL host. Proves the public side of the NixOS
# composition (scoped inputs, overlay, machine modules, home modules)
# without any private data — see docs/plans/2026-10-06-001-feat-nixos-wsl-host-migration-plan.md.

{
  inputs,
  hostName ? "example-x86_64-linux",
  primaryUser ? "example",
  ...
}:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../../modules/nixos/common.nix
    ../../modules/nixos/wsl.nix

    # Home Manager as a NixOS module so `nixos-rebuild switch` deploys it.
    inputs.home-manager-nixos.nixosModules.home-manager
  ];

  nixpkgs.overlays = import ../../modules/nixos/overlays.nix inputs;

  machine.common.enable = true;
  machine.wsl.enable = true;

  networking.hostName = hostName;

  # WSL boots into this user by default; it must be a regular account.
  wsl.defaultUser = primaryUser;

  users.users.${primaryUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  home-manager.extraSpecialArgs = {
    inherit inputs;
  };

  home-manager.users.${primaryUser} = import ../../users/example-nixos.nix;

  system.stateVersion = "26.05";
}
