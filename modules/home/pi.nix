{
  config,
  lib,
  pkgs,
  ...
}:

let
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
in
{
  # Install runtime prerequisites used around pi. The pi coding agent binary is
  # installed with the official pi.dev managed installer as a separate
  # imperative step so `pi update` can update Pi itself. Node/npm support
  # LazyPi's `npx @robzolkos/lazypi` package bootstrap; Bun is kept for legacy
  # global installs and related Pi ecosystem tooling.
  home.packages = with pkgs; [
    bun
    nodejs_22
    managedPiWrapper
  ];

  home.sessionVariables = {
    # Bun installs global packages to $BUN_INSTALL/bin (default ~/.bun).
    # Set it explicitly so the imperative `bun install -g pi` lands in a
    # predictable, user-writable location regardless of how Bun was installed.
    BUN_INSTALL = "${config.home.homeDirectory}/.bun";

    # Keep pi and LazyPi on the same writable config tree. Without this,
    # LazyPi defaults to ~/.pi/agent while this module seeds ~/.config/pi/agent.
    PI_CODING_AGENT_DIR = "${config.home.homeDirectory}/.config/pi/agent";

    # Stable, user-writable location for pi extension packages (npm/git).
    # Avoids Nix-store path tokenisation issues documented in pi's Nix guidance.
    PI_PACKAGE_DIR = "${config.home.homeDirectory}/.local/share/pi/packages";

    # Disable install/update telemetry by default on managed hosts.
    # To re-enable, set PI_TELEMETRY=1 in a local, non-committed shell profile.
    PI_TELEMETRY = "0";
  };

  # Add the managed installer bin path and Bun's legacy global-package bin to
  # PATH so `pi` resolves after the documented first-run install.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.bun/bin"
  ];

  home.activation = {
    # Seed a minimal, public-safe baseline settings.json only if one does not
    # already exist. This avoids creating a read-only Nix-store symlink at a
    # path pi actively mutates (settings.json, trust.json, ide-selection.json,
    # sessions/, and package caches all live in the same config directory).
    # A subsequent darwin-rebuild switch never overwrites an existing file.
    seedPiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          pi_config_dir="${config.home.homeDirectory}/.config/pi/agent"
          pi_settings="$pi_config_dir/settings.json"

          if [ ! -f "$pi_settings" ]; then
            $DRY_RUN_CMD mkdir -p "$pi_config_dir"
            if [ -z "$DRY_RUN_CMD" ]; then
              cat > "$pi_settings" << 'PISETTINGS'
      {
        "enableInstallTelemetry": false
      }
      PISETTINGS
            fi
            $VERBOSE_ECHO "pi: seeded baseline settings.json"
          fi
    '';

    installOrUpdatePi =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "seedPiConfig"
        ]
        ''
          if [ -n "''${DRY_RUN_CMD:-}" ]; then
            $VERBOSE_ECHO "pi: dry run; skipping install/update"
          else
            export HOME="${config.home.homeDirectory}"
            export PATH="${
              lib.makeBinPath [
                pkgs.curl
                pkgs.git
                pkgs.nodejs_22
                pkgs.openssh
              ]
            }:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

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
}
