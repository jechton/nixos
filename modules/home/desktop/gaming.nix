{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs.prismlauncher.enable = true;

    home.packages = with pkgs; [
      # keep-sorted start
      bottles
      itch
      osu-lazer-bin
      # keep-sorted end
    ];

    home.persistence."/persist".directories = [
      # keep-sorted start
      ".config/itch"
      ".local/share/Steam"
      ".local/share/bottles"
      ".local/share/osu"
      ".steam"
      # keep-sorted end
    ];
  };
}
