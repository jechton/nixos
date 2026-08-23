{ lib, ... }:
let
  inherit (import ./_lib.nix { inherit lib; }) mkNodes;
in
{
  wayland.windowManager.niri.settings = {
    layout = {
      gaps = 10;
      border.off = { };
      focus-ring.width = 2;
      preset-column-widths._children = mkNodes "proportion" [
        0.33333
        0.5
        0.66667
        1.0
      ];
      default-column-width.proportion = 0.5;
      always-center-single-column = { };
    };
  };
}
