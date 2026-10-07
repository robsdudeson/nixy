{ inputs, pkgs, ... }:

{
  # Applies the nix-vscode-extensions overlay so `pkgs.vscode-marketplace`
  # resolves for programs.vscode (see modules/home/vscode.nix), and installs
  # VS Code itself from Nix. Hosts importing this module must not also
  # install the `vscode` Homebrew cask — Nix owns the app here.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  environment.systemPackages = [ pkgs.vscode ];
}
