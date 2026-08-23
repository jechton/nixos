{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.burrow.theme;

  c = config.lib.stylix.colors.withHashtag;
  oreo-gruvbox-cursor = pkgs.oreo-cursors-plus.override {
    cursorsConf = ''
      sizes = 24, 32, 40, 48

      gruvbox = color: ${c.base05}, label: ${c.base00}, shadow: ${c.base00}, shadow-opacity: 0.4, stroke: ${c.base00}, stroke-width: 1, stroke-opacity: 0.8
    '';
  };

  mkFontOption =
    { name, package }:
    {
      name = mkOption {
        type = types.str;
        default = name;
        description = "Font family name.";
      };
      package = mkOption {
        type = types.package;
        default = package;
        description = "Package providing the font.";
      };
    };
in
{
  imports = [ inputs.stylix.homeModules.stylix ];

  options.burrow.theme = {
    colorScheme = mkOption {
      type = types.str;
      default = "gruvbox-material-dark-medium";
      description = "Base16 scheme name from tinted-schemes/base16.";
    };

    fonts = {
      monospace = mkFontOption {
        name = "Iosevka Nerd Font";
        package = pkgs.nerd-fonts.iosevka;
      };
      sansSerif = mkFontOption {
        name = "Inter";
        package = pkgs.inter;
      };
      serif = mkFontOption {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
      emoji = mkFontOption {
        name = "Twitter Color Emoji";
        package = pkgs.twitter-color-emoji;
      };
    };
  };

  config = {
    stylix = {
      enable = true;
      # Don't complain about version mismatch, since stylix updates slower than nixpkgs
      enableReleaseChecks = false;
      autoEnable = true;
      base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/${cfg.colorScheme}.yaml";

      inherit (cfg) fonts;

      cursor = {
        name = "oreo_gruvbox_cursors";
        package = oreo-gruvbox-cursor;
        size = 32;
      };

      icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus-Light";
      };
    };

    # Stylix's GTK target writes GNOME interface keys to dconf, which requires
    # a D-Bus session bus that isn't available during system activation.
    # Niri doesn't use GNOME so these settings aren't needed; GTK theming via
    # file-based settings.ini still works.
    dconf.settings = lib.mkForce { };

    # stylix configures the cursor theme/size/icons above but leaves the
    # top-level toggle off; x11 support is unneeded since niri is wayland-only
    home.pointerCursor = {
      enable = true;
      x11.enable = lib.mkForce false;
    };
  };
}
