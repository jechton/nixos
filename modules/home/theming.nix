{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  oreo-gruvbox-cursor = pkgs.oreo-cursors-plus.override {
    cursorsConf = ''
      sizes = 24, 32, 40, 48

      gruvbox = color: ${c.base09}, label: ${c.base00}, shadow: ${c.base00}, shadow-opacity: 0.4, stroke: ${c.base00}, stroke-width: 1, stroke-opacity: 0.8
    '';
  };
in {
  imports = [inputs.stylix.homeModules.stylix];

  stylix = {
    enable = true;
    # Don't complain about version mismatch, since stylix updates slower than nixpkgs
    enableReleaseChecks = false;
    autoEnable = true;
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/gruvbox-material-dark-medium.yaml";

    fonts = {
      monospace = {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
      sansSerif = {
        name = "Inter";
        package = pkgs.inter;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
      emoji = {
        name = "Twitter Color Emoji";
        package = pkgs.twitter-color-emoji;
      };
    };

    cursor = {
      name = "oreo_gruvbox_cursor";
      package = oreo-gruvbox-cursor;
      size = 32;
    };
  };

  # Stylix's GTK target writes GNOME interface keys to dconf, which requires
  # a D-Bus session bus that isn't available during system activation.
  # Niri doesn't use GNOME so these settings aren't needed; GTK theming via
  # file-based settings.ini still works.
  dconf.settings = lib.mkForce {};
}
