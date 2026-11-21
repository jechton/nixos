{ config, lib, ... }:
let
  username = config.burrow.users.username;
  # LAN address, so the shares work on home wifi without tailscale. The bare
  # name "bunpi" only resolves through tailscale's MagicDNS.
  host = "192.168.4.45";
  # Mounted on first access and unmounted after a minute idle, so boot and
  # suspend never block when bunpi is unreachable.
  mkShare = share: {
    device = "//${host}/${share}";
    fsType = "cifs";
    options = [
      "credentials=${config.age.secrets.bunpi-credentials.path}"
      "uid=${username}"
      "gid=users"
      "vers=3"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=10s"
    ];
  };
in
{
  config = lib.mkIf config.burrow.agenix.enable {
    fileSystems = {
      "/mnt/bunpi" = mkShare "mnt";
      "/mnt/bunpi-home" = mkShare "pi-home";
    };
  };
}
