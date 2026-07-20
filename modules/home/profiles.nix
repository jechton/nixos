{ lib, osConfig, ... }:
let
  inherit (lib.options) mkEnableOption;
in
{
  options.burrow.profiles = {
    laptop.enable = mkEnableOption "Laptop";
  };

  config = {
    burrow.profiles = {
      inherit (osConfig.burrow.profiles) laptop;
    };
  };
}
