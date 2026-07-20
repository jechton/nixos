{
  hardware.facter.reportPath = ./facter.json;

  networking.hostName = "pawpad";

  burrow = {
    storage = {
      enable = true;
      luks = true;
      device = "/dev/nvme0n1";
      swapSize = "8G";
    };
    agenix.enable = true;
    profiles.laptop.enable = true;
  };

  # Host-specific extras
  system.stateVersion = "26.11";
}
