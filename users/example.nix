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
  # intentionally accepting Home Manager state migrations.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
