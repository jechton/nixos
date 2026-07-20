{
  networking = {
    networkmanager.enable = true;
    firewall = {enable = true;};
  };

  services.openssh = {
    enable = true;
    settings = {PermitRootLogin = "no";};
  };
}
