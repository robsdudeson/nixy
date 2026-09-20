{ lib, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user.name = lib.mkDefault "Example User";
      user.email = lib.mkDefault "example@example.invalid";
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
