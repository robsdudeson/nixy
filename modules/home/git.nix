{ ... }:

{
  programs.git = {
    enable = true;
    userName = "Example User";
    userEmail = "example@example.invalid";

    extraConfig = {
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
