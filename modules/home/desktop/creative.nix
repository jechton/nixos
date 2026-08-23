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
      hunspell
      hunspellDicts.en_US
      inkscape
      languagetool
      libreoffice-stable
      # keep-sorted end
    ];

    xdg.mimeApps.defaultApplications =
      let
        officeSuite = "startcenter.desktop";
      in
      {
        "application/msword" = "writer.desktop";
        "application/vnd.ms-excel" = "calc.desktop";
        "application/vnd.ms-powerpoint" = "impress.desktop";
        "application/vnd.oasis.opendocument.*" = officeSuite;
        "application/vnd.openxmlformats-officedocument.*" = officeSuite;
      };

    home.persistence."/persist".directories = [
      ".config/LanguageTool"
      ".config/libreoffice"
    ];
  };
}
