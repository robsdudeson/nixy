{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    curl
    git
    vim
  ];

  programs.zsh.enable = true;
}
