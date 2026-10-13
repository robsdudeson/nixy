# Fake-safe Raspberry Pi 4 host. Proves the public aarch64-linux NixOS
# composition without real hostnames, users, network inventory, or secrets.

{
  inputs,
  hostName ? "example-aarch64-rpi",
  primaryUser ? "example",
  ...
}:

{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/raspberry-pi.nix

    # Home Manager as a NixOS module so nixos-rebuild deploys it on real Pi hosts.
    inputs.home-manager-rpi.nixosModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  machine.common.enable = true;
  machine.raspberry-pi.enable = true;

  networking.hostName = hostName;

  users.users.${primaryUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  home-manager.extraSpecialArgs = {
    inherit inputs;
  };
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${primaryUser} = import ../../users/example-rpi.nix;

  system.stateVersion = "26.05";
}
