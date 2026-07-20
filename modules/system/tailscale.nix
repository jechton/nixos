{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [
      "--accept-dns"
      "--accept-routes"
      "-ssh"
    ];
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
  };
}
