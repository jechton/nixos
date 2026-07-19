{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.nix-gaming.nixosModules.pipewireLowLatency];

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [pkgs.proton-ge-bin];
  };

  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };

  services.pipewire.lowLatency = {
    enable = true;
    quantum = 64;
    rate = 48000;
  };
}
