# Fake-safe Home Manager profile for the example NixOS WSL host.

{ pkgs, ... }:

{
  home.homeDirectory = "/home/example";
  home.stateVersion = "26.05";

  imports = [
    ../modules/home/fish.nix
    ../modules/home/gh.nix
    ../modules/home/git.nix
    ../modules/home/pi-declarative.nix
    # vscode.nix is intentionally not imported: the live WSL host does not
    # enable it (VS Code runs on the Windows side) and its extension list
    # needs the nix-vscode-extensions overlay, which the public line does not
    # carry.
  ];

  # Exercises the declarative pi module with its fake-safe public defaults:
  # empty settings, no models/auth/instructions file, no user services.
  programs.pi-declarative.enable = true;
}
