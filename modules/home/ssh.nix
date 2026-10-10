{ lib, ... }:
{
  # programs.ssh normally symlinks ~/.ssh/config into /nix/store, but /nix/store
  # is group-writable by nixbld, which trips OpenSSH's safe_path() check
  # ("Bad owner or permissions") for any strict ssh client. Replace the symlink
  # with a real copy after each activation so the resolved path never touches the store.
  home.activation.sshConfigRealFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "$HOME/.ssh/config" ]; then
      cp --remove-destination "$(readlink -f "$HOME/.ssh/config")" "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
    fi
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        HashKnownHosts = true;
        ForwardAgent = false;
      };
      # keep-sorted start block=yes
      bunpi = {
        HostName = "192.168.4.45";
        User = "jeremiah";
      };
      opti = {
        HostName = "opti";
        User = "driftwood";
      };
      plex = {
        HostName = "plex";
        User = "driftwood";
      };
      # keep-sorted end
    };
  };
}
