{ pkgs, ... }:
let
  # wireplumber writes the route's mute state to $XDG_STATE_HOME/wireplumber/
  # default-routes and restores it from there whenever the route reinitializes,
  # e.g. when noctalia restarts and reconnects wireplumber's mixer-api. Muting
  # via wpctl below persists "mute":true there, so leaving it would re-mute on
  # every such reconnect instead of just at boot. Flip it back to false right
  # after so the live sink stays muted now, but future restores default to
  # unmuted. Retry briefly since wireplumber writes the file asynchronously.
  # wireplumber can take a moment after startup to enumerate a default sink,
  # so @DEFAULT_AUDIO_SINK@ may resolve to no node yet right after the
  # service's After/Requires is satisfied. Retry until wpctl succeeds.
  muteDefaultSink = pkgs.writeShellScript "mute-default-sink" ''
    for _ in $(seq 1 20); do
      if ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 1; then
        exit 0
      fi
      sleep 0.1
    done
    exit 1
  '';

  resetMuteRestore = pkgs.writeShellScript "reset-mute-restore" ''
    file="$HOME/.local/state/wireplumber/default-routes"
    for _ in $(seq 1 20); do
      if [ -f "$file" ] && grep -q '"mute":true' "$file"; then
        sed -i 's/"mute":true/"mute":false/g' "$file"
        break
      fi
      sleep 0.1
    done
  '';
in
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
      ExecStart = "${muteDefaultSink}";
      ExecStartPost = [
        "${resetMuteRestore}"
        "${pkgs.coreutils}/bin/touch /run/user/%U/mute-audio-on-boot.done"
      ];
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
