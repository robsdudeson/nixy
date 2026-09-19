{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fd
    jq
    ripgrep
    tree
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };
}
