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
      # Matches the installed version so the "updated from 0.0.0" notice stays hidden.
      lastVerMajor = lib.toInt (lib.versions.major pkgs.qimgv.version);
      lastVerMicro = lib.toInt (lib.versions.patch pkgs.qimgv.version);
      lastVerMinor = lib.toInt (lib.versions.minor pkgs.qimgv.version);
      infoBarFullscreen = true;
      infoBarWindowed = true;
      panelEnabled = true;
      panelPosition = "top";
      useSystemColorScheme = true;
    };
  };
}
