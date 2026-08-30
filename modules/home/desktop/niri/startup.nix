{ lib, config, ... }:
let
  inherit (import ./_lib.nix { inherit lib; }) mkNodes;
  chatApps = lib.optionals (!config.burrow.profiles.vm.enable) [
    [ "equibop" ]
    [ "signal-desktop" ]
    [ "telegram-desktop" ]
    [
      "slack"
      "-u"
    ]
  ];
in
{
  wayland.windowManager.niri.settings._children = mkNodes "spawn-at-startup" (
    [ [ "noctalia" ] ] ++ chatApps
  );

  # nm-applet's autostart .desktop only excludes KDE/GNOME/COSMIC, so it
  # launches its own tray icon under niri too; hide it since noctalia's
  # network widget already covers this.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

  # blueman's autostart .desktop has the same issue; noctalia's bluetooth
  # widget already covers this, so hide the tray icon.
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
