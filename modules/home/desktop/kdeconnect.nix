{ pkgs, ... }:
{
  services.kdeconnect = {
    enable = true;
    indicator = false;
  };

  # kdeconnectd shells out to kdialog for its file-transfer and "run
  # command" prompts; without it those actions silently fail to open.
  home.packages = [ pkgs.kdePackages.kdialog ];

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

  # The package's own XDG autostart entry has no OnlyShowIn restriction, so
  # systemd-xdg-autostart-generator starts a second kdeconnectd alongside the
  # one from services.kdeconnect's systemd unit above. Hide it so only one runs.
  xdg.configFile."autostart/org.kde.kdeconnect.daemon.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Hidden=true
  '';
}
