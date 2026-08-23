{
  # The niri binary, xwayland-satellite and the portal are already provided
  # system-wide (see modules/system/niri.nix), and the session is started via
  # niri-session from greetd, not from a home-manager systemd user unit.
  # This module's only job here is generating $XDG_CONFIG_HOME/niri/config.kdl.
  wayland.windowManager.niri = {
    enable = true;
    package = null;
    xwaylandSatellitePackage = null;
    portalPackage = null;
    systemd.enable = false;
  };
}
