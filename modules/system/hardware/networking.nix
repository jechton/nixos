{config, ...}: {
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      unmanaged = [
        "interface-name:tailscale*"
        "interface-name:docker*"
        "type:bridge"
      ];

      wifi = {
        backend = "iwd";
        powersave = config.burrow.profiles.laptop.enable;
        scanRandMacAddress = true;
      };
    };

    firewall.enable = true;

    nameservers = [
      # these are all quad9
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {PermitRootLogin = "no";};
  };
}
