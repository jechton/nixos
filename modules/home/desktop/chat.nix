{ pkgs, ... }:
{
  home.packages = [
    # keep-sorted start
    pkgs.signal-desktop
    pkgs.slack
    pkgs.telegram-desktop
    # keep-sorted end
  ];
}
