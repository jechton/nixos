{ lib, config, ... }:
let
  inherit (lib.lists) any elem;

  hasWifi = any (c: elem "wlan_card" c.class_list) (
    config.hardware.facter.report.hardware.network_controller or [ ]
  );
in
{
  # mt7921e's PCIe ASPM negotiation is broken on resume: throughput craters
  # after suspend and only a driver reload (or reboot) fixes it. Disabling
  # ASPM for the driver sidesteps the bug entirely.
  boot.extraModprobeConfig = lib.mkIf hasWifi ''
    options mt7921e disable_aspm=1
  '';

  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      unmanaged = [
        "interface-name:tailscale*"
        "interface-name:docker*"
        "type:bridge"
      ];

      wifi = lib.mkIf hasWifi {
        backend = "iwd";
        powersave = config.burrow.profiles.laptop.enable;
        scanRandMacAddress = true;
      };
    };

    # networkmanager's iwd backend still runs the real iwd daemon underneath it,
    # so iwd's own settings are honored even though NetworkManager owns the connection
    wireless.iwd.settings = lib.mkIf hasWifi {
      Settings.AutoConnect = true;

      General = {
        EnableNetworkConfiguration = true;
        RoamRetryInterval = 15;
      };
    };

    stevenblack = {
      enable = true;
      block = [
        "fakenews"
        "gambling"
      ];
    };

    firewall = {
      enable = true;
      # discovery broadcast + pairing/transfer, used by home-manager's
      # services.kdeconnect (no openFirewall option of its own)
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };

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
    settings = {
      PermitRootLogin = "no";
    };
    openFirewall = true;
  };

  services.resolved.enable = true;

  environment.persistence."/persist" = {
    directories = [ "/etc/NetworkManager/system-connections" ];
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };

  systemd = {
    # allow the system to boot without waiting for network interfaces to come online
    network.wait-online.enable = false;

    services = {
      NetworkManager-wait-online.enable = false;

      # don't restart resolved on config changes; avoids a DNS hiccup during nixos-rebuild switch
      systemd-resolved.stopIfChanged = false;
    };
  };
}
