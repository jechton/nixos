{ config, ... }:
{
  programs.solaar.enable = !config.burrow.profiles.vm.enable;
}
