{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
in
{
  config = mkIf config.burrow.profiles.laptop.enable {
    environment.systemPackages = [
      pkgs.acpi
      pkgs.powertop
    ];

    services = {
      acpid.enable = true;
      tuned = {
        enable = true;
        ppdSettings.main.battery_detection = true;
      };
      upower.enable = true;

      logind.settings.Login = {
        # hibernate is disabled (security.protectKernelImage sets nohibernate),
        # so use plain suspend instead of suspend-then-hibernate
        HandlePowerKey = "suspend";
      };
    };
  };
}
