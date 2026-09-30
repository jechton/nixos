{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs.zathura.enable = true;

    xdg.mimeApps.defaultApplications."application/pdf" = "org.pwmt.zathura.desktop";
  };
}
