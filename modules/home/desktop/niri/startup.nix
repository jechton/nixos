{
  programs.niri.settings.spawn-at-startup = [
    { command = [ "noctalia" ]; }
    { command = [ "signal-desktop" ]; }
    { command = [ "telegram-desktop" ]; }
    { command = [ "slack" ]; }
  ];

  # nm-applet's autostart .desktop only excludes KDE/GNOME/COSMIC, so it
  # launches its own tray icon under niri too; hide it since noctalia's
  # network widget already covers this.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
