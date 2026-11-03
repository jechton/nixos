{ lib, pkgs, ... }:
{
  services.ivpn.enable = true;

  # Untrusted by default. The daemon itself does not auto-connect the VPN
  # (connecting enables the firewall, which blocks captive portal login pages);
  # the NetworkManager dispatcher below does it after the portal. Mark trusted
  # networks imperatively (kept out of the repo):
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
      ivpn wifi -set_trusted_action untrusted_connect_vpn:off
      ivpn wifi -set_trusted_action untrusted_enable_firewall:off
    '';
  };

  # NetworkManager only reports "portal" vs "full" with a connectivity check.
  networking.networkmanager.settings.connectivity = {
    uri = "http://nmcheck.gnome.org/check_network_status.txt";
    interval = 60;
  };

  # Connect the VPN once the captive portal (if any) is logged in, i.e. when
  # NetworkManager reports full connectivity on a WiFi network not marked
  # trusted. Connecting earlier would enable the firewall and block the portal.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "ivpn-connect-untrusted" ''
        PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.ivpn
            pkgs.networkmanager
          ]
        }
        [ "$2" = connectivity-change ] && [ "$CONNECTIVITY_STATE" = FULL ] || exit 0
        ssid=$(nmcli -t -g active,ssid dev wifi | sed -n 's/^yes://p')
        [ -n "$ssid" ] || exit 0
        ivpn wifi | grep -F "$ssid" | grep -q ': Trusted' && exit 0
        ivpn status | grep -q 'VPN *: CONNECTED' && exit 0
        ivpn firewall -lan_allow
        ivpn connect -fastest
      '';
    }
  ];

  # account login, servers cache, and preferences live here; persist so a
  # reboot doesn't lose the logged-in session
  environment.persistence."/persist".directories = [ "/etc/opt/ivpn" ];
}
