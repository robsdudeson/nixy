{
  primaryUser,
  ...
}:

{
  imports = [
    ../modules/home/direnv.nix
    ../modules/home/git.nix
    ../modules/home/shell.nix
  ];

  home.username = primaryUser;
  home.homeDirectory = "/Users/${primaryUser}";

  # Keep this aligned with the Home Manager release in the flake inputs when
  # intentionally accepting Home Manager state migrations. mkDefault so a
  # private host can pin an older anchor to avoid running migrations on an
  # already-migrated home.
  home.stateVersion = lib.mkDefault "25.11";

  programs.home-manager.enable = true;
}
