{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # lazy: xwayland-satellite 0.8.2 (current nixpkgs pin) drops override-redirect
  # popups instantly, breaking Steam's context/top-bar menus. Fix is merged
  # upstream (Supreeeme/xwayland-satellite#494) but unreleased; drop this
  # override once nixpkgs bumps past 0.8.2.
  nixpkgs.overlays = [
    (final: prev: {
      xwayland-satellite = prev.xwayland-satellite.overrideAttrs (
        old:
        let
          version = "0.8.2-unstable-2026-09-26";
          src = final.fetchFromGitHub {
            owner = "Supreeeme";
            repo = "xwayland-satellite";
            rev = "add2795134593faafce60e404a0a75df68e9ee0c";
            hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
          };
        in
        {
          inherit version src;
          cargoDeps = final.rustPlatform.fetchCargoVendor {
            inherit (old) pname;
            inherit version src;
            hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
          };
        }
      );
    })
  ];

  programs.niri.enable = true;

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

    # programs.niri.enable's default xdg.portal.config.niri prefers
    # gnome before gtk with no per-interface override. xdg-desktop-portal-gnome
    # only implements FileChooser under real Mutter/GNOME Shell; under niri it
    # logs "Non-compatible display server, exposing settings only" and the
    # call fails outright instead of falling back to gtk. Route FileChooser
    # through gtk explicitly. Same story for ScreenCast, which needs actual
    # Mutter/GNOME Shell and doesn't work there either; route it through wlr.
    config.niri = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
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
