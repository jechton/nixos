{
  services = {
    power-profiles-daemon.enable = true;
    upower.enable = true;
    tuned.ppdSettings.main.battery_detection = true;
  };

  systemd.services.fwupd-refresh = {
    after = ["polkit.service"];
    wants = ["polkit.service"];
  };
}
