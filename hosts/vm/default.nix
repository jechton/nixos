{
  hardware.facter.reportPath = ./facter.json;

  networking.hostName = "vm";

  burrow = {
    storage = {
      enable = true;
      luks = false;
      device = "/dev/vda";
      swapSize = "10G";
    };
    agenix.enable = true;
    profiles.vm.enable = true;
  };

  # Host-specific extras
  documentation.man.enable = false;

  system.stateVersion = "26.11";
}
