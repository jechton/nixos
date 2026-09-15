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

  # Tray apps only land in the tray if noctalia's StatusNotifier host is
  # already up when they launch, so poll for it before exec-ing the app
  # instead of racing a fixed sleep.
  waitForTrayHost = pkgs.writeShellScript "wait-for-tray-host" ''
    for _ in $(seq 1 50); do
      state=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null)
      [ "$state" = "b true" ] && exit 0
      sleep 0.2
    done
  '';
  trayApp = args: [
    "sh"
    "-c"
    "${waitForTrayHost} && exec ${lib.escapeShellArgs args}"
  ];

  chatApps = lib.optionals (!config.burrow.profiles.vm.enable) (
    map trayApp [
      [
        "equibop"
        "--start-minimized"
      ]
      [ "signal-desktop" ]
      [ "telegram-desktop" ]
      [
        "slack"
        "-u"
      ]
    ]
  );
in
{
  # noctalia is started by its systemd user service (programs.noctalia.systemd
  # in ../noctalia.nix), not here, so it can be restarted on resume and on
  # config changes.
  wayland.windowManager.niri.settings._children = mkNodes "spawn-at-startup" (
    [
      unlockKeyring
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
