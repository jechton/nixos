{ config, ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [
      "--accept-dns"
      "--accept-routes"
      "--operator=${config.burrow.users.username}"
      "-ssh"
    ];
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
  };
}
