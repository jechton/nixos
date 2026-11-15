{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.qimgv ];

  # Read-only, so the in-app settings dialog cannot change anything. Keys left
  # out fall back to qimgv's defaults.
  xdg.configFile."qimgv/qimgv.conf".text = lib.generators.toINI { } {
    General = {
      # The config is read-only, so qimgv can never record that the welcome
      # dialog was shown.
      firstRun = false;
      infoBarFullscreen = true;
      infoBarWindowed = true;
      panelEnabled = true;
      panelPosition = "top";
      useSystemColorScheme = true;
    };
  };
}
