{
  lib,
  config,
  ...
}:
let
  inherit (lib.modules) mkIf;
in
{
  config = mkIf config.hardware.facter.detected.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;

      disabledPlugins = [
        "sap"
        "handsfree"
      ];

      settings = {
        General = {
          JustWorksRepairing = "always";
          MultiProfile = "multiple";
          Enable = "Source,Sink,Media,Socket";
          FastConnectable = true;
          Experimental = true;
          KernelExperimental = true;
        };

        Policy = {
          AutoEnable = true;
          ReconnectAttempts = 7;
          ReconnectIntervals = "1, 2, 4, 8, 16, 32, 64";
        };
      };
    };

    boot.kernelModules = [ "btusb" ];

    services.blueman.enable = true;
  };
}
