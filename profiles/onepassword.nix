{ ... }:

{
  # Opt-in composition point for 1Password. Real hosts import this profile
  # from nixy-priv (or an equivalent local override) rather than public nixy
  # enabling it by default. See docs/onepassword.md for the manual first-run
  # steps this module does not automate.
  imports = [
    ../modules/darwin/onepassword.nix
  ];
}
