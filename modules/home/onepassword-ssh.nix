{ ... }:

{
  # Opt-in: only wired in for users that enable 1Password through
  # profiles/onepassword.nix. Points SSH at the 1Password SSH agent socket
  # instead of a local ssh-agent; private keys live in 1Password, never on
  # disk. Home Manager will refuse to silently overwrite an existing
  # unmanaged ~/.ssh/config rather than replace it outright — see
  # docs/onepassword.md for the migration path.
  programs.ssh = {
    enable = true;
    # Home Manager's bundled default settings just restate OpenSSH's own
    # defaults; opt out explicitly so this module only ever writes the one
    # stanza it owns.
    enableDefaultConfig = false;
    settings."*".IdentityAgent = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  # Non-secret ergonomics for tools that read SSH_AUTH_SOCK instead of
  # honoring SSH config. This is a socket path, not a resolved secret.
  home.sessionVariables.SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
}
