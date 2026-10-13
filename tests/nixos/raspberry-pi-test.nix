# Test for the Raspberry Pi NixOS machine module.
# Run with: nix eval --file ./raspberry-pi-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  evalModule =
    {
      enable ? false,
      ssh ? true,
      openSsh ? true,
      packages ? true,
      extraPackages ? [ ],
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          ../../modules/nixos/raspberry-pi.nix
          {
            options = {
              hardware.enableRedistributableFirmware = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              boot.loader.grub.enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              boot.loader.generic-extlinux-compatible.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              fileSystems = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              networking.useDHCP = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              networking.firewall.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              networking.firewall.allowedTCPPorts = lib.mkOption {
                type = lib.types.listOf lib.types.port;
                default = [ ];
              };
              services.openssh.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              services.openssh.settings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              environment.systemPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
            };

            config._module.args = { inherit pkgs; };
          }
          {
            machine.raspberry-pi = {
              inherit enable extraPackages;
              ssh.enable = ssh;
              firewall.openSsh = openSsh;
              packages.enable = packages;
            };
          }
        ];
      };
    in
    evaluated.config;

  packageNames = config: map lib.getName config.environment.systemPackages;

  tests = {
    test_disabled_by_default = {
      expr =
        let
          config = evalModule { enable = false; };
        in
        {
          firmware = config.hardware.enableRedistributableFirmware;
          grub = config.boot.loader.grub.enable;
          extlinux = config.boot.loader.generic-extlinux-compatible.enable;
          fileSystems = config.fileSystems;
          dhcp = config.networking.useDHCP;
          firewall = config.networking.firewall.enable;
          ssh = config.services.openssh.enable;
          ports = config.networking.firewall.allowedTCPPorts;
          packages = config.environment.systemPackages;
        };
      expected = {
        firmware = false;
        grub = true;
        extlinux = false;
        fileSystems = { };
        dhcp = false;
        firewall = false;
        ssh = false;
        ports = [ ];
        packages = [ ];
      };
    };

    test_enabled_sets_headless_boot_network_and_ssh_defaults = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          firmware = config.hardware.enableRedistributableFirmware;
          grub = config.boot.loader.grub.enable;
          extlinux = config.boot.loader.generic-extlinux-compatible.enable;
          rootDevice = config.fileSystems."/".device;
          rootFsType = config.fileSystems."/".fsType;
          firmwareDevice = config.fileSystems."/boot/firmware".device;
          firmwareFsType = config.fileSystems."/boot/firmware".fsType;
          dhcp = config.networking.useDHCP;
          firewall = config.networking.firewall.enable;
          ssh = config.services.openssh.enable;
          passwordAuth = config.services.openssh.settings.PasswordAuthentication;
          rootLogin = config.services.openssh.settings.PermitRootLogin;
          ports = config.networking.firewall.allowedTCPPorts;
        };
      expected = {
        firmware = true;
        grub = false;
        extlinux = true;
        rootDevice = "/dev/disk/by-label/NIXOS_SD";
        rootFsType = "ext4";
        firmwareDevice = "/dev/disk/by-label/FIRMWARE";
        firmwareFsType = "vfat";
        dhcp = true;
        firewall = true;
        ssh = true;
        passwordAuth = false;
        rootLogin = "no";
        ports = [ 22 ];
      };
    };

    test_ssh_and_port_are_independently_gated = {
      expr =
        let
          sshDisabled = evalModule {
            enable = true;
            ssh = false;
          };
          portClosed = evalModule {
            enable = true;
            openSsh = false;
          };
        in
        {
          sshDisabledService = sshDisabled.services.openssh.enable;
          sshDisabledPorts = sshDisabled.networking.firewall.allowedTCPPorts;
          portClosedService = portClosed.services.openssh.enable;
          portClosedPorts = portClosed.networking.firewall.allowedTCPPorts;
        };
      expected = {
        sshDisabledService = false;
        sshDisabledPorts = [ ];
        portClosedService = true;
        portClosedPorts = [ ];
      };
    };

    test_packages_are_gated_and_extendable = {
      expr =
        let
          disabled = evalModule {
            enable = true;
            packages = false;
          };
          enabled = evalModule {
            enable = true;
            extraPackages = [ pkgs.hello ];
          };
          names = packageNames enabled;
        in
        {
          disabledCount = builtins.length disabled.environment.systemPackages;
          enabledCount = builtins.length names;
          hasExpectedPackages = lib.all (name: builtins.elem name names) [
            "bind"
            "ethtool"
            "tcpdump"
            "hello"
          ];
        };
      expected = {
        disabledCount = 0;
        enabledCount = 4;
        hasExpectedPackages = true;
      };
    };
  };

  results = lib.mapAttrs (_: test: test.expr == test.expected) tests;
  failures = lib.filterAttrs (_: passed: !passed) results;
in
{
  success = failures == { };
  message =
    if failures == { } then
      "all raspberry-pi module tests passed"
    else
      "failed tests: ${builtins.concatStringsSep ", " (builtins.attrNames failures)}";
  inherit results;
}
