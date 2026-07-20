{
  inputs,
  config,
  ...
}:
{
  imports = [ inputs.noctalia.homeModules.default ];

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
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "session"
        ];
      };

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

      shell = {
        corner_radius_scale = 0.0;
        setup_wizard_enabled = false;
        time_format = "%-I:%M %p";
        polkit_agent = true;
        avatar_path = "${config.home.homeDirectory}/.face";
        screenshot.directory = "~/Pictures/Screenshots";

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
        clock.format = "%a %-m/%e %-I:%M %p";
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
