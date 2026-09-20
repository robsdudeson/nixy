{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Install the Bun JavaScript runtime. The pi coding agent
  # (@earendil-works/pi-coding-agent) is installed on top of Bun as a
  # separate imperative step — see docs/pi.md for the one-time install command.
  # Bun is in nixpkgs; pi itself is not, and fully declarative packaging was
  # deliberately deferred (see docs/plans/2026-09-20-001-feat-pi-coding-agent-nix-plan.md).
  home.packages = with pkgs; [
    bun
  ];

  home.sessionVariables = {
    # Bun installs global packages to $BUN_INSTALL/bin (default ~/.bun).
    # Set it explicitly so the imperative `bun install -g pi` lands in a
    # predictable, user-writable location regardless of how Bun was installed.
    BUN_INSTALL = "${config.home.homeDirectory}/.bun";

    # Stable, user-writable location for pi extension packages (npm/git).
    # Avoids Nix-store path tokenisation issues documented in pi's Nix guidance.
    PI_PACKAGE_DIR = "${config.home.homeDirectory}/.local/share/pi/packages";

    # Disable install/update telemetry by default on managed hosts.
    # To re-enable, set PI_TELEMETRY=1 in a local, non-committed shell profile.
    PI_TELEMETRY = "0";
  };

  # Add Bun's global-package bin to PATH so the imperatively-installed `pi`
  # binary resolves after a `bun install -g @earendil-works/pi-coding-agent`.
  home.sessionPath = [
    "${config.home.homeDirectory}/.bun/bin"
  ];

  # Seed a minimal, public-safe baseline settings.json only if one does not
  # already exist. This avoids creating a read-only Nix-store symlink at a
  # path pi actively mutates (settings.json, trust.json, ide-selection.json,
  # sessions/, and package caches all live in the same config directory).
  # A subsequent darwin-rebuild switch never overwrites an existing file.
  home.activation.seedPiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
}
