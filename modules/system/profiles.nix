{ lib, ... }:
let
  inherit (lib.options) mkEnableOption;
in
{
  options.burrow.profiles = {
    laptop.enable = mkEnableOption "Laptop";
  };
}
