# Test for the WSL NixOS machine module.
# Run with: nix eval --file ./wsl-test.nix
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
          ../../modules/nixos/wsl.nix
          {
            options = {
              wsl.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              wsl.defaultUser = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              wsl.ssh-agent.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              programs.nix-ld.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              networking.hostName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              system.stateVersion = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              home-manager.users = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              users.users = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
            };

            config._module.args = { inherit pkgs; };
          }
          {
            machine.wsl.enable = enable;
          }
        ];
      };
    in
    evaluated.config;

  tests = {
    test_disabled_by_default = {
      expr =
        let
          config = evalModule { };
        in
        {
          wslEnabled = config.wsl.enable;
          nixLdEnabled = config.programs.nix-ld.enable;
          defaultUser = config.wsl.defaultUser;
          sshAgentEnabled = config.wsl.ssh-agent.enable;
        };
      expected = {
        wslEnabled = false;
        nixLdEnabled = false;
        defaultUser = null;
        sshAgentEnabled = false;
      };
    };

    test_enabled_sets_wsl_defaults = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          wslEnabled = config.wsl.enable;
          nixLdEnabled = config.programs.nix-ld.enable;
        };
      expected = {
        wslEnabled = true;
        nixLdEnabled = true;
      };
    };

    test_enabled_leaves_host_identity_local = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          hostName = config.networking.hostName;
          systemStateVersion = config.system.stateVersion;
          defaultUser = config.wsl.defaultUser;
          sshAgentEnabled = config.wsl.ssh-agent.enable;
          osUsers = config.users.users;
          homeUsers = config.home-manager.users;
        };
      expected = {
        hostName = null;
        systemStateVersion = null;
        defaultUser = null;
        sshAgentEnabled = false;
        osUsers = { };
        homeUsers = { };
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
