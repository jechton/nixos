{ config, lib, ... }:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    # Opens the firewall ranges kdeconnect needs; the package
    # itself is skipped since home-manager's services.kdeconnect already
    # installs and runs it.
    programs.kdeconnect = {
      enable = true;
      package = null;
    };
  };
}
