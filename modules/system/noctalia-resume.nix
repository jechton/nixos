{ config, pkgs, ... }:
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
  # runs as the system thaws. try-restart is a no-op when noctalia isn't
  # running (e.g. suspended at the greeter).
  systemd.services.noctalia-resume = {
    description = "Restart noctalia after resume (works around a stale curl connection pool)";
    after = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user --machine=${config.burrow.users.username}@.host try-restart noctalia.service";
    };
  };
}
