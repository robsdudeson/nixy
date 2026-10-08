{ inputs, pkgs, ... }:

{
  # Applies the nix-vscode-extensions overlay so `pkgs.vscode-marketplace`
  # resolves for programs.vscode (see modules/home/vscode.nix), and installs
  # VS Code itself from Nix. Hosts importing this module must not also
  # install the `vscode` Homebrew cask — Nix owns the app here.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # pkgs.vscode carries an unfree license; evaluation is refused without this.
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ pkgs.vscode ];

  # Expose the Nix-installed app bundle at a stable path so Dock tiles,
  # Spotlight, and Launchpad can find it. Re-created on every activation
  # because the store path changes between builds. extraActivation is used
  # (rather than postActivation) to avoid conflicting with hosts that set
  # their own post-activation scripts.
  system.activationScripts.extraActivation.text = ''
    ln -sfn "${pkgs.vscode}/Applications/Visual Studio Code.app" "/Applications/Visual Studio Code.app"
  '';
}
