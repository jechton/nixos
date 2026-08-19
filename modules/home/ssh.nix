{
  programs.ssh = {
    enable = true;
    hashKnownHosts = true;
    forwardAgent = false;
    matchBlocks = {
      # keep-sorted start
      bunpi = {
        hostname = "192.168.4.45";
        user = "jeremiah";
      };
      opti = {
        hostname = "opti";
        user = "driftwood";
      };
      plex = {
        hostname = "plex";
        user = "driftwood";
      };
      # keep-sorted end
    };
  };
}
