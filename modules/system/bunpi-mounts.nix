{ config, lib, ... }:
let
  username = config.burrow.users.username;
  # Mounted on first access and unmounted after a minute idle, so boot and
  # suspend never block when bunpi's tailnet is unreachable.
  mkShare = share: {
    device = "//bunpi/${share}";
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
