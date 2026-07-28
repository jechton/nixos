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
      osu-laser-bin
      # keep-sorted end
    ];
  };
}
