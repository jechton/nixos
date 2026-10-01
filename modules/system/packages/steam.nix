{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    nixpkgs.overlays = [ inputs.millennium.overlays.default ];

    programs = {
      steam = {
        enable = true;
        package = pkgs.millennium-steam;
        protontricks.enable = true;
        gamescopeSession.enable = true;
        # For laptop, should set to gamescope -W 1920 -H 1200 -r 60 -f --adaptive-sync -- %command%
        #  Runs native res, enables VRR inside gamescope's own nested output (independent of niri's system VRR toggle), no upscale overhead for lighter games.
        extraCompatPackages = [ pkgs.proton-ge-bin ];
      };

      gamemode = {
        enable = true;
        settings = {
          general.renice = 10;
          custom = {
            start = "${pkgs.pipewire}/bin/pw-metadata -n settings 0 clock.force-quantum 64";
            end = "${pkgs.pipewire}/bin/pw-metadata -n settings 0 clock.force-quantum 0";
          };
        };
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

  };
}
