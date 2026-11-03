{ lib, ... }:
{
  services.ivpn.enable = true;

  # Only run the daemon while actually connecting, not at every boot.
  systemd.services.ivpn-service.wantedBy = lib.mkForce [ ];

  # account login, servers cache, and preferences live here; persist so a
  # reboot doesn't lose the logged-in session
  environment.persistence."/persist".directories = [ "/etc/opt/ivpn" ];
}
