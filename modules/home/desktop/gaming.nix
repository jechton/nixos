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
      (bottles.override { removeWarningPopup = true; })
      itch
      osu-lazer-bin
      wineasio
      # keep-sorted end
    ];

    home.persistence."/persist".directories = [
      # keep-sorted start
      ".config/itch"
      ".config/millennium"
      ".local/share/Steam"
      ".local/share/bottles"
      ".local/share/osu"
      ".renpy"
      ".steam"
      # keep-sorted end
    ];
  };
}
