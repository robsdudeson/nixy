{
  hostName,
  primaryUser,
  ...
}:

{
  imports = [
    ../../modules/darwin/determinate.nix
    ../../modules/darwin/home-manager.nix
    ../../modules/darwin/homebrew.nix
    ../../profiles/minimal.nix
  ];

  networking.hostName = hostName;
  nixpkgs.hostPlatform = "aarch64-darwin";

  # The public example is build/evaluation-safe. A real switch target must
  # override this with an existing macOS user from private configuration.
  system.primaryUser = primaryUser;

  system.stateVersion = 6;
}
