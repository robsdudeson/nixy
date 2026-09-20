{
  inputs,
  primaryUser,
  ...
}:

{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  # nix-homebrew owns Homebrew bootstrap so this repo does not depend on an
  # undocumented pre-existing Homebrew install. It refuses to adopt a
  # conflicting existing installation rather than migrating it destructively.
  nix-homebrew = {
    enable = true;
    user = primaryUser;
  };

  # nix-darwin declares brews/casks once nix-homebrew owns the prefix.
  # Activation defaults stay non-destructive so adopting an existing Mac does
  # not silently update, upgrade, or remove user apps.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
