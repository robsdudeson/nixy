# Test for the optionless fish home module.
# Run with: nix eval --file ./fish-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  evalModule =
    {
      enable ? false,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options = {
              home.packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              programs.fish = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                    shellAbbrs = lib.mkOption {
                      type = lib.types.attrsOf lib.types.str;
                      default = { };
                    };
                    functions = lib.mkOption {
                      type = lib.types.attrsOf lib.types.str;
                      default = { };
                    };
                    plugins = lib.mkOption {
                      type = lib.types.listOf lib.types.attrs;
                      default = [ ];
                    };
                  };
                };
                default = { };
              };
            };
            config._module.args = { inherit pkgs; };
          }
        ]
        ++ lib.optional enable ../../modules/home/fish.nix;
      };
    in
    evaluated.config;

  tests = {
    test_disabled_when_module_excluded = {
      expr =
        let
          config = evalModule { };
        in
        {
          fishEnabled = config.programs.fish.enable;
          hasPackages = config.home.packages != [ ];
        };
      expected = {
        fishEnabled = false;
        hasPackages = false;
      };
    };

    test_import_sets_fish = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          fishEnabled = config.programs.fish.enable;
          hasFunctions = config.programs.fish.functions != { };
          hasPlugins = config.programs.fish.plugins != [ ];
        };
      expected = {
        fishEnabled = true;
        hasFunctions = true;
        hasPlugins = true;
      };
    };

    test_import_has_greeting_function = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        builtins.hasAttr "fish_greeting" config.programs.fish.functions;
      expected = true;
    };

    test_import_has_tide_config_function = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        builtins.hasAttr "my_tide_config" config.programs.fish.functions;
      expected = true;
    };

    test_import_has_tide_plugin = {
      expr =
        let
          config = evalModule { enable = true; };
          pluginNames = map (p: p.name) config.programs.fish.plugins;
        in
        builtins.elem "tide" pluginNames;
      expected = true;
    };

    test_import_has_shared_abbreviations = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          git = config.programs.fish.shellAbbrs.g;
          list = config.programs.fish.shellAbbrs.l;
          vim = config.programs.fish.shellAbbrs.vim;
          opSignin = config.programs.fish.shellAbbrs.ops;
        };
      expected = {
        git = "git";
        list = "ls -lah";
        vim = "nvim";
        opSignin = "op signin";
      };
    };

    test_import_has_packages = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        config.home.packages != [ ];
      expected = true;
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
