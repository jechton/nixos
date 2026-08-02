{ pkgs, ... }:
{
  home.packages = [
    # keep-sorted start
    pkgs.signal-desktop
    pkgs.slack
    pkgs.telegram-desktop
    # keep-sorted end
  ];

  programs.vesktop.enable = true;

  home.persistence."/persist".directories = [
    ".config/Signal"
    ".config/Slack"
    ".local/share/TelegramDesktop"
  ];
}
