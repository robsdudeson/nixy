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
  home-manager.extraSpecialArgs = {
    inherit primaryUser;
  };
  home-manager.users.${primaryUser} = import ../../users/example.nix;
}
