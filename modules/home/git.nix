{ config, lib, ... }:

let
  cfg = config.gitIdentity;
in
{
  options.gitIdentity = {
    enable = lib.mkEnableOption "real Git identity and SSH signing";

    name = lib.mkOption {
      type = lib.types.str;
      description = "Git user name to use when gitIdentity is enabled.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      description = "Git user email to use when gitIdentity is enabled.";
    };

    signingKey = lib.mkOption {
      type = lib.types.str;
      description = "SSH signing key to use when gitIdentity is enabled.";
    };

    workstationDefaults = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable opinionated workstation Git defaults such as vimdiff, rebase, and push defaults.";
    };

    sshSigningProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional SSH signing helper program.";
    };

    sshCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional SSH command override for Git.";
    };

    extraIgnores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional global gitignore entries appended when gitIdentity is enabled.";
    };
  };

  config.programs.git = {
    enable = true;

    settings = lib.mkMerge [
      {
        user.name = lib.mkDefault "Example User";
        user.email = lib.mkDefault "example@example.invalid";
        init.defaultBranch = "main";
        pull.ff = "only";
        push.autoSetupRemote = true;
      }

      (lib.mkIf cfg.enable (
        lib.recursiveUpdate
          {
            user = {
              name = cfg.name;
              email = cfg.email;
              signingKey = cfg.signingKey;
            };
            commit.gpgSign = true;
            gpg.format = "ssh";
          }
          (
            lib.optionalAttrs cfg.workstationDefaults {
              "mergetool \"vimdiff\"".cmd =
                "vim -d \"$LOCAL\" \"$REMOTE\" \"$BASE\" -c 'wincmd J' -c 'wincmd K' -c 'wincmd H' -c 'wincmd L' -c 'wincmd ='";
              "mergetool \"vimdiff\"".keepBackup = false;
              "mergetool \"vimdiff\"".trustExitCode = false;
              "url \"git@github.com:\"".insteadOf = "https://github.com/";
              "filter \"spacify\"".clean = "expand --tabs=4 --initial";
              diff.tool = "vimdiff";
              difftool.prompt = false;
              merge.tool = "vimdiff";
              pull.rebase = true;
              push.autoSetupRemote = true;
              push.default = "current";
              rebase.autoSquash = true;
              rebase.autoStash = true;
              rebase.tool = "vimdiff";
              rebase.updateRefs = true;
              remote.pushDefault = "origin";
              status.short = true;
            }
            // lib.optionalAttrs (cfg.sshSigningProgram != null) {
              "gpg \"ssh\"".program = cfg.sshSigningProgram;
            }
            // lib.optionalAttrs (cfg.sshCommand != null) {
              core.sshCommand = cfg.sshCommand;
            }
          )
      ))
    ];

    ignores = lib.mkIf cfg.enable (
      [
        "**.DS_Store"
        "**/__pycache__"
        "**.venv"
        "**/.ruff_cache"
      ]
      ++ cfg.extraIgnores
    );
  };
}
