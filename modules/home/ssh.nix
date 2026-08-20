{
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
