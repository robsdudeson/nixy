{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.pi-declarative;
  hmDag = lib.hm.dag or { entryAfter = _deps: script: script; };

  managedPiWrapper = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    for candidate in \
      "$HOME/.local/bin/pi" \
      "$HOME/.pi/agent/bin/pi" \
      "$HOME/.bun/bin/pi" \
      "$HOME/.npm-global/bin/pi"
    do
      if [ -x "$candidate" ]; then
        exec "$candidate" "$@"
      fi
    done

    echo "pi: managed pi is not installed yet; rebuild or run: curl -fsSL https://pi.dev/install.sh | sh" >&2
    exit 127
  '';

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

    installMethod = lib.mkOption {
      type = lib.types.enum [
        "managed-installer"
        "nix"
      ];
      default = "managed-installer";
      description = ''
        How the pi executable is provided. Use "managed-installer" for the
        official pi.dev installer so `pi update` can update Pi itself. Use
        "nix" only when the binary should be provided by Nix; in that mode
        `pi update` can update extensions and models but not Pi itself.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = "pi-coding-agent package to install when installMethod is \"nix\" and to put on PATH for package reconciliation when available.";
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

    manageOnActivation = lib.mkEnableOption "install or update managed pi during Home Manager activation";
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optional (cfg.installMethod == "nix") {
      assertion = cfg.package != null;
      message = "programs.pi-declarative.installMethod = \"nix\" requires pkgs.pi-coding-agent or an explicit programs.pi-declarative.package.";
    };

    home.packages =
      lib.optional (cfg.installMethod == "nix" && cfg.package != null) cfg.package
      ++ lib.optional (cfg.installMethod == "managed-installer") managedPiWrapper;

    home.sessionPath = lib.mkIf (cfg.installMethod == "managed-installer") [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
    ];

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

    home.activation = lib.mkIf (cfg.installMethod == "managed-installer" && cfg.manageOnActivation) {
      installOrUpdatePi = hmDag.entryAfter [ "writeBoundary" ] ''
        if [ -n "''${DRY_RUN_CMD:-}" ]; then
          $VERBOSE_ECHO "pi: dry run; skipping install/update"
        else
          export PATH="${
            lib.makeBinPath [
              pkgs.curl
              pkgs.git
              pkgs.nodejs
              pkgs.openssh
            ]
          }:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

          if command -v pi >/dev/null 2>&1; then
            $VERBOSE_ECHO "pi: updating managed install and extensions"
            pi update
            pi update --extensions
          else
            $VERBOSE_ECHO "pi: installing managed pi"
            curl -fsSL https://pi.dev/install.sh | sh
            if command -v pi >/dev/null 2>&1; then
              pi update --extensions
            else
              echo "pi: installer completed but pi is not on PATH" >&2
              exit 1
            fi
          fi
        fi
      '';
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
            ExecStart = "${pkgs.writeShellScript "pi-package-reconcile" ''
              set -euo pipefail

              export PATH="${
                lib.makeBinPath (
                  [
                    pkgs.nodejs
                    pkgs.git
                    pkgs.openssh
                  ]
                  ++ lib.optional (cfg.installMethod == "nix" && cfg.package != null) cfg.package
                )
              }:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

              if ! command -v pi >/dev/null 2>&1; then
                echo "pi-package-reconcile: pi is not installed; run the pi.dev installer first" >&2
                exit 0
              fi

              exec pi update --extensions
            ''}";
          };

          Install.WantedBy = [ "default.target" ];
        };
      })
    ];
  };
}
