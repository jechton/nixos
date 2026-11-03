{ config, pkgs, ... }:
let
  userctl = "${pkgs.systemd}/bin/systemctl --user --machine=${config.burrow.users.username}@.host";
in
{
  # noctalia's shared curl handle keeps a connection pool that goes stale across
  # a suspend/resume: every plugin HTTP request (kimai, home-assistant) then
  # hangs until its 30s timeout and never recovers until the process restarts
  # (noctalia-dev/noctalia-shell src/net/http_client.cpp: the plugin `request`
  # path sets neither CURLOPT_FRESH_CONNECT nor a resume hook). Bounce the
  # service on resume until that's fixed upstream.
  #
  # This has to be a system unit: the user manager has no sleep.target, so a
  # user unit wanted by it never runs. Ordering After sleep.target means this
  # runs as the system thaws.
  #
  # The session is locked before suspend (lock-before-sleep in
  # hardware/power.nix). Killing the locker makes niri show a solid red surface
  # until a new locker takes over, so the restart waits until noctalia reports
  # the session unlocked. The wait runs in a user unit, which has the session
  # environment noctalia's IPC socket needs.
  systemd.services.noctalia-resume = {
    description = "Schedule a noctalia restart after resume (works around a stale curl connection pool)";
    after = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${userctl} start --no-block noctalia-restart-after-unlock.service";
    };
  };

  systemd.user.services.noctalia-restart-after-unlock = {
    description = "Restart noctalia once the session is unlocked";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "noctalia-restart-after-unlock" ''
        # status fails when noctalia isn't running (e.g. suspended at the greeter)
        while status=$(/run/current-system/sw/bin/noctalia msg status); do
          if echo "$status" | ${pkgs.gnugrep}/bin/grep -q '"locked": false'; then
            exec ${pkgs.systemd}/bin/systemctl --user restart noctalia.service
          fi
          sleep 1
        done
      '';
    };
  };
}
