{ lib, osConfig, ... }:
let
  inherit (lib.options) mkEnableOption;
in
{
  options.burrow.profiles = {
    laptop.enable = mkEnableOption "Laptop";
    vm.enable = mkEnableOption "Virtual machine";
  };

  config = {
    burrow.profiles = {
      inherit (osConfig.burrow.profiles) laptop vm;
    };
  };
}
