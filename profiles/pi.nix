{
  primaryUser,
  ...
}:

{
  # Opt-in composition point for pi coding agent. Real hosts import this
  # profile from nixy-priv (or an equivalent local override) rather than
  # public nixy enabling it by default. See docs/pi.md for the manual
  # first-run install step this module does not automate.
  home-manager.users.${primaryUser}.imports = [
    ../modules/home/pi.nix
  ];
}
