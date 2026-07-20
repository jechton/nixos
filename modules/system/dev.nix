{ lib, config, ... }:
{
  virtualisation.docker = lib.mkIf (!config.burrow.profiles.vm.enable) {
    enable = true;
    autoPrune.enable = true;
  };
}
