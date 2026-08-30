{ config, lib, ... }:
let
  inherit (import ./_lib.nix { inherit lib; }) mkNodes mkRule;

  windowRules = [
    {
      geometry-corner-radius = [
        0.0
        0.0
        0.0
        0.0
      ];
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
      matches = [
        { app-id = "^zen$"; }
        { app-id = "^zen-browser$"; }
        { app-id = "^zen-twilight$"; }
      ];
      draw-border-with-background = false;
    }
    {
      matches = [ { title = "^Extension: \\(Bitwarden Password Manager\\)"; } ];
      open-floating = true;
    }
    {
      matches = [
        { app-id = "^steam$"; }
        { app-id = "^Steam$"; }
        { app-id = "^com\\.heroicgameslauncher\\.hgl$"; }
        { app-id = "^net\\.lutris\\.Lutris$"; }
      ];
      variable-refresh-rate = true;
    }
    {
      matches = [
        { app-id = "^signal$"; }
        { app-id = "^org\\.telegram\\.desktop$"; }
        { app-id = "^telegram-desktop$"; }
      ];
      default-column-width.proportion = 0.33333;
    }
  ];

  layerRules = [
    {
      matches = [ { namespace = "^noctalia-backdrop"; } ];
      place-within-backdrop = true;
    }
  ];
in
{
  wayland.windowManager.niri.settings = {
    overview.zoom = 0.75;

    prefer-no-csd = { };
    debug.honor-xdg-activation-with-invalid-serial = { };

    cursor = {
      xcursor-theme = config.stylix.cursor.name;
      xcursor-size = config.stylix.cursor.size;
    };

    layout = {
      focus-ring.off = { };
      border = with config.lib.stylix.colors.withHashtag; {
        width = 2;
        active-color = base0D;
        inactive-color = base03;
      };
    };

    _children =
      (mkNodes "window-rule" (map mkRule windowRules)) ++ (mkNodes "layer-rule" (map mkRule layerRules));
  };
}
