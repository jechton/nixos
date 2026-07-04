{pkgs, ...}: {
  # Required for dconf to work during home-manager activation (GTK theming via stylix)
  programs.dconf.enable = true;

  fonts = {
    packages = [
      # keep-sorted start
      pkgs.atkinson-hyperlegible-next
      pkgs.corefonts
      # keep-sorted end
    ];
    enableDefaultPackages = true;
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
