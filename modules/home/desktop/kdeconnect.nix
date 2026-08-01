{
  services.kdeconnect = {
    enable = true;
    indicator = false;
  };

  # The "KDE Connect Indicator" launcher entry only excludes itself on KDE
  # (NotShowIn=KDE), so it still shows up in the niri app menu.
  xdg.dataFile."applications/org.kde.kdeconnect.nonplasma.desktop".text = ''
    [Desktop Entry]
    Type=Application
    NoDisplay=true
  '';
}
