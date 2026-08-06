{ pkgs, lib, ... }:
let
  hyprwhspr = pkgs.callPackage ../../../pkgs/hyprwhspr/package.nix { };
in
{
  home.packages = [ hyprwhspr ];

  # Mirrors upstream's config/systemd/hyprwhspr.service (HYPRWHSPR_ROOT is
  # already baked into the wrapper, so no need to set it here)
  systemd.user.services.hyprwhspr = {
    Unit = {
      Description = "hyprwhspr stt";
      Documentation = "https://github.com/goodroot/hyprwhspr";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "pipewire.service"
        "wireplumber.service"
      ];
      Wants = [
        "pipewire.service"
        "wireplumber.service"
      ];
    };

    Service = {
      # Same wait-for-Wayland-socket guard as upstream's own unit: home-manager
      # can start this before niri's socket exists
      ExecStartPre = ''${lib.getExe' pkgs.bash "bash"} -lc 'for i in $(seq 1 60); do [ -n "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && exit 0; sleep 0.25; done; exit 1' '';
      ExecStart = lib.getExe hyprwhspr;
      ExecStopPost = ''${lib.getExe' pkgs.bash "bash"} -c '( pkill -9 -f "hyprwhspr-virtual-keyboard[d]" 2>/dev/null; pkill -9 -f "hyprwhspr-ydotool.soc[k]" 2>/dev/null ) || true' '';
      Environment = "PYTHONUNBUFFERED=1";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
