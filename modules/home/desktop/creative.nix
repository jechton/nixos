{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs = {
      obs-studio.enable = true;
      obsidian.enable = true;
    };

    home.packages = with pkgs; [
      # keep-sorted start
      aseprite
      blender
      gimp
      inkscape
      libreoffice-stable
      # keep-sorted end
    ];
  };
}
