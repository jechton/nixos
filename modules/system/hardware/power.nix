{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;

  # tuned's battery_detection only retunes the *current* PPD profile for
  # AC vs battery - it never changes which profile (performance/balanced/
  # power-saver) is active. This script picks the profile itself: performance
  # on AC, power-saver under the low-battery threshold, balanced otherwise.
  lowBatteryPercent = 20;
  setPowerProfile = pkgs.writeShellScript "set-power-profile" ''
    set -eu
    PATH=${
      lib.makeBinPath [
        pkgs.power-profiles-daemon
        pkgs.gnugrep
      ]
    }

    ac_online=$(cat /sys/class/power_supply/A*/online 2>/dev/null | grep -m1 1 || true)
    capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || true)

    if [ -n "$ac_online" ]; then
      profile=performance
    elif [ -n "$capacity" ] && [ "$capacity" -le ${toString lowBatteryPercent} ]; then
      profile=power-saver
    else
      profile=balanced
    fi

    powerprofilesctl set "$profile"
  '';
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

      udev.extraRules = ''
        SUBSYSTEM=="power_supply", RUN+="${setPowerProfile}"
      '';

      logind.settings.Login = {
        # hibernate is disabled (security.protectKernelImage sets nohibernate),
        # so use plain suspend instead of suspend-then-hibernate
        HandlePowerKey = "suspend";
      };
    };

    # set the initial profile at boot; udev only fires on subsequent changes
    systemd.services.set-initial-power-profile = {
      description = "Set initial power profile based on AC/battery state";
      after = [ "tuned-ppd.service" ];
      wants = [ "tuned-ppd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${setPowerProfile}";
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
