{ ... }:

{
  # Determinate Nix owns the Nix installation, daemon launchd service, and
  # /etc/nix/nix.conf. nix-darwin should manage system configuration around it,
  # not replace or rewrite the Nix daemon configuration.
  nix.enable = false;
}
