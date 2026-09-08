{ lib, config, ... }:
let
  inherit (lib.lists) any elem;

  hasWifi = any (c: elem "wlan_card" c.class_list) (
    config.hardware.facter.report.hardware.network_controller or [ ]
  );
in
{
  # The firmware never hands PCIe ASPM control to the kernel on this board, so
  # the mt7921e `disable_aspm=1` option silently no-ops ("can't disable ASPM; OS
  # doesn't have ASPM control") and L1 ASPM stays on, roughly halving MT7922
  # WiFi throughput. Forcing ASPM off platform-wide is the only lever that works
  # and also covers the post-resume throughput crater the driver option targeted.
  boot.kernelParams = lib.mkIf hasWifi [ "pcie_aspm=off" ];

  # NetworkManager owns DHCP on every managed interface. Without this, facter's
  # auto-detection also points dhcpcd at wlan0, so two DHCP clients race on the
  # same link (dhcpcd's start times out waiting for carrier during rebuilds).
  hardware.facter.detected.dhcp.enable = false;

  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";

      # ignore DHCP-supplied resolvers, DNS goes
      # to the global Quad9 servers below, or tailscale's MagicDNS when up
      connectionConfig = {
        "ipv4.ignore-auto-dns" = true;
        "ipv6.ignore-auto-dns" = true;
      };

      unmanaged = [
        "interface-name:tailscale*"
        "interface-name:docker*"
        "type:bridge"
      ];

      wifi = lib.mkIf hasWifi {
        backend = "wpa_supplicant";
        powersave = config.burrow.profiles.laptop.enable;
        scanRandMacAddress = true;
      };
    };

    stevenblack = {
      enable = true;
      block = [
        "fakenews"
        "gambling"
      ];
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
