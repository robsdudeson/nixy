# Test for the git home module and gitIdentity option group.
# Run with: nix eval --file ./git-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  evalModule =
    {
      enable ? false,
      name ? "Example User",
      email ? "example@example.invalid",
      signingKey ? "ssh-ed25519 AAAATESTKEY",
      workstationDefaults ? true,
      sshSigningProgram ? null,
      sshCommand ? null,
      extraIgnores ? [ ],
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          ../../modules/home/git.nix
          {
            options = {
              programs.git = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                    settings = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                    };
                    ignores = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                    };
                  };
                };
                default = { };
              };
            };
            config._module.args = { inherit pkgs; };
          }
          {
            gitIdentity = {
              inherit enable workstationDefaults extraIgnores;
            }
            // lib.optionalAttrs enable {
              inherit name email signingKey;
            }
            // lib.optionalAttrs (sshSigningProgram != null) {
              inherit sshSigningProgram;
            }
            // lib.optionalAttrs (sshCommand != null) {
              inherit sshCommand;
            };
          }
        ];
      };
    in
    evaluated.config;

  basePublicIgnores = [
    "**.DS_Store"
    "**/__pycache__"
    "**.venv"
    "**/.ruff_cache"
  ];

  tests = {
    test_git_identity_disabled_uses_fake_safe_settings = {
      expr =
        let
          config = evalModule { };
        in
        {
          gitEnabled = config.programs.git.enable;
          userName = config.programs.git.settings.user.name;
          userEmail = config.programs.git.settings.user.email;
          hasSigningKey = builtins.hasAttr "signingKey" config.programs.git.settings.user;
          hasCommitGpgSign = builtins.hasAttr "commit" config.programs.git.settings;
          hasGpgFormat = builtins.hasAttr "gpg" config.programs.git.settings;
          hasSshSigningProgram = builtins.hasAttr "gpg \"ssh\"" config.programs.git.settings;
          hasCore = builtins.hasAttr "core" config.programs.git.settings;
          ignores = config.programs.git.ignores;
        };
      expected = {
        gitEnabled = true;
        userName = "Example User";
        userEmail = "example@example.invalid";
        hasSigningKey = false;
        hasCommitGpgSign = false;
        hasGpgFormat = false;
        hasSshSigningProgram = false;
        hasCore = false;
        ignores = [ ];
      };
    };

    test_enabled_sets_user_info_and_signing = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          userName = config.programs.git.settings.user.name;
          userEmail = config.programs.git.settings.user.email;
          signingKey = config.programs.git.settings.user.signingKey;
          commitGpgSign = config.programs.git.settings.commit.gpgSign;
          gpgFormat = config.programs.git.settings.gpg.format;
        };
      expected = {
        userName = "Example User";
        userEmail = "example@example.invalid";
        signingKey = "ssh-ed25519 AAAATESTKEY";
        commitGpgSign = true;
        gpgFormat = "ssh";
      };
    };

    test_workstation_defaults_present_when_enabled = {
      expr =
        let
          config = evalModule {
            enable = true;
            workstationDefaults = true;
          };
        in
        {
          pullRebase = config.programs.git.settings.pull.rebase;
          pushDefault = config.programs.git.settings.push.default;
          statusShort = config.programs.git.settings.status.short;
          githubRewrite = config.programs.git.settings."url \"git@github.com:\"".insteadOf;
          vimdiffTool = config.programs.git.settings.diff.tool;
        };
      expected = {
        pullRebase = true;
        pushDefault = "current";
        statusShort = true;
        githubRewrite = "https://github.com/";
        vimdiffTool = "vimdiff";
      };
    };

    test_workstation_defaults_can_be_disabled = {
      expr =
        let
          config = evalModule {
            enable = true;
            workstationDefaults = false;
          };
        in
        {
          hasPull = builtins.hasAttr "pull" config.programs.git.settings;
          hasPushDefault = (config.programs.git.settings.push or { }) ? default;
          hasRemote = builtins.hasAttr "remote" config.programs.git.settings;
          hasStatus = builtins.hasAttr "status" config.programs.git.settings;
        };
      expected = {
        hasPull = true;
        hasPushDefault = false;
        hasRemote = false;
        hasStatus = false;
      };
    };

    test_optional_ssh_signing_program_only_when_set = {
      expr =
        let
          withoutProgram = evalModule { enable = true; };
          withProgram = evalModule {
            enable = true;
            sshSigningProgram = "/usr/bin/example-ssh-sign";
          };
        in
        {
          omittedByDefault = !builtins.hasAttr "gpg \"ssh\"" withoutProgram.programs.git.settings;
          configured = withProgram.programs.git.settings."gpg \"ssh\"".program;
        };
      expected = {
        omittedByDefault = true;
        configured = "/usr/bin/example-ssh-sign";
      };
    };

    test_optional_ssh_command_only_when_set = {
      expr =
        let
          withoutCommand = evalModule { enable = true; };
          withCommand = evalModule {
            enable = true;
            sshCommand = "ssh -F /tmp/example-ssh-config";
          };
        in
        {
          omittedByDefault = !builtins.hasAttr "core" withoutCommand.programs.git.settings;
          configured = withCommand.programs.git.settings.core.sshCommand;
        };
      expected = {
        omittedByDefault = true;
        configured = "ssh -F /tmp/example-ssh-config";
      };
    };

    test_enabled_ignores_public_base_entries_plus_extra_ignores = {
      expr =
        let
          config = evalModule {
            enable = true;
            extraIgnores = [
              "example-extra-one"
              "example-extra-two"
            ];
          };
        in
        {
          ignores = config.programs.git.ignores;
          count = builtins.length config.programs.git.ignores;
        };
      expected = {
        ignores = basePublicIgnores ++ [
          "example-extra-one"
          "example-extra-two"
        ];
        count = 6;
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
