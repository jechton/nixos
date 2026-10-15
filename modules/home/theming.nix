{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkOption types;
  # Catppuccin mocha "dark" cursors with the mocha palette replaced by the
  # stylix scheme. Only the colors the cursor templates use are overridden.
  catppuccin-custom-cursor =
    let
      colorOverrides = pkgs.writeText "cursor-colors.json" (
        builtins.toJSON {
          mocha = {
            base = config.lib.stylix.colors.base00;
            text = config.lib.stylix.colors.base05;
            blue = config.lib.stylix.colors.base0D;
            green = config.lib.stylix.colors.base0B;
            lavender = config.lib.stylix.colors.base0D;
            mauve = config.lib.stylix.colors.base0E;
            peach = config.lib.stylix.colors.base09;
            red = config.lib.stylix.colors.base08;
          };
        }
      );
    in
    pkgs.catppuccin-cursors.overrideAttrs (old: {
      outputs = [ "out" ];
      postPatch = (old.postPatch or "") + ''
        substituteInPlace build \
          --replace-fail 'whiskers $file $flavour' \
          'whiskers $file $flavour --color-overrides "$(cat ${colorOverrides})"'
      '';
      buildPhase = ''
        runHook preBuild
        patchShebangs .
        just build mocha dark
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/icons
        mv dist/catppuccin-mocha-dark-cursors $out/share/icons/
        runHook postInstall
      '';
    });

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
  # The system-level stylix module (modules/system/theming.nix) auto-imports
  # this same home-manager module and copies its enable/base16Scheme/fonts/etc
  # over via home-manager.sharedModules, so it's not imported again here.

  options.burrow.theme = {
    colorScheme = mkOption {
      type = types.str;
      default = "gruvbox-material-dark-medium";
      description = "Base16 scheme name from tinted-schemes/base16.";
    };

    fonts = {
      monospace = mkFontOption {
        name = "Iosevka Nerd Font Mono";
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
    burrow.theme = {
      inherit (osConfig.burrow.theme) colorScheme fonts;
    };

    stylix = {
      cursor = {
        name = "catppuccin-mocha-dark-cursors";
        package = catppuccin-custom-cursor;
        size = 32;
      };

      icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus-Light";
      };

      # `home-manager.useGlobalPkgs` forbids `nixpkgs.overlays` in home scope,
      # which stylix's nixos-icons and gtksourceview targets would otherwise
      # register. The nixos-icons logo is still themed by the system stylix
      # module; gtksourceview only affects GtkSourceView apps, we don't have any.
      overlays.enable = false;
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
