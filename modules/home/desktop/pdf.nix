{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs.zathura = {
      enable = true;
      # Only differences from the zathura defaults: j/k change pages, J/K scroll.
      mappings = {
        "j" = "navigate next";
        "k" = "navigate previous";
        "J" = "scroll down";
        "K" = "scroll up";
        "ge" = "goto bottom";
        "0" = "zoom default";
      };
    };

    xdg.mimeApps.defaultApplications."application/pdf" = "org.pwmt.zathura.desktop";
  };
}
