{ pkgs, ... }:
{
  # mute the default sink once per boot, not on every home-manager switch.
  # the stamp lives in /run (tmpfs), so it clears on reboot and the
  # ConditionPathExists guard turns the unit into a no-op on later restarts.
  systemd.user.services.mute-audio-on-boot = {
    Unit = {
      Description = "Mute default audio sink on boot";
      After = [ "wireplumber.service" ];
      Requires = [ "wireplumber.service" ];
      ConditionPathExists = "!/run/user/%U/mute-audio-on-boot.done";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 1";
      ExecStartPost = "${pkgs.coreutils}/bin/touch /run/user/%U/mute-audio-on-boot.done";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # pkgs.rnnoise-plugin is already loaded system-wide via
  # services.pipewire.extraLadspaPackages (see hardware/audio.nix); this wires
  # it into an actual "Noise Canceling source" virtual mic
  xdg.configFile."pipewire/pipewire.conf.d/99-input-denoising.conf".text = builtins.toJSON {
    "context.modules" = [
      {
        "name" = "libpipewire-module-filter-chain";
        "args" = {
          "node.description" = "Noise Canceling source";
          "media.name" = "Noise Canceling source";
          "filter.graph" = {
            "nodes" = [
              {
                "type" = "ladspa";
                "name" = "rnnoise";
                "plugin" = "librnnoise_ladspa";
                "label" = "noise_suppressor_stereo";
                "control" = {
                  "VAD Threshold (%)" = 60.0;
                  "VAD Grace Period (ms)" = 20;
                  "Retroactive VAD Grace (ms)" = 0;
                };
              }
            ];
          };
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = "effect_input.rnnoise";
            "node.passive" = true;
          };
          "playback.props" = {
            "node.name" = "effect_output.rnnoise";
            "media.class" = "Audio/Source";
          };
        };
      }
    ];
  };
}
