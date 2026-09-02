{
  inputs,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  voxtypeEnabled = config.burrow.desktop.voxtype.enable;
  widgets = {
    # keep-sorted start block=yes
    clock = {
      actions.right = "exec xdg-open https://calendar.google.com/calendar/u/0/r";
      format = "%a %-m/%-d %-I:%M %P";
    };
    kimai.type = "jechton/kimai:bar";
    network.show_label = false;
    notifications.hide_when_no_unread = true;
    phone-connect = {
      type = "icefish/phone-connect:bar";
    };
    # opens jechton/phone-media's standalone synced-lyrics popup; the
    # now-playing popup below also embeds a compact version of the same view
    phone-lyrics.type = "jechton/phone-media:lyrics_bar";
    # replaces the builtin "media" widget and its control-center popup: same
    # now-playing display, plus scroll-to-change-phone-volume when the active
    # player is KDE Connect, minus the popup's spectrum visualizer, which
    # never shows anything for a KDE Connect player
    phone-media.type = "jechton/phone-media:bar";
    screen-toolkit.type = "alexander/screen-toolkit:widget";
    taskbar = {
      group_by_workspace = true;
      group_single_icon_per_app = true;
      hide_empty_workspaces = true;
      show_workspace_label = false;
      show_active_indicator = false;
    };
    tenpo-ko.type = "jechton/tenpo-ko:bar";
    udiskie = {
      hide_when_empty = true;
      type = "aristides/udiskie:status";
    };
    volume.mute_color = "outline";
    workspaces.style = "minimal";
    # keep-sorted end
  }
  // lib.optionalAttrs voxtypeEnabled {
    voxtype.type = "gabedunn/voxtype:status";
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Noctalia's live config is $XDG_STATE_HOME/noctalia/settings.toml (wiped on
  # boot, so it starts each session from the Nix-managed config.toml below).
  # niri spawns noctalia as a bare process, not a systemd unit, so a switch
  # can't restart it and mid-session settings changes here need a manual
  # `noctalia msg config-reload` (or restart / relogin). If the desktop-widget
  # editor was used this session, delete settings.toml's [desktop_widgets] block
  # first so the reload falls back to config.toml.

  # udiskie/udiskie-info binaries the aristides/udiskie plugin shells out to;
  # udisks2 itself is already enabled system-wide in modules/system/niri.nix.
  # glib provides gdbus, which the phone-connect plugin shells out to for all
  # KDE Connect device queries.
  # grim/slurp/swappy are already on PATH from modules/system/niri.nix. The rest
  # are the alexander/screen-toolkit plugin's runtime dependencies for OCR,
  # colour picking, QR decoding, palette extraction, translation and recording.
  home.packages = [
    pkgs.bc
    pkgs.ffmpeg
    pkgs.glib
    pkgs.gpu-screen-recorder
    pkgs.hyprpicker
    pkgs.imagemagick
    pkgs.jq
    pkgs.satty
    pkgs.tesseract
    pkgs.translate-shell
    pkgs.udiskie
    pkgs.zbar
  ];

  # Curated wallpapers checked into the repo. recursive=true keeps the
  # directory itself writable, so wallhaven's plugin can still download new
  # wallpapers alongside these without conflicting with the managed symlinks.
  home.file."Pictures/Wallpapers" = {
    source = ./wallpapers;
    recursive = true;
  };

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

    # The build-time config validator runs in the Nix sandbox, where it can't
    # load the local path plugin source (jechton/*), so it warns that these
    # plugins' widget types are "unrecognized". The config is fine: it
    # validates cleanly outside the sandbox and the plugin loads at runtime.
    # nix flake check plus noctalia's own startup validation still cover us.
    checkConfig = false;

    settings = {
      # keep-sorted start block=yes newline_separated=yes
      backdrop = {
        enabled = true;
        blur_intensity = 0.85;
        tint_intensity = 0.45;
      };

      bar.default = {
        thickness = 24;
        margin_edge = 0;
        margin_ends = 0;
        radius = 0;
        shadow = false;

        start = [
          "launcher"
          "workspaces"
          "taskbar"
          "phone-media"
          "phone-lyrics"
        ];
        end = [
          "tray"
          "udiskie"
          "kimai"
          "screen-toolkit"
        ]
        ++ lib.optional voxtypeEnabled "voxtype"
        ++ [
          "phone-connect"
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

      # account name must stay "personal_google" to match the OAuth token
      # already stored in the (persisted) system keyring
      calendar = {
        enabled = true;
        account.personal_google.type = "google";
      };

      control_center = {
        calendar.event_time_format = "%-I:%M %P";
        sidebar_section = "none";
        # hide tabs for hardware that isn't actually present, rather than
        # keying off the vm profile: bluetooth.nix only flips hardware.bluetooth
        # on when facter detected an adapter, and power.nix only enables upower
        # when there's power management (i.e. battery) hardware to report on
        hidden_tabs =
          lib.optional (!osConfig.hardware.bluetooth.enable) "bluetooth"
          ++ lib.optional (!osConfig.services.upower.enable) "power";
      };

      # Both widgets align to where a left-hand window sits, stacked, so that
      # window covers them. Offsets mirror niri's geometry: left edge = `gaps
      # 10`, top edge = 24px bar + `gaps 10` = 34, and the 10px between the two
      # boxes (and the people widget's internal cell gaps) is the same `gaps 10`.
      # cx/cy are the box CENTER, so cx = left_edge + box_width/2, cy = top_edge
      # + box_height/2. Nudge in the editor and copy the numbers back.
      desktop_widgets = {
        schema_version = 2;
        widget_order = [
          "desktop-widget-0000000000000001"
          "desktop-widget-0000000000000003"
        ];

        grid = {
          cell_size = 32;
          major_interval = 4;
          visible = true;
        };

        widget = {
          # People / whereabouts: a single row of 4. left edge 10, top edge 34,
          # box 608x64 -> cx = 10 + 304, cy = 34 + 32.
          "desktop-widget-0000000000000001" = {
            box_height = 64.0;
            box_width = 608.0;
            cx = 314.0;
            cy = 66.0;
            output = "eDP-1";
            placement_height = 1200.0;
            placement_width = 1920.0;
            rotation = 0.0;
            type = "jechton/home-assistant:template-desktop";
            settings = {
              background_radius = 0;
              cell_align = "center";
              cell_width = 140;
              columns = 4;
              column_gap = 10;
              font_size = 42;
              row_gap = 10;
              template_file = osConfig.age.secrets.home-assistant-people-template.path;
              title = "";
            };
          };
          # Calendar: directly below, one window-gap (10px) down. left edge 10,
          # top edge 108 (34 + 64 + 10), box 608x416 -> cx = 314, cy = 108 + 208.
          "desktop-widget-0000000000000003" = {
            box_height = 416.0;
            box_width = 608.0;
            cx = 314.0;
            cy = 316.0;
            output = "eDP-1";
            placement_height = 1200.0;
            placement_width = 1920.0;
            rotation = 0.0;
            type = "calendar";
            settings = {
              background = true;
              background_color = "surface";
              background_opacity = 0.8;
              background_padding = 10;
              background_radius = 0;
              font_family = "";
              show_events = true;
              show_week_numbers = false;
            };
          };
        };
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

      plugin_settings = {
        "icefish/phone-connect" = {
          battery_display = "hidden";
        };
        "jechton/home-assistant" = {
          # Secret file: line 1 the HA URL, line 2 a long-lived access token.
          credentials_file = osConfig.age.secrets.home-assistant-credentials.path;
        };
        "jechton/kimai" = {
          # Secret file: line 1 the Kimai URL, line 2 an API token.
          credentials_file = osConfig.age.secrets.kimai-credentials.path;
        };
        "yuuto/calculator" = {
          panel_placement = "floating";
          panel_position = "center";
        };
      };

      plugins = {
        enabled = [
          "alexander/screen-toolkit"
          "aristides/udiskie"
          "icefish/phone-connect"
          "jechton/home-assistant"
          "jechton/kimai"
          "jechton/phone-media"
          "jechton/tenpo-ko"
          "noctalia/wallhaven"
          "yuuto/calculator"
        ]
        ++ lib.optional voxtypeEnabled "gabedunn/voxtype";

        # Every source is pinned by Nix (flake inputs or this repo), so noctalia
        # must never try to update them itself.
        auto_update = "none";

        source = [
          {
            name = "official";
            kind = "path";
            location = toString inputs.noctalia-official-plugins;
          }
          {
            name = "community";
            kind = "path";
            location = toString inputs.noctalia-community-plugins;
          }
          {
            name = "local";
            kind = "path";
            location = toString inputs.noctalia-plugins;
          }
        ];
      };

      shell = {
        corner_radius_scale = 0.0;
        setup_wizard_enabled = false;
        time_format = "%-I:%M %P";
        polkit_agent = true;
        avatar_path = "${config.home.homeDirectory}/.face";
        screenshot.directory = "~/Pictures/Screenshots";
        font_family = lib.mkForce config.burrow.theme.fonts.monospace.name;

        launcher = {
          categories = false;
          compact = true;
        };

        panel.open_near_click_control_center = true;
      };

      theme.templates = {
        enable_builtin_templates = false;
        enable_community_templates = false;
      };

      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/Pictures/Wallpapers";

        automation = {
          enabled = true;
          interval_seconds = 1800;
          order = "random";
          recursive = true;
        };
      };

      weather.unit = "imperial";

      widget = widgets;
      # keep-sorted end
    };
  };
}
