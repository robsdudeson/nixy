# Fake-safe Home Manager profile for the example Raspberry Pi host.

{ ... }:

{
  home.homeDirectory = "/home/example";
  home.stateVersion = "26.05";

  imports = [
    ../modules/home/fish.nix
    ../modules/home/git.nix
  ];
}
