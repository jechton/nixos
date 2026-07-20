{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  programs.dconf.enable = true;

  environment.variables = {
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland,x11";
    XDG_SESSION_TYPE = "wayland";
  };

  services = {
    gvfs.enable = true;
    udisks2.enable = true;

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    printing.enable = true;
    tumbler.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];

    # xdg-desktop-portal-gnome's ScreenCast implementation needs actual
    # Mutter/GNOME Shell to work, which niri doesn't provide; route
    # screencast through the wlr portal instead, which niri does support
    wlr = {
      enable = true;
      settings.screencast = {
        max_fps = 60;
        chooser_type = "simple";
        chooser_cmd = "${lib.getExe pkgs.slurp} -f %o -or";
      };
    };

    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];

      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];

      "org.freedesktop.impl.portal.Access" = [ "gtk" ];
      "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
    };
  };

  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default

    xwayland-satellite
    wl-clipboard
    grim
    slurp
    swappy
    brightnessctl
    playerctl
    pamixer
    pavucontrol
    networkmanagerapplet
  ];
}
