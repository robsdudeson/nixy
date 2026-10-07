# Test for the optionless gh home module.
# Run with: nix eval --file ./gh-test.nix
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
            options.programs.gh = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                  settings = lib.mkOption {
                    type = lib.types.attrs;
                    default = { };
                  };
                };
              };
              default = { };
            };
            config._module.args = { inherit pkgs; };
          }
        ]
        ++ lib.optional enable ../../modules/home/gh.nix;
      };
    in
    evaluated.config;

  tests = {
    test_disabled_when_module_excluded = {
      expr =
        let
          config = evalModule { };
        in
        config.programs.gh.enable;
      expected = false;
    };

    test_import_sets_gh = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        config.programs.gh.enable;
      expected = true;
    };

    test_import_sets_git_protocol_ssh = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        config.programs.gh.settings.git_protocol;
      expected = "ssh";
    };

    test_import_sets_aliases = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        config.programs.gh.settings.aliases;
      expected = {
        co = "pr checkout";
        pv = "pr view";
        pvw = "pr view --web";
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
