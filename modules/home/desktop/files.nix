{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    home.packages = [
      pkgs.file-roller
      pkgs.nautilus
    ];

    # Nautilus reads these from the GTK3 bookmarks file. The paths are the lazy
    # automounts from modules/system/bunpi-mounts.nix.
    gtk.gtk3.bookmarks = [
      "file:///mnt/bunpi bunpi"
      "file:///mnt/bunpi-home bunpi home"
    ];
  };
}
