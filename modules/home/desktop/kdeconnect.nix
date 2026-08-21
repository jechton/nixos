{
  services.kdeconnect = {
    enable = true;
    indicator = false;
  };

  # Device pairing keys/trust live here; without persisting it, every
  # device has to be re-paired after each boot.
  home.persistence."/persist".directories = [
    ".config/kdeconnect"
  ];

  # The "KDE Connect Indicator" launcher entry only excludes itself on KDE
  # (NotShowIn=KDE), so it still shows up in the niri app menu.
  xdg.dataFile."applications/org.kde.kdeconnect.nonplasma.desktop".text = ''
    [Desktop Entry]
    Type=Application
    NoDisplay=true
  '';
}
