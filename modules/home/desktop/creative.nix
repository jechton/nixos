{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs.obs-studio.enable = true;

    # programs.obsidian is not used: with no vaults configured it only adds an
    # activation script that rewrites ~/.config/obsidian/obsidian.json via
    # `install`, which fails because impermanence bind-mounts that file. Obsidian
    # manages its own vault registry at runtime and it persists via that mount.
    home.packages = with pkgs; [
      # keep-sorted start
      aseprite
      blender
      gimp
      hunspell
      hunspellDicts.en_US
      inkscape
      libreoffice-stable
      obsidian
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
      ".config/libreoffice"
    ];
  };
}
