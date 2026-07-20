{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    programs = {
      steam = {
        enable = true;
        protontricks.enable = true;
        gamescopeSession.enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
      };

      gamemode = {
        enable = true;
        settings.general.renice = 10;
      };

      gamescope = {
        enable = true;
        capSysNice = true;
        args = [
          "--rt"
          "--expose-wayland"
        ];
      };
    };

    services.pipewire.lowLatency = {
      enable = true;
      quantum = 64;
      rate = 48000;
    };
  };
}
