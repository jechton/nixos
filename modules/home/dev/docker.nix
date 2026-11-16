{ config, lib, ... }:
{
  home.persistence."/persist".directories = lib.mkIf (!config.burrow.profiles.vm.enable) [
    ".docker"
  ];
}
