{ lib, pkgs, ... }:
let
  inherit (lib.strings) concatStringsSep;

  avoid = concatStringsSep "|" [
    "niri"
    "niri-session"
    "xwayland-satellite"
    "quickshell"
    "cryptsetup"
    "dbus-.*"
    "gpg-agent"
    "greetd"
    "ssh-agent"
    ".*qemu-system.*"
    "sshd"
    "systemd"
    "systemd-.*"
    "ghostty"
    "bash"
    "zsh"
    "fish"
    "n?vim"
  ];

  prefer = concatStringsSep "|" [
    "Web Content"
    "Isolated Web Co"
    "firefox.*"
    "chrom(e|ium).*"
    "electron"
    "dotnet"
    ".*.exe"
    "java.*"
    "pipewire(.*)"
    "nix"
    "npm"
    "node"
  ];
in
{
  # https://dataswamp.org/~solene/2022-09-28-earlyoom.html
  # avoid the linux kernel from locking itself when we're putting too much strain on the memory
  # this helps avoid having to shut down forcefully when we OOM
  services = {
    earlyoom = {
      enable = true;
      enableNotifications = true; # annoying, but we want to know what's killed

      reportInterval = 0;
      freeSwapThreshold = 5;
      freeSwapKillThreshold = 2;
      freeMemThreshold = 5;
      freeMemKillThreshold = 2;

      extraArgs = [
        "-g"
        "--avoid"
        "'^(${avoid})$'" # things that we want to avoid killing
        "--prefer"
        "'^(${prefer})$'" # things we want to remove fast
      ];

      killHook = pkgs.writeShellScript "earlyoom-kill-hook" ''
        echo "Process $EARLYOOM_NAME ($EARLYOOM_PID) was killed"
      '';
    };

    systembus-notify.enable = lib.mkForce true;
  };
}
