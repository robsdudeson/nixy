{
  inputs,
  primaryUser,
  ...
}:

{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  users.users.${primaryUser}.home = "/Users/${primaryUser}";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # `inputs` must reach the Home Manager user evaluation: user modules that
  # import nixy modules via `"${inputs.nixy}/..."` strings otherwise fail to
  # resolve it (the fallback through `_module.args` forces `config` and
  # recurses). Mirrors what private NixOS hosts do in their host files.
  home-manager.extraSpecialArgs = {
    inherit inputs primaryUser;
  };
  home-manager.users.${primaryUser} = import ../../users/example.nix;
}
