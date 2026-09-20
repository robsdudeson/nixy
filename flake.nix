{
  description = "Public-safe Determinate Nix macOS host foundation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      darwinConfigurations.example-aarch64-darwin = nix-darwin.lib.darwinSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
          hostName = "example-aarch64-darwin";
          primaryUser = "example";
        };

        modules = [
          ./hosts/example-aarch64-darwin
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      checks.${system} = {
        example-aarch64-darwin = self.darwinConfigurations.example-aarch64-darwin.system;

        # Evaluation-only coverage for opt-in profiles. This is not a
        # darwinConfiguration, so it can never be switched to, but it proves
        # the profile composes cleanly before nixy-priv imports it for real.
        example-aarch64-darwin-onepassword =
          (nix-darwin.lib.darwinSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
              hostName = "example-aarch64-darwin";
              primaryUser = "example";
            };

            modules = [
              ./hosts/example-aarch64-darwin
              ./profiles/onepassword.nix
            ];
          }).system;
      };
    };
}
