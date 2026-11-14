{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.qimgv ];

  # Read-only, so the in-app settings dialog cannot change anything. Keys left
  # out fall back to qimgv's defaults.
  xdg.configFile."qimgv/qimgv.conf".text = lib.generators.toINI { } {
    General = {
      infoBarFullscreen = true;
      infoBarWindowed = true;
      panelEnabled = true;
      panelPosition = "top";
      useSystemColorScheme = true;
    };
  };
}
