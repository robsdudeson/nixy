# Test for the common NixOS machine module.
# Run with: nix eval --file ./common-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  evalModule =
    {
      enable ? false,
      nh ? false,
      packages ? false,
      extraPackages ? [ ],
      editor ? null,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          ../../modules/nixos/common.nix
          {
            options = {
              nix.settings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              nixpkgs.config = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              programs.nh.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              programs.nh.clean.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              environment.systemPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              environment.variables = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
              };
              home-manager.useUserPackages = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              home-manager.useGlobalPkgs = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              home-manager.sharedModules = lib.mkOption {
                type = lib.types.listOf lib.types.anything;
                default = [ ];
              };
            };

            config._module.args = { inherit pkgs; };
          }
          {
            machine.common = {
              inherit enable extraPackages editor;
              nh.enable = nh;
              packages.enable = packages;
            };
          }
        ];
      };
    in
    evaluated.config;

  packageNames = config: map lib.getName config.environment.systemPackages;

  tests = {
    test_disabled_by_default = {
      expr =
        let
          config = evalModule { };
        in
        {
          settings = config.nix.settings;
          nixpkgsConfig = config.nixpkgs.config;
          nhEnabled = config.programs.nh.enable;
          nhCleanEnabled = config.programs.nh.clean.enable;
          systemPackages = config.environment.systemPackages;
          editor = config.environment.variables.EDITOR or null;
          useUserPackages = config.home-manager.useUserPackages;
          useGlobalPkgs = config.home-manager.useGlobalPkgs;
          sharedModules = config.home-manager.sharedModules;
        };
      expected = {
        settings = { };
        nixpkgsConfig = { };
        nhEnabled = false;
        nhCleanEnabled = false;
        systemPackages = [ ];
        editor = null;
        useUserPackages = false;
        useGlobalPkgs = false;
        sharedModules = [ ];
      };
    };

    test_enabled_sets_base_options = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          experimentalFeatures = config.nix.settings.experimental-features;
          useXdgBaseDirs = config.nix.settings.use-xdg-base-directories;
          allowUnfree = config.nixpkgs.config.allowUnfree;
          useUserPackages = config.home-manager.useUserPackages;
          useGlobalPkgs = config.home-manager.useGlobalPkgs;
        };
      expected = {
        experimentalFeatures = "nix-command flakes";
        useXdgBaseDirs = true;
        allowUnfree = true;
        useUserPackages = true;
        useGlobalPkgs = true;
      };
    };

    test_enabled_leaves_optional_defaults_off = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          nhEnabled = config.programs.nh.enable;
          nhCleanEnabled = config.programs.nh.clean.enable;
          systemPackageCount = builtins.length config.environment.systemPackages;
          editor = config.environment.variables.EDITOR or null;
        };
      expected = {
        nhEnabled = false;
        nhCleanEnabled = false;
        systemPackageCount = 0;
        editor = null;
      };
    };

    test_enabled_sets_xdg_in_shared_modules = {
      expr =
        let
          config = evalModule { enable = true; };
          sharedModule = builtins.head config.home-manager.sharedModules;
        in
        {
          hasSharedModules = builtins.length config.home-manager.sharedModules > 0;
          xdgEnabled = sharedModule.xdg.enable or false;
        };
      expected = {
        hasSharedModules = true;
        xdgEnabled = true;
      };
    };

    test_nh_gated_by_enable_and_nh_option = {
      expr =
        let
          disabled = evalModule { nh = true; };
          enabled = evalModule {
            enable = true;
            nh = true;
          };
        in
        {
          disabledNh = disabled.programs.nh.enable;
          enabledNh = enabled.programs.nh.enable;
          enabledClean = enabled.programs.nh.clean.enable;
        };
      expected = {
        disabledNh = false;
        enabledNh = true;
        enabledClean = true;
      };
    };

    test_editor_sets_editor_variable = {
      expr =
        let
          config = evalModule {
            enable = true;
            editor = "nvim";
          };
        in
        config.environment.variables.EDITOR;
      expected = "nvim";
    };

    test_common_packages_are_six_generic_packages_plus_extra_packages = {
      expr =
        let
          config = evalModule {
            enable = true;
            packages = true;
            extraPackages = [ pkgs.hello ];
          };
          names = packageNames config;
          expectedPackageNames = [
            "1password-cli"
            "git"
            "git-crypt"
            "nh"
            "nixfmt"
            "wget"
            "hello"
          ];
        in
        {
          count = builtins.length names;
          hasExpectedPackages = lib.all (name: builtins.elem name names) expectedPackageNames;
        };
      expected = {
        count = 7;
        hasExpectedPackages = true;
      };
    };
  };

  results = lib.mapAttrs (
    name: test:
    let
      passed = test.expr == test.expected;
    in
    {
      inherit passed;
      inherit (test) expected;
      actual = test.expr;
      message =
        if passed then
          "PASS"
        else
          "FAIL: expected ${builtins.toJSON test.expected}, got ${builtins.toJSON test.expr}";
    }
  ) tests;

  allPassed = lib.all (r: r.passed) (lib.attrValues results);

  summary = {
    inherit results allPassed;
    total = lib.length (lib.attrNames tests);
    passed = lib.length (lib.filter (r: r.passed) (lib.attrValues results));
  };
in
if allPassed then
  {
    success = true;
    message = "All ${toString summary.total} tests passed!";
    inherit (summary) results;
  }
else
  {
    success = false;
    message = "Tests failed: ${toString (summary.total - summary.passed)}/${toString summary.total}";
    inherit (summary) results;
  }
