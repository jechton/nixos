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

    # noctalia doesn't lock automatically on suspend (its PrepareForSleep
    # handler only manages idle-overlay/night-light/bluetooth), so lock
    # explicitly before sleep.target - covers lid close too, since that
    # also suspends via logind's default HandleLidSwitch.
    systemd.user.services.lock-before-sleep = {
      description = "Lock the session before suspending";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "noctalia msg session lock";
      };
    };
  };
}
