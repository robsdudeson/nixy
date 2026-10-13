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

  cfg = config.machine.raspberry-pi;
in
{
  options.machine.raspberry-pi = {
    enable = mkEnableOption "Raspberry Pi headless NixOS defaults";

    ssh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable OpenSSH for headless Raspberry Pi administration.";
    };

    firewall.openSsh = mkOption {
      type = types.bool;
      default = true;
      description = "Open TCP port 22 when SSH is enabled.";
    };

    packages.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install small Raspberry Pi troubleshooting packages.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional system packages for Raspberry Pi hosts.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      hardware.enableRedistributableFirmware = true;

      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;

      fileSystems."/" = {
        device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
        fsType = lib.mkDefault "ext4";
        options = lib.mkDefault [ "noatime" ];
      };

      fileSystems."/boot/firmware" = {
        device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
        fsType = lib.mkDefault "vfat";
      };

      networking.useDHCP = lib.mkDefault true;
      networking.firewall.enable = lib.mkDefault true;
    })

    (mkIf (cfg.enable && cfg.ssh.enable) {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = lib.mkDefault false;
          PermitRootLogin = lib.mkDefault "no";
        };
      };
    })

    (mkIf (cfg.enable && cfg.ssh.enable && cfg.firewall.openSsh) {
      networking.firewall.allowedTCPPorts = [ 22 ];
    })

    (mkIf (cfg.enable && cfg.packages.enable) {
      environment.systemPackages =
        (with pkgs; [
          dig
          ethtool
          tcpdump
        ])
        ++ cfg.extraPackages;
    })
  ];
}
