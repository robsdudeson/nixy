{ config, lib, ... }:
let
  cfg = config.darwin.macosDefaults;

  user = config.system.primaryUser;

  # Declarative preferences (NSGlobalDomain, dock, trackpad, menu extras,
  # accent color) belong in the host file via nix-darwin's native
  # `system.defaults` options. This module only covers what nix-darwin cannot
  # express: creating a user-owned screenshots directory, rewriting the Dock's
  # persistent-apps array, and restarting the services that cache those
  # preferences. All generated commands are idempotent except the dock
  # rewrite, which intentionally resets the dock to the declared app list.
  dockTile =
    app:
    "sudo -u ${user} /usr/bin/defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${app}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'";

  lines =
    (lib.optionals (cfg.screenshotsDirectory != null) [
      "sudo -u ${user} mkdir -p ${cfg.screenshotsDirectory}"
      "sudo -u ${user} /usr/bin/defaults write com.apple.screencapture location ${cfg.screenshotsDirectory}"
    ])
    ++ lib.optionals (cfg.clockDateFormat != null) [
      "sudo -u ${user} /usr/bin/defaults write com.apple.menuextra.clock DateFormat -string '${cfg.clockDateFormat}'"
    ]
    ++ lib.optionals cfg.showBatteryPercent [
      "sudo -u ${user} /usr/bin/defaults write com.apple.menuextra.battery ShowPercent YES"
    ]
    ++ lib.optionals (!cfg.naturalScrolling) [
      "sudo -u ${user} /usr/bin/defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false"
      "sudo -u ${user} /usr/bin/defaults write NSGlobalDomain com.apple.scrollwheel.scaling -bool false"
    ]
    ++ lib.optionals (cfg.accentColor != null) [
      "sudo -u ${user} /usr/bin/defaults write NSGlobalDomain AppleAccentColor -int ${toString cfg.accentColor}"
    ]
    ++ lib.optionals (cfg.highlightColor != null) [
      "sudo -u ${user} /usr/bin/defaults write NSGlobalDomain AppleHighlightColor -string '${cfg.highlightColor}'"
    ]
    ++ lib.optionals (cfg.dockPersistentApps != [ ]) ([
      # Clear first so repeated activations do not accumulate duplicate tiles.
      "sudo -u ${user} /usr/bin/defaults write com.apple.dock persistent-apps -array"
    ]
    ++ lib.map dockTile cfg.dockPersistentApps);

  script =
    if lines == [ ] then "" else ''
      echo "Applying macOS defaults for ${user}..."
      ${lib.concatStringsSep "\n" lines}

      # Restart the services that cache these preferences.
      sudo -u ${user} /usr/bin/killall Dock || true
      sudo -u ${user} /usr/bin/killall SystemUIServer || true
      sudo -u ${user} /usr/bin/killall Finder || true
      echo "macOS defaults applied"
    '';
in
{
  options.darwin.macosDefaults = {
    enable = lib.mkEnableOption "activation-time macOS preferences that nix-darwin cannot express declaratively";

    screenshotsDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "User-owned directory for screenshots; created on activation and set as the com.apple.screencapture location.";
    };

    clockDateFormat = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "EEE MMM d  H:mm:ss";
      description = "Menu-bar clock date format written to com.apple.menuextra.clock.";
    };

    showBatteryPercent = lib.mkEnableOption "the battery percentage in the menu bar";

    naturalScrolling = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When false, disables natural scrolling for trackpad and mouse on activation.";
    };

    accentColor = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "AppleAccentColor index written to NSGlobalDomain (5 is purple, 6 is graphite).";
    };

    highlightColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "0.968627 0.831373 1.000000 Purple";
      description = "AppleHighlightColor value written to NSGlobalDomain.";
    };

    dockPersistentApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/Applications/Visual Studio Code.app" ];
      description = ''
        Application bundle paths pinned to the Dock. Declaring any entry
        resets the Dock's persistent-apps array to exactly this list on every
        activation, replacing apps added manually.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = user != "";
        message = "darwin.macosDefaults requires system.primaryUser to be set.";
      }
    ];

    system.activationScripts.postActivation.text = script;
  };
}
