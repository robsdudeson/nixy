{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fishPlugins.tide
  ];

  programs.fish = {
    enable = true;

    shellAbbrs = {
      g = "git";
      l = "ls -lah";
      ll = "ls -lh";
      v = "nvim";
      vi = "nvim";
      vim = "nvim";
      ops = "op signin";
      opl = "op item list";
      opg = "op item get";
    };

    functions = {
      fish_greeting = ''
        fastfetch
      '';

      my_tide_config = ''
        tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Darkest --show_time='24-hour format' --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Round --powerline_prompt_style='Two lines, character' --prompt_connection=Dotted --powerline_right_prompt_frame=No --prompt_connection_andor_frame_color=Lightest --prompt_spacing=Sparse --icons='Many icons' --transient=Yes
      '';
    };

    plugins = [
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
    ];
  };
}
