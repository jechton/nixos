{
  pkgs,
  inputs,
  ...
}: {
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  programs.dconf.enable = true;

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

    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];

      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];

      "org.freedesktop.impl.portal.Access" = ["gtk"];
      "org.freedesktop.impl.portal.Notification" = ["gtk"];
      "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
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
