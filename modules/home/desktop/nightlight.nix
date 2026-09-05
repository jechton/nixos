{ pkgs, ... }:
{
  # gammastep ramps color temperature gradually across dusk/dawn instead of
  # noctalia's nightlight, which snaps between day and night temperature.
  # geoclue2 auto-locates it the same way noctalia's location.auto_locate does.
  systemd.user.services.gammastep = {
    Unit = {
      Description = "Gradual screen color temperature adjustment";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.gammastep}/bin/gammastep -l geoclue2 -t 6500:3500";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
