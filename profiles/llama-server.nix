{
  primaryUser,
  ...
}:

{
  # Opt-in composition point for llama.cpp server. Real hosts import this
  # profile from nixy-priv (or an equivalent local override) rather than
  # public nixy enabling it by default. The module is disabled unless
  # explicitly configured with a model path and enabled.
  home-manager.users.${primaryUser}.imports = [
    ../modules/home/llama-server.nix
  ];
}
