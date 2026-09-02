{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (import ./_lib.nix { inherit lib; }) mkNodes;

  # greetd autologin never runs the PAM auth step, so pam_gnome_keyring starts
  # gnome-keyring-daemon but never unlocks the login keyring
  unlockKeyring = [
    "sh"
    "-c"
    "printf '' | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --unlock"
  ];

  chatApps = lib.optionals (!config.burrow.profiles.vm.enable) [
    # equibop only lands in the tray if noctalia's StatusNotifier host is
    # already up when it launches, so give the bar a head start and pass the
    # explicit minimize flag.
    [
      "sh"
      "-c"
      "sleep 5 && exec equibop --start-minimized"
    ]
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
    [
      unlockKeyring
      [ "noctalia" ]
    ]
    ++ chatApps
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
