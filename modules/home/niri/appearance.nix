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
in {
  programs.niri = {
    config = lib.mkOptionDefault (lib.mkAfter [
      # (plain "window-rule" [
      #   (plain "background-effect" [
      #     (leaf "blur" true)
      #     (leaf "xray" true)
      #     (leaf "noise" 0.05)
      #     (leaf "saturation" 2.4)
      #   ])
      # ])
      # (plain "layer-rule" [
      #   (leaf "match" {namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel)$";})
      #   (plain "background-effect" [
      #     (leaf "blur" true)
      #     (leaf "xray" false)
      #     (leaf "noise" 0.05)
      #     (leaf "saturation" 2.6)
      #   ])
      # ])
      (plain "layer-rule" [
        (leaf "match" {namespace = "^noctalia-backdrop";})
        (leaf "place-within-backdrop" true)
      ])
      #   (plain "blur" [
      #     (leaf "passes" 3)
      #     (leaf "offset" 5.0)
      #     (leaf "noise" 0.04)
      #     (leaf "saturation" 1.8)
      #   ])
    ]);

    settings = {
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

      layout = {
        gaps = 10;
        border.enable = false;
        focus-ring = {
          enable = true;
          width = 2;
        };
        preset-column-widths = [
          {proportion = 0.33333;}
          {proportion = 0.5;}
          {proportion = 0.66667;}
          {proportion = 1.0;}
        ];
        default-column-width.proportion = 0.5;
        always-center-single-column = true;
      };

      cursor = {
        theme = config.stylix.cursor.name;
        size = config.stylix.cursor.size;
      };
    };
  };
}
