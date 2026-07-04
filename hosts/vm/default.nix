{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "vm";

  custom = {
    storage = {
      enable = true;
      luks = false;
      device = "/dev/vda";
      swapSize = "10G";
    };
    agenix.enable = true;
  };

  # Host-specific extras
  system.stateVersion = "26.11";
}
