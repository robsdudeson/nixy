{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.pi-declarative;

  piAuthMerge = pkgs.writeShellScript "pi-auth-merge" ''
    set -euo pipefail

    base="$HOME/.pi/agent/auth.base.json"
    target="$HOME/.pi/agent/auth.json"

    if [ ! -f "$base" ]; then
      exit 0
    fi

    mkdir -p "$HOME/.pi/agent"
    tmp=$(mktemp "$HOME/.pi/agent/auth.json.XXXXXX")
    update_tmp=""
    cleanup() {
      rm -f "$tmp"
      if [ -n "$update_tmp" ]; then
        rm -f "$update_tmp"
      fi
    }
    trap cleanup EXIT
    chmod 600 "$tmp"

    if [ -f "$target" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" "$base" > "$tmp"
    else
      ${pkgs.jq}/bin/jq '.' "$base" > "$tmp"
    fi

    while IFS= read -r credential; do
      name=$(printf '%s' "$credential" | ${pkgs.jq}/bin/jq -r '.key')
      command=$(printf '%s' "$credential" | ${pkgs.jq}/bin/jq -r '.value.key | ltrimstr("!")')

      if ! resolved="$(${pkgs.bash}/bin/bash -c "$command" 2>/dev/null)"; then
        printf 'pi-auth-merge: failed to resolve command-backed api_key for auth entry "%s"\n' "$name" >&2
        exit 1
      fi

      resolved=$(printf '%s' "$resolved" | ${pkgs.jq}/bin/jq -R -r -s 'sub("^\\s+"; "") | sub("\\s+$"; "")')
      if [ -z "$resolved" ]; then
        printf 'pi-auth-merge: resolved command-backed api_key for auth entry "%s" was empty\n' "$name" >&2
        exit 1
      fi

      update_tmp=$(mktemp "$HOME/.pi/agent/auth.json.XXXXXX")
      chmod 600 "$update_tmp"
      ${pkgs.jq}/bin/jq --arg name "$name" --arg key "$resolved" '.[$name].key = $key' "$tmp" > "$update_tmp"
      mv "$update_tmp" "$tmp"
      update_tmp=""
      chmod 600 "$tmp"
    done < <(${pkgs.jq}/bin/jq -c 'to_entries[] | select((.value | type) == "object" and .value.type == "api_key" and (.value.key | type == "string") and (.value.key | startswith("!")))' "$tmp")

    mv "$tmp" "$target"
    trap - EXIT
    chmod 600 "$target"
  '';
in
{
  options.programs.pi-declarative = {
    enable = lib.mkEnableOption "pi-coding-agent with declarative base configuration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.pi-coding-agent or null;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent or null";
      description = "pi-coding-agent package to install and use for package reconciliation.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Contents of ~/.pi/agent/settings.json.";
    };

    models = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Optional contents of ~/.pi/agent/models.json.";
    };

    authBase = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Optional base Pi auth entries merged into ~/.pi/agent/auth.json at login without replacing existing local credentials.";
    };

    agentInstructionsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional AGENTS.md file to install at ~/.pi/agent/AGENTS.md.";
    };

    reconcilePackagesOnLogin = lib.mkEnableOption "a user service that runs pi update --extensions after activation/login";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "programs.pi-declarative requires pkgs.pi-coding-agent or an explicit programs.pi-declarative.package.";
      }
    ];

    home.packages = [ cfg.package ];

    home.file = {
      ".pi/agent/settings.json" = {
        text = lib.generators.toJSON { } cfg.settings;
        force = true;
      };
    }
    // lib.optionalAttrs (cfg.models != null) {
      ".pi/agent/models.json" = {
        text = lib.generators.toJSON { } cfg.models;
        force = true;
      };
    }
    // lib.optionalAttrs (cfg.authBase != null) {
      ".pi/agent/auth.base.json" = {
        text = lib.generators.toJSON { } cfg.authBase;
        force = true;
      };
    }
    // lib.optionalAttrs (cfg.agentInstructionsFile != null) {
      ".pi/agent/AGENTS.md" = {
        source = cfg.agentInstructionsFile;
        force = true;
      };
    };

    systemd.user.services = lib.mkMerge [
      (lib.mkIf (cfg.authBase != null) {
        pi-auth-merge = {
          Unit = {
            Description = "Merge declarative base Pi auth entries";
            ConditionPathExists = "%h/.pi/agent/auth.base.json";
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${piAuthMerge}";
          };

          Install.WantedBy = [ "default.target" ];
        };
      })
      (lib.mkIf cfg.reconcilePackagesOnLogin {
        pi-package-reconcile = {
          Unit = {
            Description = "Reconcile pi-coding-agent packages from declarative settings";
            After = [ "network-online.target" ];
            ConditionPathExists = "%h/.pi/agent/settings.json";
          };

          Service = {
            Type = "oneshot";
            WorkingDirectory = "%h";
            Environment = "PATH=${
              lib.makeBinPath [
                cfg.package
                pkgs.nodejs
                pkgs.git
                pkgs.openssh
              ]
            }";
            ExecStart = "${cfg.package}/bin/pi update --extensions";
          };

          Install.WantedBy = [ "default.target" ];
        };
      })
    ];
  };
}
