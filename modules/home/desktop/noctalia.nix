{
  inputs,
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  hyprwhspr = pkgs.callPackage ../../../pkgs/hyprwhspr/package.nix { };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Hide launcher entries for background/tray tooling that shouldn't show up
  # as user-facing apps: noctalia itself, and Qt theming helpers pulled in by
  # stylix's qt target (qt5ct/qt6ct/kvantummanager).
  xdg.dataFile =
    lib.genAttrs
      [
        "applications/dev.noctalia.Noctalia.desktop"
        "applications/qt5ct.desktop"
        "applications/qt6ct.desktop"
        "applications/kvantummanager.desktop"
      ]
      (_: {
        text = ''
          [Desktop Entry]
          Type=Application
          NoDisplay=true
        '';
      });

  programs.noctalia = {
    enable = true;
    settings = {
      # keep-sorted start block=yes newline_separated=yes
      backdrop = {
        enabled = true;
        blur_intensity = 0.85;
        tint_intensity = 0.45;
      };

      bar.default = {
        margin_edge = 0;
        margin_ends = 0;
        radius = 0;
        shadow = false;

        start = [
          "launcher"
          "workspaces"
          "media"
        ];
        end = [
          "noctalia/bongocat:cat"
          "tray"
          "notifications"
          "goodroot/noctwhspr:status"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "session"
        ];
      };

      # hide tabs for hardware that isn't actually present, rather than
      # keying off the vm profile: bluetooth.nix only flips hardware.bluetooth
      # on when facter detected an adapter, and power.nix only enables upower
      # when there's power management (i.e. battery) hardware to report on
      control_center.hidden_tabs =
        lib.optional (!osConfig.hardware.bluetooth.enable) "bluetooth"
        ++ lib.optional (!osConfig.services.upower.enable) "power";

      idle = {
        behavior_order = [
          "lock"
          "screen-off"
          "lock-and-suspend"
        ];

        behavior = {
          lock = {
            action = "lock";
            enabled = true;
            timeout = 600.0;
          };
          screen-off = {
            action = "screen_off";
            enabled = true;
            timeout = 660.0;
          };
        };
      };

      location.auto_locate = true;

      lockscreen = {
        blur_intensity = 0.75;
        blurred_desktop = true;
      };

      nightlight.enabled = true;

      notification = {
        offset_x = 8;
        offset_y = 8;
      };

      # the noctwhspr widget looks here first, before HYPRWHSPR_ROOT / its
      # /usr/lib/hyprwhspr default, since we install to the nix store instead
      plugin_settings."goodroot/noctwhspr".root = "${hyprwhspr}/lib/hyprwhspr";

      plugins = {
        enabled = [
          "goodroot/noctwhspr"
          "noctalia/wallhaven"
        ];

        source = [
          {
            name = "official";
            kind = "path";
            location = toString inputs.noctalia-official-plugins;
            auto_update = false;
          }
          {
            name = "community";
            kind = "path";
            location = toString inputs.noctalia-community-plugins;
            auto_update = false;
          }
        ];
      };

      shell = {
        corner_radius_scale = 0.0;
        setup_wizard_enabled = false;
        time_format = "%-I:%M %p";
        polkit_agent = true;
        avatar_path = "${config.home.homeDirectory}/.face";
        screenshot.directory = "~/Pictures/Screenshots";
        font_family = lib.mkForce config.burrow.theme.fonts.monospace.name;

        launcher = {
          categories = false;
          compact = true;
        };
      };

      theme.templates = {
        enable_builtin_templates = false;
        enable_community_templates = false;
      };

      weather.unit = "imperial";

      widget = {
        # keep-sorted start block=yes
        clock.format = "%a %-m/%-d %-I:%M %p";
        media.hide_when_no_media = true;
        network.show_label = false;
        notifications.hide_when_no_unread = true;
        volume.mute_color = "outline";
        workspaces.minimal = true;
        # keep-sorted end
      };
      # keep-sorted end
    };
  };
}
