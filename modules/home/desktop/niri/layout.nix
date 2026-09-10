{ lib, ... }:
let
  inherit (import ./_lib.nix { inherit lib; }) mkNodes columnWidths;
in
{
  wayland.windowManager.niri.settings = {
    layout = {
      gaps = 10;
      preset-column-widths._children = mkNodes "proportion" [
        columnWidths.third
        columnWidths.half
        columnWidths.twoThirds
        columnWidths.full
      ];
      default-column-width.proportion = columnWidths.half;
      always-center-single-column = { };
    };
  };
}
