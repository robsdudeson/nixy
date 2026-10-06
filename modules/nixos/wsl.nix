{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.machine.wsl;
in
{
  options.machine.wsl = {
    enable = mkEnableOption "WSL machine defaults";
  };

  config = mkIf cfg.enable {
    wsl.enable = true;

    # Make /lib64/ld-linux-x86-64.so.2 available for dynamically linked tooling
    # such as VS Code remote server and Node binaries under WSL.
    programs.nix-ld.enable = true;
  };
}
