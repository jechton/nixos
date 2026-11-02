{ pkgs, ... }:
{
  services.ivpn.enable = true;

  # Untrusted by default: the daemon connects the VPN on any WiFi network not
  # marked trusted. Mark trusted ones imperatively (kept out of the repo):
  #   ivpn wifi -set_trusted_network 'SSID':trusted
  systemd.services.ivpn-wifi-control = {
    description = "Apply IVPN WiFi trust settings";
    after = [ "ivpn-service.service" ];
    requires = [ "ivpn-service.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.ivpn ];
    serviceConfig.Type = "oneshot";
    script = ''
      # the daemon socket can lag behind the unit starting
      for _ in $(seq 20); do
        ivpn wifi -trusted_control on && break
        sleep 0.5
      done
      ivpn wifi -default_trust_status untrusted
      ivpn wifi -set_trusted_action untrusted_connect_vpn:on
      # a firewall on join would block the captive portal login page
      ivpn wifi -set_trusted_action untrusted_enable_firewall:off
    '';
  };

  # account login, servers cache, and preferences live here; persist so a
  # reboot doesn't lose the logged-in session
  environment.persistence."/persist".directories = [ "/etc/opt/ivpn" ];
}
