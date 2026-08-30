{
  pkgs,
  lib,
  ...
}:
{
  # Required for dconf to work during home-manager activation (GTK theming via stylix)
  programs.dconf.enable = true;

  # Compiled into the system dconf db at build time, so it applies without
  # needing a D-Bus session (unlike home-manager's dconf.settings, which is
  # forced off in modules/home/theming.nix for that reason). This is what
  # tells GTK apps and the xdg-desktop-portal Settings backend (which browsers
  # query for their own dark/light mode) that the system prefers dark, and
  # which GTK theme and icon theme GNOME-style apps (e.g. Nautilus, and
  # Chromium/Electron's native file picker) should use, since they read
  # gtk-theme/icon-theme from dconf rather than gtk-3.0/settings.ini.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "adw-gtk3";
          icon-theme = "Papirus-Dark";
        };
      };
    }
  ];

  fonts = {
    packages = lib.attrValues {
      inherit (pkgs)
        # keep-sorted start
        atkinson-hyperlegible-next
        corefonts
        dejavu_fonts
        inter
        material-design-icons
        material-icons
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        source-sans
        source-serif
        twemoji-color-font
        # keep-sorted end
        ;

      inherit (pkgs.nerd-fonts) symbols-only;
    };

    enableDefaultPackages = true;

    fontconfig = {
      enable = true;
      hinting.enable = true;
      antialias = true;
      # Nerd Font icon glyphs live in the Private Use Area, which fontconfig's
      # charset-based fallback doesn't reach on its own, so apps (browsers
      # included) render tofu instead of falling back to the symbols font.
      # Append it explicitly as a fallback for the generic families.
      localConf = /* xml */ ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <alias>
            <family>monospace</family>
            <prefer><family>Symbols Nerd Font Mono</family></prefer>
          </alias>
          <alias>
            <family>sans-serif</family>
            <prefer><family>Symbols Nerd Font</family></prefer>
          </alias>
          <alias>
            <family>serif</family>
            <prefer><family>Symbols Nerd Font</family></prefer>
          </alias>
        </fontconfig>
      '';
    };
    fontDir.decompressFonts = true;
  };

  boot = {
    consoleLogLevel = 3;
    initrd.verbose = false;

    plymouth.enable = true;

    # silent boot
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.system.show_status=auto"
    ];

    # hide os choice, still accessible by pressing any key during startup
    loader.timeout = 0;
  };
}
