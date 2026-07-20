{
  pkgs,
  lib,
  ...
}: {
  # Required for dconf to work during home-manager activation (GTK theming via stylix)
  programs.dconf.enable = true;

  fonts = {
    packages = lib.attrValues {
      inherit
        (pkgs)
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
    };
    fontDir.decompressFonts = true;
  };

  boot = {
    consoleLogLevel = 3;
    initrd.verbose = false;

    # silent boot
    kernelParams = ["quiet" "splash" "boot.shell_on_fail" "udev.log_priority=3" "rd.system.show_status=auto"];

    # hide os choice, still accessible by pressing any key during startup
    loader.timeout = 0;
  };
}
