{
  inputs,
  lib,
  config,
  ...
}: let
  inherit
    (inputs.niri.lib.kdl)
    leaf
    plain
    ;

  windowOpenShader = ''
    vec4 open_color(vec3 coords_geo, vec3 size_geo) {
          float progress = niri_clamped_progress;
          float opacity = clamp(progress * 1.5, 0.0, 1.0);
          float slide_distance = 0.05;
          float y_offset = (1.0 - progress) * slide_distance;
          float scale = 0.95 + (0.05 * progress);
          vec3 coords = vec3((coords_geo.xy - vec2(0.5, 1.0)) / scale + vec2(0.5, 1.0), 1.0);
          coords.y -= y_offset;
          vec3 coords_tex = niri_geo_to_tex * coords;
          vec4 color = texture2D(niri_tex, coords_tex.st);
          return color * opacity;
      }
  '';

  windowCloseShader = ''
    vec4 close_color(vec3 coords_geo, vec3 size_geo) {
        float progress = 1.0 - niri_clamped_progress;
        float opacity = progress;
        float slide_distance = 0.05;
        float y_offset = (1.0 - progress) * slide_distance;
        float scale = 0.95 + (0.05 * progress);
        vec3 coords = vec3((coords_geo.xy - vec2(0.5, 1.0)) / scale + vec2(0.5, 1.0), 1.0);
        coords.y -= y_offset;
        vec3 coords_tex = niri_geo_to_tex * coords;
        vec4 color = texture2D(niri_tex, coords_tex.st);
        return color * opacity;
    }
  '';

  spring = stiffness: {
    damping-ratio = 1.0;
    inherit stiffness;
    epsilon = 0.0001;
  };
in {
  programs.niri = {
    config = lib.mkOptionDefault (lib.mkAfter [
      (plain "layer-rule" [
        (leaf "match" {namespace = "^noctalia-backdrop";})
        (leaf "place-within-backdrop" true)
      ])
    ]);

    settings = {
      animations = {
        workspace-switch.kind.spring = spring 1000;
        horizontal-view-movement.kind.spring = spring 1000;
        window-movement.kind.spring = spring 1000;
        window-resize.kind.spring = spring 1000;
        overview-open-close.kind.spring = spring 850;
        window-open = {
          kind.easing = {
            duration-ms = 300;
            curve = "ease-out-cubic";
          };
          custom-shader = windowOpenShader;
        };
        window-close = {
          kind.easing = {
            duration-ms = 200;
            curve = "ease-out-quad";
          };
          custom-shader = windowCloseShader;
        };
        config-notification-open-close.kind.spring = {
          damping-ratio = 0.95;
          stiffness = 900;
          epsilon = 0.001;
        };
        screenshot-ui-open.kind.easing = {
          duration-ms = 200;
          curve = "ease-out-quad";
        };
      };

      window-rules = [
        {
          geometry-corner-radius = {
            top-left = 0.0;
            top-right = 0.0;
            bottom-right = 0.0;
            bottom-left = 0.0;
          };
          clip-to-geometry = true;
        }
        {
          matches = [
            {
              title = "^(Open|Save|Save As|Open File|Choose File|Select File|File Upload|Preferences|Settings|Noctalia Settings)$";
            }
          ];
          open-floating = true;
          default-column-width.proportion = 0.5;
          default-window-height.fixed = 720;
        }
        {
          matches = [{app-id = "^zen$";} {app-id = "^zen-browser$";}];
          draw-border-with-background = false;
        }
        {
          matches = [
            {app-id = "^steam$";}
            {app-id = "^Steam$";}
            {app-id = "^com\\.heroicgameslauncher\\.hgl$";}
            {app-id = "^net\\.lutris\\.Lutris$";}
          ];
          variable-refresh-rate = true;
        }
      ];
      prefer-no-csd = true;
      debug.honor-xdg-activation-with-invalid-serial = [];

      cursor = {
        theme = config.stylix.cursor.name;
        size = config.stylix.cursor.size;
      };
    };
  };
}
