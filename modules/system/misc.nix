{
  # disable stub-ld's warning about dynamically linked executables not
  # working on NixOS; we already know that
  environment.stub-ld.enable = false;

  # enables itself on graphical systems, but pulls in a ~700MiB speechd
  # closure we don't use; browsers ship their own minimal TTS anyway
  services.speechd.enable = false;

  systemd = {
    enableStrictShellChecks = true;

    settings.Manager = {
      DefaultTimeoutStartSec = "15s";
      DefaultTimeoutStopSec = "15s";
      DefaultTimeoutAbortSec = "15s";
      DefaultDeviceTimeoutSec = "15s";
    };

    user.settings.Manager = {
      DefaultTimeoutStartSec = "15s";
      DefaultTimeoutStopSec = "15s";
      DefaultTimeoutAbortSec = "15s";
      DefaultDeviceTimeoutSec = "15s";
    };
  };
}
