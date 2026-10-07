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

    # Scoped NixOS line for WSL hosts. These inputs are pinned to the exact
    # locked revisions of the live host's flake (see docs/plans/
    # 2026-10-06-001-feat-nixos-wsl-host-migration-plan.md) — do not let them
    # drift with `nix flake update` without re-verifying the migration gates.
    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager-nixos = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
    };

    pi.url = "github:earendil-works/pi/stable";

    # The live host runs bun 1.4.2 from this PR-head rev; the locked
    # nixos-26.05 rev still carries bun 1.3.13 (verified 2026-10-06). PR
    # 556047 merged to master 2026-09-12 but is not backported to the locked
    # 26.05 rev yet — drop this input and the overlay in modules/nixos/
    # overlays.nix once nixos-26.05 carries bun >= 1.4.
    nixpkgs-bun.url = "github:NixOS/nixpkgs/pull/556047/head";
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
      nixosSystem = "x86_64-linux";
      nixosPkgs = inputs.nixpkgs-nixos.legacyPackages.${nixosSystem};
      runModuleTest =
        name: file:
        let
          result = import file { pkgs = nixosPkgs; };
        in
        nixosPkgs.runCommand name { } (
          if result.success then
            ''
              echo ${nixosPkgs.lib.escapeShellArg result.message}
              touch $out
            ''
          else
            throw "${name} FAILED: ${result.message}"
        );
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

      # Fake-safe NixOS WSL host on the scoped 26.05 line (see
      # hosts/example-x86_64-linux/). Proves the public composition: inputs,
      # overlay, machine modules, and home modules — no private data.
      nixosConfigurations.example-x86_64-linux = inputs.nixpkgs-nixos.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
          hostName = "example-x86_64-linux";
          primaryUser = "example";
        };

        modules = [
          ./hosts/example-x86_64-linux
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      checks.${system} = {
        example-aarch64-darwin = self.darwinConfigurations.example-aarch64-darwin.system;

        # Evaluation-only coverage for opt-in profiles. These are not
        # darwinConfigurations, so they can never be switched to, but they
        # prove each profile composes cleanly before nixy-priv imports it.
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

        example-aarch64-darwin-pi =
          (nix-darwin.lib.darwinSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
              hostName = "example-aarch64-darwin";
              primaryUser = "example";
            };

            modules = [
              ./hosts/example-aarch64-darwin
              ./profiles/pi.nix
            ];
          }).system;

        example-aarch64-darwin-llama-server =
          (nix-darwin.lib.darwinSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
              hostName = "example-aarch64-darwin";
              primaryUser = "example";
            };

            modules = [
              ./hosts/example-aarch64-darwin
              ./profiles/llama-server.nix
              # Minimal config to prove eval with service disabled.
              (
                { lib, ... }:
                {
                  home-manager.users.example.services.llama-server.enable = lib.mkForce false;
                }
              )
            ];
          }).system;

        # Sanitized enabled configuration that exercises the complete command
        # and launchd-agent shape without referencing a real host or model.
        example-aarch64-darwin-llama-server-enabled =
          (nix-darwin.lib.darwinSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
              hostName = "example-aarch64-darwin";
              primaryUser = "example";
            };

            modules = [
              ./hosts/example-aarch64-darwin
              ./profiles/llama-server.nix
              {
                home-manager.users.example.services.llama-server = {
                  enable = true;
                  modelPath = "/Users/example/.cache/llama-server/example.gguf";
                  alias = "example-model";
                };
              }
            ];
          }).system;
      };

      # NixOS side: full toplevel build of the example WSL host on the
      # scoped 26.05 line (separate system from the darwin checks above).
      checks.x86_64-linux = {
        example-x86_64-linux = self.nixosConfigurations.example-x86_64-linux.config.system.build.toplevel;

        fish-test = runModuleTest "fish-module-test" ./tests/home/fish-test.nix;
        gh-test = runModuleTest "gh-module-test" ./tests/home/gh-test.nix;
        git-test = runModuleTest "git-module-test" ./tests/home/git-test.nix;
        pi-declarative-test = runModuleTest "pi-declarative-module-test" ./tests/home/pi-declarative-test.nix;
        vscode-test = runModuleTest "vscode-module-test" ./tests/home/vscode-test.nix;
        common-test = runModuleTest "common-module-test" ./tests/nixos/common-test.nix;
        wsl-test = runModuleTest "wsl-module-test" ./tests/nixos/wsl-test.nix;
      };
    };
}
