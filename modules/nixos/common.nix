{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.machine.common;
in
{
  options.machine.common = {
    enable = mkEnableOption "common machine defaults";

    nh.enable = mkEnableOption "nh defaults";

    packages.enable = mkEnableOption "common system packages";

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional system packages to install when common packages are enabled.";
    };

    editor = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Default editor to set through environment.variables.EDITOR.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      nix.settings = {
        experimental-features = "nix-command flakes";
        use-xdg-base-directories = true;
      };

      nixpkgs.config.allowUnfree = true;

      home-manager = {
        useUserPackages = true;
        useGlobalPkgs = true;

        sharedModules = [
          {
            xdg.enable = true;
          }
        ];
      };
    })

    (mkIf (cfg.enable && cfg.nh.enable) {
      programs.nh = {
        enable = true;
        clean.enable = true;
      };
    })

    (mkIf (cfg.enable && cfg.packages.enable) {
      environment.systemPackages =
        (with pkgs; [
          _1password-cli
          git
          git-crypt
          nh
          nixfmt
          wget
        ])
        ++ cfg.extraPackages;
    })

    (mkIf (cfg.enable && cfg.editor != null) {
      environment.variables.EDITOR = cfg.editor;
    })
  ];
}
