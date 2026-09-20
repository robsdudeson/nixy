{ ... }:

{
  # Installs the 1Password desktop app and CLI v2 only. Account sign-in, CLI
  # integration, and SSH agent enablement remain manual first-run steps — see
  # docs/onepassword.md. This module holds no account, vault, item, or secret
  # metadata.
  homebrew = {
    casks = [ "1password" ];
    brews = [ "1password-cli" ];
  };
}
